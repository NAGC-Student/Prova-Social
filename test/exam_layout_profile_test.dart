import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/exam_layout_profile.dart';

void main() {
  const profiler = ExamLayoutProfiler();

  test('reconhece a banca assinada no caderno e o layout de alternativas', () {
    final profile = profiler.profile([
      'FUNDAÇÃO VUNESP — CONCURSO PÚBLICO 2024\nInstruções para a prova.',
      'QUESTÃO 01\nQual é a capital?\n(A) Uma.\n(B) Duas.\n(C) Três.\n(D) Quatro.',
      'QUESTÃO 02\nOutra pergunta?\n(A) Sim.\n(B) Não.\n(C) Talvez.\n(D) Nula.',
    ]);

    expect(profile.banca, 'VUNESP');
    expect(profile.layout, QuestionLayout.letteredAlternatives);
    expect(profile.evidencePages, [1]);
    expect(profile.label, 'VUNESP — alternativas de A a E');
  });

  test('reconhece o caderno de itens para julgar do CEBRASPE', () {
    final profile = profiler.profile([
      'CEBRASPE — Centro Brasileiro de Pesquisa em Avaliação e Seleção',
      'Julgue os itens seguintes.\n1. ( ) A administração direta inclui as autarquias.\n'
          '2. ( ) O ato administrativo discricionário não admite controle.\n'
          '3. (C) (E) A revogação opera efeitos ex tunc.',
    ]);

    expect(profile.banca, 'CEBRASPE');
    expect(profile.layout, QuestionLayout.judgementItems);
    expect(profile.label, 'CEBRASPE — itens para julgar');
  });

  test('distingue caderno misto de documento sem estrutura reconhecível', () {
    final mixed = profiler.profile([
      'INSTITUTO AOCP — PROVA OBJETIVA',
      'Questão 1\nO servidor deve\nA) exercer.\nB) omitir.\nC) atrasar.\nD) faltar.',
      'Julgue os itens.\n2. ( ) A estabilidade é direito.\n3. ( ) A precariedade é regra.\n4. ( ) Nada.',
    ]);
    expect(mixed.layout, QuestionLayout.mixed);

    final plain = profiler.profile(['Texto corrido sem marcação de prova.']);
    expect(plain.banca, isNull);
    expect(plain.layout, QuestionLayout.unknown);
    expect(plain.isKnown, isFalse);
    expect(plain.label, 'Formato não reconhecido');
  });

  test('a banca da capa vence o nome citado no texto de uma questão', () {
    final profile = profiler.profile([
      'INSTITUTO CONSULPLAN — PREFEITURA DE SÃO PAULO',
      'QUESTÃO 05 - Getúlio Vargas criou o DIP com a finalidade de\n'
          '(A) censurar. (B) propaganda. (C) educação. (D) saúde.',
    ]);

    expect(profile.banca, 'Consulplan');
  });

  test('não infere a banca pelo nome do arquivo em capa escaneada', () {
    final profile = profiler.profile([
      'VESTIBULAR 2026',
      'Questão 1\n(A) uma. (B) duas. (C) três.',
    ], sourceName: 'ita-2026-fase-1.pdf');

    expect(profile.banca, isNull);
    expect(profile.layout, QuestionLayout.letteredAlternatives);
  });
}
