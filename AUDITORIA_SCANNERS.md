# Auditoria Especializada dos Scanners — Prova Social

**Entrega:** Fase 3 — Inventário de scanners, capacidades, bancas e cadeia completa  
**SHA de referência:** `1a2b3c4`  
**Foco:** `lib/core/import/`, `packages/paddleocr_android/`, `lib/features/publish/publish_page.dart`

---

## 3.1 Inventário dos scanners

O sistema de importação do Prova Social não é um único "scanner", mas um **pipeline de múltiplos componentes** que atuam em sequência. Abaixo, cada componente com suas responsabilidades, arquivos, tecnologias, entradas, saídas, dependências e capacidades.

### Scanner 1 — Extrator de texto nativo do PDF (`PdfTextExtractor`)

| Campo | Valor |
|-------|-------|
| Nome | `PdfTextExtractor` / `PdfPageExtraction` / `PdfExtractionResult` |
| Finalidade | Abrir PDF com `pdfrx`, ler `loadStructuredText` por página, ordenar fragmentos por coordenadas, detectar duas colunas, filtrar mobília, expor texto por página com metadados (origem, rota, motor, confiança, regiões, linhas de rodapé) |
| Arquivos | `lib/core/import/pdf_text_extractor.dart` (910 linhas), `lib/core/import/page_furniture_filter.dart`, `lib/core/import/text_normalizer.dart` |
| Tecnologias | `pdfrx 2.6.6`, `package:image` (renderização JPEG), `dart:convert`, `dart:math` |
| Entradas | `Uint8List` bytes do PDF, `maxPages` (padrão 500), `sourceName`, callback de progresso |
| Saídas | `PdfExtractionResult` com `List<PdfPageExtraction>` (texto por página, fonte, OCR tentado, rota, motor, confiança, regiões, footerLines, warning) + `furnitureLines` |
| Dependências | `OcrService` (injetável), `OcrRouter`, `OcrLayoutOrderer`, `PageFurnitureFilter`, `ExamTextNormalizer` |
| Capacidades documentadas | Leitura nativa por página, ordenação de colunas, remoção de cabeçalhos/rodapés, renderização de páginas para preview, limite de 500 páginas, OCR seletivo via router |
| Capacidades realmente implementadas | Todas as acima, funcionando. Testado com VUNESP 2024 (80 questões/32 páginas), sintético (80 questões/2 colunas) e ENEM 2025 (90 questões) |
| Limitações | Não faz OCR por si só (delega ao `OcrService`); não detecta imagens/fórmulas dentro da página (só texto); não preserva coordenadas por bloco de questão no documento final (só por página) |
| Testes existentes | `test/pdf_text_extractor_test.dart` (roteamento, ordenação de colunas), `test/vunesp_2024_import_test.dart`, `test/enem_2025_import_test.dart`, `test/synthetic_pdf_import_test.dart` |
| Integração | Chama `OcrService.recognizePage`, passa resultado para `QuestionParser.parsePages` |

### Scanner 2 — Roteador de OCR (`OcrRouter`)

| Campo | Valor |
|-------|-------|
| Nome | `OcrRouter` / `OcrRouteDecision` |
| Finalidade | Escolher a rota de extração mais barata por página: texto nativo suficiente → nativo; página sem texto nativo → PaddleOCR; texto nativo curto → ML Kit; sem motor → indisponível |
| Arquivos | `lib/core/import/ocr_router.dart` (75 linhas) |
| Tecnologias | Dart puro |
| Entradas | `nativeText` (String), `availableEngines` (Set<OcrEngine>) |
| Saídas | `OcrRouteDecision` (route, reason, fallbackEngines) |
| Dependências | `OcrEngine` enum, `OcrRoute` enum |
| Capacidades documentadas | Paddle primeiro para página-imagem, ML Kit para texto curto, fallback entre motores |
| Capacidades realmente implementadas | Todas implementadas e testadas |
| Limitações | Limiar de 20 caracteres (`minimumNativeTextLength`) não validado em corpus real; `availableEngines` é otimista (não verifica se o modelo Paddle carrega ou se o ML Kit está instalado) |
| Testes existentes | `test/pdf_text_extractor_test.dart:101-141` |
| Integração | Usado por `PdfTextExtractor.extract` a cada página |

