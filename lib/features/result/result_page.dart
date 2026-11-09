import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/source_badge.dart';
import '../../core/backend/attempt_sync_service.dart';
import '../../core/review/wrong_question_practice_service.dart';
import '../../domain/models/exam.dart';
import 'review_page.dart';
import '../quiz/quiz_page.dart';

class PendingResultPage extends StatefulWidget {
  const PendingResultPage({
    required this.clientAttemptId,
    required this.syncService,
    this.onSignIn,
    super.key,
  });
  final String clientAttemptId;
  final AttemptSyncService syncService;
  final Future<void> Function()? onSignIn;

  @override
  State<PendingResultPage> createState() => _PendingResultPageState();
}

class _PendingResultPageState extends State<PendingResultPage>
    with WidgetsBindingObserver {
  PendingAttempt? attempt;
  Timer? retryTimer;
  bool syncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _sync({
    bool ignoreSchedule = false,
    bool retryAttention = false,
  }) async {
    if (!mounted || syncing) return;
    setState(() => syncing = true);
    try {
      final outcome = await widget.syncService.sync(
        widget.clientAttemptId,
        ignoreSchedule: ignoreSchedule,
        retryAttention: retryAttention,
      );
      if (!mounted) return;
      if (outcome.result != null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ResultPage(result: outcome.result!),
          ),
        );
        return;
      }
      setState(() => attempt = outcome.attempt);
      _schedule(outcome.attempt.nextAttemptAt);
    } catch (_) {
      if (mounted) {
        final stored = await widget.syncService.store.find(
          widget.clientAttemptId,
        );
        if (mounted) setState(() => attempt = stored);
      }
    } finally {
      if (mounted) setState(() => syncing = false);
    }
  }

  Future<void> _signInAndSync() async {
    final signIn = widget.onSignIn;
    if (signIn == null) return;
    await signIn();
    if (mounted) await _sync(ignoreSchedule: true);
  }

  void _schedule(DateTime? when) {
    retryTimer?.cancel();
    if (when == null) return;
    final delay = when.difference(DateTime.now());
    retryTimer = Timer(delay.isNegative ? Duration.zero : delay, _sync);
  }

  @override
  Widget build(BuildContext context) {
    final state = syncing ? AttemptSyncState.sending : attempt?.state;
    final (title, message, icon) = switch (state) {
      AttemptSyncState.sending => (
        'Enviando entrega',
        'Aguarde enquanto enviamos suas respostas para correção.',
        Icons.sync_rounded,
      ),
      AttemptSyncState.requiresAttention => (
        'Entrega requer atenção',
        attempt?.lastError ?? 'O servidor recusou esta entrega.',
        Icons.error_outline_rounded,
      ),
      AttemptSyncState.waitingAuthentication => (
        'Entre para sincronizar',
        attempt?.lastError ?? 'Sua entrega está salva neste aparelho. Entre para receber a correção.',
        Icons.lock_outline_rounded,
      ),
      AttemptSyncState.synced => (
        'Entrega sincronizada',
        'A correção está disponível.',
        Icons.check_circle_outline_rounded,
      ),
      _ => (
        'Entrega salva no aparelho — aguardando correção',
        state == AttemptSyncState.waitingConnection
            ? 'Aguardando conexão. Tentaremos novamente no horário programado.'
            : 'A entrega está segura no aparelho e será enviada em seguida.',
        Icons.cloud_off_rounded,
      ),
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Entrega da prova')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 56,
                    color: state == AttemptSyncState.requiresAttention
                        ? EmeraldColors.error
                        : EmeraldColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center),
                  if (!syncing) ...[
                    const SizedBox(height: 20),
                    if (state == AttemptSyncState.waitingAuthentication &&
                        widget.onSignIn != null)
                      FilledButton.icon(
                        onPressed: _signInAndSync,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Entrar e sincronizar'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: () =>
                            _sync(ignoreSchedule: true, retryAttention: true),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Tentar agora'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ResultPage extends StatelessWidget {
  const ResultPage({required this.result, this.syncService, super.key});
  final ExamResult result;
  final AttemptSyncService? syncService;

  @override
  Widget build(BuildContext context) {
    final wrongQuestionsExam = result.wrongQuestionsExam;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: EmeraldColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROVA CONCLUÍDA',
                            style: TextStyle(
                              color: EmeraldColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            result.correctableCount == 0
                                ? '—'
                                : '${result.scorePercent}%',
                            style: const TextStyle(
                              color: EmeraldColors.textPrimary,
                              fontSize: 64,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -3,
                            ),
                          ),
                          Text(
                            result.correctableCount == 0
                                ? 'Nenhuma questão tem gabarito para corrigir'
                                : '${result.correct} de ${result.correctableCount} questões corrigíveis',
                            style: const TextStyle(
                              color: EmeraldColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Confira seu desempenho e revise as questões quando quiser.',
                            style: TextStyle(color: EmeraldColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: _time(result.durationSeconds),
                          label: 'Tempo total',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value: '${result.correct}',
                          label: 'Corretas',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Stat(
                          value:
                              '${result.exam.questions.length - result.correct}',
                          label: 'Revisar',
                        ),
                      ),
                    ],
                  ),
                  if (wrongQuestionsExam != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => QuizPage(exam: wrongQuestionsExam),
                        ),
                      ),
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        wrongQuestionsExam.questions.length == 1
                            ? 'Refazer 1 questão errada'
                            : 'Refazer ${wrongQuestionsExam.questions.length} questões erradas',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  _HistoryWrongPracticeButton(
                    result: result,
                    syncService: syncService,
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      Text('Erradas: ${result.wrongQuestionIndices.length}'),
                      Text('Em branco: ${result.unanswered}'),
                      Text('Marcadas: ${result.markedForReview.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SourceBadge(sourceType: result.exam.sourceType),
                  Text(
                    '${result.exam.author}'
                    '${result.exam.year == null ? '' : ' · ${result.exam.year}'}',
                  ),
                  if (result.exam.safeSourceUrl case final sourceUrl?)
                    TextButton.icon(
                      onPressed: () => launchUrl(sourceUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Abrir fonte'),
                    ),
                  if (result.byTopic.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Desempenho por assunto',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    for (final topic in result.byTopic.entries)
                      _TopicPerformance(
                        topic: topic.key,
                        correct: topic.value.correct,
                        total: topic.value.total,
                      ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReviewPage(result: result),
                      ),
                    ),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Abrir revisão das questões'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _copyJson(context),
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copiar resultado JSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyJson(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Resultado JSON copiado.')));
    }
  }

  static String _time(int value) =>
      '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
}

class _HistoryWrongPracticeButton extends StatefulWidget {
  const _HistoryWrongPracticeButton({required this.result, this.syncService});

  final ExamResult result;
  final AttemptSyncService? syncService;

  @override
  State<_HistoryWrongPracticeButton> createState() =>
      _HistoryWrongPracticeButtonState();
}

class _HistoryWrongPracticeButtonState
    extends State<_HistoryWrongPracticeButton> {
  final _service = const WrongQuestionPracticeService();
  late Future<Map<String, ExamResult>> _history;
  String? _topic;
  String? _examId;
  int? _days;
  int _questionLimit = 10;

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<Map<String, ExamResult>> _loadHistory() async {
    final history = await (widget.syncService ?? AttemptSyncService()).store
        .completed();
    final allCandidates = _service.generate(
      history: history.values,
      currentResult: widget.result,
      request: const WrongQuestionPracticeRequest(questionLimit: 100),
    );
    if (allCandidates.availableCount > 0) {
      _questionLimit = allCandidates.availableCount.clamp(1, 10);
    }
    return history;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, ExamResult>>(
    future: _history,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível ler o histórico de erros salvo neste aparelho.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () => setState(() => _history = _loadHistory()),
              child: const Text('Tentar carregar novamente'),
            ),
          ],
        );
      }
      if (!snapshot.hasData) {
        return const Text('Lendo histórico de erros salvo neste aparelho...');
      }

      final outcome = _service.generate(
        history: snapshot.data!.values,
        currentResult: widget.result,
        request: WrongQuestionPracticeRequest(
          questionLimit: _questionLimit,
          topic: _topic,
          examId: _examId,
          since: _days == null
              ? null
              : DateTime.now().subtract(Duration(days: _days!)),
        ),
      );
      if (outcome.availableCount == 0) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ainda não há questões respondidas incorretamente que atendam a esses filtros.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_topic != null || _examId != null || _days != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _editFilters(history: snapshot.data!.values),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Ajustar filtros'),
                ),
              ),
          ],
        );
      }

      final insufficient = !outcome.isSufficient;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            onPressed: insufficient
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => QuizPage(exam: outcome.exam!),
                    ),
                  ),
            icon: const Icon(Icons.history_rounded),
            label: Text(
              'Refazer ${outcome.selectedCount} questão(ões) dos erros',
            ),
          ),
          if (insufficient) ...[
            const SizedBox(height: 4),
            Text(
              'Há ${outcome.availableCount} questão(ões), mas o filtro pede ${outcome.requestedCount}. Ajuste os filtros ou a quantidade.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _editFilters(history: snapshot.data!.values),
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Filtros e quantidade'),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _editFilters({required Iterable<ExamResult> history}) async {
    final results = {
      for (final result in [...history, widget.result]) result.exam.id: result,
    }.values.toList(growable: false);
    final topics =
        results
            .expand(
              (result) => result.exam.questions.map((question) {
                final topic = question.topic.trim();
                return topic.isEmpty ? 'Geral' : topic;
              }),
            )
            .toSet()
            .toList()
          ..sort();
    final exams = {
      for (final result in results) result.exam.id: result.exam.title,
    };
    final countController = TextEditingController(
      text: _questionLimit.toString(),
    );
    var topic = _topic;
    var examId = _examId;
    var days = _days;
    final selected = await showDialog<_WrongPracticeFilter>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtrar questões para revisar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: topic,
                  decoration: const InputDecoration(labelText: 'Assunto'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos os assuntos'),
                    ),
                    ...topics.map(
                      (value) => DropdownMenuItem<String?>(
                        value: value,
                        child: Text(value),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => topic = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: examId,
                  decoration: const InputDecoration(
                    labelText: 'Prova original',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todas as provas'),
                    ),
                    ...exams.entries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => examId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: days,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items: const [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Todo o histórico'),
                    ),
                    DropdownMenuItem<int?>(
                      value: 7,
                      child: Text('Últimos 7 dias'),
                    ),
                    DropdownMenuItem<int?>(
                      value: 30,
                      child: Text('Últimos 30 dias'),
                    ),
                    DropdownMenuItem<int?>(
                      value: 90,
                      child: Text('Últimos 90 dias'),
                    ),
                  ],
                  onChanged: (value) => setDialogState(() => days = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: countController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantidade desejada (1–100)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(countController.text.trim());
                if (count == null || count < 1 || count > 100) return;
                Navigator.pop(
                  context,
                  _WrongPracticeFilter(
                    topic: topic,
                    examId: examId,
                    days: days,
                    questionLimit: count,
                  ),
                );
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    countController.dispose();
    if (!mounted || selected == null) return;
    setState(() {
      _topic = selected.topic;
      _examId = selected.examId;
      _days = selected.days;
      _questionLimit = selected.questionLimit;
    });
  }
}

class _WrongPracticeFilter {
  const _WrongPracticeFilter({
    required this.questionLimit,
    this.topic,
    this.examId,
    this.days,
  });

  final int questionLimit;
  final String? topic;
  final String? examId;
  final int? days;
}

class _TopicPerformance extends StatelessWidget {
  const _TopicPerformance({
    required this.topic,
    required this.correct,
    required this.total,
  });

  final String topic;
  final int correct;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      container: true,
      label: '$topic: $correct de $total acertos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(topic)),
              const SizedBox(width: 12),
              Text('$correct/$total'),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: total == 0 ? 0 : correct / total,
            semanticsLabel: 'Desempenho em $topic',
            semanticsValue: '${(correct / total * 100).round()}%',
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
