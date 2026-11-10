import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/question_parser.dart';

void main() {
  const parser = QuestionParser();

  test('separa múltipla escolha com Questão e A-D', () {
    const text = '''
Questão 1. Qual é a capital do Brasil?
(A) São Paulo
(B) Brasília
(C) Recife
(D) Curitiba

2 - Quanto é dois mais dois?
A) 3
B) 4
C) 5
D) 6
''';
    final questions = parser.parse(text);
    expect(questions, hasLength(2));
    expect(questions.first.statement, contains('capital'));
    expect(questions.first.options, hasLength(4));
    expect(questions.last.options[1], '4');
  });

  test('restores a complete numbered sequence extracted out of order', () {
    final questions = parser.parse('''
Questão 2. Segunda pergunta?
A) Sim.
B) Não.

Questão 1. Primeira pergunta?
A) Sim.
B) Não.
''');

    expect(questions.map((question) => question.number), [1, 2]);
    expect(questions.first.statement, contains('Primeira pergunta'));
    expect(questions.last.statement, contains('Segunda pergunta'));
  });

  test('preserva 80 questões sintéticas em ordem, sem perder alternativas', () {
    final source = List.generate(80, (index) {
      final number = index + 1;
      return '''
Questão $number. Enunciado de validação da questão número $number?
A) Primeira alternativa da questão $number.
B) Segunda alternativa da questão $number.
C) Terceira alternativa da questão $number.
D) Quarta alternativa da questão $number.
E) Quinta alternativa da questão $number.
''';
    }).join('\n');

    final questions = parser.parse(source);
    expect(questions, hasLength(80));
    expect(questions.map((question) => question.number), [
      for (var number = 1; number <= 80; number++) number,
    ]);
    expect(questions.every((question) => question.options.length == 5), isTrue);
  });

  test(
    'preserva a sequência em títulos de texto e lê alternativas circuladas',
    () {
      final questions = parser.parse('''
20 Assinale a alternativa correta. Ⓐ Primeira. Ⓑ Segunda. Ⓒ Terceira. Ⓓ Quarta. Ⓔ Quinta.
TEXTO III
Texto de apoio que pertence à questão seguinte.
TEXTO V
21 Com base no texto, indique a resposta. Ⓐ Primeira. Ⓑ Segunda. Ⓒ Terceira. Ⓓ Quarta. Ⓔ Quinta.
TEXTO VI
22 Analisando o trecho, escolha a resposta. Ⓐ Primeira. Ⓑ Segunda. Ⓒ Terceira. Ⓓ Quarta. Ⓔ Quinta.
HISTÓRIA E GEOGRAFIA DO BRASIL
23 Considerações sobre o tema orientam a escolha. Ⓐ Primeira. Ⓑ Segunda. Ⓒ Terceira. Ⓓ Quarta. Ⓔ Quinta.
''');

      expect(questions.map((question) => question.number), [20, 21, 22, 23]);
      expect(questions.first.options.last, 'Quinta.');
      expect(
        questions.every(
          (question) =>
              question.format == QuestionFormat.multipleChoice &&
              question.options.length == 5,
        ),
        isTrue,
      );
    },
  );

  test('recupera marcador sequencial após referência na mesma linha', () {
    final questions = parser.parse('''
19 Assinale uma opção correta?
A) Primeira.
B) Segunda.
C) Terceira.
D) Quarta.
E) Quinta.
12 - Questões - valor de 0,000 a 10,000 (dez) 20 "A afirmação abaixo está correta?"
A) Sim.
B) Não.
C) Talvez.
D) Nunca.
E) Sempre.
''');

    expect(questions.map((question) => question.number), [19, 20]);
    expect(questions.last.statement, contains('A afirmação abaixo'));
    expect(questions.last.statement, isNot(contains('Fonte oficial')));
    expect(questions.last.options, hasLength(5));
  });

  test(
    'mantém a página de origem quando questão continua na página seguinte',
    () {
      final questions = parser.parsePages([
        'Questão 1. Enunciado que começa na primeira página e',
        '''continua na segunda página?
A) Primeira alternativa.
B) Segunda alternativa.

Questão 2. Próxima questão inteira na segunda página?
A) Sim.
B) Não.''',
      ]);

      expect(questions, hasLength(2));
      expect(questions.first.sourcePage, 1);
      expect(questions.first.statement, contains('continua na segunda página'));
      expect(questions.last.sourcePage, 2);
    },
  );

  test('agrupa trilhas paralelas de idioma sem descartar versões', () {
    String track(String heading, String prompt) =>
        '''
$heading
${List.generate(6, (index) {
          final number = index + 39;
          return '''
Questão $number. $prompt $number?
A) Opção A $number.
B) Opção B $number.
C) Opção C $number.
D) Opção D $number.
E) Opção E $number.
''';
        }).join('\n')}
''';
    final questions = parser.parse(
      'Leia o texto para responder às questões de\n39 a 44.\n'
      '${track('Língua Inglesa', 'What is the answer to')}\n'
      '${track('Língua Espanhola', '¿Cuál es la respuesta para')}',
    );

    expect(questions, hasLength(6));
    expect(questions.map((question) => question.number), [
      39,
      40,
      41,
      42,
      43,
      44,
    ]);
    expect(
      questions.every((question) => question.alternateVersions.length == 1),
      isTrue,
    );
    expect(questions.first.versionLabel, 'Inglês');
    expect(questions.first.alternateVersions.single.label, 'Espanhol');
    expect(questions.first.statement, contains('What is the answer'));
    expect(
      questions.first.alternateVersions.single.statement,
      contains('¿Cuál'),
    );
    questions.first.selectAlternateVersion(0);
    expect(questions.first.versionLabel, 'Espanhol');
    expect(questions.first.statement, contains('¿Cuál'));
    questions.first.selectAlternateVersion(0);
    expect(questions.first.versionLabel, 'Inglês');
    expect(questions.first.statement, contains('What is the answer'));
  });

  test('não agrupa um número duplicado isolado como versão paralela', () {
    const source = '''
Questão 1. Primeira pergunta válida?
A) Sim
B) Não

Questão 1. Outra pergunta válida?
A) Sim
B) Não
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(
      questions.every((question) => question.alternateVersions.isEmpty),
      isTrue,
    );
  });

  test('aceita numeração com zero à esquerda e cinco alternativas', () {
    const source = '''
01
Qual alternativa descreve corretamente o fenômeno apresentado?
(A) Primeira possibilidade.
(B) Segunda possibilidade.
(C) Terceira possibilidade.
(D) Quarta possibilidade.
(E) Quinta possibilidade.

02.
Considere o texto e selecione a resposta adequada.
A) Opção um.
B) Opção dois.
C) Opção três.
D) Opção quatro.
E) Opção cinco.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(5));
    expect(questions.last.statement, contains('Considere o texto'));
  });

  test('sai das instruções diante de questão numerada com alternativas', () {
    const source = '''
INSTRUÇÕES
Leia o caderno antes de começar.

01 Considere a situação descrita e assinale a resposta correta?
A) Primeira alternativa.
B) Segunda alternativa.
''';

    final questions = parser.parse(source);

    expect(questions, hasLength(1));
    expect(questions.single.number, 1);
    expect(questions.single.options, hasLength(2));
    expect(questions.single.statement, contains('situação descrita'));
  });

  test('não confunde total de questões da seção com questão numerada', () {
    const source = '''
14 - Questões - valor total 10 pontos
01 A robótica tem se tornado cada vez mais presente?
A) Primeira alternativa.
B) Segunda alternativa.
''';

    final questions = parser.parse(source);

    expect(questions, hasLength(1));
    expect(questions.single.number, 1);
    expect(questions.single.statement, contains('A robótica'));
  });

  test(
    'reconhece marcadores de questão entre chaves após instruções numeradas',
    () {
      final questions = parser.parsePages([
        '''
INSTRUÇÕES
1. Leia este caderno.
2. Confira o número de questões.
''',
        '''
{01}
Qual alternativa corresponde ao primeiro item?
(A) Primeira.
(B) Segunda.
(C) Terceira.
(D) Quarta.
(E) Quinta.
{02}
Qual alternativa corresponde ao segundo item?
(A) Primeira.
(B) Segunda.
(C) Terceira.
(D) Quarta.
(E) Quinta.
''',
      ]);

      expect(questions.map((question) => question.number), [1, 2]);
      expect(questions.first.statement, contains('primeiro item'));
      expect(
        questions.every((question) => question.options.length == 5),
        isTrue,
      );
    },
  );

  test('não trunca seis alternativas', () {
    const source = '''
QUESTÃO 12
Escolha a alternativa correta.
A) Uma.
B) Duas.
C) Três.
D) Quatro.
E) Cinco.
F) Seis.
''';
    final question = parser.parse(source).single;
    expect(question.options, hasLength(6));
    expect(question.warning, contains('6 alternativas'));
  });

  test('preserva texto com marcador repetido sem criar alternativa falsa', () {
    const source = '''
QUESTÃO 12
Escolha a alternativa correta.
A) Uma.
B) Duas.
A) Continuação mal reconhecida de duas.
C) Três.
D) Quatro.
E) Cinco.
''';
    final question = parser.parse(source).single;

    expect(question.options, hasLength(5));
    expect(question.options[1], contains('A) Continuação'));
    expect(question.warning, contains('incompletos ou fora de ordem'));
    expect(question.confidence, lessThan(.95));
  });

  test('não interpreta numeração isolada sem sequência de alternativas', () {
    const source = '''
2024
Página 3
25 questões objetivas.
''';

    expect(parser.parse(source), isEmpty);
  });

  test('reconhece alternativas OCR sem pontuação no marcador', () {
    const source = '''
1
Considere os dados e assinale a conclusão correta.
A Primeira possibilidade.
B Segunda possibilidade.
C Terceira possibilidade.
D Quarta possibilidade.
''';

    final question = parser.parse(source).single;
    expect(question.number, 1);
    expect(question.options, hasLength(4));
    expect(question.options.first, 'Primeira possibilidade.');
  });

  test('aceita variantes de marcador', () {
    const source = '''
QUESTÃO Nº 1: Escolha uma opção.
[A] Uma opção
[B] Outra opção
[C] Terceira opção
[D] Quarta opção

2) Outra questão?
a - sim
b - não
c - talvez
d - depende
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.options, hasLength(4));
    expect(questions.last.options, hasLength(4));
  });

  test('não confunde números do enunciado com questões', () {
    const source = '''
QUESTÃO 1. Uma população de 25% cresceu em 2024 e percorreu 10 km.
A) Cresceu.
B) Diminuiu.
C) Permaneceu igual.
D) Não é possível concluir.