### Scanner 3 — Serviço de OCR nativo (`OcrService` native)

| Campo | Valor |
|-------|-------|
| Nome | `OcrService` (implementação nativa via export condicional) |
| Finalidade | Renderizar página do PDF em imagem, comprimir JPEG, chamar PaddleOCR ou ML Kit, devolver regiões com coordenadas e confiança |
| Arquivos | `lib/core/import/ocr_service_native.dart` (190 linhas), `lib/core/import/ocr_service_stub.dart` (Web/desktop), `lib/core/import/ocr_service.dart` (export condicional) |
| Tecnologias | `google_mlkit_text_recognition 0.17.1`, `paddleocr_android 0.1.0` (plugin local), `pdfrx`, `package:image`, `path_provider`, `dart:io` |
| Entradas | `PdfPage`, `OcrEngine` |
| Saídas | `OcrRecognition` (engine, texto, confiança, regiões com pontos) |
| Dependências | `PaddleOcrAndroid` (plugin), ML Kit `TextRecognizer` |
| Capacidades documentadas | OCR local no aparelho, Paddle para página-imagem, ML Kit para texto curto/iOS, fallback por página, trabalho pesado fora da UI (`compute`) |
| Capacidades realmente implementadas | Todas implementadas no Android/iOS; stub declara indisponível na Web |
| Limitações | Sem timeout nem cancelamento; `availableEngines` otimista (não verifica asset do modelo); falha de criação do motor repetida em toda página; renderização fixa (2.200 px, JPEG 88); sem grayscale/contraste/deskew; OCR só de página inteira (não por região) |
| Testes existentes | Não há teste que instancie `PaddleOcrAndroid` nem simule `MethodChannel`; nenhum teste Kotlin do plugin |
| Integração | Chamado por `PdfTextExtractor` quando o router decide OCR |

### Scanner 4 — Plugin PaddleOCR Android (`packages/paddleocr_android`)

| Campo | Valor |
|-------|-------|
| Nome | `paddleocr_android` / `PaddleOcrPlugin` |
| Finalidade | Wrapper do SDK oficial PaddleOCR (ONNX Runtime) para Android; detecção e reconhecimento de texto em imagem; devolve linhas com pontos e confiança |
| Arquivos | `packages/paddleocr_android/android/src/main/kotlin/...` (PaddleOcrPlugin.kt, OCREngine.kt, ORTSessionManager.kt, DetectionEngine.kt, RecognitionEngine.kt, pré/pós-processamento), `android/build.gradle` |
| Tecnologias | Kotlin, ONNX Runtime Android, OpenCV 4.5.3, SDK PaddleOCR PP-OCRv6, Flutter MethodChannel |
| Entradas | `Uint8List` de imagem (JPEG), limite 20 MB |
| Saídas | Mapa com `lines` (texto, confidence, points) |
| Dependências | ONNX Runtime `1.31.1` (build), OpenCV `4.5.3`, modelos ONNX (detecção ~1,7 MB, reconhecimento ~4,3 MB) |
| Capacidades documentadas | OCR local, engine serializado (Mutex), criação preguiçosa, limite de 20 MB, liberação em `onDetachedFromEngine` |
| Capacidades realmente implementadas | Todas implementadas estaticamente; não testado nativamente |
| Limitações | Sem timeout; sem health check; falha de criação repetida por página; erros genéricos (`paddle_ocr_failed`); sem mapeamento de `OCRError`; notice declara ONNX `1.21.1` mas build usa `1.31.1`; lockfile não versionado |
| Testes existentes | **Nenhum** (`find packages/paddleocr_android -path '*test*'` vazio) |
| Integração | Chamado via `OcrService._recognizeWithPaddle` |

