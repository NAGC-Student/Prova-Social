import 'dart:typed_data';

import 'models/visual_models.dart';
import 'render/visual_page_renderer.dart';
import 'assets/visual_asset_extractor.dart';
import 'detect/visual_layout_detector.dart';
import 'assemble/visual_question_assembler.dart';

/// Orquestra o Visual Document Engine: renderiza páginas, detecta layout,
/// extrai ativos visuais e reconstrói questões com componentes independentes.
class VisualDocumentEngineService {
  const VisualDocumentEngineService({
    this.renderer = const VisualPageRenderer(),
    this.detector = const VisualLayoutDetector(),
    this.assembler = const VisualQuestionAssembler(),
    this.assetExtractor = const VisualAssetExtractor(),
  });

  final VisualPageRenderer renderer;
  final VisualLayoutDetector detector;
  final VisualQuestionAssembler assembler;
  final VisualAssetExtractor assetExtractor;

  Future<VisualImportResult> process(
    Uint8List pdfBytes, {
    List<int>? pageNumbers,
  }) async {
    final pages = await renderer.renderPages(
      pdfBytes,
      pageNumbers: pageNumbers ?? [],
      maxLongEdge: 1600,
      jpegQuality: 82,
    );

    if (pages.isEmpty) {
      return const VisualImportResult(
        pages: [],
        questions: [],
        assets: {},
        warning: 'Nenhuma página pôde ser renderizada.',
      );
    }

    final classifiedPages = <VisualPage>[];
    for (final page in pages) {
      detector.detectColumnSplit(page.elements, page.width);
      final classified = detector.classifyRegions(page.elements, page.width);
      classifiedPages.add(page.copyWith(elements: classified));
    }

    final questions = assembler.assemble(classifiedPages);

    final assets = <String, VisualAsset>{};
    for (final page in classifiedPages) {
      final pageAssets = await assetExtractor.extractAssets(page);
      assets.addAll(pageAssets);
    }

    return VisualImportResult(
      pages: classifiedPages,
      questions: questions,
      assets: assets,
    );
  }
}

class VisualImportResult {
  const VisualImportResult({
    required this.pages,
    required this.questions,
    required this.assets,
    this.warning,
  });

  final List<VisualPage> pages;
  final List<VisualImportedQuestion> questions;
  final Map<String, VisualAsset> assets;
  final String? warning;

  bool get hasQuestions => questions.isNotEmpty;
  bool get hasVisualAssets => assets.isNotEmpty;
}