QUESTÃO 2. Qual resultado?
A) 1.
B) 2.
C) 3.
D) 4.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.statement, contains('25%'));
    expect(questions.first.statement, contains('2024'));
    expect(questions.first.statement, contains('10 km'));
  });

  test('reconhece formato Cebraspe como certo/errado', () {
    const source = '''
1. Julgue o item a seguir.
A licitude do objeto é requisito de validade do contrato.

2. Julgue o item seguinte.
A administração pública deve observar a legalidade.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.first.format, QuestionFormat.trueFalse);
    expect(questions.first.options, ['CERTO', 'ERRADO']);
  });

  test('reconhece assertiva sem fabricar alternativas', () {
    const source = '''
QUESTÃO 1
Situação hipotética: João comprou um imóvel.
Assertiva: o contrato deverá observar os requisitos legais.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(1));
    expect(questions.single.format, QuestionFormat.assertion);
    expect(questions.single.options, isEmpty);
    expect(questions.single.warning, contains('sem alternativas'));
  });

  test('reconhece itens Cebraspe sem pontuação após o número', () {
    const source = '''
Julgue os itens a seguir.
1 A primeira assertiva está correta.
2 A segunda assertiva está incorreta.
3 A terceira assertiva também deve ser julgada.
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(3));
    expect(
      questions.every((q) => q.format == QuestionFormat.trueFalse),
      isTrue,
    );
    expect(questions.every((q) => q.options.length == 2), isTrue);
  });

  test(
    'reconhece itens Cebraspe com números isolados após texto contextual',
    () {
      final questions = parser.parsePages([
        '''
Texto publicado em 2015.
PROVAS OBJETIVAS
CONHECIMENTOS BÁSICOS
Julgue os itens a seguir.
1
A primeira assertiva deve ser julgada.
2
A segunda assertiva deve ser julgada.
3
A terceira assertiva deve ser julgada.
''',
      ]);

      expect(questions.map((question) => question.number), [1, 2, 3]);
      expect(
        questions.every(
          (question) => question.format == QuestionFormat.trueFalse,
        ),
        isTrue,
      );
    },
  );

  test('reinicia a sequência após título de seção em caixa de título', () {
    final questions = parser.parse('''
1
Informação numerada da capa.
20
Questões objetivas.
Conhecimentos Gerais Língua Portuguesa
1
Qual alternativa é correta?
(A) Primeira.
(B) Segunda.
(C) Terceira.
(D) Quarta.
(E) Quinta.
2
Qual alternativa também é correta?
(A) Primeira.
(B) Segunda.
(C) Terceira.
(D) Quarta.
(E) Quinta.
''');

    expect(questions.map((question) => question.number), [1, 2]);
    expect(questions.every((question) => question.options.length == 5), isTrue);
  });

  test(
    'mantém questões numeradas antes de marcador explícito em outra seção',
    () {
      final questions = parser.parsePages([
        '''
Conhecimentos Gerais Língua Portuguesa
1
Qual alternativa corresponde à primeira questão objetiva?
(A) Primeira.
(B) Segunda.
(C) Terceira.
(D) Quarta.
(E) Quinta.
''',
        '''
Questões Discursivas (Coordenador Pedagógico)
Questão 1
Explique a resposta da primeira questão discursiva.
1
2
20
''',
        '''
FGV CONHECIMENTO
Questão 2
Explique a resposta da segunda questão discursiva.
''',
      ]);

      expect(questions.map((question) => question.number), [1, 1, 2]);
      expect(questions.last.number, 2);
    },
  );

  test('permite processar colunas separadas sem intercalá-las', () {
    final questions = parser.parseColumns([
      '''
QUESTÃO 1. Coluna esquerda.
A) A
B) B
C) C
D) D
''',
      '''
