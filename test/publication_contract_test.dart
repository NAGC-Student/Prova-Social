import 'package:flutter_test/flutter_test.dart';
import 'package:prova_social/core/import/question_parser.dart';
import 'package:prova_social/core/publish/exam_publication_contract.dart';

ImportedQuestion _question({
  String statement = 'Enunciado válido?',
  List<String> options = const ['Alternativa A', 'Alternativa B'],
  int? correctIndex = 0,
  String? topic = 'História',
  QuestionFormat format = QuestionFormat.multipleChoice,
  QuestionReviewState reviewState = QuestionReviewState.reviewed,
}) => ImportedQuestion(
  statement: statement,
  options: options,
  correctIndex: correctIndex,
  topic: topic,
  format: format,
  reviewState: reviewState,
);

String? _questionsError(
  List<ImportedQuestion> questions, {
  bool allowOpenEnded = false,
}) => ExamPublicationContract.questionsError(
  questions,
  allowOpenEnded: allowOpenEnded,
);

void main() {
  group('normalizeTopic', () {
    test('remove espaços e usa Geral quando o tópico está vazio', () {
      expect(
        ExamPublicationContract.normalizeTopic('  História  '),
        'História',
      );
      expect(ExamPublicationContract.normalizeTopic(''), 'Geral');
      expect(ExamPublicationContract.normalizeTopic('   '), 'Geral');
      expect(ExamPublicationContract.normalizeTopic(null), 'Geral');
    });

    test('limita o tópico a 100 caracteres', () {
      final longTopic = 'á' * 120;
      expect(ExamPublicationContract.normalizeTopic(longTopic).length, 100);
    });
  });

  group('metadataError', () {
    String? error({
      String title = 'Prova válida',
      String category = 'Matemática',
      String source = 'Instituição',
      int durationMinutes = 60,
      int? year = 2024,
      String? sourceUrl,
      String? board,
      String? institution,
      String? instance,
    }) => ExamPublicationContract.metadataError(
      title: title,
      category: category,
      source: source,
      durationMinutes: durationMinutes,
      year: year,
      sourceUrl: sourceUrl,
      board: board,
      institution: institution,
      instance: instance,
    );

    test('aceita metadados válidos', () {
      expect(error(), isNull);
      expect(error(year: null), isNull);
      expect(error(sourceUrl: 'https://prova.example.org/2024'), isNull);
    });

    test('recusa título, categoria e fonte fora dos limites', () {
      expect(error(title: 'ab'), contains('título'));
      expect(error(title: 'a' * 181), contains('título'));
      expect(error(category: 'a'), contains('categoria'));
      expect(error(category: 'a' * 81), contains('categoria'));
      expect(error(source: 'a'), contains('fonte'));
      expect(error(source: 'a' * 161), contains('fonte'));
    });

    test('recusa duração e ano fora dos limites', () {
      expect(error(durationMinutes: 0), contains('duração'));
      expect(error(durationMinutes: 1441), contains('duração'));
      expect(error(year: 1899), contains('ano'));
      expect(error(year: 2201), contains('ano'));
    });

    test('recusa URL que não seja HTTPS válida', () {
      expect(error(sourceUrl: 'http://prova.example.org'), contains('HTTPS'));
      expect(error(sourceUrl: 'nao-e-url'), contains('HTTPS'));
      expect(
        error(sourceUrl: 'https://user:senha@prova.example.org'),
        contains('HTTPS'),
      );
    });

    test('validates optional board, institution and instance lengths', () {
      expect(error(), isNull);
      expect(error(board: 'B' * 121), contains('banca'));
      expect(error(institution: 'I' * 181), contains('instituição'));
      expect(error(instance: 'E' * 121), contains('etapa'));
      expect(error(board: '  '), isNull);
    });
  });

  group('questionsError', () {
    test('recusa prova vazia e prova acima de 300 questões', () {
      expect(_questionsError(const []), 'Adicione pelo menos uma questão.');
      expect(_questionsError(List.filled(301, _question())), contains('300'));
    });

    test('recusa enunciado fora dos limites', () {
      expect(
        _questionsError([_question(statement: 'a')]),
        contains('enunciado'),
      );
      expect(
        _questionsError([_question(statement: 'a' * 20001)]),
        contains('enunciado'),
      );
    });

    test('recusa quantidade ou conteúdo inválido de alternativas', () {
      expect(
        _questionsError([
          _question(options: const ['A'], correctIndex: 0),
        ]),
        contains('2 e 8'),
      );
      expect(
        _questionsError([
          _question(options: List.filled(9, 'A'), correctIndex: 0),
        ]),
        contains('2 e 8'),
      );
      expect(
        _questionsError([
          _question(options: const ['A', '  '], correctIndex: 0),
        ]),
        contains('alternativa'),
      );
      expect(
        _questionsError([
          _question(options: ['A', 'b' * 4001], correctIndex: 0),
        ]),
        contains('4.000'),
      );
    });

    test('recusa gabarito ausente ou fora do intervalo', () {
      expect(
        _questionsError([_question(correctIndex: null)]),
        contains('gabarito'),
      );
      expect(
        _questionsError([_question(correctIndex: -1)]),
        contains('gabarito'),
      );
      expect(
        _questionsError([_question(correctIndex: 2)]),
        contains('gabarito'),
      );
    });

    test('recusa questão que ainda não foi revisada', () {
      expect(
        _questionsError([
          _question(reviewState: QuestionReviewState.unreviewed),
        ]),
        'A questão 1 ainda não foi revisada.',
      );
    });

    test('recusa discursiva com mensagem explícita', () {
      expect(
        _questionsError([
          _question(
            options: const [],
            correctIndex: null,
            format: QuestionFormat.openEnded,
          ),
        ]),
        'A questão 1 é discursiva. A publicação de discursivas ainda não está disponível.',
      );
    });

    test('recusa formato desconhecido com mensagem explícita', () {
      expect(
        _questionsError([_question(format: QuestionFormat.unknown)]),
        'A questão 1 tem formato desconhecido e não pode ser publicada.',
      );
    });

    test('recusa payload acima de 8 MB', () {
      final heavy = _question(
        options: List.filled(8, 'a' * 4000),
        correctIndex: 0,
      );
      final payload = List.filled(300, heavy);
      expect(_questionsError(payload), 'O conteúdo excede o limite de 8 MB.');
    });
  });

  group('questionPayload', () {
    test('preserva e normaliza o tópico e apara os textos', () {
      final payload = ExamPublicationContract.questionPayload([
        _question(
          statement: '  Enunciado  ',
          options: const ['  A  ', '  B  '],
          topic: '  Matemática  ',
        ),
      ], includeOpenEnded: false);

      expect(payload.single['topic'], 'Matemática');
      expect(payload.single['statement'], 'Enunciado');
      expect(payload.single['options'], ['A', 'B']);
      expect(payload.single['correct_index'], 0);
      expect(payload.single.containsKey('format'), isFalse);
    });

    test('exclui discursivas quando elas não são permitidas', () {
      final payload = ExamPublicationContract.questionPayload([
        _question(),
        _question(
          options: const [],
          correctIndex: null,
          format: QuestionFormat.openEnded,
        ),
      ], includeOpenEnded: false);
      expect(payload, hasLength(1));
    });

    test('inclui discursivas quando permitido', () {
      final payload = ExamPublicationContract.questionPayload([
        _question(),
        _question(
          options: const [],
          correctIndex: null,
          format: QuestionFormat.openEnded,
        ),
      ], includeOpenEnded: true);
      expect(payload, hasLength(2));
      expect(payload.last['options'], isEmpty);
      expect(payload.last['correct_index'], isNull);
    });
  });

  group('URL de origem', () {
    test('normaliza, valida e rejeita', () {
      expect(ExamPublicationContract.normalizeSourceUrl('  '), isNull);
      expect(
        ExamPublicationContract.normalizeSourceUrl(
          ' https://prova.example.org/2024 ',
        ),
        'https://prova.example.org/2024',
      );
      expect(
        ExamPublicationContract.isValidSourceUrl(
          'https://prova.example.org/2024',
        ),
        isTrue,
      );
      expect(
        ExamPublicationContract.isValidSourceUrl('http://prova.example.org'),
        isFalse,
      );
    });
  });
}
