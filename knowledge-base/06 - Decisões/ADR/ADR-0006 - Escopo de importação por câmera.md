---
tipo: adr
area: importação e digitalização
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [README.md, AGENTS.md, lib/features/publish/publish_page.dart, lib/core/import/ocr_service_native.dart, lib/core/widgets/question_media_gallery.dart, pubspec.yaml, android/app/src/main/AndroidManifest.xml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0006 — Escopo de importação por câmera: implementar ou remover do README

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 9, 13, 18
- **Urgência:** Média

## Contexto

A promessa existe em dois documentos; a implementação não existe em nenhum.

- **Promessa no README.** `README.md:26-28` lista, em “Importação”:
  “PDFs (com OCR local no Android)”, “**Imagens**”, “Criação manual de
  questões”. A palavra “câmera” não aparece no README.
- **Promessa no normativo.** `AGENTS.md:302` (fluxo ideal de importação):
  “Escolher PDF, **imagens, câmera**, JSON ou criação manual”.
- **O que a tela oferece.** `lib/features/publish/publish_page.dart:68-101`
  tem exatamente três escolhas: `Importar PDF` → `PdfImportPage`,
  `Importar JSON` → `_importJson`, `Criar manualmente` → `ImportReviewPage`.
  PDF usa `FilePicker.pickFile` com `['pdf']` (`:263-266`, teto de 25 MB em
  `:270`); JSON com `['json']` (`:123-126`, teto de 4 MB em `:129`). O botão
  “Escanear e identificar” (`:404-414`) só empilha `PdfProcessingPage` — não
  abre câmera.
- **Nenhuma dependência de câmera ou seletor de imagem.**
  `grep -n "camera\|image_picker" pubspec.yaml
  android/app/src/main/AndroidManifest.xml` não retorna nada: sem pacote, sem
  permissão `CAMERA`. `grep -rn "camera\|image_picker\|ImageSource" lib/`
  retorna só a string `'questionImageSource'`
  (`lib/core/import/imported_document.dart:298`), que é metadado de figura
  extraída de PDF, não captura.
- **O OCR só aceita página de PDF.** A assinatura é
  `Future<OcrRecognition> recognizePage(PdfPage page, {required OcrEngine
  engine})` (`lib/core/import/ocr_service_native.dart:27-30`), com
  `pdfrx` importado em `:9`. Os motores existem (PaddleOCR e ML Kit no
  Android, ML Kit no iOS, nenhum nas outras plataformas — `:21-25`), mas
  **não há ponto de entrada que receba um arquivo de imagem**. Implementar
  câmera não é só adicionar um picker: é abrir uma segunda entrada de OCR.
- **A aba de imagens do normativo também não existe.** `AGENTS.md:370-380`
  pede, na criação/revisão, uma aba para enviar imagem do aparelho,
  selecionar imagem já enviada, pesquisar imagem pública licenciada,
  informar autoria/licença/URL e recortar antes de salvar.
  `QuestionMediaGallery` é **só leitura** e é usada em
  `lib/features/quiz/quiz_page.dart:1025`,
  `lib/features/result/review_page.dart:163` e
  `lib/features/share/share_link_page.dart:111` — nenhuma chamada em
  `publish_page.dart`. As figuras que ela mostra vêm da extração do PDF.

**Limites.** “Não existe” aqui significa não existe em `lib/`, `pubspec.yaml`
e `AndroidManifest.xml` no SHA auditado; não foi executado o app para
confirmar em runtime. Não foi estimado o esforço de implementar — a
afirmação de custo abaixo é estrutural (nova entrada de OCR + permissão +
pacote), não uma medição de horas.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — remover/adiar a promessa agora e decidir a
implementação depois, em ADR próprio.** A decisão é:

1. Tirar “Imagens” de `README.md:28` e registrar em nota de produto que a
   entrada por imagem/câmera está fora do escopo atual.
2. Em `AGENTS.md:302`, marcar “imagens, câmera” como fase posterior (o
   documento já usa esse recurso para outras etapas, p.ex. “Avaliação
   avançada de texto fica para fase posterior” em `:368`), em vez de
   apresentar como fluxo disponível.
3. Tratar a aba de imagens de `AGENTS.md:370-380` como escopo separado, com
   decisão de licença junto (ADR-0007), porque ela exige autoria, licença e
   URL de origem — não é um detalhe de UI.

Razão: a promessa falsa já custou uma divergência registrada na auditoria da
área 18 e continua induzindo quem lê o README a esperar um recurso que não
existe. Corrigir o documento é barato e reversível; implementar câmera é
caro e depende de decisão de produto que ainda não foi tomada.

## Alternativas

- **A — Remover/adiar a promessa (escolhida).** Prós: custo de duas linhas;
  elimina a divergência código × docs imediatamente; não fecha a porta para
  implementar depois. Contras: o produto passa a declarar menos do que o
  normativo original pedia; quem esperava importar foto de prova fica sem
  caminho.
- **B — Implementar importação por imagem (galeria), sem câmera.** Adicionar
  `image_picker` (ou `file_picker` com extensões de imagem), criar entrada de
  OCR que receba arquivo em vez de `PdfPage`, reusar o roteador de motores.
  Prós: atende “Imagens” do README sem permissão de câmera; ML Kit já aceita
  imagem de arquivo; é o degrau natural antes da câmera. Contras: novo
  caminho de extração para testar (layout de uma página fotografada é pior
  que PDF renderizado); depende de decisão de pin (ADR-0009) e aumenta o APK
  (ADR-0011).
- **C — Implementar imagem + câmera.** B mais pacote `camera`, permissão
  `CAMERA`, fluxo de captura e recorte. Prós: cumpre `AGENTS.md:302` por
  inteiro. Contras: maior superfície de permissões e de testes em dispositivo
  real; câmera exige tratamento de orientação, foco e recorte para o OCR não
  receber lixo; é a opção mais cara e a que mais exige device lab.
- **D — Não fazer nada.** Prós: custo zero. Contras: README e `AGENTS.md`
  continuam prometendo entrada inexistente; a divergência da área 18
  permanece aberta e vai reaparecer em toda auditoria futura.
- **E — Implementar a aba de imagens primeiro (`AGENTS.md:370-380`).**
  Prós: resolve o anexo de figura com autoria e licença, que hoje só existe
  para figuras extraídas de PDF. Contras: não atende a promessa de
  *importar prova* por imagem; são dois problemas diferentes e tratá-los
  como um só atrasaria os dois.

## Consequências e reversão

- **Positivas de A:** documentação volta a ser verdadeira; a auditoria da
  área 18 ganha um item resolvido; nenhuma dependência nova, nenhum aumento
  de APK, nenhuma permissão nova.
- **Negativas/custos:** reduzir escopo declarado é decisão de produto e
  precisa do aval do responsável; se a câmera já foi prometida a alguém
  externamente, remover do README não apaga a promessa feita.
- **Riscos de B/C:** novo caminho de OCR sem os testes de layout que o
  caminho de PDF já tem (`test/pdf_text_extractor_test.dart`,
  `test/synthetic_pdf_import_test.dart`, `test/import_quality_gate_test.dart`)
  entraria em produção com cobertura menor que a do caminho antigo.
- **Reversão:** A é `git revert` de duas linhas. B e C são reversíveis no
  código, mas a permissão `CAMERA` declarada numa release publicada continua
  visível na loja/instalador mesmo depois de revertida — reverter código não
  recolhe permissão já distribuída.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Área 09]],
  [[../../09 - Auditoria/Áreas/13 - OCR Android, PaddleOCR e digitalização|Área 13]],
  [[../../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|Área 18]].