QUESTÃO 2. Coluna direita.
A) A
B) B
C) C
D) D
''',
    ]);
    expect(questions.map((q) => q.number), [1, 2]);
  });

  test('preserva bloco incerto para revisão humana', () {
    final question = parser.parse('Questão 1. Apenas texto').single;
    expect(question.number, 1);
    expect(question.statement, 'Apenas texto');
    expect(question.options, isEmpty);
    expect(question.format, QuestionFormat.unknown);
    expect(question.confidence, lessThan(.85));
    expect(question.warning, contains('Estrutura não reconhecida'));
  });

  test('mantém questão que atravessa quebra de página e ignora cabeçalho', () {
    const text = '''
INSTITUTO DE EXEMPLO — CADERNO DE PROVA
Página 4
Questão 18. Considere as informações apresentadas na primeira parte do
enunciado, que continua na página seguinte.
Página 5
INSTITUTO DE EXEMPLO — CADERNO DE PROVA
Assinale a alternativa correta.
A) Primeira alternativa.
B) Segunda alternativa.
C) Terceira alternativa.
D) Quarta alternativa.
''';
    final question = parser.parse(text).single;
    expect(question.number, 18);
    expect(question.statement, contains('continua na página seguinte'));
    expect(question.options, hasLength(4));
  });

  test('aceita alternativas acima de E e formatos V/F e assertiva', () {
    final six = parser.parse('''
