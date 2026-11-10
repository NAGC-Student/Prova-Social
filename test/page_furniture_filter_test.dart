import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/page_furniture_filter.dart';

/// A page of body text long and distinct enough that only the line under test
/// can look like furniture.
String examPage(
  int page, {
  String? first,
  List<String> extra = const [],
  String? last,
  int lines = 4,
}) => [
  ?first,
  for (var line = 0; line < lines; line++)
    'Enunciado $line da prova $page que muda de uma pagina para a outra',
  ...extra,
  ?last,
].join('\n');

const edgeNote =
    'Observações finais desta folha, que passam de quarenta caracteres';

void main() {
  const filter = PageFurnitureFilter();

  test(
    'remove o cabeçalho que volta em todas as páginas, inclusive no meio',
    () {
      const header = 'Confidencial até o momento da aplicação.';
      final report = filter.apply([
        for (var page = 0; page < 6; page++)
          page == 3
              ? examPage(page, extra: [header])
              : examPage(page, first: header),
      ]);

      for (final page in report.pages) {
        expect(page, isNot(contains(header)));
      }
      expect(report.removedLines, contains(header));
      expect(report.removedAnything, isTrue);
    },
  );

  test('remove o número de página corrido do rodapé', () {
    final report = filter.apply([
      for (var page = 0; page < 8; page++) examPage(page, last: '${page + 3}'),
    ]);

    for (final page in report.pages) {
      expect(
        page.trimRight().split('\n').last,
        startsWith('Enunciado 3 da prova'),
      );
    }
    expect(report.removedLines, hasLength(8));
    expect(report.removedLines, containsAll(['3', '10']));
  });

  test('remove a numeração explícita “Página n de m”', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, last: 'Página ${page + 1} de 6'),
    ]);

    expect(report.pages.every((page) => !page.contains('Página')), isTrue);
    expect(report.removedLines, hasLength(6));
  });

  test('remove cabeçalho cuja numeração muda a cada página', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, first: 'PMES2401 | 0${page + 1}-Prova Objetiva'),
    ]);

    expect(report.pages.every((page) => !page.contains('PMES2401')), isTrue);
  });

  test('não remove o número de questão que abre a coluna', () {
    const numbers = ['7', '13', '21', '5', '30', '9', '4', '11'];
    final report = filter.apply([
      for (final number in numbers) examPage(int.parse(number), first: number),
    ]);

    for (var index = 0; index < report.pages.length; index++) {
      expect(report.pages[index].split('\n').first, numbers[index]);
    }
    expect(report.removedLines, isEmpty);
  });

  test('não remove número de rodapé que não forma contagem corrida', () {
    const numbers = ['57', '58', '61', '62', '14', '20'];
    final report = filter.apply([
      for (final number in numbers) examPage(int.parse(number), last: number),
    ]);

    expect(report.removedLines, isEmpty);
    for (var index = 0; index < report.pages.length; index++) {
      expect(report.pages[index].split('\n').last, numbers[index]);
    }
  });

  test('a contagem do rodapé não autoriza apagar outras linhas da margem', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(
          page,
          lines: 5,
          extra: ['$edgeNote na prova $page'],
          last: '${page + 1}',
        ),
    ]);

    for (var page = 0; page < 6; page++) {
      expect(report.pages[page], contains('$edgeNote na prova $page'));
    }
    expect(report.removedLines, hasLength(6));
  });

  test('preserva “Questão 21” por mais regular que seja na margem', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++) examPage(page, first: 'Questão 21'),
    ]);

    expect(report.pages.every((page) => page.startsWith('Questão 21')), isTrue);
    expect(report.removedLines, isEmpty);
  });

  test('preserva o fragmento “Quest” de um marcador quebrado', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, first: 'Quest', extra: ['ão ${page + 1}']),
    ]);

    expect(report.pages.every((page) => page.startsWith('Quest')), isTrue);
    expect(report.removedLines, isEmpty);
  });

  test('preserva a grade de resposta certa errada que se repete na página', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, extra: [for (var line = 0; line < 8; line++) 'C E']),
    ]);

    expect(
      report.pages.every((page) => 'C E'.allMatches(page).length == 8),
      isTrue,
    );
    expect(report.removedLines, isEmpty);
  });

  test('preserva os marcadores de página do parser', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        [
          '\u0000PROVA_SOCIAL_PAGE_${page + 1}\u0000',
          examPage(page, last: '${page + 1}'),
        ].join('\n'),
    ]);

    for (var page = 0; page < 6; page++) {
      expect(
        report.pages[page],
        contains('\u0000PROVA_SOCIAL_PAGE_${page + 1}\u0000'),
      );
    }
  });

  test('usa a faixa geométrica do rodapé quando o PDF a entrega', () {
    final report = filter.apply(
      [
        for (var page = 0; page < 6; page++)
          examPage(
            page,
            lines: 5,
            extra: ['${page + 2}', '$edgeNote da prova $page'],
          ),
      ],
      footers: [
        for (var page = 0; page < 6; page++) const <int>{5, 6},
      ],
    );

    // Only the number in the band is furniture; the note under it is content.
    for (var page = 0; page < 6; page++) {
      expect(report.pages[page], contains('$edgeNote da prova $page'));
    }
    expect(report.pages.every((page) => !page.contains('\n2\n')), isTrue);
    expect(report.removedLines, hasLength(6));
  });

  test('não remove nada quando uma linha só aparece em poucas páginas', () {
    final report = filter.apply([
      examPage(0, first: 'Cubo mágico de teste de capa'),
      examPage(1, first: 'Cubo mágico de teste de capa'),
      examPage(2),
      examPage(3),
      examPage(4),
      examPage(5),
    ]);

    expect(report.pages.first, startsWith('Cubo mágico de teste de capa'));
    expect(report.removedLines, isEmpty);
  });

  test('remove a marca d’água repetida que atravessa a folha', () {
    const watermark =
        'ENEM2025ENEM2025ENEM2025ENEM2025ENEM2025ENEN2025ENEM2025ENEM2025EN';
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        page == 0
            ? examPage(page, first: watermark)
            : examPage(page, extra: [watermark]),
    ]);

    expect(report.pages.every((page) => !page.contains('ENEM2025')), isTrue);
    expect(report.removedLines, [watermark.toUpperCase()]);
  });

  test('remove a data e a hora de impressão no meio da página', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, extra: ['23/07/2025 12:32:0${page + 1}']),
    ]);

    expect(report.pages.every((page) => !page.contains('23/07/2025')), isTrue);
    expect(report.removedLines, hasLength(6));
  });

  test('remove o código do candidato que se repete em todas as páginas', () {
    final report = filter.apply([
      for (var page = 0; page < 6; page++)
        examPage(page, extra: ['*010175AZ${page + 1}*']),
    ]);

    expect(report.pages.every((page) => !page.contains('010175AZ')), isTrue);
    expect(report.removedLines, hasLength(6));
  });

  test('preserva um código que só aparece em parte das páginas', () {
    final report = filter.apply([
      examPage(0, extra: ['*010175AZ1*']),
      examPage(1, extra: ['*010175AZ2*']),
      examPage(2, extra: ['*010175AZ3*']),
      examPage(3),
      examPage(4),
      examPage(5),
    ]);

    expect(report.removedLines, isEmpty);
    expect(report.pages[0], contains('*010175AZ1*'));
  });
}
