---
tipo: area
area: OCR Android, PaddleOCR e digitalização
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 3, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 3}
fonte_codigo: [packages/paddleocr_android/, lib/core/import/ocr_service_native.dart, lib/core/import/ocr_router.dart, lib/core/import/pdf_text_extractor.dart, lib/features/publish/publish_page.dart, android/app/build.gradle.kts, .github/workflows/flutter-ci.yml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# OCR Android, PaddleOCR e digitalização

## Resumo

O Prova Social tem um motor de OCR **local, no aparelho**, com duas rotas:
PaddleOCR PP-OCRv6 no Android e ML Kit como segunda opção e como motor do iOS.
O plugin `packages/paddleocr_android` embarca o SDK Kotlin oficial do PaddleOCR,
os modelos ONNX de detecção e reconhecimento e um `MethodChannel` próprio; o
`OcrService` renderiza a página, comprime em JPEG fora da isolate de UI e tenta
os motores em ordem, com fallback por página. O desenho é adequado para
privacidade e offline: nenhuma imagem sai do aparelho e o import continua mesmo
quando um motor falha.

As lacunas são de **robustez e contrato**: não há timeout nem cancelamento; a
criação do motor Paddle não é testada antes do uso e, se falhar, é repetida em
**toda página**; o plugin não tem teste nativo; a UI ainda mostra “confiança ≥
99%” e porcentagem por questão, contrariando a decisão de usar **fazível**,
**corrigível** e **não fazível**; a captura por câmera/galeria não existe; e os
notices declaram ONNX Runtime `1.21.1` enquanto o build usa `1.31.1`.
Classificação: **EVOLUIR** — o motor é uma boa base, mas precisa de contrato de
saúde, limites de execução e uma camada de qualidade compreensível.

## Escopo e método

- Leitura integral de `packages/paddleocr_android`:
  - `android/src/main/kotlin/dev/nagcode/paddleocr/PaddleOcrPlugin.kt` (108 linhas);
  - `com/paddle/ocr/PaddleOCR.kt` (118);
  - `com/paddle/ocr/engine/OCREngine.kt`, `ORTSessionManager.kt`,
    `DetectionEngine.kt`, `RecognitionEngine.kt`;
  - `com/paddle/ocr/preprocess/DetPreprocessor.kt`,
    `postprocess/DBPostProcessor.kt`, `postprocess/BoxSorter.kt`;
  - `android/build.gradle` e `android/build.gradle.bak`;
  - `THIRD_PARTY_NOTICES.md`, `LICENSE` e `pubspec.yaml`.
- Leitura integral de `lib/core/import/ocr_service_native.dart` (190 linhas),
  `ocr_service_stub.dart` (19), `ocr_router.dart` (75) e do trecho de OCR de
  `pdf_text_extractor.dart` (`190-306`).
- Leitura dirigida de `lib/features/publish/publish_page.dart`:
  escolha de importação (`171-247`), importação PDF (`248-426`), etapas
  (`428-915`), revisão (`997-2301`) e textos de confiança (`732`, `1733`,
  `2057`).
- Leitura de `test/pdf_text_extractor_test.dart`, `test/import_quality_gate_test.dart`
  e `test/local_corpus_benchmark_test.dart`.
- Leitura do job Android do CI (`.github/workflows/flutter-ci.yml:88-135,
  640-700`).
- Não foi executado OCR em aparelho físico, emulador ou imagem real; não foi
  medido tempo, memória, precisão nem tamanho de APK. A análise é estática,
  complementada pelos testes existentes.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| PaddleOCR local no Android | Funcional | `PaddleOcrPlugin.kt:19-108` |
| ML Kit como segundo motor no Android | Funcional | `ocr_service_native.dart:21-25, 125-172` |
| ML Kit como motor do iOS | Funcional | `ocr_service_native.dart:21-25` |
| Sem OCR no desktop/web | Funcional | `ocr_service_stub.dart:1-19` |
| Renderização da página em escala limitada | Funcional | `ocr_service_native.dart:35-42` |
| Conversão e JPEG fora da UI | Funcional | `ocr_service_native.dart:48-52, 182-190` |
| Paddle primeiro em página sem texto nativo | Funcional | `ocr_router.dart:32-73`; `pdf_text_extractor.dart:201-204` |
| ML Kit primeiro em texto nativo curto | Funcional | `ocr_router.dart:32-73` |
| Fallback entre motores por página | Funcional | `pdf_text_extractor.dart:240-257` |
| Ordenação de duas colunas | Funcional | `ocr_layout_orderer.dart:12-75` |
| Limite de 20 MB por imagem no plugin | Funcional | `PaddleOcrPlugin.kt:44, 106` |
| Limite de 25 MB por PDF | Funcional | `publish_page.dart:270-272` |
| Limite de 500 páginas | Funcional | `pdf_text_extractor.dart:143-144` |
| Engine Paddle preguiçosa e serializada | Funcional | `PaddleOcrPlugin.kt:49-54` |
| Liberação do motor ao desanexar | Funcional | `PaddleOcrPlugin.kt:88-101` |
| Limpeza do arquivo temporário do ML Kit | Funcional | `ocr_service_native.dart:129-171` |
| Aviso quando nenhum motor encontra texto | Funcional | `pdf_text_extractor.dart:266-291` |
| Timeout e cancelamento | Ausente | nenhum `withTimeout`/cancel token |
| Teste de saúde do motor | Ausente | `availableEngines` é otimista |
| Teste nativo do plugin | Ausente | nenhum `src/test` ou `androidTest` |
| Captura por câmera/galeria | Ausente | só `FilePicker` de PDF e JSON |
| UI sem porcentagem de confiança | Quebrado | `publish_page.dart:732, 1733, 2057` |

## O que funciona

1. **OCR inteiramente local.** O Paddle roda via ONNX Runtime no aparelho e o
   ML Kit é on-device. Nenhuma página é enviada a serviço externo. Isso atende
   ao princípio de privacidade e ao requisito de funcionar com conexão ruim.
2. **Roteamento por custo.** O `OcrRouter` usa texto nativo quando há camada
   suficiente; usa ML Kit quando há pouco texto; usa Paddle quando não há texto;
   e declara indisponível quando não há motor
   (`ocr_router.dart:32-73`). A decisão é testada em
   `test/pdf_text_extractor_test.dart:101-141`.
3. **Fallback real por página.** Cada motor é tentado em ordem; se um lançar
   exceção ou devolver texto curto, o próximo é tentado, e a página não aborta o
   documento inteiro (`pdf_text_extractor.dart:240-257`). Se todos falharem, a
   página recebe aviso e o import continua
   (`pdf_text_extractor.dart:266-291`).
4. **Trabalho pesado fora da UI.** O `page.render` é nativo; a conversão de
   pixels e a compressão JPEG rodam em `compute`, numa isolate separada
   (`ocr_service_native.dart:48-52`). O plugin executa criação e inferência em
   `Dispatchers.IO` (`PaddleOCR.kt:31-69, 89-100`), embora o lançamento da
   corrotina use `Dispatchers.Main.immediate`.
5. **Engine reaproveitada e serializada.** O plugin cria o Paddle uma vez e o
   mantém; um `Mutex` garante que duas chamadas não usem a mesma sessão ONNX ao
   mesmo tempo (`PaddleOcrPlugin.kt:49-54`). Isso evita corrupção de estado
   nativo e cold start por página.
6. **Limites de entrada.** O plugin recusa imagem vazia ou acima de 20 MB antes
   de tocar no motor (`PaddleOcrPlugin.kt:42-47`); o import de PDF limita a
   25 MB e 500 páginas (`publish_page.dart:270-272`;
   `pdf_text_extractor.dart:143-144`). São barreiras úteis contra arquivo
   patológico.
7. **Ordenação de leitura corrigida no cliente.** O SDK do Paddle ordena linhas
   por proximidade e pode intercalar colunas; o `OcrLayoutOrderer` detecta um
   vão horizontal claro e ordena coluna por coluna
   (`ocr_layout_orderer.dart:12-75`). É uma correção pequena e testada
   (`test/pdf_text_extractor_test.dart:143-170`).
8. **Coordenadas preservadas.** O plugin devolve os quatro pontos de cada linha
   (`PaddleOcrPlugin.kt:55-67`), o `OcrService` monta `OcrTextRegion`
   (`ocr_service_native.dart:75-107`) e o extrator guarda as regiões
   (`pdf_text_extractor.dart:279-281`). Isso permite ordenar, depurar e,
   futuramente, recortar figuras por coordenada.
9. **Descarte correto de recursos.** A página renderizada é descartada em
   `finally` (`ocr_service_native.dart:57-59`); o arquivo temporário do ML Kit é
   apagado (`ocr_service_native.dart:167-171`); o reconhecedor ML Kit é fechado
   no `dispose` (`ocr_service_native.dart:174-179`). O motor Paddle é liberado no
   `onDetachedFromEngine` (`PaddleOcrPlugin.kt:88-101`).
10. **Licença do SDK preservada.** Os arquivos Kotlin mantêm o cabeçalho Apache
    2.0 e o `LICENSE` do pacote; os modelos e o commit de origem estão
    documentados em `THIRD_PARTY_NOTICES.md:3-17`. A procedência do código
    vendorizado é rastreável.
11. **Uso conservador de recursos.** `recBatchSize = 1` e `numThreads = 2`
    (`PaddleOcrPlugin.kt:81-85`) priorizam compatibilidade com aparelhos
    modestos, em vez de buscar throughput máximo. Para uma importação
    sequencial, é uma escolha defensável.
12. **Degradação explícita.** Quando o OCR não encontra texto suficiente, a
    página não é descartada: ela mantém o texto nativo, recebe `warning` e o
    quality gate a encaminha para revisão (`pdf_text_extractor.dart:264-290`).

## O que está parcial

### Sem timeout, sem cancelamento e sem limite de duração

Não há `withTimeout` em nenhuma camada:

- `PaddleOcrPlugin.recognize` lança a corrotina e espera o motor terminar
  (`PaddleOcrPlugin.kt:49-76`);
- `PaddleOCR.recognize` apenas troca para `Dispatchers.IO` e executa
  (`PaddleOCR.kt:89-100`);
- `OcrService.recognizePage` espera `page.render`, o `compute` e o
  `MethodChannel` sem prazo (`ocr_service_native.dart:27-60`);
- `PdfTextExtractor` percorre as páginas em sequência e não tem botão de
  cancelar (`pdf_text_extractor.dart:193-292`).

Consequências:

- uma página muito densa ou um modelo corrompido pode travar a importação por
  tempo indeterminado;
- o usuário não consegue cancelar e voltar;
- o `Mutex` serializa chamadas, mas não impede uma fila longa;
- o app pode ser morto pelo sistema por ANR ou memória sem mensagem útil.

O limite de 500 páginas controla o volume, não o tempo por página.

### Falha de criação do motor é repetida em toda página

`ocr` começa nulo e só é preenchido depois de `createEngine()` ter sucesso
(`PaddleOcrPlugin.kt:51-53`). Se `OpenCVUtils.init` falhar, se o asset do modelo
estiver ausente ou se o ONNX Runtime não carregar, a exceção é capturada e
devolvida como `paddle_ocr_failed` (`PaddleOcrPlugin.kt:69-75`), mas `ocr`
continua nulo. Na página seguinte, `createEngine()` é chamado de novo.

Em um PDF de 300 páginas sem texto nativo, isso significa:

- 300 tentativas de inicialização do OpenCV;
- 300 tentativas de abrir os modelos ONNX;
- 300 erros genéricos;
- 300 fallbacks para ML Kit, cada um com renderização e JPEG próprios.

Não há cache de indisponibilidade, “circuit breaker” nem aviso único. O custo é
multiplicado justamente no cenário em que o motor está quebrado.

### Disponibilidade declarada, não verificada

`OcrService.availableEngines` retorna `{paddleOcr, mlKit}` em qualquer Android
(`ocr_service_native.dart:21-25`), sem verificar:

- se o asset `models/det/inference.onnx` existe;
- se o asset `models/rec/inference.onnx` e o `inference.yml` existem;
- se o OpenCV inicializa;
- se o ONNX Runtime carrega;
- se o ML Kit está instalado/atualizado.

O roteador confia nessa lista e escolhe Paddle para página sem texto
(`ocr_router.dart:32-73`). A primeira falha só aparece durante o processamento.
Não há `warmUp`, `healthCheck` nem versão de modelo exposta ao Dart. O resultado
é uma experiência “tenta e vê”, não um contrato.

### Erros genéricos e sem diagnóstico

O plugin captura `Exception` e devolve sempre o mesmo código e a mesma mensagem
(`PaddleOcrPlugin.kt:69-75`). O `OCRError` tipado do SDK
(`model/OCRError.kt`) não é mapeado para o canal. O Dart registra o erro e a
stack (`pdf_text_extractor.dart:250-256`), mas não recebe:

- qual etapa falhou (OpenCV, modelo de detecção, modelo de reconhecimento,
  inferência, pós-processamento);
- tempo gasto antes da falha;
- se o problema é permanente ou transitório;
- versão do modelo e do runtime.

Isso dificulta suporte, telemetria agregada e decisão de fallback. Também não há
distinção entre “imagem inválida”, “modelo ausente” e “memória insuficiente”.

### Confiança exibida como porcentagem

A decisão registrada na auditoria da área 9 e na nota de produto é não exibir
porcentagem de confiança; usar estados **fazível**, **corrigível** e **não
fazível**. O código ainda mostra:

- “validadas automaticamente (confiança ≥ 99%)” no resumo da digitalização
  (`publish_page.dart:732`);
- “questões com confiança de 99% ou mais já foram validadas automaticamente”
  (`publish_page.dart:1733`);
- “Conferir extração · confiança X%” por questão
  (`publish_page.dart:2057`).

Além de contrariar a decisão, o número não é uma probabilidade calibrada:

- no Paddle, é a média simples das confianças das linhas, sem ponderação por
  quantidade de texto (`ocr_service_native.dart:110-116`);
- no ML Kit, `confidence` é nula, então a média não existe
  (`ocr_service_native.dart:155-159`);
- a confiança da questão pode ser derivada de parser, gabarito e associação de
  imagem, não só do OCR.

Um “99%” pode esconder uma questão sem alternativas ou com figura errada. O
usuário lê precisão onde existe apenas heurística.

### Renderização fixa e perda de detalhe

A página é renderizada com escala `min(2.2, 2200 / max(largura, altura))`
(`ocr_service_native.dart:35-37`) e comprimida em JPEG de qualidade 88
(`ocr_service_native.dart:182-190`). Não há:

- escolha de DPI por tipo de página;
- escala maior para provas densas de duas colunas;
- grayscale, contraste adaptativo ou binarização antes do OCR;
- correção de inclinação/deskew;
- detecção de página em branco ou invertida;
- OCR por região (só a página inteira).

Para uma folha A4 a 72 dpi, a escala 2.2 chega a ~1.309 × 1.852 px. Para uma
folha maior, o limite de 2.200 px no maior lado reduz a resolução efetiva. Texto
pequeno de duas colunas, marcas de alternativa e símbolos matemáticos podem
perder definição. O Paddle ainda redimensiona internamente para o modelo, mas a
fonte já foi limitada e comprimida.

O teste de corpus existe, porém não mede acurácia em função de escala, JPEG ou
tipo de layout. Não há benchmark comparando 2.200 px com 3.000 px, nem medindo
impacto de grayscale.

### Sem captura por câmera ou galeria

O fluxo de entrada só aceita:

- PDF via `FilePicker` (`publish_page.dart:260-293`);
- JSON via `FilePicker` (`publish_page.dart:126-168`);
- criação manual.

O botão “Escanear e identificar” (`publish_page.dart:404-414`) é apenas o avanço
do PDF para a tela de processamento; não abre câmera, não tira foto e não aceita
imagem. O `AGENTS.md` §10 pede câmera e imagens, e §11 pede envio de imagem do
aparelho. Nada disso existe.

Também não há:

- crop/rotação de foto;
- múltiplas páginas fotografadas;
- detecção de desfoque, sombra ou baixo contraste;
- correção de orientação EXIF;
- fluxo “fotografar → revisar → OCR”.

A digitalização prometida é, na prática, importação de PDF.

### Notices divergem do build

`THIRD_PARTY_NOTICES.md:21` declara ONNX Runtime Android `1.21.1`, mas
`android/build.gradle:32` usa `1.31.1`. O `build.gradle.bak`, que continua
versionado, usa `1.21.1`; é provavelmente a origem da divergência. Não há teste
ou script que compare a versão resolvida com o notice.

O risco é de auditoria de licenças e de vulnerabilidades: o SBOM/notice não
corresponde ao artefato distribuído. O OpenCV `4.5.3` também é um artefato
antigo e sem atualização evidente; deve ser tratado na área 17.

### Lockfile Android não é versionado

`packages/paddleocr_android/android/gradle.lockfile` não existe no repositório e
não está no `.gitignore`. O CI gera o lockfile no job `android-gradle-lock`
(`flutter-ci.yml:98-111`), publica como artefato e o build baixa antes de
compilar (`flutter-ci.yml:660-670`). O OSV Scanner usa o mesmo artefato
(`flutter-ci.yml:129`).

Isso funciona no CI, mas:

- um build local resolve versões transitivas diferentes das auditadas;
- o lockfile não tem histórico nem revisão;
- se o artefato expirar ou o job falhar, o build não tem fallback versionado;
- a integridade do APK depende de um artefato efêmero.

É uma decisão defensável para evitar lockfile obsoleto, mas precisa estar
documentada e reproduzível fora do CI.

### Modelos binários sem verificação automatizada

Os modelos são assets versionados:

- detecção: ~1,7 MB;
- reconhecimento: ~4,3 MB;
- SHA-256 declarado em `THIRD_PARTY_NOTICES.md:15-16`.

Não há script de CI que confira o hash dos arquivos contra o notice, nem que
valide a versão do modelo em tempo de execução. Um asset trocado por engano
passa no build e no teste, porque nenhum teste carrega o modelo de verdade.

## O que está ausente ou quebrado

- Timeout por página e por documento.
- Cancelamento da importação.
- Health check/warm-up do Paddle e do ML Kit.
- Cache de indisponibilidade e circuit breaker.
- Mapeamento de `OCRError` para código e mensagem específicos.
- UI sem porcentagem de confiança; estados fazível/corrigível/não fazível.
- Renderização adaptativa (DPI, grayscale, contraste, deskew).
- OCR por região e recorte de figura.
- Captura por câmera, galeria e múltiplas páginas.
- Correção de orientação EXIF e checagem de qualidade da foto.
- Teste nativo do plugin (Kotlin).
- Teste Flutter com `MethodChannel` mockado.
- Teste de integração em emulador/aparelho.
- Benchmark de tempo, memória e acurácia por escala/JPEG.
- Verificação de hash dos modelos no CI.
- Notice alinhado ao build e SBOM consistente.
- Política de atualização do SDK vendorizado.
- Liberação do motor Paddle por inatividade/memória.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “OCR aplicado apenas às páginas/regiões necessárias” | OCR é aplicado à página inteira, sem região | `ocr_service_native.dart:35-60` |
| “Detectar layout e ordem de leitura” | Ordenação de colunas existe; layout estrutural fica no parser | `ocr_layout_orderer.dart:12-75`; `pdf_text_extractor.dart:259-263` |
| “Escolher PDF, imagens, câmera, JSON ou manual” | Só PDF, JSON e manual | `publish_page.dart:171-247, 260-293` |
| “Não exibir porcentagem de confiança” | UI mostra 99% e porcentagem por questão | `publish_page.dart:732, 1733, 2057` |
| “Estados fazível/corrigível/não fazível” | Não existem; existe `confidence` numérica | `import_quality_gate.dart:6, 106-131` |
| “Notices de terceiros conferem com o build” | ONNX `1.21.1` no notice, `1.31.1` no Gradle | `THIRD_PARTY_NOTICES.md:21`; `build.gradle:32` |
| “Lockfile auditado e reproduzível” | Gerado no CI, não versionado | `.github/workflows/flutter-ci.yml:98-111, 660-670` |
| “Modelos com integridade verificada” | Hash declarado, sem verificação automatizada | `THIRD_PARTY_NOTICES.md:15-16` |

## Evidência de testes

- `test/pdf_text_extractor_test.dart:101-141` cobre roteamento:
  texto nativo suficiente, ML Kit para texto curto, Paddle para página sem texto
  e indisponibilidade sem motor.
- `test/pdf_text_extractor_test.dart:143-170` cobre ordenação de duas colunas e
  ordem vertical sem separação.
- `test/import_quality_gate_test.dart` cobre o quality gate que consome
  confiança e avisos, mas não o motor.
- `test/local_corpus_benchmark_test.dart` usa o corpus local, mas não mede
  acurácia do Paddle contra ML Kit nem varia escala/JPEG.
- Não há teste que instancie `PaddleOcrAndroid` ou simule o `MethodChannel`.
- Não há teste Kotlin do plugin: `find packages/paddleocr_android -path
  '*test*'` não retorna nada.
- Não há teste do limite de 20 MB, de imagem inválida, de modelo ausente, de
  OpenCV indisponível, de timeout ou de cancelamento.
- Não há teste de integração em Android real.
- O baseline geral tem 296 testes aprovados e 1 ignorado; nenhum deles exercita
  o código nativo do Paddle.

## Riscos

1. **Import travado.** Sem timeout, uma página problemática pode prender o
   processamento e o usuário não tem como cancelar.
2. **Falha em cascata.** Motor quebrado é recriado a cada página, multiplicando
   tempo, bateria e logs.
3. **Qualidade silenciosa.** Resolução fixa e JPEG 88 podem perder texto denso
   sem que o usuário saiba por quê.
4. **Confiança enganosa.** “99%” sugere precisão que o pipeline não mede.
5. **Câmera ausente.** A promessa de digitalizar por foto não é cumprida.
6. **Licença divergente.** Notice e build apontam versões diferentes do ONNX
   Runtime.
7. **Supply chain de modelo.** Asset binário sem verificação automatizada de
   hash.
8. **APK maior.** Cerca de 6 MB de modelos mais ONNX Runtime e OpenCV, sem
   política de tamanho ou download sob demanda.
9. **Fork sem manutenção.** SDK vendorizado sem patch documentado, testes ou
   processo de atualização.
10. **Memória retida.** Engine Paddle permanece carregada após a importação, sem
    liberação por inatividade.

## Plano de refatoração da área

### Lote 1 — Contrato de saúde e falha rápida

- Adicionar ao plugin `isAvailable`, `warmUp` e `modelVersion`; fazer o
  `OcrService` chamar um health check no início da importação.
- Cachear falha de criação por sessão e desabilitar o Paddle depois da primeira
  falha permanente.
- Mapear `OCRError` para códigos estáveis (`model_missing`, `opencv_failed`,
  `invalid_image`, `out_of_memory`, `inference_failed`).
- Adicionar `withTimeout` por página e um token de cancelamento propagado do
  import.
- Critério de aceite: modelo ausente produz uma falha rápida, o ML Kit assume e
  nenhuma página seguinte tenta recriar o Paddle; timeout marca a página para
  revisão e o documento continua; teste cobre cada código.

### Lote 2 — Renderização adaptativa e qualidade

- Definir perfis de renderização por tipo de página: padrão, densa e foto.
- Aumentar o limite de 2.200 px quando a página tiver duas colunas ou texto
  pequeno; testar 2.200 vs 3.000 px no fixture de 80 questões.
- Avaliar grayscale, contraste e binarização antes do JPEG; manter JPEG apenas
  como transporte para o ML Kit e considerar PNG/WebP sem perda para o Paddle.
- Medir acurácia, tempo e memória por perfil; escolher o padrão com dados.
- Critério de aceite: fixture mantém ordem e alternativas; benchmark registra
  acurácia e custo; nenhuma página excede o orçamento de memória.

### Lote 3 — UI sem confiança numérica

- Remover “99%” e “confiança X%” da revisão.
- Derivar **fazível**, **corrigível** e **não fazível** de sinais estruturais:
  questão detectada, alternativas, gabarito, imagem associada, texto suficiente
  e warnings.
- Manter `confidence` apenas como sinal interno de triagem, nunca como promessa
  ao aluno.
- Explicar o motivo do estado (“faltam alternativas”, “gabarito não encontrado”,
  “figura não associada”).
- Critério de aceite: nenhuma porcentagem na UI; teste de widget cobre os três
  estados e seus motivos.

### Lote 4 — Digitalização por câmera e galeria

- Adicionar captura por câmera e seleção de imagem, com múltiplas páginas,
  rotação, crop e correção de EXIF.
- Checar desfoque, sombra, contraste e enquadramento antes de aceitar a foto.
- Reutilizar o mesmo pipeline de OCR e revisão.
- Se a captura não entrar nesta fase, remover o rótulo “Escanear e identificar”
  do PDF ou renomeá-lo para “Processar PDF”, para não prometer câmera.
- Critério de aceite: foto de prova gera página, OCR e revisão; EXIF e rotação
  são respeitados; teste em aparelho cobre foto escura e torta.

### Lote 5 — Licenças, lockfile e reprodutibilidade

- Alinhar `THIRD_PARTY_NOTICES.md` ao `build.gradle` e remover o
  `build.gradle.bak`.
- Documentar o commit upstream, os patches locais e o processo de atualização
  do SDK.
- Adicionar verificação de hash dos modelos e de versão das dependências no CI.
- Decidir e documentar se o `gradle.lockfile` será versionado ou gerado no CI;
  se continuar efêmero, garantir fallback e retenção.
- Critério de aceite: CI falha se notice e dependência divergirem; hash dos
  modelos confere; lockfile tem política escrita.

### Lote 6 — Testes e benchmark

- Criar testes Kotlin para o wrapper: imagem vazia, imagem acima de 20 MB,
  modelo ausente, OpenCV indisponível, erro de inferência e liberação.
- Criar teste Flutter com `MethodChannel` mockado para `PaddleOcrAndroid`.
- Criar teste de integração Android com uma imagem de fixture e um PDF de duas
  colunas.
- Medir tempo, memória e acurácia em aparelho de entrada e intermediário;
  registrar baseline e limite de regressão.
- Critério de aceite: testes do plugin rodam no CI; benchmark tem números
  reproduzíveis e alerta de regressão.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | OCR funciona e tem fallback; confiança e renderização enganam. |
| Testes | 2 | Roteamento e layout testados; plugin, timeout e integração não. |
| Acoplamento | 3 | Plugin isolado, mas serviço e UI conhecem motores e confiança. |
| Clareza | 3 | Estrutura legível; erro genérico, `.bak` e notice divergente. |
| Segurança | 3 | Processamento local e limite de 20 MB; sem timeout e sem hash de modelo. |
| Robustez | 2 | Sem timeout/cancelamento; falha de motor repetida por página. |
| Aderência | 2 | OCR local existe; câmera, estados e UI sem porcentagem faltam. |
| Portabilidade | 3 | Android com Paddle + ML Kit; iOS só ML Kit; web sem OCR. |

Classificação resultante: **EVOLUIR** — a integração é funcional e
arquiteturalmente separada, mas ainda não tem contrato de saúde, limites de
execução, testes do código nativo nem uma apresentação de qualidade compatível
com a decisão do produto.

## Dependências

- Área 9 para pipeline de importação, parser, quality gate e fixture de 80
  questões.
- Área 10 para mídia, figuras e associação de imagem.
- Área 14 para testes de integração, benchmark e caos.
- Área 15 para APK, tamanho, CI e distribuição.
- Área 16 para os estados de revisão e os componentes de qualidade.
- Área 17 para ONNX Runtime, OpenCV, lockfile e vulnerabilidades.
- Área 18 para alinhar notices, decisões e documentação.
- Decisão de produto sobre captura por câmera e sobre o significado de
  “confiança” na revisão.

## O que não foi verificado

- OCR real em aparelho Android, com Paddle e ML Kit.
- Tempo de cold start, tempo por página e memória em aparelho de entrada.
- Acurácia do Paddle vs ML Kit no corpus de 80 questões.
- Comportamento com modelo ausente, corrompido ou ONNX Runtime incompatível.
- Comportamento com imagem acima de 20 MB, PDF protegido ou página em branco.
- Cancelamento (não implementado).
- Tamanho final do APK por ABI e impacto dos modelos.
- Funcionamento do lockfile fora do CI.
- Licenças e CVEs do OpenCV `4.5.3` e do ONNX Runtime `1.31.1`.
- Compatibilidade do plugin com futuras versões do Flutter/AGP.
- Desempenho em iOS com ML Kit.

## Links

- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação e OCR]]
- [[10 - Publicação, pacotes, mídia e Storage|Área 10 — Publicação e mídia]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes e QA]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD e distribuição]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[17 - Dependências e manutenção|Área 17 — Dependências]]
- [[18 - Documentação e divergências código × docs|Área 18 — Documentação]]
- [[../../01 - Produto/Importação e OCR|Importação e OCR]]
- [[Mapa das Áreas|Mapa das Áreas]]
