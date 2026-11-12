---
tipo: area
area: domínio, modelos e regras
status: PARCIAL
classificacao: REFATORAR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 4, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 4}
fonte_codigo: [lib/domain/models/exam.dart, lib/core/review/wrong_question_practice_service.dart, lib/core/import/imported_document.dart, test/exam_result_test.dart]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-11
---

# Domínio, modelos e regras

## Resumo

O domínio é pequeno e legível: `Exam`, `Question`, `QuestionMedia`, `ExamResult`
e enums de procedência, mais o serviço de seleção de questões erradas. As regras
de pontuação objetiva funcionam e estão testadas. O modelo, porém, não representa
questão discursiva, versão de prova, explicação, rubrica, banca/instituição nem
URL canônica de questão, e as respostas são vinculadas por **índice**, não por ID
estável. Isso é uma limitação estrutural para o produto descrito no `AGENTS.md`.
Classificação: **REFATORAR**.

## Escopo e método

- Leitura integral de `lib/domain/models/exam.dart` (236 linhas) e
  `lib/core/review/wrong_question_practice_service.dart` (245 linhas).
- Leitura de `lib/core/backend/attempt_submission.dart` e das partes de
  `lib/core/import/imported_document.dart` que definem o modelo paralelo de
  importação.
- Leitura dos testes `test/exam_result_test.dart`,
  `test/exam_provenance_test.dart`, `test/wrong_question_practice_service_test.dart`
  e `test/wrong_questions_retry_test.dart`.
- Inspeção do uso de `copyWith`, `toJson` e das chaves de resposta em
  `attempt_repository.dart` e `local_exam_store.dart`.
- Não foi executada migração de dados nem comparada versão de prova em
  produção; a análise é estática.

## O que faz de fato

| Elemento | Comportamento | Evidência |
|---|---|---|
| `Exam` | Prova com id, categoria, título, descrição, autor, duração, contagem de tentativas, ano, questões, procedência e URL | `exam.dart:3-54` |
| `ExamSourceType` | `official`, `community`, `unverified`; valor desconhecido vira `unverified` | `exam.dart:56-66` |
| `Question` | Tópico, enunciado, alternativas, índice correto nullable e mídia | `exam.dart:68-94` |
| `QuestionMedia` | ID, object key, MIME, SHA-256, alt text e bytes locais | `exam.dart:96-112` |
| `ExamResult` | Respostas por índice, marcadas, duração, fim, acertos, percentual, erros, brancos, por tópico e JSON | `exam.dart:114-236` |
| Prova dos erros | Gera prova local somente com questões respondidas incorretamente | `exam.dart:160-190` |
| Histórico de erros | Deduplica tentativas, prioriza recorrência e recência, distribui por tópico e limita 1–100 | `wrong_question_practice_service.dart:40-211` |
| Procedência segura | Só aceita URL `https` com host | `exam.dart:34-37` |

## O que funciona

1. **Pontuação objetiva explícita.** `correct` só conta resposta igual a um
   gabarito não nulo; `correctableCount` valida o índice contra o número de
   alternativas (`exam.dart:129-150`).
2. **Honestidade sobre questões sem gabarito.** O percentual usa apenas questões
   corrigíveis e o resultado mostra “—” quando não há nenhuma
   (`exam.dart:137-141`, `result_page.dart:231-244`).
3. **Branco não vira erro.** `wrongQuestionIndices` exige resposta selecionada;
   brancos são contados separadamente (`exam.dart:152-158, 192-195`).
4. **Prova dos erros determinística.** O ID combina timestamp e hash dos
   candidatos, e a seleção prioriza erros recorrentes e recentes
   (`wrong_question_practice_service.dart:115-150`).
5. **Deduplicação de tentativas.** A chave usa prova, data e respostas
   ordenadas, evitando contar a mesma tentativa duas vezes
   (`wrong_question_practice_service.dart:213-218`).
6. **Procedência não confiável é explícita.** Tipo desconhecido não vira
   “oficial” por acidente (`exam.dart:61-65`).

## O que está parcial

### Modelo não representa o produto

