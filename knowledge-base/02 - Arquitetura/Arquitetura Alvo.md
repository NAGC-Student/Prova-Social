---
tipo: area
area: arquitetura-alvo
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-05
---

# Arquitetura alvo em camadas

Proposta derivada do [[Mapa de Módulos]], do
[[Mapa de Dependências|mapa de dependências medido]] e dos
[[../01 - Produto/Inventário de Telas e Cobertura|inventários de telas e
persistência]]. **Nada aqui foi aprovado**: mover código por esta nota viola o
Plano Mestre. Cada decisão estrutural abaixo exige ADR (ver
[[../06 - Decisões/ADR/README]]) e cada lote exige tarefa explícita do
responsável.

## Resumo

- **Objetivo:** dar ao app as quatro camadas do Plano Mestre — Presentation,
  Application, Domain, Infrastructure — com uma regra de dependência verificável.
- **Resultado observado no SHA `05a8fc1`:** a camada Domain tem 1 arquivo
  (236 linhas) e 9.581 linhas de código ficam em `lib/features/`; `Supabase.instance`
  aparece em 10 arquivos (26 chamadas) e **7 repositórios** resolvem o cliente por
  default no construtor — nenhum é injetado em produção. Medidas completas em
  [[Mapa de Dependências]].
- **Limite:** nenhuma fronteira aqui foi validada em runtime nem em aparelho; é
  desenho a partir de imports, declarações e leitura de código.

## Regra de dependência (o critério que falta hoje)

```
presentation  ->  application  ->  domain  <-  infrastructure
```

1. `domain/` não importa `package:flutter`, `package:supabase_flutter`,
   `dart:io`, `shared_preferences`, `pdfrx`, `image`, `path_provider` nem
   `package:google_mlkit_*`. Hoje `lib/core/import/pdf_text_extractor.dart` e
   `ocr_service_native.dart` importam exatamente esses pacotes.
2. Nada em `presentation/` alcança fornecedor: `Supabase.instance` só aparece em
   `infrastructure/`. Hoje: `features/home/home_page.dart` (10 usos),
   `features/share/question_discussion.dart` (5), `features/publish/publish_page.dart` (3).
3. Toda dependência externa entra por construtor ou função de criação explícita;
   nenhum repositório resolve singleton com valor default
   (`lib/core/backend/exam_repository.dart:25-26` e mais 6 repositórios).
4. Regras de cálculo, elegibilidade e estado pertencem ao domínio, nunca ao
   widget. Hoje a política de pontuação existe em três lugares
   (`lib/domain/models/exam.dart:137-150`, `lib/features/result/result_page.dart:280`,
   `lib/core/backend/attempt_repository.dart:98`).
5. Uma direção por vez: um lote extrai, o lote seguinte remove o caminho antigo.
   Nunca manter dois caminhos escrevendo a mesma persistência.

## Camadas e conteúdo

| Camada | O que vive ali | Origem hoje |
|---|---|---|
| `lib/domain/` | Entidades e políticas puras: `Exam`, `Question`, `QuestionOutcome`, `ScoringPolicy`, `PublicationPolicy`, `Provenance`, `ContentVersion`, `ImportQuality`, `AttemptProgress` | `domain/models/exam.dart` + trechos hoje em widgets e em `core/backend/` |
| `lib/application/` | Casos de uso com uma frase no nome: `ImportExam`, `ReviewImportedExam`, `StartAttempt`, `PersistAnswer`, `FinishAttempt`, `SyncPendingAttempts`, `PublishExam`, `DownloadExamPackage`, `ResolveShareLink`, `AnswerQuestionDiscussion` | código de `_finish`, `_process`, `_valid`, upload/download e fila que hoje mora em `features/` e `core/backend/` |
| `lib/presentation/` | Telas, widgets, tema, navegação, estados de view; só chama casos de uso e renderiza | `lib/features/`, `lib/core/widgets/`, `lib/core/theme/` |
| `lib/infrastructure/` | Adaptadores concretos: Supabase (catálogo, tentativa, publicação, discussão), Storage/objeto, SQLite ou o que o ADR-0004 escolher, PDF/pdfrx, OCR (ML Kit/Paddle), arquivos, release check, preferências | `lib/core/backend/`, `lib/core/import/` com vendor, `lib/core/update/` |
| `lib/bootstrap/` | Composição raiz: configuração, DI, gates, rotas | `main.dart`, `app.dart`, `core/startup/`, `core/navigation/`, `supabase_config.dart` |

## Portas (contratos) propostas

| Porta | Definedora | Implementações | Substitui |
|---|---|---|---|
| `TextExtractionService` | domain | `PdfTextExtractorAdapter`, fake em teste | `PdfTextExtractor()` chamado direto (`publish_page.dart:467-620`) |
| `OcrEngine` | domain | `MlKitEngine`, `PaddleEngine`, `NoOcrEngine` | `OcrService()` fixo em `pdf_text_extractor.dart:179` |
| `ExamAnswerKey` | domain | `PrivateAnswerKeyStore` | gabarito misturado ao enunciado dentro do mesmo JSON |
| `AttemptStore`, `AttemptQueue` | domain | `SqliteAttemptStore` (ADR-0004), hoje `SharedPreferences` | `attempt_draft_store.dart`, `attempt_sync_service.dart:57-62` |
| `ObjectStore` | domain | `SupabaseObjectStore` | `exam_media_repository.dart` + `content_delivery_repository.dart` (mecânica duplicada) |
| `ExamCatalogRepository`, `PublicationRepository`, `DiscussionRepository` | domain | Supabase | `exam_repository.dart`, `exam_publication_service.dart`, `question_discussion_repository.dart` |
| `SessionSource` | domain | `SupabaseSession`, `VisitorSession` | 13 leituras de `auth.currentUser` espalhadas na UI |
| `ReleaseChecker`, `TimerSettings`, `LocalLibrary` | domain | infra | `github_release_service.dart`, `focus_timer_settings.dart`, `local_exam_store.dart` |

