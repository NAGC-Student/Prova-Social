import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/backend/local_exam_store.dart';
import 'package:prova_social/core/content/content_version.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/domain/models/exam.dart';

const _question = Question(
  id: 'q1',
  topic: 'Geral',
  statement: 'Pergunta?',
  options: ['Um', 'Dois'],
  correctIndex: 1,
);

ImportedQuestion _imported({
  String statement = 'Pergunta?',
  List<String> options = const ['Um', 'Dois'],
  int? correctIndex = 1,
  String? topic = 'Geral',
  QuestionFormat format = QuestionFormat.multipleChoice,
}) => ImportedQuestion(
  statement: statement,
  options: List.of(options),
  correctIndex: correctIndex,
  topic: topic,
  format: format,
);

void main() {
  group('ContentVersion.ofQuestions', () {
    test('produz o digest canônico documentado', () {
      // [{"position":0,"statement":"Pergunta?","options":["Um","Dois"],
      //   "correctIndex":1,"topic":"Geral"}]
      expect(
        ContentVersion.ofQuestions(const [_question]),
        '4306ab3d9c35c8c100f3dac30fad7f65910ca75113d1b3da4cade4adf4a7040c',
      );
    });

    test('é determinístico e ignora espaços nas pontas', () {
      const spaced = Question(
        id: 'outro-id',
        topic: '  Geral  ',
        statement: '  Pergunta?  ',
        options: [' Um ', ' Dois '],
        correctIndex: 1,
      );
      expect(
        ContentVersion.ofQuestions(const [_question]),
        ContentVersion.ofQuestions(const [spaced]),
      );
    });

    test('muda quando enunciado, alternativa, gabarito ou tópico mudam', () {
      final base = ContentVersion.ofQuestions(const [_question]);
      expect(
        ContentVersion.ofQuestions(const [
          Question(
            topic: 'Geral',
            statement: 'Outra pergunta?',
            options: ['Um', 'Dois'],
            correctIndex: 1,
          ),
        ]),
        isNot(base),
      );
      expect(
        ContentVersion.ofQuestions(const [
          Question(
            topic: 'Geral',
            statement: 'Pergunta?',
            options: ['Um', 'Outra'],
            correctIndex: 1,
          ),
        ]),
        isNot(base),
      );
      expect(
        ContentVersion.ofQuestions(const [
          Question(
            topic: 'Geral',
            statement: 'Pergunta?',
            options: ['Um', 'Dois'],
            correctIndex: 0,
          ),
        ]),
        isNot(base),
      );
      expect(
        ContentVersion.ofQuestions(const [
          Question(
            topic: 'História',
            statement: 'Pergunta?',
            options: ['Um', 'Dois'],
            correctIndex: 1,
          ),
        ]),
        isNot(base),
      );
    });

    test('muda quando a ordem das questões muda', () {
      const other = Question(
        id: 'q2',
        topic: 'Geral',
        statement: 'Segunda?',
        options: ['A', 'B'],
        correctIndex: 0,
      );
      expect(
        ContentVersion.ofQuestions(const [_question, other]),
        isNot(ContentVersion.ofQuestions(const [other, _question])),
      );
    });
  });

  group('ContentVersion.ofImportedQuestions', () {
    test('produz o digest canônico e inclui o formato', () {
      // O formato entra como "multipleChoice" no payload canônico.
      expect(
        ContentVersion.ofImportedQuestions([_imported()]),
        '937015602a30753eea32e7a2ab1579993a87c1512450cf632862079ab5a872ce',
      );
      expect(
        ContentVersion.ofImportedQuestions([
          _imported(format: QuestionFormat.openEnded),
        ]),
        isNot(ContentVersion.ofImportedQuestions([_imported()])),
      );
    });

    test('tópico vazio equivale a Geral', () {
      expect(
        ContentVersion.ofImportedQuestions([_imported(topic: '')]),
        ContentVersion.ofImportedQuestions([_imported(topic: 'Geral')]),
      );
    });
  });

  test('attemptExamId preserva exatamente o hash legado', () {
    final exam = LocalExam(
      id: 'local-test',
      title: 'Prova',
      category: 'Geral',
      source: 'Fonte',
      durationMinutes: 30,
      questions: [_imported()],
    );
    // Hash antigo de [{statement, options, correctIndex}] sem posição, tópico
    // nem formato. Mudar esta expectativa quebra a retomada de rascunhos já
    // gravados (ADR-0003, alternativa B).
    expect(
      exam.attemptExamId,
      'local-test-b5a7d383ab0ef85ef2a8c8c8c105e83512c946f9636a3263d565b30d87fa0e90',
    );
    expect(
      exam.attemptExamId,
      isNot('local-test-${ContentVersion.ofImportedQuestions([_imported()])}'),
    );
  });
}
