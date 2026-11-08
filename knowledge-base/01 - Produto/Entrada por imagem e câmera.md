---
tipo: area
area: entrada por imagem e câmera
status: VALIDADO
classificacao: ADIAR
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/features/publish/publish_page.dart, lib/core/import/ocr_service_native.dart, pubspec.yaml, android/app/src/main/AndroidManifest.xml, README.md, AGENTS.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-07
---

# Entrada por imagem e câmera

Nota de escopo, não auditoria de área: registra uma decisão de produto e a
ausência medida que a justifica. Por isso `nivel` não é pontuado — não existe
implementação para avaliar. A classificação **ADIAR** vem do
[[../09 - Auditoria/Classificação/Guia de Classificação|guia]]: capacidade válida,
que depende de fundação ainda inexistente.

## Decisão

[[../06 - Decisões/ADR/ADR-0006 - Escopo de importação por câmera|ADR-0006]],
alternativa **A**, aceita em 2026-11-07 pelo responsável pelo projeto: a entrada
por imagem e câmera **está fora do escopo atual**. A promessa foi retirada dos
documentos em vez de ser implementada. Implementar exige ADR próprio.

Três mudanças aplicadas em 2026-11-07:

| Documento | Antes | Depois |
|---|---|---|
| `README.md:28` | `- Imagens` na lista de importação | linha removida |
| `AGENTS.md:302` | “Escolher PDF, imagens, câmera, JSON ou criação manual” | PDF, JSON e manual; imagem/câmera marcadas como fase posterior |
| `AGENTS.md` §11 | aba de imagens apresentada como requisito disponível | aviso de escopo posterior, com a dependência de licença explícita |

## O que existe hoje (medido)

| Capacidade | Estado | Evidência |
|---|---|---|
| Importar PDF | Funcional | `publish_page.dart:71,264-271` — `FileType.custom`, limite de 25 MB |
| Importar JSON exportado pelo editor | Funcional | `publish_page.dart:81,124-129` — limite de 4 MB |
| Criação manual | Funcional | `publish_page.dart:68-101` (três entradas) |
| “Escanear e identificar” | Abre o processamento de **PDF**, não a câmera | `publish_page.dart:413` → `PdfProcessingPage` |
| Importar imagem da galeria | Ausente | nenhum `FileType.image`; sem `image_picker` no `pubspec.yaml` |
| Capturar por câmera | Ausente | sem pacote `camera`; sem `android.permission.CAMERA` no manifesto |
| OCR sobre arquivo de imagem | Ausente na borda | `ocr_service_native.dart:27-28` — `recognizePage(PdfPage page, …)` |
| Exibir figuras extraídas do PDF | Funcional, somente leitura | `QuestionMediaGallery` em `quiz_page.dart`, `review_page.dart`, `share_link_page.dart` |

O ponto que torna a promessa cara: **o OCR só recebe página de PDF**. Os dois
motores existem e roteiam, mas a entrada do pipeline é `PdfPage`. Importar foto
não é adicionar um picker — é criar uma entrada de extração que produza o mesmo
contrato de página/região, com layout de uma página fotografada (perspectiva,
iluminação, foco) em vez de PDF renderizado.

## Por que adiar, e não implementar

- **Custo de teste desproporcional.** O corpus atual e os 105 testes do scanner
  ([[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|área 9]])
  exercitam PDF. Um caminho de foto entraria sem ground truth e sem regressão.
- **Superfície de permissão.** Câmera exige permissão em tempo de execução,
  tratamento de orientação, foco e recorte; galeria exige decisão de pin
  ([[../06 - Decisões/ADR/ADR-0009 - Política de dependências e pins|ADR-0009]]) e
  aumenta o APK ([[../06 - Decisões/ADR/ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]]).
- **Nenhuma pilha de OCR pode ser escolhida ainda.** A remoção de um motor está
  condicionada a benchmark em aparelho Android (ADR-0011); decidir a entrada de
  imagem antes dessa medição seria escolher sem dado.
- **Corrigir o documento é barato e reversível.** A promessa falsa já tinha
  produzido divergência registrada na
  [[../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|área 18]]
  e continuava induzindo quem lê o README a esperar um recurso inexistente.

## O que seria necessário para reabrir

1. Prova de conceito de OCR sobre foto real, com o mesmo contrato de saída de
   `recognizePage`, medida contra o corpus sintético e contra PDF equivalente.
2. Benchmark estrutural dos dois motores em aparelho Android, registrado — gate
   do ADR-0011, ainda pendente de dispositivo.
3. Decisão de pin para `image_picker`/`file_picker` e, se houver câmera, do pacote
   `camera` e da permissão no manifesto.
4. ADR próprio escolhendo entre galeria sem câmera (alternativa B do ADR-0006) e
   imagem + câmera (alternativa C), com custo de device lab declarado.

## A aba de imagens é outro problema

`AGENTS.md` §11 pede aba para enviar/selecionar/pesquisar imagem, com autoria,
licença e URL de origem, mais recorte. Isso é **anexo de figura em questão**, não
**importação de prova por imagem**. São dois problemas: o anexo existe parcialmente
(figuras extraídas do PDF, em galeria somente leitura) e depende de decisão de
licença ([[../06 - Decisões/ADR/ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]]);
a importação por foto não existe em nada. Tratar os dois como um só item foi o que
produziu a promessa vaga no README.

## Limite desta nota

A ausência foi verificada por leitura estática de `pubspec.yaml`, manifesto
Android, assinaturas e pontos de entrada, e por busca de `camera`/`image_picker`.
**Nenhum OCR de foto foi executado** — não há como medir acurácia sobre imagem
fotografada sem o caminho de entrada. A nota não afirma que importar foto seja
inviável; afirma que não está implementado e que a decisão de implementá-lo ainda
não foi tomada.

## Links

[[Importação e OCR]] · [[Fluxo de Entrada e Criação]] ·
[[../06 - Decisões/ADR/ADR-0006 - Escopo de importação por câmera|ADR-0006]] ·
[[../06 - Decisões/ADR/README|Índice de ADRs]] ·
[[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Área 9]] ·
[[../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|Área 18]]

- [ocr_service_native.dart](../../lib/core/import/ocr_service_native.dart)
- [publish_page.dart](../../lib/features/publish/publish_page.dart)
- [README.md](../../README.md)
- [AGENTS.md](../../AGENTS.md)