Questão 1. Escolha uma opção adequada.
A) Um
B) Dois
C) Três
D) Quatro
E) Cinco
F) Seis
''').single;
    expect(six.options, hasLength(6));
    final vf = parser.parse('''
Julgue os itens seguintes.
1. O primeiro enunciado deve ser avaliado.
2. O segundo enunciado deve ser avaliado.
''');
    expect(vf, hasLength(2));
    expect(vf.every((q) => q.format == QuestionFormat.trueFalse), isTrue);
  });

  test('numerações de listas no enunciado não viram novas questões', () {
    final questions = parser.parse('''
Questão 18. Considere as etapas do procedimento:
1. Inicialize a variável com o valor informado.
2. Some os elementos da lista antes de prosseguir.
1º passo: confirme o resultado intermediário.
2º passo: compare com a condição descrita.
A) Resultado um.
B) Resultado dois.
C) Resultado três.
D) Resultado quatro.

Questão 19. Qual é a conclusão correta?
A) Conclusão um.
B) Conclusão dois.
C) Conclusão três.
D) Conclusão quatro.
''');

    expect(questions, hasLength(2));
    expect(questions.map((question) => question.number), [18, 19]);
    expect(questions.first.statement, contains('2º passo'));
    expect(questions.first.options, hasLength(4));
  });

  test('identifica questão discursiva sem fabricar alternativas', () {
    final question = parser
        .parse(
          'Questão 7. Explique a diferença entre os conceitos apresentados.',
        )
        .single;
    expect(question.format, QuestionFormat.openEnded);
    expect(question.options, isEmpty);
    expect(question.warning, contains('discursiva'));
  });

  test('numera questão discursiva sem rótulo após sequência objetiva', () {
    final questions = parser.parse('''
1. Primeira questão objetiva?
A) Sim.
B) Não.

