# Plano — Visual Document Engine (módulo independente de reconstrução visual)

## Contexto

O pipeline de importação atual (`lib/core/import/`) resolve tudo com expressões regulares sobre o texto extraído:

- `pdf_text_extractor.dart` — extrai texto nativo/OCR por página, ordena colunas com heurísticas.
- `question_parser.dart` — detecção de questões/alternativas apenas por regex sobre linhas.
- `page_furniture_filter.dart`, `ocr_layout_orderer.dart`, `text_normalizer.dart` — coadjuvantes de texto.
- `visual_option_image_extractor.dart` — recorta alternativas visuais já detectadas como "vazias".

O erro arquitetural identificado: converter toda a prova em texto antes de estruturá-la. Fórmulas, equações, gráficos vetoriais e figuras geométricas perdem informação espacial. A recomendação do usuário é um módulo separado, o **Visual Document Engine**, que preserve o visual primeiro e interprete depois.

## Decisões de arquitetura

1. **Módulo independente**: `lib/core/import/visual_document_engine/` — camada separada do parser atual (`question_parser.dart` continua existindo para documentos com texto nativo confiável).
2. **Preservação primeiro, interpretação depois**: cada questão reconstrói uma estrutura de blocos tipados (`text`, `formula`, `image`, `table`, `graphic`) em vez de um único `statement` string.
3. **Não substituir o parser existente**: o VDE recebe a página renderizada + dados estruturados do PDF (texto com coordenadas, vetores, imagens) e produz `VisualImportedQuestion`. O parser atual continua como fallback/parse secundário.
4. **Não depender de IA paga**: OCR com PaddleOCR (Android) + ML Kit (iOS) já no `pubspec`; nenhuma nova dependência paga. O Mathpix é mencionado pelo usuário como opcional, mas fora do escopo desta fase (nenhum serviço externo de fórmulas).
5. **Confiança por campo e sinalização de incerteza**: casos de baixa confiança vão para revisão humana, nunca descartados silenciosamente.
6. **PDF original não é armazenado nem redistribuído** (princípio 13 do AGENTS.md): apenas o modelo estruturado e assets extraídos (imagens de figuras, crops de alternativas).

## Modelo de dados (visual)

```dart
class VisualBlock {
  final VisualBlockType type; // text, formula, image, table, graphic, optionLabel, optionContent
  final String? text;        // texto reconhecido (quando aplicável)
  final String? assetId;     // referência a asset salvo (imagem/formula/vetor)
  final Rect bounds;         // coordenadas na página renderizada
  final double confidence;   // 0..1, heurística
  final List<VisualBlock> children;
}

class VisualImportedQuestion {
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
}

class VisualAlternative {
  final String label; // A..E
  final List<VisualBlock> content;
  final String? imageAssetId; // alternativa que é só imagem
}
```

## Tarefas (ordem de execução)

1. **Diagnóstico e estrutura de pastas**
   - Criar `lib/core/import/visual_document_engine/` com subpastas: `models/`, `render/`, `detect/`, `assemble/`, `assets/`.
   - Revisar `pdf_text_extractor.dart`, `ocr_recognition.dart`, `visual_option_image_extractor.dart` para reutilizar o que já existe (renderização de página, regiões OCR, recorte de alternativas visuais).
   - Confirmar dependências atuais: `pdfrx`, `image`, `google_mlkit_text_recognition`, `paddleocr_android` (já em `pubspec.yaml`).

2. **Modelos de dados do VDE** (`models/`)
   - `VisualBlock`, `VisualAlternative`, `VisualImportedQuestion`, `VisualBlockType`, `VisualPage`, `VisualAsset`.
   - Serialização JSON (`toJson`/`fromJson`) compatível com `ImportedDocument`/`SupportingMaterial` existentes.
   - Confiança por campo (`fieldConfidence`) e estado de revisão (`QuestionReviewState`).

3. **Renderização de página com coordenadas** (`render/`)
   - `VisualPageRenderer`: renderiza cada página em alta resolução (pdfrx, já existente em `pdf_text_extractor.renderPages`) e preserva coordenadas dos fragmentos de texto, imagens e desenhos vetoriais.
   - Retorna `VisualPage` com tamanho da página, lista de elementos posicionados e imagem renderizada.