O `AGENTS.md` §§7, 9, 10 e 12 exige tipo de questão, discursivas com resposta
esperada/rubrica, explicação, procedência detalhada (banca, instituição, ano,
autor, data), URL canônica por questão, versão/revisão e vínculo com prova. O
modelo atual tem apenas:

- `Exam.category`, `author`, `year`, `sourceType` e `sourceUrl`;
- `Question.topic`, `statement`, `options`, `correctIndex` e `media`.

Não existe `QuestionType`, `explanation`, `expectedAnswer`, `rubric`,
`ExamVersion`, `QuestionVersion`, `canonicalUrl`, `board`, `institution` ou
`publishedAt`. O parser até detecta discursiva e emite aviso
(`question_parser.dart:1017`), mas o domínio não consegue carregar a resposta
esperada nem os critérios.

### Respostas por índice e ausência de versão

`ExamResult.answers` é `Map<int, int>` indexado pela posição da questão
(`exam.dart:124`). Se a ordem das questões mudar entre versões da mesma prova,
uma tentativa antiga passa a apontar para outra questão. O serviço de erros
tenta compensar usando `exam.id + question.id`, mas a resposta em si continua
posicional (`wrong_question_practice_service.dart:220-225`). Não há
`examVersionId` na tentativa nem no resultado.

### `copyWith` não limpa campos nulos

`Question.copyWith` usa `correctIndex ?? this.correctIndex`
(`exam.dart:85-93`); portanto, não é possível remover um gabarito já definido.
O mesmo vale para `Exam.copyWith(year:)` (`exam.dart:39-53`). Isso impede
operações de correção/despublicação sem construir o objeto inteiro à mão.

### Dois modelos de questão

A importação usa `ImportedQuestion` (`imported_document.dart`), com campos de
página, confiança, avisos e versões; a UI e o resultado usam `Question`. A
conversão entre eles é manual e dispersa. Isso duplica regras e permite que um
campo exista em um lado e não no outro. A área 9 já registrou que
`fieldConfidence` morre no caminho.

### Mídia dentro do domínio

`QuestionMedia` carrega `Uint8List? localBytes` (`exam.dart:96-112`). O domínio
passa a depender de bytes de apresentação, o que dificulta persistência,
comparação e uso em isolate. O ideal é o domínio guardar referência/hash e a
camada de mídia resolver os bytes.

### Regra de tópico

`byTopic` ignora tópico vazio e questão sem gabarito, mas conta branco como erro
no denominador (`exam.dart:197-213`). É uma decisão defensável, porém não
documentada; o resultado pode mostrar 0/1 para uma questão em branco como se
fosse erro.

## O que está ausente ou quebrado

- Tipo objetivo/discursivo e resposta esperada/rubrica.
- Explicação por questão e vínculo com discussão.
- Versão de prova e versão de questão.
- Banca, instituição e URL canônica da questão.
- `fromJson`/`toJson` do domínio `Exam`; a serialização vive em modelos de
  importação e stores.
- Igualdade (`==`/`hashCode`) e imutabilidade profunda das listas.
- Validação de índice de resposta na revisão (ver área 6).
- Teste de ordem trocada, versão diferente e questão com ID vazio.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Questão discursiva publicável sem correção automática” | Modelo não tem tipo nem resposta esperada; parser só avisa | `exam.dart:68-94`, `question_parser.dart:1017` |
| “Cada questão tem ID estável e URL canônica” | `Question.id` é string opcional e não há URL por questão | `exam.dart:70, 78` |
| “Versão/revisão da questão” | Não existe no modelo | `exam.dart:68-94` |
| “Explicação e rubrica na revisão” | Não existem campos | `exam.dart:68-94` |
| “Banca, instituição e ano” | Só `category`, `author` e `year` | `exam.dart:21-32` |
| “Tentativa vinculada à versão resolvida” | Respostas por índice, sem versão | `exam.dart:124` |

## Evidência de testes

- `exam_result_test.dart:5-64` cobre pontuação, JSON, erros, brancos e tópico.
- `exam_result_test.dart:66-99` cobre questão sem gabarito e prova vazia.
- `exam_result_test.dart:101-135` cobre denominador apenas corrigível.
- `wrong_question_practice_service_test.dart` cobre seleção, recorrência,
  filtros e limite; `wrong_questions_retry_test.dart` cobre o fluxo de UI.