### Scanner 5 — Ordenador de layout OCR (`OcrLayoutOrderer`)

| Campo | Valor |
|-------|-------|
| Nome | `OcrLayoutOrderer` |
| Finalidade | Restaurar ordem de leitura de regiões OCR com coordenadas; separar colunas por lacuna horizontal clara |
| Arquivos | `lib/core/import/ocr_layout_orderer.dart` (76 linhas) |
| Tecnologias | Dart puro |
| Entradas | `List<OcrTextRegion>` |
| Saídas | `List<String>` (linhas em ordem de leitura) |
| Dependências | `OcrTextRegion` |
| Capacidades documentadas | Split de duas colunas por lacuna horizontal, ordenação vertical dentro da coluna |
| Capacidades realmente implementadas | Implementado e testado |
| Limitações | Só separa quando há lacuna horizontal clara e ambos os lados com múltiplas regiões; não trata layout irregular |
| Testes existentes | `test/pdf_text_extractor_test.dart:143-170` |
| Integração | Usado por `PdfTextExtractor` para ordenar regiões OCR |

### Scanner 6 — Parser de questões (`QuestionParser`)

| Campo | Valor |
|-------|-------|
| Nome | `QuestionParser` / `ImportedQuestion` |
| Finalidade | Receber texto (por página ou contínuo), detectar marcadores de questão, separar enunciado de alternativas, classificar formato (MC, C/E, asserção, discursiva, desconhecido), associar gabarito, gerar IDs estáveis, detectar versões paralelas de idioma |
| Arquivos | `lib/core/import/question_parser.dart` (2.210 linhas), `lib/core/import/answer_key_parser.dart`, `lib/core/import/exam_layout_profile.dart` |
| Tecnologias | Dart puro, expressões regulares, `crypto` (SHA-256 para IDs) |
| Entradas | `String` (texto contínuo) ou `List<String>` (páginas via `parsePages`) |
| Saídas | `List<ImportedQuestion>` (statement, options, correctIndex, number, format, confidence, warning, sourcePage, sourcePages, hasVisualOptions, etc.) |
| Dependências | `text_normalizer.dart`, `answer_key_parser.dart` (separado) |
| Capacidades documentadas | Marcadores explícitos, sequência numérica, alternativas irregulares, múltipla escolha, certo/errado, asserção, discursiva, desconhecido, trilhas de idioma paralelas, continuação entre páginas, instruções não viram questões |
| Capacidades realmente implementadas | Todas implementadas; heurístico; perde questões em bancas militares (AFA/EPCAR/EEAR); não preserva coordenadas por bloco; confiança é heurística fixa (não calibrada) |
| Limitações | Não é generalizável para qualquer banca/layout sem ajuste; `fieldConfidence` é atribuído pelo parser em todas as construções mas não testado contra ground truth; não detecta questões anuladas; não reconhece fórmulas dentro de alternativas |
| Testes existentes | `test/question_parser_test.dart` (1.279 linhas, muitos casos), `test/vunesp_2024_import_test.dart`, `test/enem_2025_import_test.dart`, `test/synthetic_pdf_import_test.dart`, `test/ita_scanned_ocr_flow_test.dart` |
| Integração | Recebe saída de `PdfTextExtractor` (texto por página) e produz `ImportedQuestion` para `ImportedDocument` |

### Scanner 7 — Parser de gabarito (`AnswerKeyParser`)