4. **Detecção de layout e regiões** (`detect/`)
   - `VisualLayoutDetector`: dividir página em colunas, identificar blocos de texto, figuras, tabelas, fórmulas e gráficos por posição e proximidade (OpenCV-style via `image` package ou geometria simples; nenhuma nova dependência pesada nesta fase).
   - `VisualRegionClassifier`: classificar cada região como texto, fórmula, imagem, tabela ou gráfico.

5. **Reconstrução estrutural da questão** (`assemble/`)
   - `VisualQuestionAssembler`: relacionar enunciado, alternativas e elementos visuais por posição, ordem de leitura e proximidade.
   - Associar cada bloco à questão correta (número da questão, marcador de alternativa, proximidade espacial).
   - Detectar continuação de enunciado entre colunas/páginas.

6. **Extração de ativos visuais** (`assets/`)
   - `VisualAssetExtractor`: salvar imagens recortadas de figuras, fórmulas e alternativas visuais como assets independentes (JPEG/PNG), com hash por deduplicação.
   - Nunca converter uma imagem necessária em texto para sobreviver à importação.

7. **Sinalização de incerteza e revisão**
   - Casos de baixa confiança ou estrutura não reconstruída → `reviewState = needsAttention` + `warning` explicativo.
   - Integração com `ImportQualityGate` existente (status `good`/`review`/`retry`).

8. **Integração com o fluxo de importação existente**
   - `VisualDocumentEngineService`: orquestrador que escolhe entre caminho VDE (páginas escaneadas/visuais complexas) e caminho atual (texto nativo confiável).
   - Não quebrar `question_parser.dart`, `answer_key_parser.dart`, `exam_layout_profile.dart`, `exam_metadata_suggester.dart`.
   - O VDE entra como camada opcional/avisada no `publish_page.dart` e `import_feedback_service.dart` quando houver conteúdo visual não resolvido.

9. **Testes**
   - Testes unitários para modelos, renderização, detecção de colunas, montagem de questão sintética.
   - Teste de regressão contra PDF real do ITA/IME/AFA/FUVEST/ENEM (quando o PDF estiver disponível localmente, como já ocorre em `enem_2025_import_test.dart`).
   - Verificar que nenhum teste existente quebrou (`flutter test`).

10. **Verificações de qualidade**
    - `dart format` sem alterações pendentes.
    - `flutter analyze` sem erros.
    - `flutter test` aprovado.

## Riscos

- **Renderização pesada**: renderizar cada página em alta resolução pode ser caro em memória no mobile. Mitigar com `maxLongEdge` limitado e processamento fora da UI isolate (já feito em `pdf_text_extractor.dart` via `compute`).
- **OCR apenas no mobile**: Web não tem OCR nativo (`ocr_service_stub.dart`). O VDE no Web funciona só com texto nativo; páginas escaneadas vão para revisão.
- **Fórmulas**: nenhum extrato matemático dedicado existe ainda. Fórmulas vão como bloco de tipo `formula` com asset de imagem; revisão humana confirma.
- **Não há ground truth anotado**: os testes de precisão/recall dependem de PDFs reais locais; sem eles, só testes estruturais sintéticos são possíveis.

## Critérios de aceitação (definição de pronto)

- O módulo compila e passa em `flutter analyze` e `flutter test`.
- Nenhum teste existente é alterado ou quebrado.
- Uma questão sintética com enunciado + fórmula + imagem + 5 alternativas é reconstruída como blocos tipados, não como texto puro.
- Casos de baixa confiança são sinalizados para revisão (`needsAttention`).
- O PDF original não é armazenado nem redistribuído; apenas assets estruturados.
- O parser atual (`question_parser.dart`) continua funcionando como caminho alternativo.

## Perguntas em aberto (marcar como fora de escopo ou decidir)

- O VDE deve ser acionado automaticamente para toda importação ou apenas quando o parser atual reporta `hasVisualOptions` / `warning`? [Recomendado: apenas quando há sinal de conteúdo visual não resolvido, para não encarecer importações simples de texto nativo.]
- Qual formato de asset para fórmulas (imagem PNG/JPEG vs SVG)? [Recomendado: JPEG/PNG recortado da página renderizada, preservando o visual; sem conversão para LaTeX nesta fase.]
- O módulo deve rodar em Isolate separado para não travar a UI? [Recomendado: sim, via `compute`, seguindo o padrão já existente em `pdf_text_extractor.dart`.]
