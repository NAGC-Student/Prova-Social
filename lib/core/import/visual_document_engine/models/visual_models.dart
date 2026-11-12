import 'dart:math' as math;
import 'dart:typed_data';

/// Tipo de bloco visual reconstruído de uma página de prova.
enum VisualBlockType {
  text,
  formula,
  image,
  table,
  graphic,
  optionLabel,
  optionContent,
}

/// Ponto com coordenadas na página renderizada.
class VisualPoint {
  const VisualPoint(this.x, this.y);

  final double x;
  final double y;

  double distanceTo(VisualPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  factory VisualPoint.fromJson(Map<String, dynamic> json) =>
      VisualPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
}

/// Retângulo com coordenadas na página renderizada.
class VisualRect {
  const VisualRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  VisualPoint get center => VisualPoint((left + right) / 2, (top + bottom) / 2);
  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;

  double overlapWith(VisualRect other) {
    final overlapLeft = math.max(left, other.left);
    final overlapRight = math.min(right, other.right);
    final overlapTop = math.max(top, other.top);
    final overlapBottom = math.min(bottom, other.bottom);
    if (overlapRight <= overlapLeft || overlapBottom <= overlapTop) return 0.0;
    final intersection =
        (overlapRight - overlapLeft) * (overlapBottom - overlapTop);
    final area = width * height;
    if (area <= 0) return 0.0;
    return (intersection / area).clamp(0.0, 1.0);
  }

  bool containsPoint(VisualPoint point) =>
      point.x >= left &&
      point.x <= right &&
      point.y >= top &&
      point.y <= bottom;

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory VisualRect.fromJson(Map<String, dynamic> json) => VisualRect(
    left: (json['left'] as num).toDouble(),
    top: (json['top'] as num).toDouble(),
    right: (json['right'] as num).toDouble(),
    bottom: (json['bottom'] as num).toDouble(),
  );
}

/// Um bloco visual reconstruído de uma página de prova.
class VisualBlock {
  const VisualBlock({
    required this.type,
    required this.bounds,
    this.text,
    this.assetId,
    this.confidence = 0.0,
    this.children = const [],
  });

  final VisualBlockType type;
  final VisualRect bounds;
  final String? text;
  final String? assetId;
  final double confidence;
  final List<VisualBlock> children;

  Map<String, Object?> toJson() => {
    'type': type.name,
    'bounds': bounds.toJson(),
    'text': text,
    'assetId': assetId,
    'confidence': confidence,
    'children': children.map((child) => child.toJson()).toList(),
  };

  VisualBlock copyWith({
    VisualBlockType? type,
    VisualRect? bounds,
    String? text,
    String? assetId,
    double? confidence,
    List<VisualBlock>? children,
  }) {
    return VisualBlock(
      type: type ?? this.type,
      bounds: bounds ?? this.bounds,
      text: text ?? this.text,
      assetId: assetId ?? this.assetId,
      confidence: confidence ?? this.confidence,
      children: children ?? this.children,
    );
  }

  factory VisualBlock.fromJson(Map<String, dynamic> json) => VisualBlock(
    type: VisualBlockType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => VisualBlockType.text,
    ),
    bounds: VisualRect.fromJson(
      Map<String, dynamic>.from(json['bounds'] as Map),
    ),
    text: json['text'] as String?,
    assetId: json['assetId'] as String?,
    confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.0).clamp(0, 1),
    children: (json['children'] as List? ?? const [])
        .map((c) => VisualBlock.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(growable: false),
  );

  String get plainText {
    final parts = <String>[];
    if (text != null && text!.isNotEmpty) parts.add(text!);
    for (final child in children) {
      final childText = child.plainText;
      if (childText.isNotEmpty) parts.add(childText);
    }
    return parts.join(' ');
  }
}

/// Uma alternativa de questão reconstruída visualmente.
class VisualAlternative {
  const VisualAlternative({
    required this.label,
    required this.content,
    this.imageAssetId,
  });

  final String label;
  final List<VisualBlock> content;
  final String? imageAssetId;

  Map<String, Object?> toJson() => {
    'label': label,
    'content': content.map((c) => c.toJson()).toList(),
    'imageAssetId': imageAssetId,
  };

  factory VisualAlternative.fromJson(Map<String, dynamic> json) =>
      VisualAlternative(
        label: json['label'] as String? ?? '',
        content: (json['content'] as List? ?? const [])
            .map(
              (c) => VisualBlock.fromJson(Map<String, dynamic>.from(c as Map)),
            )
            .toList(growable: false),
        imageAssetId: json['imageAssetId'] as String?,
      );

  String get plainText {
    if (imageAssetId != null && content.isEmpty) return '';
    return content.map((c) => c.plainText).where((t) => t.isNotEmpty).join(' ');
  }
}

