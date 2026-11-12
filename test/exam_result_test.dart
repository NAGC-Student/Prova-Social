import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/domain/models/exam.dart';

void main() {
  test('calcula pontuação e gera JSON', () {
    const q1 = Question(id: 'q1', topic: 'Geral', statement: 'Q1', options: ['A', 'B'], correctIndex: 1);
    const q2 = Question(id: 'q2', topic: 'Geral', statement: 'Q2', options: ['A', 'B'], correctIndex: 0);
    const q3 = Question(id: 'q3', topic: 'Geral', statement: 'Q3', options: ['A', 'B', 'C'], correctIndex: 2);
    const q4 = Question(id: 'q4', topic: 'Geral', statement: 'Q4', options: ['A', 'B'], correctIndex: 0);
    const q5 = Question(id: 'q5', topic: 'Geral', statement: 'Q5', options: ['A', 'B', 'C'], correctIndex: 2);
    const exam = Exam(
      id: 'exam-test',
      category: 'Matemática',
      title: 'Prova de teste',
      description: '',
      author: 'Teste',
      durationMinutes: 60,
      attempts: 0,
      questions: [q1, q2, q3, q4, q5],
    );
    final result = ExamResult(
      exam: exam,
      answers: {'q1': 1, 'q2': 0, 'q3': 2, 'q4': 1, 'q5': 2},
      markedForReview: {'q2'},
      durationSeconds: 90,
      finishedAt: DateTime.utc(2026, 9, 16),
    );

    expect(result.correct, 4);
    expect(result.scorePercent, 80);
    expect(result.toJson()['total'], 5);
    expect(result.wrongQuestionIds, ['q4']);
    expect(result.wrongQuestionsExam?.isLocal, isTrue);
    expect(result.wrongQuestionsExam?.questions.single.statement, 'Q4');
    expect(result.wrongQuestionsExam?.questions.single.correctIndex, 0);
    expect(result.unanswered, 0);
    expect(result.byTopic['Geral'], (correct: 4, total: 5));
  });

  test('questão em branco sem gabarito não é exportada como correta', () {
    const q1 = Question(id: 'q1', topic: 'Geral', statement: 'Q?', options: ['A', 'B']);
    const exam = Exam(
      id: 'sem-gabarito',
      category: 'Geral',
      title: 'Prova',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [q1],
    );
    final result = ExamResult(
      exam: exam,
      answers: {},
      markedForReview: {},
      durationSeconds: 0,
      finishedAt: DateTime.utc(2026, 9, 26),
    );
    expect(result.correct, 0);
    expect(result.unanswered, 1);
    expect(result.wrongQuestionIds, isEmpty);
    expect(result.wrongQuestionsExam, isNull);
    expect((result.toJson()['answers'] as List).single['isCorrect'], isFalse);
    final empty = ExamResult(
      exam: exam.copyWith(questions: []),
      answers: {},
      markedForReview: {},
      durationSeconds: 0,
      finishedAt: result.finishedAt,
    );
    expect(empty.scorePercent, 0);
  });

  test('pontuação considera apenas questões que têm gabarito válido', () {
    const q1 = Question(id: 'q1', topic: 'Geral', statement: 'Questão corrigível', options: ['A', 'B'], correctIndex: 1);
    const q2 = Question(id: 'q2', topic: 'Geral', statement: 'Questão sem gabarito', options: ['A', 'B']);
    const exam = Exam(
      id: 'misto',
      category: 'Geral',
      title: 'Prova',
      description: '',
      author: 'Fonte',
      durationMinutes: 30,
      attempts: 0,
      questions: [q1, q2],
    );
    final result = ExamResult(
      exam: exam,
      answers: const {'q1': 1, 'q2': 0},
      markedForReview: const {},
      durationSeconds: 30,
      finishedAt: DateTime.utc(2026, 11, 3),
    );

    expect(result.correctableCount, 1);
    expect(result.correct, 1);
    expect(result.scorePercent, 100);
  });
}