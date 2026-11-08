---
tipo: adr
area: tamanho de apk e componentes nativos
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [packages/paddleocr_android/android/build.gradle, packages/paddleocr_android/android/src/main/assets/models/, packages/paddleocr_android/THIRD_PARTY_NOTICES.md, lib/core/import/ocr_service_native.dart, pubspec.yaml, build/app/outputs/flutter-apk/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0011 — Tamanho de APK, modelos sob demanda e componentes nativos

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 13, 17
- **Urgência:** Média

## Contexto

O APK carrega **duas pilhas de OCR completas**, e nenhuma delas é baixada sob
demanda.

- **Composição medida dentro do APK arm64 local**
  (`unzip -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`,
  352 arquivos, 83.907.336 B descomprimidos; a release `v0.7.5` publicada
  tem 82.134.581 B comprimidos):

  | Componente | Bytes |
  |---|---:|
  | `lib/arm64-v8a/libonnxruntime.so` | 17.908.496 |
  | `lib/arm64-v8a/libopencv_java4.so` | 17.109.960 |
  | `lib/arm64-v8a/libflutter.so` | 11.747.864 |
  | `lib/arm64-v8a/libmlkit_google_ocr_pipeline.so` | 11.064.544 |
  | `lib/arm64-v8a/libapp.so` | 7.865.224 |
  | `lib/arm64-v8a/libpdfium.so` | 6.386.696 |
  | `assets/models/rec/inference.onnx` | 4.462.639 |
  | `assets/models/det/inference.onnx` | 1.780.590 |
  | `classes.dex` | 1.739.068 |
  | `lib/arm64-v8a/libc++_shared.so` | 911.696 |

- **A pilha PaddleOCR sozinha soma ~41,3 MB** descomprimidos
  (ONNX Runtime + OpenCV + os dois modelos), contra ~11,1 MB da pipeline do
  ML Kit mais seus modelos (o maior asset do ML Kit medido é
  `assets/mlkit-google-ocr-models/taser/detector/rpn_text_detector_mobile_space_to_depth_quantized_mbv2_v1.tflite`,
  340.760 B).
- **Os dois motores são oferecidos no Android.**
  `lib/core/import/ocr_service_native.dart:21-25`:
  `TargetPlatform.android => {OcrEngine.paddleOcr, OcrEngine.mlKit}`,
  iOS só ML Kit, demais plataformas nenhum. Ou seja: o usuário Android
  baixa as duas pilhas para poder escolher uma.
- **Modelos são assets do plugin, não do app.**
  `packages/paddleocr_android/android/src/main/assets/models/det/inference.onnx`
  = 1.780.590 B e `rec/inference.onnx` = 4.462.639 B, mais
  `rec/inference.yml` = 55.571 B (total 6.298.800 B em disco). O app não
  declara asset de modelo: `pubspec.yaml:38-40` lista só
  `assets/branding/app_icon.png`. Não há `android/app/src/main/assets` nem
  `jniLibs` próprios.
- **Nenhum download sob demanda.** `grep -rn "\.onnx\|\.tflite\|download"
  lib/ packages/paddleocr_android/lib/` não retorna caminho de busca de
  modelo; os hashes em `THIRD_PARTY_NOTICES.md:15-16` batem com os arquivos
  locais (conferidos com `sha256sum`), o que confirma que são os mesmos
  modelos empacotados, não baixados.
- **Já existe preguiça em runtime, mas não no pacote.** O motor nativo é
  criado no primeiro uso sob mutex
  (`packages/paddleocr_android/android/src/main/kotlin/.../PaddleOcrPlugin.kt:51-53`)
  e liberado no detach (`:88-101`). Isso economiza RAM e tempo de início,
  **não** bytes de download. Não há `deferred as` em lugar nenhum de `lib/`
  (`grep -rn "deferred as" lib/ | wc -l` → 0).
- **Versões nativas fixadas no Gradle.**
  `packages/paddleocr_android/android/build.gradle:32-34`:
  `onnxruntime-android:1.31.1`, `opencv:4.5.3`,
  `kotlinx-coroutines-android:1.9.0`, com `lockAllConfigurations()` em
  `:28`. O aviso de terceiros declara ONNX `1.21.1`
  (`THIRD_PARTY_NOTICES.md:21`) — divergência já registrada no ADR-0007.
- **Proveniência de `libpdfium.so` não rastreada.** `pdfium_flutter ^0.3.0`
  é **dev** dependency (`pubspec.yaml:34`); o runtime de PDF é
  `pdfrx ^2.6.5` (`:25`). A `.so` de 6,4 MB está no APK, mas qual dos dois a
  introduz não foi determinado nesta auditoria.

**Limites.** Os números são de um build local de 1º/11 e da release
`v0.7.5`; não foi feito build limpo de `0.7.5+15` para medir a composição
atual. Tamanhos descomprimidos não são o que o usuário baixa (a release
comprimida é 82,1 MB). Não foi medido tempo de primeiro OCR nem uso de RAM
em aparelho. Não há medição de quantos usuários escolhem cada motor.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — uma pilha de OCR por plataforma, como direção a
avaliar**, condicionada a benchmark de acurácia e tempo. A decisão é **medir
antes de cortar**, atacando primeiro a duplicação de pilha, que é o maior
item isolado:

1. **Decidir se os dois motores precisam coexistir no mesmo APK.** Se o
   PaddleOCR é o motor preferido no Android, avaliar empacotar só ele (ou só
   ML Kit) e medir a diferença real num build limpo. Isso é decisão de
   produto/qualidade de OCR, não só de tamanho: exige comparar acurácia nos
   fixtures antes.
2. **Modelos sob demanda só depois de haver medição de necessidade.** Os
   modelos são 6,3 MB; o custo está nas `.so` (35 MB de ONNX + OpenCV), que
   não dá para baixar como asset sem um loader nativo. Baixar modelo não
   resolve o problema maior.
3. **Registrar tamanho de APK por release como métrica**, não como número
   solto em nota: hoje não há tamanho registrado em documento rastreado.
4. **Não introduzir `deferred as` no Dart como solução de tamanho** sem
   medir: o peso está em nativo, não em código Dart.

## Alternativas

- **A — Uma pilha de OCR por plataforma (escolhida para avaliação).**
  Prós: maior redução disponível (~41 MB ou ~11 MB descomprimidos, a
  depender de qual fica); menos superfície nativa para manter e auditar;
  alinha com o ADR-0009. Contras: perde a opção de trocar de motor em
  runtime; exige comparar acurácia nos corpora antes; ML Kit depende de
  serviço Google, PaddleOCR é local — a troca tem implicação de
  privacidade/offline.
- **B — Modelos sob demanda (download no primeiro uso).** Prós: reduz
  ~6,3 MB do APK; permite atualizar modelo sem release do app. Contras:
  exige rede no primeiro OCR (hoje é local por princípio,
  `README.md:27`), hospedagem e verificação de hash, tratamento de falha e
  de versão; não toca nas `.so`, que são o custo maior; aumenta o caminho
  crítico de importação.
- **C — Play Asset Delivery / dynamic feature module.** Prós: entrega
  nativa e modelos como módulos sob demanda pela loja, sem loader próprio.
  Contras: exige distribuição por loja (hoje é GitHub + site, ver ADR-0005)
  e AAB; é mudança de canal, não de empacotamento.
- **D — Otimizar o que já existe (R8/ProGuard, compressão, remover
  `libc++_shared` duplicado).** Prós: ganho sem mudar funcionalidade;
  `proguardFiles` já está configurado (`android/app/build.gradle.kts:34-35`,
  duplicado). Contras: ganho pequeno frente a 35 MB de `.so` de terceiros;
  encolher Dart não reduz nativo.
- **E — Não fazer.** Prós: custo zero; OCR continua funcionando offline com
  dois motores. Contras: 82 MB por APK continua sendo a barreira de entrada
  em aparelho modesto e em rede limitada; a duplicação de pilha permanece
  sem decisão registrada.

## Consequências e reversão

- **Positivas:** APK menor onde importa; uma pilha nativa a menos para
  manter, auditar e licenciar; tamanho passa a ser métrica por release.
- **Negativas/custos:** escolher um motor exige benchmark de acurácia e
  tempo nos fixtures (sintético, VUNESP, ENEM local) antes de decidir;
  remover ML Kit pode afetar iOS, que só tem ML Kit
  (`ocr_service_native.dart:23`); modelos sob demanda introduzem
  dependência de rede num fluxo que hoje é local.
- **Riscos:** cortar motor sem medir acurácia regride a importação, que é
  o coração do produto. Mitigação: caracterização com
  `test/local_corpus_benchmark_test.dart` e os testes de banca antes e
  depois, com o mesmo corpus.
- **Reversão:** A e D são reversíveis por `git revert` + rebuild, mas o
  artefato já publicado continua com o tamanho antigo até a próxima
  release. B e C introduzem estado externo (modelo baixado, módulo de
  loja): reverter o código não remove o que já foi baixado/instalado, e a
  compatibilidade entre modelo baixado e versão do app precisa ser
  decidida antes.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/13 - OCR Android, PaddleOCR e digitalização|Área 13]],
  [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]].
