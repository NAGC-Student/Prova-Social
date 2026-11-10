import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/answer_key_parser.dart';
import 'package:prova_social/core/import/question_parser.dart';

ImportedQuestion choice(int number, {int options = 4, int? correctIndex}) =>
    ImportedQuestion(
      number: number,
      statement: 'Enunciado da questão $number.',
      options: [
        for (var index = 0; index < options; index++)
          'Alternativa ${String.fromCharCode(65 + index)}',
      ],
      correctIndex: correctIndex,
    );

ImportedQuestion judged(int number, {List<String>? options}) =>
    ImportedQuestion(
      number: number,
      statement: 'Item $number da prova de certo ou errado.',
      options: options ?? const ['CERTO', 'ERRADO'],
      format: QuestionFormat.trueFalse,
    );

void main() {
  const parser = AnswerKeyParser();

  group('formatos de gabarito impresso', () {
    test('lê o título e a lista “01 - B”', () {
      final key = parser.parsePages([
        'Questão 1 trata do texto abaixo.',
        'GABARITO OFICIAL\n01 - B\n02 - C\n03 - A',
      ]);
      expect(key.byNumber, {1: 'B', 2: 'C', 3: 'A'});
      expect(key.heading, 'GABARITO OFICIAL');
      expect(key.pages, [2]);
    });

    test('aceita marcadores variados no mesmo bloco', () {
      final key = parser.parsePages([
        'CHAVE DE RESPOSTAS\n(1) D\n2. B\n3) A\n4 | C\n05/E\n6  B',
      ]);
      expect(key.byNumber, {1: 'D', 2: 'B', 3: 'A', 4: 'C', 5: 'E', 6: 'B'});
    });

    test('lê a grade em colunas do caderno', () {
      final key = parser.parsePages([
        'GABARITO\n'
            '1 A   11 B   21 C   31 D\n'
            '2 B   12 C   22 D   32 A\n'
            '3 C   13 D   23 A   33 B',
      ]);
      expect(key.byNumber[1], 'A');
      expect(key.byNumber[11], 'B');
      expect(key.byNumber[23], 'A');
      expect(key.byNumber[33], 'B');
      expect(key.length, 12);
    });

    test('lê grades cujos números e letras viraram linhas separadas', () {
      final key = parser.parsePages([
        'GABARITO OFICIAL\n'
            '01\nB\n02\nC\n03\nA\n04\nD\n05\nB\n06\nC\n'
            '07\nA\n08\nD\n09\nB\n10\nC\n11\nA\n12\nD',
      ]);

      expect(key.length, 12);
      expect(key.byNumber[1], 'B');
      expect(key.byNumber[12], 'D');
    });

    test('emenda o gabarito que não coube em uma página', () {
      final key = parser.parsePages([
        'GABARITO\n1-B\n2-C\n3-A',
        '4-D\n5-B\n6-C',
      ]);
      expect(key.byNumber, {1: 'B', 2: 'C', 3: 'A', 4: 'D', 5: 'B', 6: 'C'});
      expect(key.pages, [1, 2]);
    });

    test('lê certo e errado por extenso', () {
      final key = parser.parsePages([
        'GABARITO\n1 – CERTO\n2 – ERRADO\n3 – Certo\n4 – Errado',
      ]);
      expect(key.byNumber, {1: 'C', 2: 'E', 3: 'C', 4: 'E'});
    });

    test('preserva a chave V/F escrita em letras', () {
      final key = parser.parsePages(['GABARITO\n1 V\n2 F\n3 V']);
      expect(key.byNumber, {1: 'V', 2: 'F', 3: 'V'});
    });
  });

  group('confiança', () {
    test('ignora o gabarito citado em prosa, sem sequência', () {
      final key = parser.parsePages([
        'O gabarito preliminar será divulgado no dia 12 de maio, às 10h.',
        'Confira a resposta da questão 5 (letra A) e da questão 9 (letra B).',
      ]);
      expect(key.isEmpty, isTrue);
    });

    test('exige três números consecutivos sob o título', () {
      final key = parser.parsePages(['GABARITO\n1-B\n5-C\n9-A']);
      expect(key.isEmpty, isTrue);
    });

    test('arquivo sem título precisa de uma sequência longa', () {
      expect(parser.parseText('1 A\n2 B\n3 C').isEmpty, isTrue);
      final long = parser.parseText(
        [
          for (var number = 1; number <= 20; number++)
            '$number ${String.fromCharCode(65 + number % 4)}',
        ].join('\n'),
      );
      expect(long.length, 20);
      expect(long.heading, isNull);
    });

    test('o enunciado das questões não vira gabarito sem título', () {
      final key = parser.parseText(
        'Questão 1\nLeia o texto abaixo.\n(A) primeira\n(B) segunda\n'
        '(C) terceira\n(D) quarta\nQuestão 2\nObserve as colunas 3 A 4 B.',
      );
      expect(key.isEmpty, isTrue);
    });

    test('dois cadernos: o maior vence e o outro só preenche lacunas', () {
      final key = parser.parsePages([
        'GABARITO PROVA B\n1-B\n2-B\n3-B',
        'GABARITO PROVA A\n1-A\n2-A\n3-A\n4-A\n5-A\n6-A',
      ]);
      expect(key.byNumber.values.toSet(), {'A'});
      expect(key.length, 6);
    });
  });

  group('aplicação nas questões', () {
    test('preenche a alternativa correta pelo número', () {
      final questions = [choice(1), choice(2), choice(3)];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-B\n2-D\n3-A'),
        questions,
      );
      expect(questions.map((q) => q.correctIndex), [1, 3, 0]);
      expect(result.applied, 3);
      expect(result.keyable, 3);
      expect(result.coverage, 1);
      expect(result.withoutKey, isEmpty);
      expect(result.unmatched, isEmpty);
    });

    test('não sobrescreve a marcação manual do revisor', () {
      final questions = [choice(1, correctIndex: 2), choice(2)];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-A\n2-A\n3-A'),
        questions,
      );
      expect(questions.first.correctIndex, 2);
      expect(questions.last.correctIndex, 0);
      expect(result.applied, 1);
    });

    test('letra fora do intervalo de alternativas fica sem resposta', () {
      final questions = [choice(1), choice(2)];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-D\n2-E\n3-A'),
        questions,
      );
      expect(questions.first.correctIndex, 3);
      expect(questions.last.correctIndex, isNull);
      expect(result.withoutKey, [2]);
      expect(result.unmatched, [3]);
      expect(result.coverage, .5);
    });

    test('usa a ordem das alternativas do item julgado', () {
      final questions = [
        judged(1),
        judged(2, options: const ['ERRADO', 'CERTO']),
        judged(3),
      ];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-C\n2-E\n3-V\n4-F'),
        questions,
      );
      expect(questions.map((q) => q.correctIndex), [0, 0, 0]);
      expect(result.applied, 3);
    });

    test('questão sem alternativas não entra na conta', () {
      final questions = [
        choice(1),
        ImportedQuestion(
          number: 2,
          statement: 'Redija um texto dissertativo.',
          options: const [],
        ),
      ];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-A\n2-B\n3-C'),
        questions,
      );
      expect(result.keyable, 1);
      expect(result.applied, 1);
    });

    test('questão sem número fica de fora', () {
      final questions = [
        ImportedQuestion(
          statement: 'Questão sem numeração.',
          options: const ['A', 'B', 'C', 'D'],
        ),
      ];
      final result = parser.apply(
        parser.parseText('GABARITO\n1-A\n2-B\n3-C'),
        questions,
      );
      expect(result.keyable, 0);
      expect(result.applied, 0);
      expect(result.unmatched, [1, 2, 3]);
    });
  });

  group('convivência com as páginas do extrator', () {
    test('tolera as páginas marcadas pelo sentinela', () {
      final key = parser.parsePages([
        '\u0000PROVA_SOCIAL_PAGE_1\u0000\nGABARITO\n1-B\n2-C',
        '\u0000PROVA_SOCIAL_PAGE_2\u0000\n3-A\n4-D',
      ]);
      expect(key.byNumber, {1: 'B', 2: 'C', 3: 'A', 4: 'D'});
      expect(key.pages, [1, 2]);
    });

    test('um gabarito sem questões lidas ainda é reconhecido', () {
      final key = parser.parsePages([
        'GABARITO DEFINITIVO\n1-A\n2-B\n3-C\n4-D\n5-A',
      ]);
      expect(key.heading, 'GABARITO DEFINITIVO');
      expect(key.length, 5);
    });
  });
}
