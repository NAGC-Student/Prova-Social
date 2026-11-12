import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

enum QuestionType { objective, discursive }

enum ExamSourceType {
  official,
  community,
  unverified;

  static ExamSourceType fromDatabase(Object? value) => switch (value) {
    'official' => official,
    'community' => community,
    _ => unverified,
  };
}

class Question {
  const Question({
    this.id = '',
    required this.topic,
    required this.statement,
    required this.options,
    this.correctIndex,
    this.media = const [],
    this.type = QuestionType.objective,
    this.explanation,
    this.expectedAnswer,
    this.rubric,
    this.canonicalUrl,
    this.source,
    this.version = 1,
    this.contentHash,
  });

  final String id;
  final String topic;
  final String statement;
  final List<String> options;
  final int? correctIndex;
  final List<QuestionMedia> media;
  final QuestionType type;
  final String? explanation;
  final String? expectedAnswer;
  final String? rubric;
  final String? canonicalUrl;
  final String? source;
  final int version;
  final String? contentHash;

  bool get isDiscursive => type == QuestionType.discursive;
  bool get isObjective => type == QuestionType.objective;
  bool get hasCorrectAnswer => correctIndex != null &&
      correctIndex! >= 0 &&
      correctIndex! < options.length;

  Question copyWith({
    String? id,
    String? topic,
    String? statement,
    List<String>? options,
    int? correctIndex,
    List<QuestionMedia>? media,
    QuestionType? type,
    String? explanation,
    String? expectedAnswer,
    String? rubric,
    String? canonicalUrl,
    String? source,
    int? version,
    String? contentHash,
  }) => Question(
    id: id ?? this.id,
    topic: topic ?? this.topic,
    statement: statement ?? this.statement,
    options: options ?? this.options,
    correctIndex: correctIndex ?? this.correctIndex,
    media: media ?? this.media,
    type: type ?? this.type,
    explanation: explanation ?? this.explanation,
    expectedAnswer: expectedAnswer ?? this.expectedAnswer,
    rubric: rubric ?? this.rubric,
    canonicalUrl: canonicalUrl ?? this.canonicalUrl,
    source: source ?? this.source,
    version: version ?? this.version,
    contentHash: contentHash ?? this.contentHash,
  );

  String computeContentHash() {
    final data = [
      statement,
      ...options,
      correctIndex?.toString() ?? '',
      type.name,
      explanation ?? '',
      expectedAnswer ?? '',
      rubric ?? '',
    ].join('\u0000');
    return sha256.convert(utf8.encode(data)).toString();
  }

  Question withContentHash() => copyWith(
    contentHash: computeContentHash(),
    version: version + 1,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'topic': topic,
    'statement': statement,
    'options': options,
    'correctIndex': correctIndex,
    'media': media.map((m) => m.toJson()).toList(),
    'type': type.name,
    'explanation': explanation,
    'expectedAnswer': expectedAnswer,
    'rubric': rubric,
    'canonicalUrl': canonicalUrl,
    'source': source,
    'version': version,
    'contentHash': contentHash,
  };

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    id: json['id'] as String? ?? '',
    topic: json['topic'] as String? ?? '',
    statement: json['statement'] as String? ?? '',
    options: List<String>.from(json['options'] as List? ?? const []),
    correctIndex: json['correctIndex'] as int?,
    media: (json['media'] as List?)
            ?.map((m) => QuestionMedia.fromJson(Map<String, dynamic>.from(m)))
            .toList() ??
        const [],
    type: QuestionType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => QuestionType.objective,
    ),
    explanation: json['explanation'] as String?,
    expectedAnswer: json['expectedAnswer'] as String?,
    rubric: json['rubric'] as String?,
    canonicalUrl: json['canonicalUrl'] as String?,
    source: json['source'] as String?,
    version: json['version'] as int? ?? 1,
    contentHash: json['contentHash'] as String?,
  );
}

class QuestionMedia {
  const QuestionMedia({
    required this.id,
    required this.objectKey,
    required this.mimeType,
    required this.sha256,
    required this.altText,
    this.localBytes,
  });

  final String id;
  final String objectKey;
  final String mimeType;
  final String sha256;
  final String altText;
  final Uint8List? localBytes;