## Contratos de domínio que ainda não existem

Estes quatro contratos são pré-condição de quase todo o resto (Lote 2 da
[[../09 - Auditoria/Síntese da Refatoração|Síntese]]):

1. **`QuestionOutcome`** — unifica `QuestionState` (`review_page.dart`),
   `_AttemptQuestionOutcome` (`wrong_question_practice_service.dart`) e o cálculo
  solto em `result_page.dart:280`. Estados: `correct`, `wrong`, `blank`,
  `unknownAnswer` (sem gabarito), `excluded`. Denominador único.
2. **`ContentVersion`** — versão imutável do conteúdo resolvido. O existente
   `ImportedQuestionVersion` (`question_parser.dart:206`) é versão de *enunciado*
   dentro da importação, não versão de conteúdo publicado; a tentativa hoje
   referencia só `exam.id` (`attempt_draft_store.dart:72`).
3. **`PublicationPolicy`** — `options.length >= 2` e `correctIndex != null` para
   toda questão estão duplicados em `publish_page.dart:1317-1344` e
   `exam_publication_service.dart:32-60`; o serviço **não** verifica
   `reviewState` (`digital_exam_service.dart:200` chega a marcar `reviewed` na
   descarga). O contrato único decide: discursiva publicável, sem gabarito vira
   rascunho privado, revisão humana obrigatória.
4. **`Provenance`** — `p_source_type` está fixo em `'community'`
   (`exam_publication_service.dart:80`), apagando oficial/não verificada na escrita.

## Ordem de migração proposta (strangler, reversível)

Cada passo é um lote pequeno, com teste de caracterização antes e rollback sem
dupla escrita.

| Passo | Movimento | Dependência | Critério de saída |
|---:|---|---|---|
| 1 | `ImportedQuestion`, `QuestionFormat`, `QuestionReviewState` e `AnswerKey` de `core/import/` para `domain/` (re-export transitório) | ADR-0002 | `flutter analyze` limpo; nenhum importador mudou de comportamento |
| 2 | `QuestionOutcome` + `ScoringPolicy` únicos; widgets e servidor passam a consultá-los | passo 1, ADR-0002 | uma asserção por estado; teste de contradição entre local e servidor |
| 3 | `PublicationPolicy` no domínio; `publish_page._valid` e o serviço delegam | passo 1, ADR-0002 | serviço recusa não revisado; discursiva publicável |
| 4 | Extrair `HomeController`/`AttemptController`/`ImportController` dos `StatefulWidget` giantes; widgets viram view | passos 1-3, testes de caracterização | `home_page.dart` e `quiz_page.dart` abaixo de um teto acordado; `test/ux/` verde |
| 5 | Portas `SessionSource`, `ExamCatalog`, `ObjectStore`; injetar no construtor; remover `Supabase.instance` da UI | passo 4 | `rg "Supabase.instance" lib/features/` = 0 |
| 6 | `application/` recebe os casos de uso restantes; `infrastructure/` agrupa adaptadores; `bootstrap/` faz a composição | passos 1-5 | grafo de imports respeita a regra 1-3 e é checado em CI |
| 7 | Trocar persistência de tentativas atrás de `AttemptStore` | ADR-0004 | fallback de leitura mantido; teste de crash |

## O que a arquitetura alvo **não** muda

- Gabarito nunca é inferido; continua separado das questões públicas.
- Offline primeiro: resposta salva antes de rede; `clientAttemptId` idempotente.
- Revisão humana antes de publicar; procedência explícita.
- Questão como objeto central; sem feed genérico; sem IA paga estrutural.
- RLS e isolamento por conta no Supabase.

## Riscos

1. Extrair controller antes de fechar contrato (`QuestionOutcome`) congela a
   regra errada em classe nova.
2. Re-export transitório que sobrevive por anos e vira segunda fonte de nomes.
3. `test/ux/` dirige o comportamento por pump de widget; extrair sem caracterizar
   destrói a única rede de proteção que existe.
4. Dupla escrita em persistência (SharedPreferences + SQLite) sem teste de
   migração pode responder duas versões diferentes da mesma tentativa.
5. O hash de pipeline do benchmark (`test/local_corpus_benchmark_test.dart:47`)
   identifica arquivos por caminho; mover `core/import/` invalida a baseline.

## Dependências

- ADRs 0002 (modelo de questão), 0003 (versionamento), 0004 (persistência),
  0001/0012 (identidade e acessibilidade, para o passo de widgets).
- Lote 0 (esteira verde) e Lote 1 (fonte única) da
  [[../09 - Auditoria/Síntese da Refatoração|Síntese]].
- [[Fluxos Propostos]] para os fluxos medidos que estas camadas precisam servir.

## Links

- [[Mapa de Módulos]] · [[Mapa de Dependências]] · [[Fluxos Reais]] · [[Fluxos Propostos]]
- [[../01 - Produto/Inventário de Telas e Cobertura]] ·
  [[../04 - Infraestrutura/Inventário de Persistência e Dados]]
- [[../03 - Domínios/Fluxos Principais]] · [[../04 - Infraestrutura/Dados e Segurança]]
- [[../06 - Decisões/ADR/README]] · [[../09 - Auditoria/Síntese da Refatoração]]
