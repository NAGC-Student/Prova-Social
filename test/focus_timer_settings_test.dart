import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/attempt_draft_store.dart';
import 'package:prova_social/core/backend/attempt_sync_service.dart';
import 'package:prova_social/core/backend/focus_timer_settings.dart';
import 'package:prova_social/domain/models/exam.dart';
import 'package:prova_social/features/quiz/quiz_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryDraftStorage implements DraftStorage {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class MemoryQueueStorage implements AttemptQueueStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}

const exam = Exam(
  id: 'timer-exam',
  category: 'Geral',
  title: 'Prova com tempo',
  description: '',
  author: 'Fonte',
  durationMinutes: 30,
  attempts: 0,
  questions: [
    Question(
      id: 'q1',
      topic: 'Geral',
      statement: 'Primeira?',
      options: ['Um', 'Dois'],
    ),
    Question(
      id: 'q2',
      topic: 'Geral',
      statement: 'Segunda?',
      options: ['Um', 'Dois'],
    ),
  ],
);

/// Opens the quiz on memory stores: the shared_preferences singleton keeps a
/// draft alive between tests of one isolate and would hijack the attempt.
Future<AttemptDraftStore> _openQuizPage(WidgetTester tester) async {
  final drafts = AttemptDraftStore(storage: MemoryDraftStorage());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: QuizPage(
          exam: exam,
          draftStore: drafts,
          syncService: AttemptSyncService(
            store: AttemptQueueStore(storage: MemoryQueueStorage()),
          ),
        ),
      ),
    ),
  );
  // Restaurar o rascunho custa várias idas ao armazenamento do aparelho.
  for (var attempt = 0; attempt < 12; attempt++) {
    await tester.pump();
    if (tester.any(find.text('Questão 1 de 2'))) break;
  }
  expect(find.text('Questão 1 de 2'), findsOneWidget);
  await _settleClock(tester);
  return drafts;
}

/// The preference arrives through an asynchronous channel, so the clock is
/// watched until it stops changing before any test counts a single second.
Future<void> _settleClock(WidgetTester tester) async {
  var previous = _clockSeconds(tester);
  var stable = 0;
  for (var attempt = 0; attempt < 30 && stable < 3; attempt++) {
    await tester.pump();
    final current = _clockSeconds(tester);
    stable = current == previous ? stable + 1 : 0;
    previous = current;
  }
}

final _clockPattern = RegExp(r'^\d{2}:\d{2}$');

/// The seconds shown by the Modo Foco clock, whatever limit is configured.
int _clockSeconds(WidgetTester tester) {
  final shown = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? '')
      .where((data) => _clockPattern.hasMatch(data))
      .toList();
  expect(shown, hasLength(1), reason: 'a barra do Modo Foco mostra um relógio');
  final parts = shown.single.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Advances the fake clock one second at a time, the only way a periodic
/// timer can be observed without an unbounded [WidgetTester.pumpAndSettle].
Future<void> _advance(WidgetTester tester, int seconds) async {
  for (var index = 0; index < seconds; index++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

void main() {
  test('no stored preference keeps the clock informational', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await FocusTimerSettings.load();
    expect(settings.limit, FocusTimeLimit.none);
    expect(settings.limitSeconds, isNull);
  });

  test('a preference from another version falls back to the default', () async {
    SharedPreferences.setMockInitialValues({
      'focus_timer_settings_v1': '{"limit":"weekly"}',
    });
    expect(
      (await FocusTimerSettings.load()).limit,
      FocusTimeLimit.none,
      reason: 'uma preferência ilegível não pode abrir a prova quebrada',
    );
  });

  test('values outside the supported range are clamped on load', () async {
    SharedPreferences.setMockInitialValues({
      'focus_timer_settings_v1':
          '{"limit":"total","totalMinutes":9999,"questionSeconds":1}',
    });
    final settings = await FocusTimerSettings.load();
    expect(settings.totalMinutes, FocusTimerSettings.maxTotalMinutes);
    expect(settings.questionSeconds, FocusTimerSettings.minQuestionSeconds);
    expect(settings.limitSeconds, FocusTimerSettings.maxTotalMinutes * 60);
  });

  testWidgets('without a limit the clock still counts up', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final drafts = await _openQuizPage(tester);
    expect(_clockSeconds(tester), 0, reason: 'sem limite o relógio só conta');
    await _advance(tester, 3);
    expect(_clockSeconds(tester), 3);
    expect(find.text('Tempo esgotado'), findsNothing);
    drafts.dispose();
  });

  testWidgets('a per-question budget counts down and resets per question', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focus_timer_settings_v1':
          '{"limit":"perQuestion","totalMinutes":60,"questionSeconds":30}',
    });
    final drafts = await _openQuizPage(tester);
    expect(_clockSeconds(tester), 30);

    await _advance(tester, 4);
    expect(_clockSeconds(tester), 26);

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(
      _clockSeconds(tester),
      30,
      reason: 'cada questão tem orçamento próprio',
    );
    drafts.dispose();
  });

  testWidgets('an exhausted budget announces itself once and stays editable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'focus_timer_settings_v1':
          '{"limit":"perQuestion","totalMinutes":60,"questionSeconds":15}',
    });
    final drafts = await _openQuizPage(tester);
    await _advance(tester, 16);
    await tester.pump();

    expect(_clockSeconds(tester), 0);
    expect(
      find.text('Tempo esgotado. Você pode continuar respondendo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Um'));
    await tester.pump();
    expect(_clockSeconds(tester), 0);
    drafts.dispose();
  });

  testWidgets('choosing a total limit persists and counts the whole proof', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final drafts = await _openQuizPage(tester);

    await tester.tap(find.byTooltip('Configurar tempo do Modo Foco'));
    await tester.pumpAndSettle();
    expect(find.text('Tempo do Modo Foco'), findsOneWidget);

    await tester.tap(find.text('Prova'));
    await tester.pump();
    await tester.tap(find.text('Salvar tempo'));
    await tester.pumpAndSettle();

    // pumpAndSettle consome tempo falso, então o valor exato depende do
    // número de quadros: o que importa é a contagem regressiva do orçamento.
    expect(_clockSeconds(tester) <= 60 * 60, isTrue);
    final before = _clockSeconds(tester);
    await _advance(tester, 3);
    expect(_clockSeconds(tester), before - 3);

    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('focus_timer_settings_v1'),
      contains('"total"'),
    );
    drafts.dispose();
  });

  testWidgets('a 360px phone fits the clock, the trigger and the sheet', (
    tester,
  ) async {
    // Um botão a mais na barra do Modo Foco só é aceitável se a barra couber
    // no celular; overflow de RenderFlex estoura este teste sozinho.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final drafts = await _openQuizPage(tester);

    expect(find.byTooltip('Configurar tempo do Modo Foco'), findsOneWidget);
    await tester.tap(find.byTooltip('Configurar tempo do Modo Foco'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar tempo'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Questão'));
    await tester.pump();
    await tester.tap(find.text('Salvar tempo'));
    await tester.pumpAndSettle();
    final before = _clockSeconds(tester);
    expect(before <= FocusTimerSettings.maxQuestionSeconds, isTrue);
    await _advance(tester, 3);
    expect(_clockSeconds(tester), before - 3);
    drafts.dispose();
  });
}