  Map<String, Object?> toJson() => {
    'id': id,
    'objectKey': objectKey,
    'mimeType': mimeType,
    'sha256': sha256,
    'altText': altText,
  };

  factory QuestionMedia.fromJson(Map<String, dynamic> json) => QuestionMedia(
    id: json['id'] as String? ?? '',
    objectKey: json['objectKey'] as String? ?? '',
    mimeType: json['mimeType'] as String? ?? '',
    sha256: json['sha256'] as String? ?? '',
    altText: json['altText'] as String? ?? '',
  );
}

class ExamVersion {
  const ExamVersion({
    required this.id,
    required this.examId,
    required this.contentHash,
    required this.questions,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String examId;
  final String contentHash;
  final List<Question> questions;
  final DateTime createdAt;
  final String? description;

  bool get isEmpty => questions.isEmpty;

  ExamVersion copyWith({
    String? id,
    String? examId,
    String? contentHash,
    List<Question>? questions,
    DateTime? createdAt,
    String? description,
  }) => ExamVersion(
    id: id ?? this.id,
    examId: examId ?? this.examId,
    contentHash: contentHash ?? this.contentHash,
    questions: questions ?? this.questions,
    createdAt: createdAt ?? this.createdAt,
    description: description ?? this.description,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'examId': examId,
    'contentHash': contentHash,
    'questions': questions.map((q) => q.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'description': description,
  };

  factory ExamVersion.fromJson(Map<String, dynamic> json) => ExamVersion(
    id: json['id'] as String? ?? '',
    examId: json['examId'] as String? ?? '',
    contentHash: json['contentHash'] as String? ?? '',
    questions: (json['questions'] as List?)
            ?.map((q) => Question.fromJson(Map<String, dynamic>.from(q)))
            .toList() ??
        const [],
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    description: json['description'] as String?,
  );
}

class Exam {
  const Exam({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.author,
    required this.durationMinutes,
    required this.attempts,
    required this.questions,
    this.uploaderName,
    this.year,
    this.board,
    this.institution,
    this.instance,
    this.sourceType = ExamSourceType.unverified,
    this.sourceUrl,
    this.isLocal = false,
    this.currentVersion,
    this.versions = const [],
  });

  final bool isLocal;
  final String id;
  final String category;
  final String title;
  final String description;
  final String author;
  final String? uploaderName;
  final int durationMinutes;
  final int attempts;
  final int? year;
  final String? board;
  final String? institution;
  final String? instance;
  final List<Question> questions;
  final ExamSourceType sourceType;
  final String? sourceUrl;
  final ExamVersion? currentVersion;
  final List<ExamVersion> versions;

  Uri? get safeSourceUrl {
    final uri = Uri.tryParse(sourceUrl?.trim() ?? '');
    return uri?.scheme == 'https' && uri!.host.isNotEmpty ? uri : null;
  }

  Exam copyWith({
    List<Question>? questions,
    int? year,
    String? board,
    String? institution,
    String? instance,
    ExamVersion? currentVersion,
    List<ExamVersion>? versions,
  }) => Exam(
    id: id,
    isLocal: isLocal,
    category: category,
    title: title,
    description: description,
    author: author,
    uploaderName: uploaderName,
    durationMinutes: durationMinutes,
    attempts: attempts,
    year: year ?? this.year,
    board: board ?? this.board,
    institution: institution ?? this.institution,
    instance: instance ?? this.instance,
    questions: questions ?? this.questions,
    sourceType: sourceType,
    sourceUrl: sourceUrl,
    currentVersion: currentVersion ?? this.currentVersion,
    versions: versions ?? this.versions,
  );

  ExamVersion createVersion({String? description}) {
    final questionsWithHash = questions.map((q) => q.withContentHash()).toList();
    final contentHash = sha256.convert(
      utf8.encode(questionsWithHash.map((q) => q.contentHash).join()),
    ).toString();
    return ExamVersion(
      id: 'ver-${DateTime.now().microsecondsSinceEpoch}',
      examId: id,
      contentHash: contentHash,
      questions: questionsWithHash,
      createdAt: DateTime.now(),
      description: description,
    );
  }

  Exam withNewVersion({String? description}) {
    final version = createVersion(description: description);
    return copyWith(
      currentVersion: version,
      versions: [...versions, version],
    );
  }
}

class ExamResult {
  const ExamResult({
    required this.exam,
    this.examVersionId = '',
    required this.answers,
    required this.markedForReview,
    required this.durationSeconds,
    required this.finishedAt,
  });

  final Exam exam;
  final String examVersionId;
  final Map<String, int> answers;
  final Set<String> markedForReview;
  final int durationSeconds;
  final DateTime finishedAt;

  ExamVersion? get version {
    if (examVersionId.isEmpty) return exam.currentVersion;
    try {
      return exam.versions.firstWhere((v) => v.id == examVersionId);
    } catch (_) {
      return exam.currentVersion;
    }
  }

  List<Question> get versionedQuestions => version?.questions ?? exam.questions;

  int get correct => versionedQuestions
      .where((question) =>
          question.correctIndex != null &&
          answers[question.id] == question.correctIndex)
      .length;

  int get scorePercent => versionedQuestions.isEmpty
      ? 0
      : correctableCount == 0
      ? 0
      : (correct / correctableCount * 100).round();

  int get correctableCount => versionedQuestions
      .where((question) => question.hasCorrectAnswer)
      .length;

  List<String> get wrongQuestionIds => versionedQuestions
      .where((question) =>
          answers[question.id] != null &&
          question.hasCorrectAnswer &&
          answers[question.id] != question.correctIndex)
      .map((q) => q.id)
      .toList();

  /// Backward compatibility: returns positional indices of wrong questions.
  @Deprecated('Use wrongQuestionIds instead')
  List<int> get wrongQuestionIndices => versionedQuestions
      .where((question) =>
          answers[question.id] != null &&
          question.hasCorrectAnswer &&
          answers[question.id] != question.correctIndex)
      .map((q) => versionedQuestions.indexOf(q))
      .toList();

  Exam? get wrongQuestionsExam {
    final wrongIds = wrongQuestionIds;
    if (wrongIds.isEmpty) return null;
    final wrongQuestions = versionedQuestions.where((q) => wrongIds.contains(q.id)).toList();
    return Exam(
      id: 'local-review-${finishedAt.microsecondsSinceEpoch}',
      isLocal: true,
      category: exam.category,
      title: '${exam.title} · Questões erradas',
      description: 'Revisão local das questões respondidas incorretamente.',
      author: exam.author,
      durationMinutes: exam.durationMinutes,
      attempts: 0,
      year: exam.year,
      uploaderName: exam.uploaderName,
      board: exam.board,
      institution: exam.institution,
      instance: exam.instance,
      sourceType: exam.sourceType,
      sourceUrl: exam.sourceUrl,
      questions: wrongQuestions,
    );
  }

  int get unanswered => versionedQuestions
      .where((question) => answers[question.id] == null)
      .length;

  Map<String, ({int correct, int total})> get byTopic {
    final totals = <String, ({int correct, int total})>{};
    for (final question in versionedQuestions) {
      if (question.topic.trim().isEmpty || question.correctIndex == null) {
        continue;
      }
      final previous = totals[question.topic] ?? (correct: 0, total: 0);
      totals[question.topic] = (
        correct:
            previous.correct +
            (answers[question.id] == question.correctIndex ? 1 : 0),
        total: previous.total + 1,
      );
    }
    return totals;
  }

  Map<String, Object?> toJson() => {
    'examId': exam.id,
    'examVersionId': examVersionId,
    'examTitle': exam.title,
    'examCategory': exam.category,
    'examYear': exam.year,
    'examBoard': exam.board,
    'examInstitution': exam.institution,
    'examInstance': exam.instance,
    'finishedAt': finishedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'total': versionedQuestions.length,
    'correct': correct,
    'scorePercent': scorePercent,
    'answers': versionedQuestions.asMap().entries.map((entry) {
      final index = entry.key;
      final question = entry.value;
      final selected = answers[question.id];
      return {
        'question': index + 1,
        'questionId': question.id,
        'questionNumber': question.statement.length > 50
            ? question.statement.substring(0, 50)
            : question.statement,
        'selected': selected,
        'correct': question.correctIndex,
        'isCorrect':
            question.hasCorrectAnswer && selected == question.correctIndex,
        'markedForReview': markedForReview.contains(question.id),
      };
    }).toList(),
  };
}