| Campo | Valor |
|-------|-------|
| Nome | `AnswerKeyParser` / `AnswerKey` / `AnswerKeyApplication` |
| Finalidade | Ler gabarito impresso (bloco titulado ou run denso de pares número-letra), aplicar ao conjunto de questões, reportar cobertura e não correspondências |
| Arquivos | `lib/core/import/answer_key_parser.dart` (425 linhas) |
| Tecnologias | Dart puro, expressões regulares |
| Entradas | `String` (texto) ou `List<String>` (páginas) |
| Saídas | `AnswerKey` (byNumber: Map<int,String>, heading, pages) e `AnswerKeyApplication` |
| Dependências | `question_parser.dart` (`ImportedQuestion`, `QuestionFormat`) |
| Capacidades documentadas | `1-B`, `01. B`, `(1) B`, grids `1 A 11 B 21 C`, CERTO/ERRADO, run mínimo de 3 (titulado) ou 10 (sem título), não sobrescreve correção manual |
| Capacidades realmente implementadas | Todas implementadas e testadas |
| Limitações | Não valida se o gabarito pertence ao mesmo caderno das questões (apenas run de números); não detecta questões anuladas no gabarito |
| Testes existentes | `test/answer_key_parser_test.dart` |
| Integração | Usado no fluxo de publicação para preencher `correctIndex` |

### Scanner 8 — Extrator de imagens de alternativas visuais (`VisualOptionImageExtractor`)

| Campo | Valor |
|-------|-------|
| Nome | `VisualOptionImageExtractor` |
| Finalidade | Recortar alternativas que existem como imagens no PDF (texto layer vazio), preservando a imagem sem adivinhar conteúdo (sem OCR/LaTeX da fórmula) |
| Arquivos | `lib/core/import/visual_option_image_extractor.dart` (368 linhas) |
| Tecnologias | `pdfrx`, `package:image` |
| Entradas | `Uint8List` PDF bytes, `List<ImportedQuestion>` |
| Saídas | `Map<String, Uint8List>` (chave `questionId:optionIndex` → JPEG bytes) |
| Dependências | `question_parser.dart` (`ImportedQuestion`) |
| Capacidades documentadas | Detectar alternativas com `options[i]` vazio + `hasVisualOptions`, recortar região da alternativa na página, lidar com duas colunas |
| Capacidades realmente implementadas | Implementado; integrado no fluxo de publicação (dashboard s3: VUNESP Q53,54,79,80) |
| Limitações | Só funciona quando o parser já detectou `hasVisualOptions` (alternativas vazias com 4-5 marcadores); não valida se o recorte contém realmente uma alternativa; não faz OCR da imagem |
| Testes existentes | `test/visual_option_image_extractor_test.dart` |
| Integração | Chamado em `publish_page.dart` após o parser |

### Scanner 9 — Perfil de layout da prova (`ExamLayoutProfiler`)

| Campo | Valor |
|-------|-------|
| Nome | `ExamLayoutProfiler` / `ExamLayoutProfile` |
| Finalidade | Reconhecer a banca (por texto) e o layout (alternativas de A a E vs itens para julgar vs misto vs desconhecido) a partir das páginas |
| Arquivos | `lib/core/import/exam_layout_profile.dart` (86 linhas) |
| Tecnologias | Dart puro, expressões regulares, `exam_metadata_suggester.dart` |
| Entradas | `List<String>` (páginas), `sourceName` opcional |
| Saídas | `ExamLayoutProfile` (banca, layout, evidencePages) |
| Dependências | `ExamMetadataSuggestion` |
| Capacidades documentadas | Ler banca do documento (não do nome do arquivo), classificar layout por caixas vazias e rótulos A |
| Capacidades realmente implementadas | Implementado; heurístico de caixas `()` e rótulos `(a)` / `a)` |
| Limitações | Não influencia o parser (perfil separado); não detecta perfil específico de banca militar (AFA/EPCAR/EEAR usam formatos especiais) |
| Testes existentes | `test/exam_layout_profile_test.dart` |
| Integração | Usado na revisão/importação para informar o usuário |

### Scanner 10 — Sugestor de metadados (`ExamMetadataSuggester`)

