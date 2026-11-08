---
tipo: area
area: importação e OCR
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 2, clareza: 3, seguranca: 3, robustez: 3, aderencia: 3, portabilidade: 4}
fonte_codigo: [lib/core/import/, lib/features/publish/publish_page.dart, test/, qa/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Importação e OCR

## Estado verificado em 2026-11-04

A auditoria profunda da área 9 está em
[[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Importação, OCR, parser e quality gate]].
Resumo:

| Capacidade | Estado | Evidência |
|---|---|---|
| PDF com texto nativo, colunas e páginas preservadas | Funcional | `pdf_text_extractor.dart`, teste VUNESP 80/32 |
| OCR seletivo (PaddleOCR/ML Kit) | Parcial; não validado em aparelho | `ocr_router.dart:30` |
| Remoção de cabeçalho, rodapé, marca d'água e código | Funcional | `page_furniture_filter.dart` |
| Parser de múltipla escolha, certo/errado, asserção, discursiva e desconhecido | Parcial | `question_parser.dart` |
| Gabarito impresso com preservação da correção manual | Funcional | `answer_key_parser.dart` |
| Quality gate `good`/`review`/`retry` | Funcional | `import_quality_gate.dart:6` |
| Revisão humana com página original e preview | Parcial; UI mostra porcentagem | `publish_page.dart:2041-2146` |
| Publicação de discursivas | Ausente/divergente; exige alternativas e gabarito de todas as questões | `publish_page.dart:1333-1343` |
| Câmera, galeria e imagens | Ausente; **escopo adiado por decisão** (ADR-0006, 2026-11-07) — ver [[Entrada por imagem e câmera]] | busca sem `camera`/`image_picker`; `ocr_service_native.dart:27-28` só recebe `PdfPage` |
| Fila de feedback, envio e retorno | Ausente; só o contrato JSON existe | `import_diagnostic_event.dart:44-46` |

A especificação abaixo está **fechada**; a implementação continua **parcial**.
Não declarar o scanner completo sem cumprir os critérios de aceite da seção
final.

## Fluxo pretendido

Arquivo → extração → reconhecimento de layout → OCR apenas quando necessário →
parser → vínculo de figuras → revisão humana → gabarito explicitamente
confirmado → rascunho → publicação confirmada.

## Escopo fechado por fase

A entrada não precisa nascer com todas as mídias. O scanner é entregue em
fases, sem fingir capacidade que não existe:

1. **P1.0 — PDF, JSON e criação manual.** É o caminho implementado hoje:
   texto nativo, OCR seletivo no mobile, layout, parser, gabarito, quality gate,
   revisão e tentativa privada. A publicação ainda precisa aceitar discursivas; o
   rascunho objetivo sem gabarito já pode ser salvo e resolvido, mas não
   publicado.
2. **P1.1 — Imagens e câmera.** Captura pelo aparelho, múltiplas páginas,
   recorte/perspectiva, ordenação e o mesmo pipeline. Depende de teste em
   aparelho real.
3. **P1.2 — Feedback e aprendizado.** Fila local, consentimento, exportação
   anônima, painel do dono e regressão. Depende de schema/RLS/Storage.
4. **P1.3 — Validação de campo.** Ground truth autorizado, OCR nativo medido e
   precisão/recall por banca/layout.

**Decisão:** nenhuma fase pode publicar questão com fórmula/imagem necessária
ausente ou com estrutura incompleta. “Não fazível” é um estado de revisão, não
uma exclusão silenciosa. A prova pode começar com as questões válidas e deve
mostrar separadamente quantas ficaram fora.

## Guardrails

- Manter página e coordenadas quando disponíveis.
- Detectar colunas, cabeçalhos, continuação entre páginas, alternativas e
  conteúdo visual; mostrar incerteza de forma explicativa, sem porcentagem.
- Não inferir gabaritos.
- Validar com ground truth autorizado; não usar benchmark sem licença como
  conteúdo do app.

## O que o código atual faz

- `PdfTextExtractor` extrai texto por página e usa coordenadas/layout para
  ordenar blocos. O `OcrRouter` considera suficiente uma camada nativa com pelo
  menos 20 caracteres; sem texto usa PaddleOCR primeiro e, com texto curto, ML
  Kit primeiro, com fallback para o outro motor quando disponível.
- O resultado por página conserva texto nativo e final, origem, rota, motor,
  confiança retornada pelo OCR, regiões/coordenadas e avisos. O stub de OCR não
  oferece OCR no Web.
- `QuestionParser` detecta candidatos por marcadores explícitos, sequência e
  evidências de alternativas; preserva página/posição, alternativas, formato,
  avisos, versões alternativas e IDs de material visual. Os formatos incluem
  múltipla escolha, certo/errado, asserção, discursiva e desconhecido.
- Os scores do parser são valores escolhidos por heurísticas fixas no código
  (por exemplo, `.94`, `.78`, `.65`); não são probabilidades treinadas nem
  calibradas. Os limites atuais de `.99` e `.80` mudam estados de revisão, mas
  não provam uma taxa de acerto. `fieldConfidence` existe no modelo, mas o
  parser não atribui valores por campo; só faz round-trip do JSON.
- `ImportQualityGate` verifica quantidade esperada quando informada,
  numeração, duplicatas, estrutura mínima e páginas sem texto. Seu status é
  `retry` quando não há página/questão utilizável ou todas as páginas são
  ilegíveis; avisos e inconsistências levam a `review`.
- O quality gate não verifica semanticamente se uma fórmula ou imagem citada é
  essencial nem se o conteúdo visual foi compreendido. Há associação de
  materiais visuais às páginas/questões, mas isso não significa que fórmulas ou
  alternativas dentro da imagem foram extraídas.
- No caminho inspecionado não há um extrator matemático dedicado que reconheça
  ou valide fórmulas como estruturas; texto OCR legível não prova que a fórmula
  foi reconstruída corretamente.
- `ImportDiagnosticEvent` gera apenas códigos estruturais, versão `pacer-v3` e
  uma impressão digital SHA-256 de padrões de linha, sem texto da prova. O
  próprio código declara que esses diagnósticos não devem ser transmitidos; não
  há fluxo de envio de feedback no scanner auditado.
- `ImportedDocument` local pode guardar texto por página, regiões,
  `SupportingMaterial` e preview JPEG serializado em Base64. O pacote de
  feedback exportado não deve copiar o documento inteiro nem carregar a imagem
  dentro do JSON: deve selecionar só as páginas autorizadas e anexá-las como
  arquivos separados.

## Evidência e limites dos testes

- Em 2026-11-04, os 11 arquivos de teste do scanner passaram com **105 testes
  aprovados e 1 ignorado**. O ignorado é o caderno ENEM 2025, cujo PDF não está
  versionado nesta máquina; o teste de gabarito do ENEM executou.
- O fixture sintético testa 80 questões em duas colunas, ordem, alternativas,
  página de origem e quality gate. É evidência de funcionamento estrutural para
  esse layout fabricado, não uma medida de precisão em provas reais.
- O teste VUNESP 2024 encontra 80 questões e mantém quatro questões visuais com
  alternativas vazias e aviso, além de páginas/preview associados. O fixture
  está versionado em `test/fixtures/` com `licenseStatus: not-verified` e
  `allowedForProductContent: false`; serve para QA local, mas sua licença não
  autoriza conteúdo de produto e o arquivo no repositório é um risco de
  redistribuição a decidir.
- O teste ENEM 2025, quando o PDF está presente, exige 90 questões em 32
  páginas, pelo menos 85 com cinco alternativas e no máximo 12 para revisão.
  Ele cobre duas colunas, marcador partido (“Quest ão”), marca d'água e
  continuação de comando entre colunas.
- O teste VUNESP trava o SHA-256 do próprio `question_parser.dart`; qualquer
  mudança no parser exige atualizar o snapshot de forma intencional e revisar o
  resultado. Isso protege contra regressão silenciosa, mas não substitui ground
  truth.
- `bancas_import_test.dart` cobre formatos de texto de várias bancas; isso não
  valida PDFs reais dessas bancas. O inventário não tinha fixture EPCAR/AFA.
- O benchmark disponível conta candidatos (2.419 em 46 PDFs), mas não possui
  gabarito estrutural anotado suficiente para calcular precisão/recall. O runner
  também não mede OCR nativo, compreensão de fórmulas ou fidelidade visual.
- Portanto, não mostrar ao aluno porcentagens de confiança nem descartar questão
  somente pelos atuais `.99`/`.80`. Use checks explícitos para questão,
  enunciado e alternativas exigidas pelo formato; em imagem/fórmula incerta,
  peça revisão humana. A ausência inequívoca de elemento exigido a classifica
  como não fazível, até correção manual.

## Contrato JSON de feedback escolhido

Exportar um relatório por problema em JSON v1 com chaves `snake_case` (padrão
já usado em `ImportDiagnosticEvent.toJson`). Identificadores de upload são
aleatórios; não reutilizar `ImportedDocument.id`, que é derivado do texto e
identificável por conteúdo. Não incluir gabarito, nome do arquivo, PDF completo,
respostas da tentativa, identidade ou ID de conta. Incluir confiança somente
com a origem explícita; o score do parser deve ser marcado como heurístico e
nunca como porcentagem de probabilidade.

Exemplo de formato (valores fictícios):

```json
{
  "schema_version": 1,
  "feedback_id": "550e8400-e29b-41d4-a716-446655440000",
  "created_at": "2026-11-04T12:00:00Z",
  "app_version": "0.7.5+15",
  "parser_version": "pacer-v3",
  "failure": {
    "type": "required_image_missing",
    "question_number": 53,
    "source_pages": [19],
    "source_position": 120,
    "details": null
  },
  "pages": [
    {
      "page_number": 19,
      "extracted_text": "Texto extraído da página...",
      "ocr": {
        "route": "paddle_ocr",
        "engine": "paddle_ocr",
        "engine_confidence": null
      },
      "ocr_regions": [
        {
          "text": "Trecho reconhecido...",
          "confidence": null,
          "points": [[12, 24], [300, 24], [300, 60], [12, 60]]
        }
      ],
      "attachment_id": "page-19"
    }
  ],
  "question_extracted": {
    "format": "multiple_choice",
    "statement": "Enunciado reconhecido...",
    "options": ["", "", "", "", ""]
  },
  "manual_correction": {
    "attempted": false,
    "question": null
  },
  "parser_score": {
    "value": 0.65,
    "kind": "heuristic_not_probability"
  },
  "attachments": [
    {
      "id": "page-19",
      "kind": "full_source_page",
      "page_number": 19,
      "media_type": "image/jpeg",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
      "file": "attachments/page-19.jpg"
    }
  ],
  "consent": {
    "text_and_question": true,
    "text_confirmed_at": "2026-11-04T12:00:00Z",
    "page_image": true,
    "page_image_confirmed_at": "2026-11-04T12:00:05Z"
  }
}
```

`failure.type` usa códigos estáveis e extensíveis: `question_not_detected`,
`statement_unreadable`, `objective_options_missing`,
`required_formula_missing`, `required_image_missing`,
`question_structure_incomplete`, `duplicate_question`,
`question_numbering_issue`, `unreadable_page` e `other`. O exportador transforma
os códigos atuais do diagnostic event nesses códigos de produto; não altera nem
transmite automaticamente o diagnóstico estrutural atual. Imagem da página
inteira é anexo JPEG separado, enviada só com consentimento explícito. Se não
houver consentimento para imagem, exportar texto/metadados com confirmação
separada. `pages` permite uma questão que continue por várias páginas;
`ocr_regions` é opcional e só deve ser incluído quando disponível. Seus pontos
são coordenadas na imagem de OCR do motor indicado, não coordenadas
normalizadas comparáveis entre motores. O status para retorno ao aparelho e
qualquer token secreto de recibo são armazenados separadamente, nunca no JSON
anônimo exportado.

`source_position` segue a posição de linha zero-based que o parser já registra.
`question_extracted` e `manual_correction.question` contêm enunciado, formato e
alternativas, mas não gabarito; o gabarito não é necessário para corrigir OCR e
deve continuar privado.

## Depois que uma correção fica disponível

Manter no aparelho de origem um recibo aleatório associado ao feedback, sem
identidade de conta. Quando a correção for liberada, mostrar aviso nesse
aparelho para tentar digitalizar novamente. Se resolver, marcar feedback como
resolvido; se persistir, manter o caso aberto para investigação. Perder os
dados locais do aparelho pode impedir o retorno anônimo, o que deve ser
explicado antes do envio.

## Rotina de retreinamento e regressão

O feedback não treina um modelo automaticamente. Ele alimenta uma fila de
engenharia com reprodução e teste de regressão. A rotina fechada é:

1. **Captura local.** A pessoa marca **Inválida**; o app guarda tipo de falha,
   questão, texto, páginas, correção manual e diagnóstico estrutural. Nada sai
   do aparelho sem confirmação.
2. **Consentimento e exportação.** A pessoa autoriza texto/metadados e,
   separadamente, a imagem da página. O JSON anônimo e os anexos são gerados
   com identificador aleatório.
3. **Triagem.** O painel do dono recebe o caso e o classifica como `new`,
   `triaged`, `duplicate`, `reproduced`, `fixed`, `verified` ou `wont_fix`.
   Duplicatas usam o fingerprint estrutural, não o texto literal.
4. **Reprodução.** A equipe tenta reproduzir com uma fixture minimizada. Não
   copiar a prova inteira para o repositório; guardar apenas o recorte necessário
   e autorizado.
5. **Correção e teste.** A correção entra com teste de regressão que falha antes
   e passa depois. O parser/OCR ganha versão (`pacer-v3` → próxima) e o caso é
   ligado à versão.
6. **Liberação e retorno.** O aparelho de origem é avisado para tentar de novo.
   Se funcionar, `verified`; se não, volta para investigação. A retenção é de
   até 90 dias após a resolução, com exclusão verificável.
7. **Métricas.** Medir tempo de triagem, taxa de reprodução, recorrência,
   falsos “não fazível” e cobertura por banca/layout. Não usar “curtidas” ou
   “Isso me ajudou” como rótulo de qualidade do parser.

**Política de dados:** por padrão, o feedback serve para regressão e melhoria
de regras, não para treinar modelo. Uso para treinamento exige consentimento
específico, base legal e licença compatível. Conteúdo de terceiros sem licença
não entra em corpus de produto. O diagnóstico estrutural atual
(`ImportDiagnosticEvent`) é local e não deve ser transmitido; o exportador de
produto é quem traduz os códigos e aplica o consentimento.

## Critérios de aceite do scanner

O scanner só é considerado completo quando os quatro blocos abaixo forem
verificáveis. A especificação pode estar fechada antes da implementação.

### P1.0 — PDF e revisão honesta

- Nenhuma questão esperada é perdida silenciosamente: ou é detectada, ou aparece
  na revisão com motivo.
- Instruções, sumário e número de página não viram questão no corpus autorizado.
- Ordem, página, alternativas e gabarito conferem no corpus autorizado.
- A UI não exibe porcentagem; exibe **fazível**, **corrigível** ou **não
  fazível** com justificativa estrutural.
- Fórmula/imagem necessária sem associação vai para revisão e não é publicada.
- Publicação aceita discursivas sem inventar correção; prova objetiva sem
  gabarito continua podendo ser salva/resolvida como rascunho, sem publicação.
- `good`/`review`/`retry` têm testes de regressão.

### P1.1 — Câmera e imagens

- Captura pela câmera e galeria, múltiplas páginas, recorte e perspectiva.
- Ordenação, associação à página e o mesmo pipeline de layout/parser.
- Teste em aparelho pequeno e médio, light/dark e fonte ampliada.
- Limites de tamanho, quantidade e tempo visíveis antes da captura.

### P1.2 — Feedback e aprendizado

- Fila local, consentimento, JSON/anexos, painel do dono e triagem.
- Caso minimizado vira teste de regressão; parser/OCR é versionado.
- Retorno por recibo anônimo no mesmo aparelho.
- Retenção de 90 dias e exclusão verificáveis.

### P1.3 — Campo

- OCR nativo validado em Android real; iOS se houver suporte.
- Corpus autorizado com texto, duas colunas, imagem, fórmula e discursiva.
- Precisão/recall medidos por banca/layout, não apenas contagem de candidatos.
- Web declara a ausência de OCR antes da seleção do arquivo.

## Decisões de produto derivadas da auditoria

- Não exibir score de confiança numérico ao aluno. Exibir estados explicativos
  (**fazível**, **corrigível**, **não fazível**) baseados em evidência estrutural
  e revisão; score sozinho não exclui questão. Imagem/fórmula possivelmente
  necessária, mas sem associação verificável, vai para revisão humana.
- Não usar curtidas nem **“Isso me ajudou”** como rótulos de moderação. Medir
  falsos bloqueios pelas respostas rejeitadas que a revisão humana aprova;
  medir violações que passaram pelo classificador pelas respostas publicadas
  que uma revisão humana posterior confirma como violação. Reações de utilidade
  são uma métrica de qualidade separada.
- Cada tentativa de prova de revisão guarda um snapshot de suas questões. A
  lista pendente evolui entre tentativas; acertos saem dos erros pendentes e
  ficam no histórico, podendo ser incluídos à parte em **Revisar de novo**.
- Explicações não exibem confiança numérica na primeira versão. A origem fica
  explícita: oficial com fonte, escrita por uma pessoa ou gerada por IA. Se
  houver mistura de conteúdo humano e gerado, separar e rotular cada trecho.
- No Inspirion 15 e no C85, usar o mesmo conjunto representativo de questões e
  registrar modelo/configuração exatos, versão do modelo/runtime, tempo da
  primeira resposta e duração total, memória observada, falhas e avaliação
  humana de correção/clareza. O conjunto deve cobrir texto, matemática/fórmula,
  questão com imagem e enunciado longo. Não fixar um limite de desempenho antes
  de medir os aparelhos concretos; explicação é experimental, opcional e não
  pode bloquear a prova.

## Pendências de implementação

Nenhuma alteração de código foi feita nesta rodada. Em ordem de prioridade,
quando houver autorização:

1. Remover a porcentagem de confiança da UI e introduzir estados estruturais
   (`fazível`, `corrigível`, `não fazível`) com motivo.
2. Ajustar a publicação para aceitar discursivas e manter o início de prova
   objetiva sem gabarito; não permitir publicar objetiva sem chave.
3. Implementar câmera/galeria e testar em Android real.
4. Implementar a fila de feedback e o painel do dono depois de auditar
   schema/RLS/Storage.
5. Obter ground truth autorizado e medir precisão/recall por banca/layout.

## Fonte

- [AGENTS.md — importação e digitalização](../../AGENTS.md)
- [[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|Auditoria profunda da área 9]]
- [[Fluxo de Entrada e Criação|Fluxo de Entrada e Criação]]
