import 'dart:convert';
import 'dart:typed_data';

import '../question_parser.dart' as parser;
import '../imported_document.dart';
import 'visual_document_engine.dart';

/// Adapta a saída do Visual Document Engine para o modelo [ImportedQuestion]
/// existente, permitindo que o VDE seja usado como caminho complementar ao
/// parser de texto sem alterar o fluxo de publicação atual.
class VisualDocumentAdapter {
  const VisualDocumentAdapter();

  List<parser.ImportedQuestion> adapt({
    required VisualImportResult visualResult,
    Uint8List? pdfBytes,
  }) {
    final questions = <parser.ImportedQuestion>[];
    final assetById = visualResult.assets;

    for (final question in visualResult.questions) {
      final statementParts = <String>[];
      final supporting = <SupportingMaterial>[];

      for (var i = 0; i < question.statement.length; i++) {
        final block = question.statement[i];
        final text = block.plainText.trim();
        if (text.isNotEmpty) {
          statementParts.add(text);
        }
        if (block.assetId != null && assetById.containsKey(block.assetId!)) {
          final asset = assetById[block.assetId!]!;
          final mediaId = 'vde-${question.id}-block-$i';
          supporting.add(
            SupportingMaterial(
              id: mediaId,
              type: 'visualBlock',
              questionId: question.id,
              page: question.sourcePage,
              caption: _captionFor(block.type),
              imageBytes: asset.bytes,
              raw: {
                'assetId': asset.id,
                'assetType': asset.type.name,
                'bounds': block.bounds.toJson(),
                'sourcePage': question.sourcePage,
              },
            ),
          );
          statementParts.insert(
            statementParts.length - 1,
            '[${asset.type.name}:${asset.id}]',
          );
        }
      }

      final optionImageBase64 = <int, String>{};
      final options = <String>[];
      for (var i = 0; i < question.alternatives.length; i++) {
        final alt = question.alternatives[i];
        final text = alt.plainText.trim();
        if (alt.imageAssetId != null &&
            assetById.containsKey(alt.imageAssetId!)) {
          final asset = assetById[alt.imageAssetId!]!;
          options.add('');
          optionImageBase64[i] = base64Encode(asset.bytes);
          supporting.add(
            SupportingMaterial(
              id: 'vde-opt-${question.id}-${alt.label}',
              type: 'visualOption',
              questionId: question.id,
              page: question.sourcePage,
              caption: 'Alternativa ${alt.label} (imagem)',
              imageBytes: asset.bytes,
              raw: {
                'assetId': alt.imageAssetId,
                'optionIndex': i,
                'label': alt.label,
              },
            ),
          );
        } else if (text.isNotEmpty) {
          options.add(text);
        } else {
          options.add('');
        }
      }

      final statement = statementParts.join(' ').trim();
      final warnings = <String>[];
      if (question.warning != null) warnings.add(question.warning!);
      if (options.isEmpty) warnings.add('Nenhuma alternativa detectada.');
      if (options.any((o) => o.trim().isEmpty) && optionImageBase64.isEmpty) {
        warnings.add('Alternativa(s) sem conteúdo de texto ou imagem.');
      }

      questions.add(
        parser.ImportedQuestion(
          id: question.id,
          statement: statement,
          options: options,
          number: question.number,
          sourcePage: question.sourcePage,
          sourcePages: [question.sourcePage],
          sourcePosition: 0,
          format: parser.QuestionFormat.values[question.format.index],
          confidence: question.confidence,
          warning: warnings.isEmpty ? null : warnings.join(' '),
          reviewState:
              parser.QuestionReviewState.values[question.reviewState.index],
          optionImageBase64: optionImageBase64,
          fieldConfidence: question.fieldConfidence,
          supportingMaterialIds: supporting.map((m) => m.id).toList(),
        ),
      );
    }

    return List.unmodifiable(questions);
  }

  String _captionFor(VisualBlockType type) {
    return switch (type) {
      VisualBlockType.formula => 'Fórmula da questão',
      VisualBlockType.image => 'Imagem da questão',
      VisualBlockType.table => 'Tabela da questão',
      VisualBlockType.graphic => 'Gráfico da questão',
      _ => 'Elemento visual da questão',
    };
  }
}
