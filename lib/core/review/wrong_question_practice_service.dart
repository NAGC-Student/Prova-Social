import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/exam.dart';

class WrongQuestionPracticeRequest {
  const WrongQuestionPracticeRequest({
    required this.questionLimit,
    this.topic,
    this.examId,
    this.since,
  });

  final int questionLimit;
  final String? topic;
  final String? examId;
  final DateTime? since;
}

class WrongQuestionPracticeOutcome {
  const WrongQuestionPracticeOutcome({
    required this.exam,
    required this.availableCount,
    required this.requestedCount,
    required this.selectedCount,
  });

  final Exam? exam;
  final int availableCount;
  final int requestedCount;
  final int selectedCount;

  bool get isSufficient => selectedCount >= requestedCount;
}

class WrongQuestionPracticeService {
  const WrongQuestionPracticeService();

  WrongQuestionPracticeOutcome generate({
    required Iterable<ExamResult> history,
    required WrongQuestionPracticeRequest request,
    ExamResult? currentResult,
    DateTime? generatedAt,
  }) {
    if (request.questionLimit < 1 || request.questionLimit > 100) {
      throw ArgumentError.value(
        request.questionLimit,
        'questionLimit',
        'Must be between 1 and 100.',
      );
    }

    final resultsByAttempt = <String, ExamResult>{};
    for (final result in [...history, ?currentResult]) {
      resultsByAttempt.putIfAbsent(_attemptKey(result), () => result);
    }
    final results = resultsByAttempt.values.toList()
      ..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));
    final candidatesByQuestion = <String, _WrongQuestionCandidate>{};

    for (final result in results) {
      for (var index = 0; index < result.exam.questions.length; index++) {
        final question = result.exam.questions[index];
        final answerKey = question.correctIndex;
        if (answerKey == null ||
            answerKey < 0 ||
            answerKey >= question.options.length) {
          continue;
        }
        final key = _questionKey(result.exam.id, question);
        final candidate = candidatesByQuestion.putIfAbsent(
          key,
          () => _WrongQuestionCandidate(
            sourceExam: result.exam,
            question: question,
            sourceIndex: index,
            topic: question.topic.trim().isEmpty ? 'Geral' : question.topic,
          ),
        );
        final selected = result.answers[index];
        if (selected == null) {
          candidate.lastOutcome = _AttemptQuestionOutcome.unanswered;
        } else if (selected == answerKey) {
          candidate.lastOutcome = _AttemptQuestionOutcome.correct;
        } else {
          candidate.wrongAttempts++;
          candidate.lastWrongAt = result.finishedAt;
          candidate.lastOutcome = _AttemptQuestionOutcome.wrong;
        }
      }
    }

    final normalizedTopic = request.topic?.trim().toLowerCase();
    final since = request.since?.toUtc();
    final candidates = candidatesByQuestion.values.where((candidate) {
      if (candidate.wrongAttempts == 0 ||
          candidate.lastOutcome == _AttemptQuestionOutcome.correct) {
        return false;
      }
      if (request.examId != null && candidate.sourceExam.id != request.examId) {
        return false;
      }
      if (normalizedTopic != null &&
          normalizedTopic.isNotEmpty &&
          candidate.topic.toLowerCase() != normalizedTopic) {
        return false;
      }
      if (since != null && candidate.lastWrongAt!.toUtc().isBefore(since)) {
        return false;
      }
      return true;
    }).toList();

    candidates.sort((a, b) {
      final recurrence = b.wrongAttempts.compareTo(a.wrongAttempts);
      if (recurrence != 0) return recurrence;
      final recency = b.lastWrongAt!.compareTo(a.lastWrongAt!);
      if (recency != 0) return recency;
      return _questionKey(
        a.sourceExam.id,
        a.question,
      ).compareTo(_questionKey(b.sourceExam.id, b.question));
    });

    final selected = _distributeAcrossTopics(candidates)
        .take(request.questionLimit)
        .toList(growable: false);
    if (selected.isEmpty) {
      return WrongQuestionPracticeOutcome(
        exam: null,
        availableCount: candidates.length,
        requestedCount: request.questionLimit,
        selectedCount: 0,
      );
    }

    final firstExam = selected.first.sourceExam;
    final key = selected
        .map(
          (candidate) =>
              _questionKey(candidate.sourceExam.id, candidate.question),
        )
        .join('|');
    final digest = sha256.convert(utf8.encode(key)).toString().substring(0, 12);
    final stamp = (generatedAt ?? DateTime.now())
        .toUtc()
        .microsecondsSinceEpoch;
    final exam = Exam(
      id: 'local-wrong-practice-$stamp-$digest',
      isLocal: true,
      category: request.topic?.trim().isNotEmpty == true
          ? request.topic!.trim()
          : 'Revisão',
      title: 'Questões para revisar',
      description:
          'Questões respondidas incorretamente no histórico local. '
          'A seleção prioriza erros recorrentes e evita repetir uma questão '
          'na mesma prova.',
      author: firstExam.author,
      uploaderName: firstExam.uploaderName,
      durationMinutes: 0,
      attempts: 0,
      year: firstExam.year,
      sourceType: firstExam.sourceType,
      sourceUrl: firstExam.sourceUrl,
      questions: [
        for (final candidate in selected)
          Question(
            id: 'retry-${_questionKey(candidate.sourceExam.id, candidate.question)}',
            topic: candidate.topic,
            statement: candidate.question.statement,
            options: candidate.question.options,
            correctIndex: candidate.question.correctIndex,
            media: candidate.question.media,
          ),
      ],
    );
    return WrongQuestionPracticeOutcome(
      exam: exam,
      availableCount: candidates.length,
      requestedCount: request.questionLimit,
      selectedCount: selected.length,
    );
  }

  List<_WrongQuestionCandidate> _distributeAcrossTopics(
    List<_WrongQuestionCandidate> candidates,
  ) {
    final groups = <String, List<_WrongQuestionCandidate>>{};
    for (final candidate in candidates) {
      groups.putIfAbsent(candidate.topic, () => []).add(candidate);
    }
    final topics = groups.keys.toList()
      ..sort((a, b) {
        final strongest = groups[b]!.first.wrongAttempts.compareTo(
          groups[a]!.first.wrongAttempts,
        );
        return strongest != 0 ? strongest : a.compareTo(b);
      });
    final result = <_WrongQuestionCandidate>[];
    var index = 0;
    while (topics.any((topic) => index < groups[topic]!.length)) {
      for (final topic in topics) {
        final group = groups[topic]!;
        if (index < group.length) result.add(group[index]);
      }
      index++;
    }
    return result;
  }

  String _attemptKey(ExamResult result) {
    final answers = result.answers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return '${result.exam.id}|${result.finishedAt.toUtc().microsecondsSinceEpoch}|'
        '${answers.map((answer) => '${answer.key}:${answer.value}').join(',')}';
  }

  String _questionKey(String examId, Question question) {
    final stableId = question.id.trim().isNotEmpty
        ? question.id.trim()
        : sha256.convert(utf8.encode(question.statement.trim())).toString();
    return '$examId|$stableId';
  }
}

enum _AttemptQuestionOutcome { wrong, correct, unanswered }

class _WrongQuestionCandidate {
  _WrongQuestionCandidate({
    required this.sourceExam,
    required this.question,
    required this.sourceIndex,
    required this.topic,
  });

  final Exam sourceExam;
  final Question question;
  final int sourceIndex;
  final String topic;
  int wrongAttempts = 0;
  DateTime? lastWrongAt;
  _AttemptQuestionOutcome? lastOutcome;
}
