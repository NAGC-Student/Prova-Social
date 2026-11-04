import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/review/wrong_question_practice_service.dart';
import 'package:prova_social/domain/models/exam.dart';

Exam exam({String id = 'exam-1', List<Question> questions = const []}) => Exam(
  id: id,
  category: 'Geral',
  title: 'Prova $id',
  description: '',
  author: 'Origem',
  durationMinutes: 60,
  attempts: 0,
  questions: questions,
);

Question question(String id, String topic) => Question(
  id: id,
  topic: topic,
  statement: 'Enunciado de $id?',
  options: const ['Correta', 'Incorreta'],
  correctIndex: 0,
);

ExamResult result({
  required Exam exam,
  required Map<int, int> answers,
  required DateTime finishedAt,
}) => ExamResult(
  exam: exam,
  answers: answers,
  markedForReview: const {},
  durationSeconds: 30,
  finishedAt: finishedAt,
);

void main() {
  const service = WrongQuestionPracticeService();
  final firstAttempt = DateTime.utc(2026, 11, 1);
  final secondAttempt = DateTime.utc(2026, 11, 2);

  test('prioritizes repeated mistakes and deduplicates selected questions', () {
    final source = exam(
      questions: [
        question('recurring', 'Matemática'),
        question('recent', 'Português'),
      ],
    );
    final outcome = service.generate(
      history: [
        result(
          exam: source,
          answers: const {0: 1, 1: 1},
          finishedAt: firstAttempt,
        ),
        result(exam: source, answers: const {0: 1}, finishedAt: secondAttempt),
      ],
      request: const WrongQuestionPracticeRequest(questionLimit: 2),
      generatedAt: secondAttempt,
    );

    expect(outcome.isSufficient, isTrue);
    expect(outcome.availableCount, 2);
    expect(outcome.exam, isNotNull);
    expect(outcome.exam!.isLocal, isTrue);
    expect(
      outcome.exam!.questions.map((item) => item.id).toSet(),
      hasLength(2),
    );
    expect(outcome.exam!.questions.first.statement, 'Enunciado de recurring?');
    expect(outcome.exam!.questions.first.topic, 'Matemática');
  });

  test('deduplicates a stable question id when its order changes', () {
    final firstVersion = exam(
      id: 'versioned-exam',
      questions: [
        question('same-question', 'Física'),
        question('other-question', 'Química'),
      ],
    );
    final reorderedVersion = exam(
      id: 'versioned-exam',
      questions: [
        question('other-question', 'Química'),
        question('same-question', 'Física'),
      ],
    );
    final outcome = service.generate(
      history: [
        result(
          exam: firstVersion,
          answers: const {0: 1},
          finishedAt: firstAttempt,
        ),
        result(
          exam: reorderedVersion,
          answers: const {1: 1},
          finishedAt: secondAttempt,
        ),
      ],
      request: const WrongQuestionPracticeRequest(questionLimit: 2),
    );

    expect(outcome.availableCount, 1);
    expect(outcome.exam!.questions, hasLength(1));
    expect(
      outcome.exam!.questions.single.statement,
      'Enunciado de same-question?',
    );
  });

  test('does not reselect a question corrected in a later attempt', () {
    final source = exam(questions: [question('learned', 'História')]);
    final outcome = service.generate(
      history: [
        result(exam: source, answers: const {0: 1}, finishedAt: firstAttempt),
        result(exam: source, answers: const {0: 0}, finishedAt: secondAttempt),
      ],
      request: const WrongQuestionPracticeRequest(questionLimit: 1),
    );

    expect(outcome.exam, isNull);
    expect(outcome.availableCount, 0);
    expect(outcome.selectedCount, 0);
  });

  test('excludes unanswered questions from being counted as wrong', () {
    final source = exam(
      questions: [
        question('wrong', 'Matemática'),
        question('blank', 'Matemática'),
      ],
    );
    final outcome = service.generate(
      history: [
        result(exam: source, answers: const {0: 1}, finishedAt: firstAttempt),
      ],
      request: const WrongQuestionPracticeRequest(questionLimit: 2),
    );

    expect(outcome.availableCount, 1);
    expect(outcome.selectedCount, 1);
    expect(outcome.isSufficient, isFalse);
    expect(outcome.exam!.questions.single.id, contains('wrong'));
  });

  test('returns an honest empty outcome when history has no errors', () {
    final source = exam(questions: [question('correct', 'Biologia')]);
    final outcome = service.generate(
      history: [
        result(exam: source, answers: const {0: 0}, finishedAt: firstAttempt),
      ],
      request: const WrongQuestionPracticeRequest(questionLimit: 1),
    );

    expect(outcome.exam, isNull);
    expect(outcome.availableCount, 0);
    expect(outcome.isSufficient, isFalse);
  });

  test('filters by topic, original exam and last mistake date', () {
    final source = exam(
      questions: [
        question('math', 'Matemática'),
        question('history', 'História'),
      ],
    );
    final outcome = service.generate(
      history: [
        result(
          exam: source,
          answers: const {0: 1, 1: 1},
          finishedAt: firstAttempt,
        ),
      ],
      request: WrongQuestionPracticeRequest(
        questionLimit: 2,
        topic: 'história',
        examId: source.id,
        since: secondAttempt,
      ),
    );

    expect(outcome.exam, isNull);
    expect(outcome.availableCount, 0);
  });

  test('includes current result once when it is also in stored history', () {
    final source = exam(questions: [question('q1', 'Geografia')]);
    final current = result(
      exam: source,
      answers: const {0: 1},
      finishedAt: firstAttempt,
    );
    final outcome = service.generate(
      history: [current],
      currentResult: current,
      request: const WrongQuestionPracticeRequest(questionLimit: 1),
    );

    expect(outcome.availableCount, 1);
    expect(outcome.selectedCount, 1);
  });

  test('rejects unreasonable question limits', () {
    expect(
      () => service.generate(
        history: const [],
        request: const WrongQuestionPracticeRequest(questionLimit: 101),
      ),
      throwsArgumentError,
    );
  });
}