- Código e docs: [publish_page.dart](../../../lib/features/publish/publish_page.dart),
  [ocr_service_native.dart](../../../lib/core/import/ocr_service_native.dart),
  [question_media_gallery.dart](../../../lib/core/widgets/question_media_gallery.dart),
  [pubspec.yaml](../../../pubspec.yaml),
  [AndroidManifest.xml](../../../android/app/src/main/AndroidManifest.xml),
  [README.md](../../../README.md), [AGENTS.md](../../../AGENTS.md).
- Testes do caminho existente (a proteger antes de adicionar outro):
  [pdf_text_extractor_test.dart](../../../test/pdf_text_extractor_test.dart),
  [synthetic_pdf_import_test.dart](../../../test/synthetic_pdf_import_test.dart),
  [import_quality_gate_test.dart](../../../test/import_quality_gate_test.dart),
  [question_media_gallery_test.dart](../../../test/question_media_gallery_test.dart).
- **Exigido antes de implementar B/C:** prova de conceito de OCR sobre uma
  foto real (não PDF renderizado) medida contra o quality gate; teste de
  permissão negada; decisão de motor (PaddleOCR × ML Kit) para imagem única;
  para C, teste em aparelho físico. Para A, varredura de links e de
  menções a “Imagens”/“câmera” no vault e no site.
- Comandos de reprodução:
  `grep -n "camera\|image_picker" pubspec.yaml android/app/src/main/AndroidManifest.xml`
  (vazio); `grep -n "recognizePage" lib/core/import/ocr_service_native.dart`;
  `sed -n '68,101p' lib/features/publish/publish_page.dart`;
  `sed -n '26,32p' README.md`.
- Relacionados: [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]],
  [[ADR-0009 - Política de dependências e pins|ADR-0009]],
  [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]],
  [[ADR-0008 - Hierarquia documental e versionamento do vault|ADR-0008]].