| Campo | Valor |
|-------|-------|
| Nome | `ExamMetadataSuggester` / `ExamMetadataSuggestion` |
| Finalidade | Sugerir título, ano, categoria, banca, instituição, fase a partir do texto das primeiras 5 páginas e do nome do arquivo |
| Arquivos | `lib/core/import/exam_metadata_suggester.dart` (872 linhas) |
| Tecnologias | Dart puro, expressões regulares |
| Entradas | `fileName`, `firstPageText`, `pages?` (primeiras 5) |
| Saídas | `ExamMetadataSuggestion` com valores e páginas de evidência |
| Dependências | Nenhuma externa |
| Capacidades documentadas | Banca/instituição/ano nunca vêm do nome do arquivo; assinaturas de 18 bancas + instituições; detecção de ENEM/FUVEST/COMVEST/militares |
| Capacidades realmente implementadas | Todas implementadas e testadas |
| Limitações | Só inspeciona as primeiras 5 páginas; bancas militares (AFA/EPCAR/EEAR) têm assinatura mas o parser não usa perfil dedicado; ano pode ser inflado por cabeçalhos/rodapés (P3 dashboard) |
| Testes existentes | `test/exam_metadata_suggester_test.dart` |
| Integração | Usado por `ExamLayoutProfiler` e na tela de revisão de importação |

---

## 3.2 Auditoria de capacidades dos scanners

Para cada capacidade listada na missão, o status real:

| Capacidade | Scanner responsável | Implementado? | Funciona corretamente? | Evidência | Status |
|------------|---------------------|---------------|------------------------|-----------|--------|
| Leitura de PDFs nativos | `PdfTextExtractor` | Sim | Sim | `test/pdf_text_extractor_test.dart`, VUNESP 80/80 | IMPLEMENTADO E VALIDADO |
| Leitura de PDFs digitalizados (imagem) | `PdfTextExtractor` + `OcrService` (Paddle) | Sim | Parcial (não testado em aparelho) | `ocr_service_native.dart`; nenhum teste nativo do Paddle | IMPLEMENTADO PARCIALMENTE |
| OCR de imagens | `OcrService` (Paddle/ML Kit) | Sim | Parcial (sem timeout/health check) | `ocr_service_native.dart`; área 13 | IMPLEMENTADO PARCIALMENTE |
| Reconhecimento de questões | `QuestionParser` | Sim | Parcial (perde bancas militares) | `test/question_parser_test.dart`; dashboard P1 (AFA/EPCAR/EEAR) | IMPLEMENTADO COM FALHAS |
| Separação de enunciado e alternativas | `QuestionParser._findOptionMarkers` / `_parseOptions` | Sim | Sim (para MC padrão) | `test/question_parser_test.dart` | IMPLEMENTADO E VALIDADO |
| Reconhecimento de alternativas visuais | `VisualOptionImageExtractor` | Sim | Parcial (não valida conteúdo do recorte) | `test/visual_option_image_extractor_test.dart`; dashboard s3 | IMPLEMENTADO PARCIALMENTE |
| Identificação de fórmulas matemáticas | Nenhum dedicado | Não | — | Não há reconhecimento LaTeX; fica como imagem | NÃO IMPLEMENTADO |
| Preservação de gráficos e tabelas | `PdfTextExtractor._mergeTableRows` | Parcial | Heurístico | `test/` (não testado diretamente) | IMPLEMENTADO PARCIALMENTE |
| Reconhecimento de diagramas | Nenhum | Não | — | Não há detecção de figuras vetoriais | NÃO IMPLEMENTADO |
| Detecção de múltiplas colunas | `PdfTextExtractor._findNativeColumnSplit` + `OcrLayoutOrderer` | Sim | Sim | `test/pdf_text_extractor_test.dart:143-170` | IMPLEMENTADO E VALIDADO |
| Continuidade entre páginas | `QuestionParser.parsePages` + `sourcePages` | Sim | Sim (VUNESP Q79 em 2 páginas) | `test/vunesp_2024_import_test.dart` | IMPLEMENTADO E VALIDADO |
| Identificação de cabeçalhos e rodapés | `PageFurnitureFilter` | Sim | Sim | `test/page_furniture_filter_test.dart` | IMPLEMENTADO E VALIDADO |
| Reconhecimento de numeração | `QuestionParser._detectQuestionStart` | Sim | Parcial (números espúrios em ENEM) | `test/enem_2025_import_test.dart`; dashboard P3 | IMPLEMENTADO COM FALHAS |
| Identificação de gabaritos | `AnswerKeyParser` | Sim | Sim | `test/answer_key_parser_test.dart`; ENEM 1-B/2-D | IMPLEMENTADO E VALIDADO |
| Associação de gabarito às questões | `AnswerKeyParser.apply` | Sim | Sim | `test/answer_key_parser_test.dart` | IMPLEMENTADO E VALIDADO |
| Detecção de questões anuladas | Nenhum | Não | — | Não há marcação de anulada | NÃO IMPLEMENTADO |
| Identificação V/F | `QuestionParser._looksLikeTrueFalse` + `_hasJudgementMarks` | Sim | Parcial (CEBRASPE C/E falha — dashboard P2) | `test/answer_key_parser_test.dart`; dashboard P2 | IMPLEMENTADO COM FALHAS |
| Reconhecimento de discursivas | `QuestionParser._looksLikeOpenEnded` | Sim | Sim (como `openEnded`) | `test/question_parser_test.dart` | IMPLEMENTADO E VALIDADO |
| Identificação de imagens associadas a alternativas | `VisualOptionImageExtractor` | Sim | Parcial | `test/visual_option_image_extractor_test.dart` | IMPLEMENTADO PARCIALMENTE |

