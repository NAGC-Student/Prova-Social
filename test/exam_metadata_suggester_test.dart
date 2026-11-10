import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/exam_metadata_suggester.dart';

void main() {
  test('suggests title and year from the first page header', () {
    final result = suggestExamMetadata(
      fileName: 'arquivo.pdf',
      firstPageText:
          'CONCURSO PÚBLICO 2024\nProva de Analista Judiciário\nQuestão 1',
    );

    expect(result.title, 'CONCURSO PÚBLICO 2024');
    expect(result.year, 2024);
  });

  test('falls back to a readable PDF filename', () {
    final result = suggestExamMetadata(
      fileName: 'enem-2023-caderno-amarelo.pdf',
      firstPageText: 'Página 1\nQuestão 1',
    );

    expect(result.title, 'enem 2023 caderno amarelo');
    expect(result.year, isNull);
    expect(result.fieldsNeedingAttention, contains('year'));
  });

  test('does not infer board from the filename when ITA is an institution', () {
    final result = suggestExamMetadata(
      fileName: 'ita-2026-fase-1.pdf',
      firstPageText:
          'INSTITUTO TECNOLÓGICO DE AERONÁUTICA\nVESTIBULAR 2026 1 FASE',
    );

    expect(result.title, startsWith('Vestibular ITA 2026'));
    expect(result.year, 2026);
    expect(result.board, isNull);
    expect(result.institution, 'Instituto Tecnológico de Aeronáutica (ITA)');
    expect(result.instance, '1ª fase');
  });

  test('identifies ESA metadata without inventing an exam board', () {
    final result = suggestExamMetadata(
      fileName: 'esa-2024-prova-geral.pdf',
      firstPageText:
          'MINISTÉRIO DA DEFESA\n'
          'EXÉRCITO BRASILEIRO\n'
          'Escola de Sargentos das Armas\n'
          'Concurso de Admissão 2024\n'
          'Área: GERAL\n'
          'Tipo de Prova: A',
    );

    expect(result.title, contains('Concurso de Admissão 2024'));
    expect(result.year, 2024);
    expect(result.category, 'Concurso de admissão');
    expect(result.board, isNull);
    expect(result.institution, 'Escola de Sargentos das Armas (ESA)');
    expect(result.instance, 'Tipo A');
    expect(result.fieldsNeedingAttention, contains('board'));
  });

  test(
    'leaves VUNESP bank and exam year pending without document evidence',
    () {
      final result = suggestExamMetadata(
        fileName: 'vunesp-2024-pm-sp.pdf',
        firstPageText:
            'CONCURSO PÚBLICO\n'
            '001. Prova objetiva — PARTE I\n'
            'Aluno-Oficial – PM',
        pages: [
          'CONCURSO PÚBLICO\n'
              '001. Prova objetiva — PARTE I\n'
              'Aluno-Oficial – PM',
          '',
          'Fonte da questão: https://atlas.fgv.br. Adaptado.',
        ],
      );

      expect(result.board, isNull);
      expect(result.institution, isNull);
      expect(result.year, isNull);
      expect(result.category, 'Concurso público');
      expect(result.instance, 'Parte I');
      expect(result.title, startsWith('Aluno Oficial'));
      expect(result.fieldsNeedingAttention, containsAll(['board', 'year']));
    },
  );

  test('separates ENEM exam identity from a responsible institution', () {
    final result = suggestExamMetadata(
      fileName: 'enem-2025-1o-dia-caderno-1.pdf',
      firstPageText:
          'CADERNO 1 | AZUL\n1º DIA\n'
          '${'ENEM2025' * 3}',
    );

    expect(result.title, 'ENEM 2025 — 1º dia · Caderno 1 — Azul');
    expect(result.category, 'Exame nacional');
    expect(result.year, 2025);
    expect(result.board, isNull);
    expect(result.institution, isNull);
    expect(result.instance, '1º dia · Caderno 1 — Azul');
  });

  test('does not choose a day when the cover contains conflicting days', () {
    final result = suggestExamMetadata(
      fileName: 'enem-2025-2o-dia-caderno-5.pdf',
      firstPageText:
          'CADERNO 5 | AMARELO\n'
          '1º DIA\n'
          '2º DIA\n'
          '${'ENEM2025' * 3}\n'
          'PROVA DE CIÊNCIAS DA NATUREZA E SUAS TECNOLOGIAS',
    );

    expect(result.instance, isNull);
    expect(result.title, 'ENEM 2025');
    expect(result.fieldsNeedingAttention, contains('instance'));
  });

  test('ignores a second-day mention in instructions on a first-day cover', () {
    final result = suggestExamMetadata(
      fileName: 'enem-2025.pdf',
      firstPageText:
          'CADERNO 1 | AZUL\n'
          '1º DIA\n'
          'ENEM 2025\n'
          'As instruções para o 2º dia serão divulgadas posteriormente.',
    );

    expect(result.instance, '1º dia · Caderno 1 — Azul');
  });

  test('prefers the year bound to the ENEM watermark over PDF metadata', () {
    final result = suggestExamMetadata(
      fileName: 'prova.pdf',
      firstPageText: 'ENEM2025ENEM2025 • arquivo atualizado em 2026',
    );

    expect(result.year, 2025);
  });

  test('does not treat “caderno de questões” as a specific instance', () {
    final result = suggestExamMetadata(
      fileName: 'ita-2025-fase-1.pdf',
      firstPageText:
          'INSTITUTO TECNOLÓGICO DE AERONÁUTICA\n'
          'VESTIBULAR 2025\n1ª FASE\n'
          'Certifique-se que recebeu um caderno de questões.',
    );

    expect(result.institution, 'Instituto Tecnológico de Aeronáutica (ITA)');
    expect(result.year, 2025);
    expect(result.category, 'Vestibular');
    expect(result.instance, '1ª fase');
    expect(result.title, 'Vestibular ITA 2025 — 1ª fase');
  });

  test('does not use the CEBRASPE edital year as exam year', () {
    final result = suggestExamMetadata(
      fileName: 'anm-cebraspe-2021.pdf',
      firstPageText: 'CEBRASPE | ANM – Edital: 2021\nPROVA DISCURSIVA',
    );

    expect(result.board, 'CEBRASPE');
    expect(result.institution, 'Agência Nacional de Mineração (ANM)');
    expect(result.year, isNull);
    expect(result.title, 'ANM — Prova discursiva');
  });

  test('does not infer vestibular category from a CEBRASPE question body', () {
    final result = suggestExamMetadata(
      fileName: 'aeb-2024-prova.pdf',
      firstPageText:
          'CEBRASPE – AEB – Edital: 2024\n'
          'PROVAS OBJETIVAS\n'
          'A questão cita uma experiência de vestibular.',
    );

    expect(result.board, 'CEBRASPE');
    expect(result.title, 'AEB — Provas objetivas');
    expect(result.year, isNull);
    expect(result.category, isNull);
  });

  test('distinguishes COMVEST from UNICAMP and names its vestibular', () {
    final result = suggestExamMetadata(
      fileName: 'unicamp-2025-fase-1.pdf',
      firstPageText:
          'COMVEST\n'
          'UNIVERSIDADE ESTADUAL DE CAMPINAS\n'
          'VESTIBULAR UNICAMP 2025\n'
          '1ª FASE',
    );

    expect(result.board, 'COMVEST');
    expect(result.institution, 'Universidade Estadual de Campinas (UNICAMP)');
    expect(result.year, 2025);
    expect(result.category, 'Vestibular');
    expect(result.instance, '1ª fase');
    expect(result.title, 'Vestibular Unicamp 2025 — 1ª fase');
  });

  test('requires an institution name rather than a weak acronym mention', () {
    final result = suggestExamMetadata(
      fileName: 'aeb-2024.pdf',
      firstPageText:
          'CEBRASPE\n'
          'PROVA OBJETIVA 2024\n'
          'A questão cita a AEB em um texto de apoio.',
    );

    expect(result.board, 'CEBRASPE');
    expect(result.institution, isNull);
    expect(result.year, 2024);
    expect(result.fieldsNeedingAttention, contains('institution'));
  });

  test('does not infer COMVEST from a question-source citation', () {
    final result = suggestExamMetadata(
      fileName: 'unicamp-2025-fase-1.pdf',
      firstPageText:
          'UNICAMP VESTIBULAR 2025 – 1ª FASE\n'
          'Elaboração: COMVEST (2024), baseado em fontes públicas.',
    );

    expect(result.board, isNull);
    expect(result.institution, 'Universidade Estadual de Campinas (UNICAMP)');
    expect(result.year, 2025);
    expect(result.category, 'Vestibular');
    expect(result.instance, '1ª fase');
    expect(result.title, 'Vestibular Unicamp 2025 — 1ª fase');
  });

  test('uses the institution named on a FUVEST cover', () {
    final result = suggestExamMetadata(
      fileName: 'fuvest-2025-primeira-fase-v1.pdf',
      firstPageText:
          'V1\n'
          'Universidade de São Paulo\n'
          'PROVA DE CONHECIMENTOS GERAIS – FUVEST 2025\n'
          'Instruções',
    );

    expect(result.board, 'FUVEST');
    expect(result.institution, 'Universidade de São Paulo (USP)');
    expect(result.year, 2025);
    expect(result.title, 'FUVEST 2025');
  });

  test('does not confuse an employer with a university cited in a question', () {
    final result = suggestExamMetadata(
      fileName: 'fgv-pms-2026-coordenador-pedagogico-tipo-1.pdf',
      firstPageText:
          'COORDENADOR PEDAGÓGICO (40H)\n'
          'PREFEITURA MUNICIPAL\n'
          'DE SALVADOR\n'
          'TIPO 1\n'
          'Um estudo realizado por pesquisadores da Universidade de São Paulo.',
      pages: [
        'COORDENADOR PEDAGÓGICO (40H)\n'
            'PREFEITURA MUNICIPAL\n'
            'DE SALVADOR\n'
            'TIPO 1\n'
            'FGV CONHECIMENTO\n'
            'Um estudo realizado por pesquisadores da Universidade de São Paulo.',
      ],
    );

    expect(result.board, 'FGV');
    expect(result.institution, 'Prefeitura Municipal de Salvador');
    expect(result.instance, 'Tipo 1');
    expect(result.title, contains('COORDENADOR PEDAGÓGICO'));
  });

  test(
    'does not attach a following word from the next line to the instance',
    () {
      final result = suggestExamMetadata(
        fileName: 'fgv.pdf',
        firstPageText:
            'FGV CONHECIMENTO\nTIPO 1\nSua prova será aplicada hoje.',
      );

      expect(result.instance, 'Tipo 1');
    },
  );

  test('does not use generic FGV cover instructions as the exam title', () {
    final result = suggestExamMetadata(
      fileName: 'fgv.pdf',
      firstPageText:
          'PREFEITURA MUNICIPAL\n'
          'DE SALVADOR\n'
          'SUA PROVA\n'
          'COORDENADOR PEDAGÓGICO (40H)\n'
          'PROVA OBJETIVA E DISCURSIVA\n'
          'TIPO 1',
      pages: [
        'PREFEITURA MUNICIPAL\n'
            'DE SALVADOR\n'
            'SUA PROVA\n'
            'COORDENADOR PEDAGÓGICO (40H)\n'
            'PROVA OBJETIVA E DISCURSIVA\n'
            'TIPO 1',
        'FGV CONHECIMENTO',
      ],
    );

    expect(result.institution, 'Prefeitura Municipal de Salvador');
    expect(result.title, 'FGV — COORDENADOR PEDAGÓGICO (40H) — Tipo 1');
  });

  test('does not promote instruction sentences to the exam title', () {
    final result = suggestExamMetadata(
      fileName: 'fgv-alema.pdf',
      firstPageText:
          'FGV CONHECIMENTO\n'
          'A resposta (A, B, C, D e E) e somente uma delas está correta.\n'
          'Consultor Legislativo Especial\n'
          'Tipo 1',
    );

    expect(result.title, contains('Consultor Legislativo'));
  });

  test('does not promote opening instructions to the exam title', () {
    final result = suggestExamMetadata(
      fileName: 'vunesp.pdf',
      firstPageText:
          'AGUARDE A ORDEM DO FISCAL PARA ABRIR ESTE CADERNO.\n'
          'Aluno-Oficial – PM',
    );

    expect(result.title, contains('Aluno Oficial'));
  });

  test('does not promote a bullet instruction to the exam title', () {
    final result = suggestExamMetadata(
      fileName: 'fgv-alema.pdf',
      firstPageText:
          'FGV CONHECIMENTO\n'
          'Anotar informações relativas às respostas em  qualquer outro meio;\n'
          'CONSULTOR LEGISLATIVO ESPECIAL',
    );

    expect(result.title, contains('CONSULTOR LEGISLATIVO ESPECIAL'));
  });

  test('recognizes FGV ALEMA identity split across cover lines', () {
    const cover =
        'ASSEMBLEIA LEGISLATIVO DO\n'
        'ESTADO DO MARANHÃO\n'
        'CONSULTOR LEGISLATIVO ESPECIAL\n'
        'NÍVEL SUPERIOR TIPO 1 – BRANCA\n'
        'SUA PROVA';
    final result = suggestExamMetadata(
      fileName: 'fgv-alema.pdf',
      firstPageText: cover,
      pages: [cover, 'FGV CONHECIMENTO'],
    );

    expect(
      result.institution,
      'Assembleia Legislativa do Estado do Maranhão (ALEMA)',
    );
    expect(result.board, 'FGV');
    expect(result.title, 'FGV — CONSULTOR LEGISLATIVO ESPECIAL — Tipo 1');
  });
}
