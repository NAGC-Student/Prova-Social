import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/text_normalizer.dart';

void main() {
  String normalize(String source) => ExamTextNormalizer.normalize(source);

  group('caracteres do PDF e do OCR', () {
    test('expande ligaduras, aspas e travessões', () {
      expect(
        normalize('A ﬁxação ﬂuiu com œvo e æreo — “assim”… não ’'),
        'A fixação fluiu com oevo e aereo - "assim"... não \'',
      );
    });

    test('remove o hífen morbido, que é ordem de diagramação', () {
      expect(
        normalize('coeficiente de dilata\u00adção térmica'),
        'coeficiente de dilatação térmica',
      );
    });

    test('os espaços especiais viram espaço simples', () {
      expect(
        normalize('leia\u00a0atentamente\u2009agora\u2007o texto'),
        'leia atentamente agora o texto',
      );
    });

    test('os códigos invisíveis dentro da palavra desaparecem', () {
      expect(
        normalize('trans\u200bcisão\ufeff e uni\u200dão'),
        'transcisão e união',
      );
    });

    test('apaga caracteres de controle', () {
      expect(normalize('â\u0001mbito da\u0008 questão'), 'âmbito da questão');
    });

    test('converte CRLF e tabulação', () {
      expect(normalize('Um texto.\r\nOutro\ttexto'), 'Um texto.\nOutro texto');
    });

    test('reconstrói o marcador de questão separado por quebra de linha', () {
      expect(normalize('Quest\não 34'), 'Questão 34');
    });

    test('mantém marcadores Quest isolados antes do enunciado seguinte', () {
      expect(
        normalize('texto anterior\nQuest\não 34\nQuest\não 35'),
        'texto anterior\nQuestão 34\nQuestão 35',
      );
    });
  });

  group('reconstrução das colunas quebradas', () {
    test('emenda a frase que a coluna cortou no meio', () {
      expect(
        normalize('Analise o texto a\nseguir para responder\nàs questões.'),
        'Analise o texto a seguir para responder às questões.',
      );
    });

    test('refaz a palavra hifenizada sem inserir espaço', () {
      expect(
        normalize(
          'o valor da dilata-\nção térmica linear\naumenta com o calor.',
        ),
        'o valor da dilatação térmica linear aumenta com o calor.',
      );
    });

    test('mantém separada a quebra de linha normal depois do hífen', () {
      expect(
        normalize('a conta deu\n-12 ao final do mês.'),
        'a conta deu\n-12 ao final do mês.',
      );
    });

    test('não emenda depois de uma frase encerrada', () {
      final text = normalize('Questão 5. Qual é a resposta?\nO texto diz isso');

      expect(text.split('\n'), [
        'Questão 5. Qual é a resposta?',
        'O texto diz isso',
      ]);
    });

    test('não emenda através de linha em branco', () {
      expect(
        normalize('parágrafo um\n\nparágrafo dois'),
        'parágrafo um\n\nparágrafo dois',
      );
    });

    test('não emenda o enunciado com a alternativa seguinte', () {
      final text = normalize(
        'O texto afirma que chove\n(A) chove.\n(B) faz sol.',
      );

      expect(text.split('\n'), [
        'O texto afirma que chove',
        '(A) chove.',
        '(B) faz sol.',
      ]);
    });

    test('mantém cada alternativa minúscula com travessão em sua linha', () {
      // Regression: the three-line look-ahead never fired for the last two
      // items, so “c - …” and “d - …” were glued to the line above and the
      // parser lost the whole list.
      final text = normalize(
        'A afirmação está correta?\n'
        'a - sim\n'
        'b - não\n'
        'c - talvez\n'
        'd - depende',
      );

      expect(text.split('\n'), [
        'A afirmação está correta?',
        'a - sim',
        'b - não',
        'c - talvez',
        'd - depende',
      ]);
    });

    test('não emenda um número de questão com o enunciado', () {
      final text = normalize('61\nO aumento no comprimento de uma haste');

      expect(text.split('\n'), ['61', 'O aumento no comprimento de uma haste']);
    });

    test('não emenda um marcador isolado com a linha seguinte', () {
      final text = normalize('1\nQuantos habitantes há na cidade?');

      expect(text.split('\n'), ['1', 'Quantos habitantes há na cidade?']);
    });

    test(
      'preserva número seguido por alternativa de uma letra e enunciado',
      () {
        final text = normalize(
          '14 - Questões - valor total\n'
          '01 A robótica tem se tornado cada vez mais presente.',
        );

        expect(text.split('\n'), [
          '14 - Questões - valor total',
          '01 A robótica tem se tornado cada vez mais presente.',
        ]);
      },
    );

    test('mantém o título em caixa alta como bloco próprio', () {
      final text = normalize(
        'Segundo o artigo da\nCONSTITUIÇÃO FEDERAL\na União deve agir.',
      );

      expect(text.split('\n'), [
        'Segundo o artigo da',
        'CONSTITUIÇÃO FEDERAL',
        'a União deve agir.',
      ]);
    });

    test('não cola o marcador de página no conteúdo', () {
      final text = normalize(
        '\u0000PROVA_SOCIAL_PAGE_3\u0000\nQuestão 12. Responda ao texto',
      );

      expect(text.split('\n'), [
        '\u0000PROVA_SOCIAL_PAGE_3\u0000',
        'Questão 12. Responda ao texto',
      ]);
    });

    test('reduz três linhas em branco a um espaço entre blocos', () {
      expect(normalize('um\n\n\n\ndois'), 'um\n\ndois');
    });
  });
}