**Avaliador de confiança:** O parser usa scores heurísticos fixos (`.99`, `.80`, etc.), não probabilidades calibradas. `fieldConfidence` existe no modelo e é atribuído pelo parser em todas as seis construções de `ImportedQuestion`. A UI não mostra mais “confiança ≥ 99%”; usa estados estruturais (fazível/corrigível/não fazível).

---

## 3.3 Auditoria de bancas

O `ExamMetadataSuggester` tem assinaturas para as seguintes bancas e instituições:

**Bancas (board signatures):** CEBRASPE, VUNESP, FGV, FCC, FUVEST, COMVEST, IBFC, FUNDATEC, Quadrix, Instituto AOCP, Consulplan, NUPECE, COMPERVE, IBADE, INEP, ITA, AFA, EPCAR, EEAR, EsPCEx, Escola Naval.

**Instituições (institution signatures):** ITA, AFA, EPCAR, EEAR, IME, EsPCEx, Escola Naval, EFOMM, ESA, INEP, ANM, AEB, USP, UNICAMP, ALEMA.

### Verificação por banca

| Banca | Assinatura no código | Detecção em PDF real | Parser usa perfil dedicado | Status | Observação |
|-------|---------------------|----------------------|---------------------------|--------|------------|
| VUNESP | Sim (`\bvunesp\b`) | Sim (80/80, teste vunesp_2024) | Não (layout genérico) | IMPLEMENTADO E VALIDADO | Funciona bem |
| FGV | Sim | Não (apenas teste de unidade de metadados) | Não | IMPLEMENTADO SEM VALIDAÇÃO | Assinatura existe, sem PDF real de teste |
| CEBRASPE | Sim (`\b(?:cebraspe|cespe)\b`) | Não (apenas gabarito) | Não | IMPLEMENTADO COM FALHAS | Dashboard P2: 20 C/E classificadas como não reconhecido |
| FCC | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| FUVEST | Sim | Não (apenas metadados) | Não | IMPLEMENTADO COM FALHAS | Q22 corrigido (dashboard s1) |
| IBFC | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| FUNDATEC | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| Quadrix | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| INEP/ENEM | Sim | Sim (90/90, gabarito aplicado) | Não | IMPLEMENTADO E VALIDADO | |
| ITA | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| IME | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| AFA | Sim | Não | Não | IMPLEMENTADO COM FALHAS | Dashboard P1: perda massiva (19-37/109) |
| EPCAR | Sim | Não | Não | IMPLEMENTADO COM FALHAS | Dashboard P1: perda massiva (12-33/89) |
| EEAR | Sim | Não | Não | IMPLEMENTADO COM FALHAS | Dashboard P1: perda massiva (10-84/94) |
| EsPCEx | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |
| Escola Naval | Sim | Não | Não | IMPLEMENTADO SEM VALIDAÇÃO | |