Questão Discursiva
Explique a resposta.
''');

    expect(questions.map((question) => question.number), [1, 2]);
    expect(questions.last.format, QuestionFormat.openEnded);
    expect(questions.last.options, isEmpty);
  });

  test('não inventa numeração para proposta de redação', () {
    final questions = parser.parse('''
50. Última questão objetiva?
A) Primeira.
B) Segunda.
Questão Discursiva de Português (Redação)
Com base nos textos de apoio, redija um texto dissertativo.
''');

    expect(questions, hasLength(2));
    expect(questions.last.number, isNull);
    expect(questions.last.format, QuestionFormat.openEnded);
  });

  test('não aceita número zero como questão', () {
    expect(
      parser.parse('''
0
Texto extraído de um diagrama, sem questão numerada.
A) Primeira.
B) Segunda.
C) Terceira.
D) Quarta.
'''),
      isEmpty,
    );
  });

  test('não interpreta números altos sem marcador explícito como questões', () {
    final questions = parser.parse('''
2024. Qual alternativa corresponde ao ano do documento?
A) 2024.
B) 2025.
C) 2026.
D) 2027.
''');

    expect(questions, isEmpty);
  });

  test('preserva slots de alternativas visuais sem texto extraído', () {
    final questions = parser.parse('''
53
Determine o valor indicado na figura.
(A)
(B)
(C)
(D)
(E)
''');

    expect(questions, hasLength(1));
    expect(questions.single.number, 53);
    expect(questions.single.format, QuestionFormat.multipleChoice);
    expect(questions.single.options, ['', '', '', '', '']);
    expect(questions.single.hasVisualOptions, isTrue);
    expect(
      questions.single.warning,
      contains('conteúdo visual não foi extraído'),
    );
    expect(questions.single.confidence, .65);
    expect(
      ImportedQuestion.fromJson(questions.single.toJson(0)).hasVisualOptions,
      isTrue,
    );
  });

  test('termina uma questão antes da seção de redação', () {
    final question = parser.parse('''
Questão 80. Selecione a opção indicada na figura.
(A)
(B)
(C)
(D)
(E)
REDAÇÃO
Texto 1: este conteúdo pertence à proposta de redação.
''').single;

    expect(question.number, 80);
    expect(question.statement, isNot(contains('Texto 1')));
    expect(question.options, ['', '', '', '', '']);
  });

  test('não classifica prosa iniciada por artigo como alternativa', () {
    final question = parser.parse('''
Questão 1. A questão trata de um princípio importante.
A) Primeira alternativa
B) Segunda alternativa
C) Terceira alternativa
D) Quarta alternativa
''').single;

    expect(question.statement, startsWith('A questão trata'));
    expect(question.options, hasLength(4));
  });

  test('aceita Q1 e questão ordinal', () {
    const source = '''
Q1. Qual é a resposta?
A. Primeira
B. Segunda
C. Terceira
D. Quarta

2ª QUESTÃO - Qual é a próxima?
A: A
B: B
C: C
D: D
''';
    final questions = parser.parse(source);
    expect(questions, hasLength(2));
    expect(questions.map((q) => q.number), [1, 2]);
  });

  test('não transforma valor isolado de tabela em questão', () {
    const source = '''
60
Qual alternativa descreve o fenômeno apresentado na prova?
(A) Primeira possibilidade.
(B) Segunda possibilidade.
(C) Terceira possibilidade.
(D) Quarta possibilidade.

61
O coeficiente de dilatação térmica aparece na tabela abaixo.
Platina
9
Ferro
12
Cobre
17
24
Alumínio
29
Chumbo
Considere duas hastes metálicas, P e Q, e responda.
(A) chumbo e platina.
(B) cobre e ferro.
(C) alumínio e platina.
(D) alumínio e ferro.
(E) chumbo e alumínio.

62
A figura mostra os sentidos e valores de correntes elétricas.
(A) 15 mA.
(B) 30 mA.
(C) 35 mA.
(D) 55 mA.
(E) 105 mA.
''';
    final questions = parser.parse(source);

    expect(questions.map((question) => question.number), [60, 61, 62]);
    expect(questions.last.statement, contains('correntes elétricas'));
  });

  test('não estende a trilha de idioma além do intervalo declarado', () {
    const source = '''
1
Qual é a capital do Brasil?
(A) Brasília
(B) Recife

Língua Inglesa Read the text to answer the questions
39 a 41.
The 2020s brought a degree of chaos. Read the text carefully.

39
What is the answer to this one?
(A) First
(B) Second
(C) Third
(D) Fourth

40
What is the answer to that one?
(A) First
(B) Second
(C) Third
(D) Fourth