- Código e config: [ocr_service_native.dart](../../../lib/core/import/ocr_service_native.dart),
  [build.gradle do plugin](../../../packages/paddleocr_android/android/build.gradle),
  [THIRD_PARTY_NOTICES.md](../../../packages/paddleocr_android/THIRD_PARTY_NOTICES.md),
  [pubspec.yaml](../../../pubspec.yaml),
  [build.gradle.kts do app](../../../android/app/build.gradle.kts).
- Testes: [local_corpus_benchmark_test.dart](../../../test/local_corpus_benchmark_test.dart),
  [synthetic_pdf_import_test.dart](../../../test/synthetic_pdf_import_test.dart),
  [vunesp_2024_import_test.dart](../../../test/vunesp_2024_import_test.dart),
  [enem_2025_import_test.dart](../../../test/enem_2025_import_test.dart),
  [import_quality_gate_test.dart](../../../test/import_quality_gate_test.dart).
- **Exigido antes de implementar:** build limpo de `0.7.5+15` com
  `--split-per-abi` e `unzip -l` registrado por ABI; comparação de acurácia
  e tempo entre PaddleOCR e ML Kit no mesmo corpus; rastrear a proveniência
  de `libpdfium.so`; para B, decisão de hospedagem, hash e política de
  offline; para C, decisão de canal (ADR-0005).
- Comandos de reprodução:
  `unzip -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | sort -rn | head -12`;
  `ls -l packages/paddleocr_android/android/src/main/assets/models/*/*`;
  `sha256sum packages/paddleocr_android/android/src/main/assets/models/*/inference.onnx`;
  `grep -rn "deferred as" lib/ | wc -l` → 0.
- Relacionados: [[ADR-0005 - Distribuição Android e seleção de ABI|ADR-0005]],
  [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]],
  [[ADR-0009 - Política de dependências e pins|ADR-0009]],
  [[ADR-0006 - Escopo de importação por câmera|ADR-0006]].