### Conclusões da auditoria de bancas

1. **A identificação de banca não depende exclusivamente do nome do arquivo** — correto, usa texto das primeiras 5 páginas.
2. **O perfil de banca NÃO é utilizado pelo parser** — o parser é universal e heurístico; o `ExamLayoutProfile` apenas informa o usuário. Bancas militares (AFA, EPCAR, EEAR) perdem muitas questões porque não há perfil de layout dedicado.
3. **Bancas desconhecidas continuam sendo processadas** — layout `unknown`, não rejeita.
4. **Falsos positivos existem** — números de cabeçalho/rodapé viram questões (ENEM, dashboard P3 parcialmente resolvido).
5. **Não há implementação artificialmente dependente de lista fechada** — o reconhecimento é por assinatura de texto, mas o parser não diferencia por banca.

---

## 3.4 Auditoria da cadeia completa de importação

### Cadeia: PDF/Imagem → Extração → OCR → Layout → Banca → Questões → Alternativas → Visuais → Gabarito → Validação → Importação

| Etapa | Componente | Produz | Consumido pelo próximo? | Informação perdida/ignorada? | Status |
|-------|------------|--------|-------------------------|------------------------------|--------|
| 1. Entrada | `publish_page.dart` (FilePicker) | bytes do PDF/JSON | `PdfTextExtractor` / JSON parser | Nenhuma | OK |
| 2. Extração nativa | `PdfTextExtractor` | texto por página + coordenadas + regiões | `page_furniture_filter`, `text_normalizer` | Coordenadas por bloco de questão (só por página) | OK (parcial) |
| 3. OCR (quando necessário) | `OcrService` (Paddle/ML Kit) | texto OCR + regiões com pontos | `OcrLayoutOrderer` | Timeout/cancelamento não existem; falha silenciosa por página | PARCIAL |
| 4. Ordenação de layout | `OcrLayoutOrderer` | linhas em ordem de leitura | `QuestionParser` | Não trata layout irregular | OK |
| 5. Filtro de mobília | `PageFurnitureFilter` | texto sem cabeçalhos/rodapés | `text_normalizer` | Pode remover linha de questão que se repete na borda (raro) | OK |
| 6. Normalização | `ExamTextNormalizer` | texto limpo, marcadores reconstruídos | `QuestionParser` | Nenhuma | OK |
| 7. Identificação de banca | `ExamMetadataSuggester` | banca, instituição, ano, categoria | `ExamLayoutProfiler` + revisão | Não influencia o parser | PARCIAL (perfil não usado pelo parser) |
| 8. Detecção de questões | `QuestionParser` | `ImportedQuestion[]` | `VisualOptionImageExtractor`, `AnswerKeyParser`, `ImportQualityGate` | Perde questões em bancas militares; não preserva coordenadas por bloco | PARCIAL |
| 9. Alternativas | `QuestionParser._findOptionMarkers` | options[] | `VisualOptionImageExtractor` | Alternativas visuais só se `hasVisualOptions` | PARCIAL |
| 10. Visuais | `VisualOptionImageExtractor` | JPEG crops | revisão humana | Não valida conteúdo do recorte; sem OCR de fórmula | PARCIAL |
| 11. Gabarito | `AnswerKeyParser` | correctIndex aplicado | `ImportQualityGate` | Não valida se gabarito é do mesmo caderno | OK |
| 12. Validação | `ImportQualityGate` | good/review/retry + avisos | revisão humana | `fieldConfidence` atribuído pelo parser; confiança não calibrada | PARCIAL |
| 13. Importação final | `publish_page.dart` (ImportReviewPage) | `ImportedDocument` | rascunho local / publicação | Discursivas publicam sem `correctIndex` (`allowOpenEnded: true`); objetivas exigem gabarito | PARCIAL |

