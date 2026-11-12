---
tipo: area
area: importação, OCR, parser e quality gate
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 2, clareza: 3, seguranca: 3, robustez: 3, aderencia: 3, portabilidade: 4}
fonte_codigo: [lib/core/import/, lib/features/publish/publish_page.dart, test/, qa/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Importação, OCR, parser e quality gate

## Resumo

O caminho **PDF → extração nativa ou OCR → ordenação de layout → remoção de
mobília → normalização → parser → gabarito → quality gate → revisão humana**
está implementado e tem cobertura estrutural relevante, inclusive com uma prova
VUNESP real de 80 questões/32 páginas e uma prova ENEM de 90 questões.

A área **não está completa**. Faltam câmera/galeria, fila de feedback,
publicação de questões discursivas, classificação estrutural honesta na interface
e validação de OCR em aparelho. A classificação é **EVOLUIR**: a base é
aproveitável, mas ainda há capacidade de produto e evidência de campo pendentes.

## Escopo e método

- Leitura direcionada dos 16 arquivos de `lib/core/import/` (4.476 linhas) e da
  orquestração em `lib/features/publish/publish_page.dart` (2.379 linhas).
- Execução de 11 arquivos de teste do scanner: **105 aprovados, 1 opcional
  ignorado**. O ignorado é o teste principal do caderno ENEM 2025, porque o PDF
  não está versionado nesta máquina; o teste de gabarito do ENEM executou.
- `flutter analyze`: sem issues no SHA auditado.
- Não foi executado OCR nativo em Android/iOS, nem teste em navegador real.
- Não foi consultado o Supabase remoto; a fila de feedback não existe no código.

## Pipeline verificado

| Etapa | Implementação | Estado | Evidência |
|---|---|---|---|
| Entrada PDF | Seleção por arquivo; limite de 25 MB; sem câmera/galeria | Parcial | `publish_page.dart:270` |
| Entrada JSON | Exportação/importação de prova estruturada; limite de 4 MB | Funcional | `publish_page.dart:129-133` |
| Criação manual | Editor de questões e alternativas | Funcional | `publish_page.dart:68-106` |
| Entrada por câmera/galeria | Não existe | Ausente | busca sem `camera`/`image_picker` |
| Extração de texto | Texto nativo por página, coordenadas, colunas e previews; até 500 páginas | Funcional | `pdf_text_extractor.dart:144-189` |
| Roteamento de OCR | Texto nativo ≥ 20 caracteres; PaddleOCR para página-imagem; ML Kit para texto curto; fallback entre motores | Parcial | `ocr_router.dart:30-70` |
| OCR na Web | Stub declara indisponível | Funcional (limitação honesta) | `ocr_service_stub.dart` |
| Ordenação de layout | Separação de duas colunas por lacuna horizontal e ordenação vertical | Funcional | `ocr_layout_orderer.dart:20-55` |
| Remoção de mobília | Cabeçalhos/rodapés repetidos, marcas d'água, números e códigos de página | Funcional | `page_furniture_filter.dart` |
| Normalização | Espaços, caracteres invisíveis, quebras e marcadores partidos | Funcional | `text_normalizer.dart` |
| Detecção de formato | Banca/estrutura por evidência no documento; alternativas, julgamento, misto | Funcional | `exam_layout_profile.dart` |
| Sugestão de metadados | Título/ano conservadores a partir do texto e nome do arquivo | Parcial | `exam_metadata_suggester.dart` |
| Parser de questões | Marcadores explícitos, sequência, alternativas, múltipla escolha, certo/errado, asserção, discursiva e desconhecido | Parcial | `question_parser.dart` |
| Gabarito | Lê gabarito impresso e aplica somente onde há vínculo confiável; não sobrescreve correção manual | Funcional | `answer_key_parser.dart:71-278` |
| Quality gate | `good`/`review`/`retry`; duplicatas, numeração, estrutura incompleta, páginas ilegíveis e contagem esperada | Funcional | `import_quality_gate.dart:6, 191-194` |
| Diagnóstico | Eventos estruturais locais com versão `pacer-v4` e fingerprint SHA-256; não devem ser transmitidos | Funcional (local) | `import_diagnostic_event.dart:44-56` |
| Revisão humana | Lista de questões, confiança, aviso, editor, página original/preview | Parcial | `publish_page.dart:2041-2146` |
| Publicação | Exige alternativas e gabarito em todas as questões | Divergente do produto | `publish_page.dart:1333-1343` |
| Fila de feedback | Contrato JSON especificado, sem fila, envio ou retorno | Ausente | `docs` e produto; código não encontrado |
| Validação em aparelho | OCR nativo, câmera e performance não medidos | Não verificável | sem execução Android/iOS |

## O que funciona de fato

1. **Preservação de página e coordenadas.** A extração mantém texto nativo,
   texto final, origem, rota, motor, confiança de OCR, regiões e avisos por
   página. O parser registra `sourcePage`, `sourcePages` e posição de linha.
2. **Duas colunas e ordem de leitura.** O teste VUNESP confirma 80 questões na
   ordem 1–80, páginas corretas e continuação entre páginas (por exemplo, a
   questão 79 em duas páginas). O teste ENEM, quando o PDF está presente,
   confirma 90 questões e rejeita marcas d'água, códigos e datas no texto
   revisável.
3. **Seleção seletiva de OCR.** Páginas com camada nativa suficiente não passam
   por OCR; páginas-imagem usam PaddleOCR e páginas com texto curto usam ML Kit,
   com fallback quando o outro motor está instalado.
4. **Remoção de mobília sem apagar conteúdo legítimo.** O filtro exige
   repetição/posição de cabeçalho ou rodapé, trata marcas d'água repetidas e
   códigos, e preserva linhas internas.
5. **Gabarito conservador.** O gabarito impresso só é aplicado quando o parser
   encontra um bloco confiável; correções manuais prevalecem. O teste ENEM
   confirma 1-B e 2-D no bloco de gabarito.
6. **Quality gate com três estados.** Sem página, sem questão ou todas as
   páginas ilegíveis → `retry`; avisos/duplicatas/numeração/estrutura → `review`;
   sem avisos → `good`. O gate não apaga questões: marca para revisão.
7. **Revisão com página original.** A tela de publicação permite comparar a
   questão com a página, editar enunciado/alternativas, marcar a correta e
   iniciar uma tentativa privada mesmo sem revisar tudo.
8. **Limites de recurso.** PDF de 25 MB, 500 páginas, JSON de 4 MB e previews
   JPEG limitados a 1.200 px. Isso reduz abuso acidental, mas não é uma
   fronteira de segurança do servidor.

## O que está parcial

### Confiança não é probabilidade

Os scores do parser são heurísticas fixas (`question_parser.dart:861, 906, 971,
994, 1005, 1016`), não probabilidades calibradas. Os limiares `.99` e `.80`
(`question_parser.dart:203` e arredores) mudam o estado de revisão, mas não
provam acerto. `fieldConfidence` existe no modelo, é serializado
(`question_parser.dart:26-63`) e **é atribuído pelo parser** em todas as seis
construções de `ImportedQuestion` (MC, visual options, trueFalse, assertion,
openEnded, unknown), com `statement` e `options`. Só não é testado contra ground
truth.

A interface atual já respeita a decisão de produto: a revisão usa estados
estruturais (**fazível**, **corrigível**, **não fazível**) com
`QuestionFeasibility.feasibilityReason` (`publish_page.dart:2259-2268`), e não
exibe “confiança ≥ 99%” nem “confiança X%”. Os únicos `%` restantes em
`publish_page.dart` são de progresso/timer/resultado, não de confiança de
questão. A nota “Confiança não é probabilidade” ainda vale porque os scores são
heurísticas fixas, não calibradas.

### Conteúdo visual e fórmulas

Há associação de material visual à questão e à página, com IDs e previews. Isso
não significa que o conteúdo dentro da imagem foi extraído. O teste VUNESP
confirma quatro questões visuais (53, 54, 79, 80) com alternativas vazias e
aviso de “conteúdo visual não foi extraído”. Não há reconhecimento matemático
dedicado nem reconstrução de fórmula. A regra de produto correta é: imagem ou
fórmula necessária sem associação verificável → revisão humana ou questão não
fazível; nunca publicar silenciosamente.

### Publicação bloqueia o que o produto quer aceitar

Resolvido em 2026-11-11: `ExamPublicationService.publish()` chama
`questionsError(questions, allowOpenEnded: true)`
(`exam_publication_service.dart:50-56`), e o editor chama
`questionsError` com `allowOpenEnded: true` (`publish_page.dart:1461`).
Assim discursivas publicam sem `correctIndex`, e provas objetivas continuam
exigindo gabarito (`publish_page.dart:1317-1344` mantém o gabarito para
objetivas). O texto abaixo é mantido como registro histórico da divergência
anterior, não como estado atual.

> Histórico (antes de 2026-11-11): `_canPublish` exigia, para **todas** as
> questões, `options.length >= 2`, alternativas não vazias, revisão concluída e
> `correctIndex != null` (`publish_page.dart:1333-1343`). `_playableQuestions`
> também exigia duas alternativas (`publish_page.dart:1346-1356`). Consequências:
> provas discursivas não podiam ser publicadas nem iniciadas. Bloquear prova
> objetiva sem gabarito confirmado está correto e deve permanecer; o problema era
> aplicar a mesma exigência a discursivas, que não têm correção objetiva.

### Entrada por imagem/câmera

Não há `camera`, `image_picker` ou galeria no fluxo. O `AGENTS.md` §10 prevê
PDF, imagens, câmera, JSON e criação manual. Hoje existem PDF, JSON e manual.
Isso é uma lacuna de produto, não um detalhe de UI.

### Feedback e retreinamento

O contrato JSON v1 está especificado, mas não há fila local, exportação,
consentimento em tela, endpoint, tabela, bucket, retorno por recibo ou rotina de
regressão. `ImportDiagnosticEvent` é apenas local e não deve ser transmitido
(`import_diagnostic_event.dart:44-46`). Sem essa estrutura, o ciclo de
aprendizado do scanner não existe fora de fixtures manuais.

### OCR nativo e portabilidade

O benchmark de 46 PDFs roda no Linux e cobre texto nativo; não mede OCR nativo,
fidelidade visual nem performance de aparelho. O caminho Web não tem OCR, o que
é declarado honestamente, mas limita a promessa de importação no navegador. O
limiar de 20 caracteres do roteador e o corte de 25% de páginas com texto em
`looksScanned` são heurísticas não validadas em corpus real.

## O que está ausente

- Câmera, galeria e captura de múltiplas imagens.
- Fila/exportação de feedback e painel do dono.
- Classificação estrutural de “não fazível” na interface (o modelo existe,
  mas o editor ainda não expõe o selo para todas as telas).
- Reconhecimento/validação de fórmulas e de alternativas dentro de imagens.
- Teste em Android/iOS real e medição de OCR nativo.
- Ground truth anotado com licença para medir precisão/recall.
- Retorno anônimo por recibo no mesmo aparelho.

Publicação de discursivas já está implementada (`allowOpenEnded: true`) e saiu
desta lista.

## Divergências documentação × código

| Afirmação | Realidade no SHA |
|---|---|
| “Fluxo ideal inclui câmera e imagens” | Não há câmera/galeria |
| “Feedback do dono e retorno ao aparelho” | Só existe o contrato JSON; nada implementado |
| `docs/DIAGNOSTICO_ATUAL.md` diz que o PDF VUNESP não atinge 80 questões | O teste atual exige 80 e passa; o documento está desatualizado |
| “Confiança ≥ 99%” sugere probabilidade | São scores heurísticos, sem calibração |

Notas da tabela anteriores já estão resolvidas e foram removidas:

- “Não exibir porcentagem de confiança” → a UI usa estados estruturais
  (`publish_page.dart:2259-2268`); não exibe `%` de confiança.
- “Discursivas são representáveis e publicáveis sem correção automática” →
  `ExamPublicationService.publish()` chama `questionsError` com
  `allowOpenEnded: true` (`exam_publication_service.dart:50-56`); discursivas
  publicam sem `correctIndex`.
- `fieldConfidence` por campo → o parser preenche `statement` e `options` em
  todas as construções de `ImportedQuestion`.

## Evidência de testes

Comando executado em 2026-11-04:

```bash
flutter test test/answer_key_parser_test.dart test/bancas_import_test.dart \
  test/imported_document_test.dart test/import_quality_gate_test.dart \
  test/local_corpus_benchmark_test.dart test/page_furniture_filter_test.dart \
  test/pdf_text_extractor_test.dart test/question_parser_test.dart \
  test/synthetic_pdf_import_test.dart test/vunesp_2024_import_test.dart \
  test/enem_2025_import_test.dart
```

Resultado: **105 aprovados, 1 ignorado**. O ignorado é o teste do caderno ENEM
2025 (PDF não versionado). O teste de gabarito do ENEM executou.

- **VUNESP 2024:** 32 páginas, 80 questões, ordem 1–80, quatro questões visuais
  com alternativas vazias, previews de 19/20/28/29/32, quality gate `review`. O
  teste trava o SHA do parser; mudanças exigem atualizar o snapshot
  intencionalmente.
- **Sintético:** 8 páginas, 80 questões em duas colunas, sem questões para
  revisão.
- **ENEM 2025:** quando o PDF está presente, exige 90 questões, 32 páginas, ≥85
  questões com cinco alternativas e ≤12 para revisão.
- **Bancas:** `bancas_import_test.dart` cobre formatos de texto; não valida PDFs
  reais de cada banca.
- **Corpus:** o benchmark local de 46 PDFs conta 2.419 candidatos, mas não tem
  ground truth anotado; não é precisão/recall.

O PDF VUNESP está versionado em `test/fixtures/` com
`licenseStatus: not-verified` e `allowedForProductContent: false`. Isso serve
para QA local, mas é um risco de redistribuição que precisa de decisão do
responsável.

## Riscos

1. **Publicar questão errada com aparência de correta.** Fórmula ou imagem
   ausente, alternativas vazias e score alto podem passar se a revisão não for
   obrigatória para o caso certo.
2. **Métrica enganosa.** “Confiança ≥ 99%” pode ser lida como acurácia.
3. **Bloqueio de formato válido.** Discursivas e provas sem gabarito não entram
   no produto, contrariando o requisito.
4. **Custo de suporte.** Sem fila de feedback, cada falha depende de relato
   manual e não gera regressão.
5. **Regressão silenciosa.** O parser é grande e heurístico; sem corpus
   autorizado e testes de layout, mudanças podem melhorar uma banca e quebrar
   outra.
6. **Licença.** O fixture VUNESP versionado não tem licença verificada; não
   transformar em conteúdo de produto.
7. **Web.** Importar prova no navegador não terá OCR; a UI precisa deixar isso
   claro antes de o usuário escolher o arquivo.

## Critérios para considerar o scanner fechado

O scanner só pode ser declarado completo quando **todos** os itens abaixo forem
verificáveis. A especificação pode ser considerada fechada antes disso; a
implementação, não.

### P1.0 — PDF confiável e revisão honesta

- [x] UI não mostra porcentagem; mostra **fazível**, **corrigível** ou **não
      fazível** com motivo estrutural (`publish_page.dart:2259-2268`).
- [x] Publicação aceita discursivas sem inventar correção; prova objetiva sem
      gabarito continua salvável/resolvível como rascunho, sem publicação
      (`exam_publication_service.dart:50-56` com `allowOpenEnded: true`).
- [ ] Nenhuma questão de ground truth é perdida silencosamente: toda questão
      esperada é detectada ou aparece explicitamente na revisão.
- [ ] Nenhuma instrução, sumário ou número de página vira questão no corpus
      autorizado.
- [ ] Ordem, página de origem, alternativas e vínculo com gabarito conferem no
      corpus autorizado.
- [ ] Imagem/fórmula necessária sem associação vai para revisão; não é publicada.
- [ ] Quality gate `retry`/`review`/`good` tem testes de regressão para os casos
      conhecidos.

### P1.1 — Imagens e câmera

- [ ] Câmera e galeria no mobile, com múltiplas páginas e recorte.
- [ ] Ordenação de imagens, correção de perspectiva e associação à página.
- [ ] OCR de imagem com o mesmo pipeline de layout/parser.
- [ ] Teste em aparelho pequeno e médio, light/dark e fonte ampliada.
- [ ] Limites de tamanho, quantidade e tempo declarados na UI.

### P1.2 — Feedback e aprendizado

- [ ] Fila local + consentimento + exportação JSON/anexos.
- [ ] Painel do dono com triagem, reprodução e estado.
- [ ] Regressão criada a partir do caso minimizado, sem conteúdo não licenciado.
- [ ] Retorno por recibo anônimo no mesmo aparelho.
- [ ] Retenção de 90 dias e exclusão verificáveis.

### P1.3 — Campo

- [ ] OCR nativo validado em pelo menos um Android real; iOS se suportado.
- [ ] Corpus autorizado com texto, duas colunas, imagem, fórmula e discursiva.
- [ ] Precisão/recall medidos e registrados por banca/layout, não só contagem.
- [ ] Web declara ausência de OCR antes da seleção do arquivo.

## Decisões fechadas nesta auditoria

1. **Escopo por fases.** P1.0 = PDF/JSON/manual; P1.1 = câmera/imagens;
   P1.2 = feedback; P1.3 = validação de campo. Não exibir caminho antes de ele
   funcionar.
2. **Confiança.** Nenhuma porcentagem ao aluno. Estados **fazível**,
   **corrigível** e **não fazível** com motivo estrutural; score não exclui
   questão sozinho.
3. **Publicação.** Discursivas são representáveis e publicáveis sem correção
   automática. Objetiva sem gabarito pode ser rascunho/resolvida, mas não
   publicada. Chave confirmada continua privada.
4. **Conteúdo visual.** Associação de imagem não é compreensão. Fórmula/imagem
   necessária sem associação verificável vai para revisão ou vira não fazível;
   nunca é publicada silenciosamente.
5. **Feedback.** Fila local, consentimento separado para texto e imagem, JSON
   anônimo, painel do dono, triagem, regressão versionada, retorno por recibo e
   retenção de 90 dias após resolução. Sem treinamento automático.
6. **Aceite.** O scanner só é completo quando os quatro blocos P1.0–P1.3 forem
   verificáveis; a especificação pode ser fechada antes.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Acerta VUNESP/ENEM estruturalmente, mas não compreende fórmulas/imagens e publica com bloqueios indevidos. |
| Testes | 3 | 105 testes e duas provas reais; falta ground truth, dispositivo e regressão de campo. |
| Acoplamento | 2 | `publish_page.dart` (2.379 linhas) orquestra importação, revisão e publicação; parser tem 1.480 linhas. |
| Clareza | 3 | Módulos nomeados e separados; a semântica de “confiança” engana e `fieldConfidence` é morto. |
| Segurança | 3 | Limites de tamanho/páginas e diagnóstico local; feedback remoto ainda não existe e exigirá RLS/Storage. |
| Robustez | 3 | Fallback de OCR, remoção de mobília e quality gate; limiares fixos e sem validação em aparelho. |
| Aderência | 3 | PDF/JSON/manual e revisão existem; câmera, feedback e discursivas faltam. |
| Portabilidade | 4 | Web declara ausência de OCR; mobile é o alvo, mas OCR nativo não foi medido. |

Classificação resultante: **EVOLUIR** — base aproveitável, capacidade de produto
e evidência de campo pendentes. Não é **MANTER** porque há critérios abaixo de 4;
não é **REFATORAR** porque o comportamento principal é preservável e não há
evidência de que a estrutura seja o bloqueio primário.

## Recomendação

1. **Fechar a especificação agora** (esta nota + [[../../01 - Produto/Importação e OCR]]),
   sem declarar implementação completa.
2. **Corrigir primeiro a honestidade da UI e o bloqueio de formatos** em lote
   de código autorizado: remover porcentagem, introduzir estados estruturais,
   permitir discursivas e manter a regra de não publicar objetiva sem chave.
3. **Depois, câmera/galeria**, porque é a maior lacuna de entrada e depende de
   permissões, recorte e teste em aparelho.
4. **Por último, feedback remoto**, porque depende de schema/RLS/Storage e de
   política de retenção; o contrato JSON já está pronto para implementação.
5. **Não calibrar thresholds com o corpus atual.** Obter ground truth
   autorizado antes de transformar heurística em promessa de precisão.

## Dependências

- Decisão de licença do fixture VUNESP e do produto.
- Ground truth autorizado por banca/layout.
- Aparelho Android real (e iOS, se houver suporte).
- Auditoria de schema, RLS e Storage do Supabase antes do feedback remoto.
- Aprovação do responsável para alterar código e para publicar/release.

## Links

- [[../../01 - Produto/Importação e OCR|Importação e OCR — produto]]
- [[../../01 - Produto/Fluxo de Entrada e Criação|Fluxo de Entrada e Criação]]
- [[../../05 - Qualidade/Validação Atual|Validação Atual]]
- [[../../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[Mapa das Áreas|Mapa das Áreas]]
- [[../../09 - Auditoria/Documentação e Divergências|Documentação e Divergências]]
- [AGENTS.md — importação e digitalização](../../../AGENTS.md)