41
What is the answer to the last one?
(A) First
(B) Second
(C) Third
(D) Fourth

Língua Espanhola Lea el texto para responder a las questões de 39 a 41.
39
¿Cuál es la respuesta a esta?
(A) Primera
(B) Segunda
(C) Tercera
(D) Cuarta

40
¿Cuál es la respuesta a esa?
(A) Primera
(B) Segunda
(C) Tercera
(D) Cuarta

41
¿Cuál es la respuesta a la última?
(A) Primera
(B) Segunda
(C) Tercera
(D) Cuarta

42
Quantos habitantes tem a cidade seguinte?
(A) Um
(B) Dois
(C) Três
(D) Quatro
''';
    final questions = parser.parse(source);

    expect(questions.map((question) => question.number), [1, 39, 40, 41, 42]);
    expect(questions.first.language, isNull);
    final parallel = questions.firstWhere((question) => question.number == 39);
    expect(parallel.versionLabel, 'Inglês');
    expect(parallel.language, 'Inglês');
    expect(parallel.alternateVersions.single.label, 'Espanhol');
    // A trilha de idioma termina no número 41: a questão seguinte é da prova.
    expect(questions.last.language, isNull);
    expect(questions.last.versionLabel, 'Versão principal');
  });

  test('não confunde o rótulo de intervalo com uma questão', () {
    const source = '''
Leia o texto para responder às questões
39 a 41.
Examine a tirinha publicada no site do autor em 08.04.2024.

39
What is the answer to this one?
(A) First
(B) Second
(C) Third
(D) Fourth
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(1));
    expect(questions.first.number, 39);
  });

  test('não cola o gabarito no enunciado da última questão', () {
    const source = '''
01
Qual alternativa apresenta a solução correta?
A) Primeira opção.
B) Segunda opção.
C) Terceira opção.
D) Quarta opção.

02
Considere o texto e responda.
A) Primeira opção.
B) Segunda opção.
C) Terceira opção.
D) Quarta opção.

GABARITO
1-B
2-C
3-A
4-D
5-B
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(2));
    expect(questions.last.statement, isNot(contains('GABARITO')));
    expect(questions.last.options, hasLength(4));
    expect(questions.last.options.last, contains('Quarta'));
  });

  test('lê itens CEBRASPE marcados pela caixa de resposta vazia', () {
    const source = '''
Julgue os itens que se seguem, relativos ao regime jurídico dos servidores.

1. ( ) O servidor é estável após três anos de efetivo exercício.
2. ( ) A reversão depende de processo administrativo.
3. (C) (E) A vacância decorre, entre outras causas, de falecimento.
4. ( ) A readaptação é aproveitamento em cargo compatível.
5. ( ) A recondução decorre de inabilitação no estágio probatório.
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(5));
    expect(questions.map((question) => question.format.name), [
      for (var item = 1; item <= 5; item++) 'trueFalse',
    ]);
    expect(questions.first.options, ['CERTO', 'ERRADO']);
    expect(questions[2].statement, contains('vacância'));
    expect(questions[2].statement, isNot(contains('(C)')));
    expect(
      questions.every((question) => !question.statement.contains('( )')),
      isTrue,
    );
    expect(questions.first.statement, startsWith('O servidor'));
  });

  test('mantém a caixa de julgamento quando o sinal vem depois do item', () {
    const source = '''
Julgue o item a seguir.

1. A administração direta compreende as autarquias. ( )
2. As fundações integram a administração indireta. ( )
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(2));
    expect(questions.every((q) => q.format.name == 'trueFalse'), isTrue);
    expect(questions.first.statement, contains('administração direta'));
  });

  test('não confunde lacuna do enunciado com caixa de julgamento', () {
    const source = '''
Questão 1. Complete a lacuna: “o prazo de validade é de ( ) dias”.
A) cinco
B) dez
C) vinte
D) trinta
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(1));
    expect(questions.single.format.name, 'multipleChoice');
    expect(questions.single.options, hasLength(4));
  });

  test('aceita marcador Questao com til separado antes do número', () {
    const source = '''
Questao ˜ 18. Um recipiente contém um gás ideal.
A ( ) primeira expressão.
B ( ) segunda expressão.
C ( ) terceira expressão.
D ( ) quarta expressão.
E ( ) quinta expressão.
''';
    final questions = parser.parse(source);

    expect(questions, hasLength(1));
    expect(questions.single.number, 18);
    expect(questions.single.options, hasLength(5));
  });
}