/// Uma questão reconstruída visualmente.
class VisualImportedQuestion {
  const VisualImportedQuestion({
    required this.id,
    required this.statement,
    required this.alternatives,
    this.number,
    required this.sourcePage,
    this.format = QuestionFormat.multipleChoice,
    this.confidence = 0.0,
    this.warning,
    this.reviewState = QuestionReviewState.unreviewed,
    this.supportingMaterialIds = const [],
    this.fieldConfidence = const {},
  });

  final String id;
  final int? number;
  final int sourcePage;
  final List<VisualBlock> statement;
  final List<VisualAlternative> alternatives;
  final QuestionFormat format;
  final double confidence;
  final String? warning;
  final QuestionReviewState reviewState;
  final List<String> supportingMaterialIds;
  final Map<String, double> fieldConfidence;

  Map<String, Object?> toJson() => {
    'id': id,
    'number': number,
    'sourcePage': sourcePage,
    'statement': statement.map((b) => b.toJson()).toList(),
    'alternatives': alternatives.map((a) => a.toJson()).toList(),
    'format': format.name,
    'confidence': confidence,
    'warning': warning,
    'reviewState': reviewState.name,
    'supportingMaterialIds': supportingMaterialIds,
    'fieldConfidence': fieldConfidence,
  };

  factory VisualImportedQuestion.fromJson(
    Map<String, dynamic> json,
  ) => VisualImportedQuestion(
    id: json['id'] as String? ?? '',
    number: (json['number'] as num?)?.toInt(),
    sourcePage: (json['sourcePage'] as num?)?.toInt() ?? 0,
    statement: (json['statement'] as List? ?? const [])
        .map((b) => VisualBlock.fromJson(Map<String, dynamic>.from(b as Map)))
        .toList(growable: false),
    alternatives: (json['alternatives'] as List? ?? const [])
        .map(
          (a) =>
              VisualAlternative.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList(growable: false),
    format: QuestionFormat.values.firstWhere(
      (f) => f.name == json['format'],
      orElse: () => QuestionFormat.multipleChoice,
    ),
    confidence: ((json['confidence'] as num?)?.toDouble() ?? 0.0).clamp(0, 1),
    warning: json['warning'] as String?,
    reviewState: QuestionReviewState.values.firstWhere(
      (r) => r.name == json['reviewState'],
      orElse: () => QuestionReviewState.unreviewed,
    ),
    supportingMaterialIds: List<String>.from(
      json['supportingMaterialIds'] as List? ?? const [],
    ),
    fieldConfidence: (json['fieldConfidence'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
    ),
  );

  String get statementPlainText {
    return statement
        .map((b) => b.plainText)
        .where((t) => t.isNotEmpty)
        .join(' ');
  }

  String get alternativesPlainText {
    return alternatives
        .map((a) => '${a.label}: ${a.plainText}')
        .where((t) => t.isNotEmpty)
        .join(' ');
  }
}

/// Uma página renderizada com seus elementos visuais posicionados.
class VisualPage {
  const VisualPage({
    required this.number,
    required this.width,
    required this.height,
    required this.imageBytes,
    this.elements = const [],
    this.nativeText = '',
    this.warning,
  });

  final int number;
  final double width;
  final double height;
  final Uint8List imageBytes;
  final List<VisualBlock> elements;
  final String nativeText;
  final String? warning;

  Map<String, Object?> toJson() => {
    'number': number,
    'width': width,
    'height': height,
    'elements': elements.map((e) => e.toJson()).toList(),
    'nativeText': nativeText,
    'warning': warning,
  };

  VisualPage copyWith({
    List<VisualBlock>? elements,
    String? nativeText,
    String? warning,
  }) {
    return VisualPage(
      number: number,
      width: width,
      height: height,
      imageBytes: imageBytes,
      elements: elements ?? this.elements,
      nativeText: nativeText ?? this.nativeText,
      warning: warning ?? this.warning,
    );
  }
}

/// Um ativo visual extraído.
class VisualAsset {
  const VisualAsset({
    required this.id,
    required this.type,
    required this.bytes,
    required this.mimeType,
    this.sourcePage,
    this.bounds,
    this.sha256,
  });

  final String id;
  final VisualAssetType type;
  final Uint8List bytes;
  final String mimeType;
  final int? sourcePage;
  final VisualRect? bounds;
  final String? sha256;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.name,
    'mimeType': mimeType,
    'sourcePage': sourcePage,
    'bounds': bounds?.toJson(),
    'sha256': sha256,
  };
}

enum VisualAssetType {
  figure,
  formula,
  graphic,
  optionImage,
  table,
  pagePreview,
}

enum QuestionFormat { multipleChoice, trueFalse, assertion, openEnded, unknown }

enum QuestionReviewState { unreviewed, inReview, reviewed, needsAttention }