- Não há teste para `copyWith` nulo, ordem de questões trocada, ID vazio,
  discursiva, rubrica ou serialização do domínio.

## Riscos

1. **Correção errada após mudança de ordem.** Uma tentativa antiga pode ser
   comparada com a questão errada.
2. **Impossibilidade de representar discursiva.** O produto não consegue
   publicar o formato que o `AGENTS.md` exige.
3. **Duplicação de modelo.** Correções na importação não chegam ao resultado e
   vice-versa.
4. **Gabarito irreversível.** `copyWith` não remove chave, dificultando corrigir
   um erro de revisão.
5. **Mídia pesada no domínio.** Bytes de imagem aumentam memória e dificultam
   testes e persistência.

## Plano de refatoração da área

### Lote 1 — Contrato de questão e versão

- Introduzir `QuestionType` (`objective`, `discursive`), `explanation`,
  `expectedAnswer`, `rubric`, `canonicalUrl` e `source` detalhado.
- Introduzir `ExamVersion`/`QuestionVersion` com ID estável e hash de conteúdo.
- Migrar `answers` para `Map<String, int>` por `questionId` ou manter um
  adaptador que resolva índice ↔ ID na versão da tentativa.
- Critério de aceite: prova antiga continua abrindo; tentativa guarda
  `examVersionId`; teste de ordem trocada não altera a correção.

### Lote 2 — Unificar modelos

- Definir um modelo de domínio único e adaptadores explícitos para
  `ImportedQuestion` e para o payload do Supabase.
- Remover `localBytes` do domínio; manter `objectKey`/`sha256` e resolver bytes
  na camada de mídia.
- Critério de aceite: um único teste de round-trip cobre importação → domínio →
  resultado; nenhum campo obrigatório se perde.

### Lote 3 — Regras verificáveis

- Documentar a regra de branco/no-key e cobrir com testes de propriedade.
- Corrigir `copyWith` para usar sentinelas e permitir limpar campos.
- Adicionar igualdade/hashCode e validação de índices.
- Critério de aceite: testes de `copyWith` nulo, branco, sem gabarito e
  discursiva passam; analyzer limpo.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Pontuação objetiva correta; modelo não cobre discursiva, versão e explicação. |
| Testes | 2 | Bons testes de pontuação, mas nenhum de versão, ordem, ID ou discursiva. |
| Acoplamento | 3 | Domínio não importa UI, mas carrega bytes e é usado diretamente por stores. |
| Clareza | 4 | Modelos curtos e legíveis. |
| Segurança | 3 | URL segura e sem segredo; JSON exporta gabarito. |
| Robustez | 2 | Índice posicional, `copyWith` sem limpar, sem validação de resposta. |
| Aderência | 2 | Faltam tipos, rubrica, versão, URL canônica e metadados de prova. |
| Portabilidade | 4 | Dart puro e sem dependência de plataforma. |

Classificação resultante: **REFATORAR** — a estrutura precisa incorporar versão,
tipo e procedência antes de o produto avançar; a pontuação existente deve ser
preservada por testes de caracterização.

## Dependências

- Área 6 (resultados) para migrar respostas por índice.
- Área 7 (persistência) para migração de tentativas e provas locais.
- Área 8 (sincronização) para o contrato de submissão por ID.
- Área 9 (importação) para unificar `ImportedQuestion` e `Question`.
- Área 12 (Supabase) para `exam_versions`, `questions` e chaves de resposta.
- Decisão de produto sobre rubrica e correção discursiva.

## O que não foi verificado

- Dados reais de tentativas com versões diferentes.
- Migração de registros antigos no Supabase.
- Compatibilidade com payloads de importação já salvos.
- Desempenho de igualdade/hash em listas grandes.
- Requisitos jurídicos de URL canônica e indexação.

## Links

- [[../Áreas/06 - Tentativas, resultados e pontuação|Área 6 — Resultados]]
- [[../Áreas/07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[../Áreas/09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[../../01 - Produto/Focus Mode|Focus Mode]]
- [[../../01 - Produto/Importação e OCR|Importação e OCR]]
- [[Mapa das Áreas|Mapa das Áreas]]