### Pontos de perda de informação na cadeia

1. **Coordenadas por bloco de questão** — `PdfTextExtractor` tem coordenadas de fragmentos e regiões OCR, mas `ImportedQuestion` só guarda `sourcePage` e `sourcePages`, não `sourcePosition` geométrico nem bounding box do enunciado/alternativas. Isso impede recorte automático preciso e comparação visual.

2. **Perfil de banca não influencia o parser** — o `ExamLayoutProfile` identifica a banca, mas o `QuestionParser` é universal. Bancas com formatos especiais (militares, CEBRASPE C/E) perdem questões.

3. **`fieldConfidence` atribuído pelo parser** — o modelo suporta confiança por campo e o parser preenche `statement` e `options` em todas as seis construções de `ImportedQuestion`. Ainda não é testado contra ground truth.

4. **Confiança exibida como porcentagem** — UI mostra `confidence X%` em 3 locais, contrariando decisão de produto (estados fazível/corrigível/não fazível).

5. **Gabarito não validado contra caderno** — `AnswerKeyParser.apply` aplica por número de questão sem verificar se o gabarito pertence ao mesmo caderno/livro de questões.

---

## 3.5 Testes reais propostos para validação de cada capacidade

Abaixo, testes que deveriam existir para comprovar cada capacidade (não são testes artificiais de auto-confirmação):

1. **PDF nativo 80 questões** → `test/vunesp_2024_import_test.dart` já existe e passa (80/80).
2. **PDF digitalizado (imagem) com OCR** → teste que renderiza um PDF sem camada de texto e confia em Paddle/ML Kit; ausente (não testado em aparelho).
3. **OCR de imagem solta** → teste que passa um `File` de imagem para `OcrService.recognizePage`; ausente (o serviço aceita `PdfPage`, não imagem direta).
4. **Duas colunas** → `test/pdf_text_extractor_test.dart:143-170` já testa ordenação.
5. **CEBRASPE CERTO/ERRADO** → teste com 20 itens C/E esperando 20 `QuestionFormat.trueFalse`; ausente (dashboard P2 aberto).
6. **Banca militar AFA** → teste com PDF real de AFA esperando ≥90% de questões detectadas; ausente (dashboard P1 aberto, perda massiva).
7. **Questão anulada** → teste que detecta questão marcada como anulada no gabarito; ausente (não implementado).
8. **Fórmula matemática** → teste que verifica que alternativa com imagem não é transcrita como texto; ausente (não implementado).
9. **Imagem associada à alternativa** → `test/visual_option_image_extractor_test.dart` existe; verificar que recorte contém a alternativa correta.

---

## Resumo da auditoria de scanners

- **Número de scanners/componentes identificados:** 10
- **Scanners funcionais e validados:** 4 (PdfTextExtractor, OcrRouter, AnswerKeyParser, QuestionParser para MC padrão)
- **Scanners parciais:** 5 (OcrService nativo, Paddle plugin, VisualOptionImageExtractor, ExamMetadataSuggester, QuestionParser para bancas especiais)
- **Scanners ausentes:** 0 (todos os componentes existem, mas alguns capacidades prometidas não são implementadas)
- **Capacidades não implementadas:** OCR de imagem solta, reconhecimento de fórmulas, detecção de diagramas/gráficos vetoriais, detecção de questões anuladas, validação de gabarito vs. caderno, perfil de banca dedicado para militares
- **Problemas críticos conhecidos (dashboard):** P1 (AFA/EPCAR/EEAR perda massiva), P2 (CEBRASPE C/E não reconhecido), P3 (ENEM numeração espúria residual)
