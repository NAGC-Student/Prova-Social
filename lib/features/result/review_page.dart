import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/question_media_gallery.dart';
import '../../domain/models/exam.dart';

enum QuestionState { all, wrong, correct, notAnswered, noKey }

class ReviewPage extends StatefulWidget {
  const ReviewPage({required this.result, super.key});

  final ExamResult result;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  QuestionState _activeFilter = QuestionState.all;

  List<String> get _visibleQuestionIds {
    final result = widget.result;
    return [
      for (final question in result.versionedQuestions)
        if (_matches(result, question)) question.id,
    ];
  }

  bool _matches(ExamResult result, Question question) {
    final selected = result.answers[question.id];
    return switch (_activeFilter) {
      QuestionState.all => true,
      QuestionState.wrong =>
        selected != null &&
            question.hasCorrectAnswer &&
            selected != question.correctIndex,
      QuestionState.correct =>
        selected != null && selected == question.correctIndex,
      QuestionState.notAnswered => selected == null,
      QuestionState.noKey => !question.hasCorrectAnswer,
    };
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final visibleIds = _visibleQuestionIds;
    final noKey = result.versionedQuestions
        .where((question) => !question.hasCorrectAnswer)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisão das questões')),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final state in QuestionState.values) ...[
                  if (state != QuestionState.all)
                    const SizedBox(width: AppSpacing.xs),
                  FilterChip(
                    label: Text(_label(state)),
                    selected: _activeFilter == state,
                    onSelected: (_) => setState(() => _activeFilter = state),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Count(label: 'Certas', value: result.correct),
                _Count(
                  label: 'Erradas',
                  value: result.wrongQuestionIds.length,
                ),
                _Count(label: 'Em branco', value: result.unanswered),
                if (noKey > 0) _Count(label: 'Sem gabarito', value: noKey),
                _Count(label: 'Exibidas', value: visibleIds.length),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleIds.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma questão ${_emptyFilterLabel(_activeFilter)}.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: visibleIds.length,
                    itemBuilder: (context, listIndex) {
                      final questionId = visibleIds[listIndex];
                      final question = result.versionedQuestions
                          .firstWhere((q) => q.id == questionId);
                      final questionNumber = result.versionedQuestions.indexWhere((q) => q.id == questionId) + 1;
                      final selected = result.answers[questionId];
                      final isCorrect =
                          selected != null && selected == question.correctIndex;
                      final isWrong =
                          selected != null &&
                          question.correctIndex != null &&
                          selected != question.correctIndex;
                      final answer = selected == null
                          ? 'Em branco'
                          : question.options[selected];
                      final key = question.correctIndex == null
                          ? 'Gabarito indisponível'
                          : question.options[question.correctIndex!];
                      final status = isCorrect
                          ? 'Correta'
                          : isWrong
                          ? 'Errada'
                          : selected == null
                          ? 'Em branco'
                          : 'Sem gabarito';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCorrect
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    color: isCorrect
                                        ? EmeraldColors.primary
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Questão $questionNumber · $status',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (result.markedForReview.contains(
                                    questionId,
                                  ))
                                    const Tooltip(
                                      message: 'Marcada para revisão',
                                      child: Icon(Icons.bookmark_rounded),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(question.statement),
                              if (question.media.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                QuestionMediaGallery(media: question.media),
                              ],
                              const SizedBox(height: 10),
                              _Answer(
                                label: 'Sua resposta',
                                value: answer,
                                question: question,
                                optionIndex: selected,
                              ),
                              if (!isCorrect)
                                _Answer(
                                  label: 'Gabarito',
                                  value: key,
                                  question: question,
                                  optionIndex: question.correctIndex,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static String _label(QuestionState state) => switch (state) {
    QuestionState.all => 'Todas',
    QuestionState.wrong => 'Erradas',
    QuestionState.correct => 'Certas',
    QuestionState.notAnswered => 'Em branco',
    QuestionState.noKey => 'Sem gabarito',
  };

  static String _emptyFilterLabel(QuestionState state) => switch (state) {
    QuestionState.all => 'disponíveis',
    QuestionState.wrong => 'erradas',
    QuestionState.correct => 'corretas',
    QuestionState.notAnswered => 'em branco',
    QuestionState.noKey => 'sem gabarito',
  };
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Text('$label: $value');
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.label,
    required this.value,
    this.question,
    this.optionIndex,
  });
  final String label;
  final String value;
  final Question? question;
  final int? optionIndex;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        if (question != null && optionIndex != null)
          QuestionOptionContent(question: question!, optionIndex: optionIndex!),
      ],
    ),
  );
}
