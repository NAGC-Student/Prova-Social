---
tipo: area
area: telas e cobertura de teste
status: VALIDADO
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 2, clareza: 3, seguranca: 3, robustez: 3, aderencia: 2, portabilidade: 3}
fonte_codigo: [lib/features/, lib/app.dart, lib/core/navigation/, test/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Inventário de telas, navegação e cobertura

Medido no worktree de 2026-11-05: `flutter test` com **290 aprovados + 1
ignorado** em 43 arquivos `*_test.dart`. É o mapa do que um app novo precisa
recriar, e da rede de proteção que existe antes de qualquer extração.

## Navegação: não há tabela de rotas

- `lib/app.dart:26-44` tem **uma** `onGenerateRoute`, e ela só atende deep link de
  compartilhamento (`ShareLinkService.parse`, `share_link_service.dart:16-32`,
  host fixo `prova-social.pages.dev`).
- Toda a navegação interna é **imperativa**: 34 chamadas `MaterialPageRoute`
  distribuídas em 9 arquivos (`home` 9, `publish` 7, `quiz` 5, `result` 4,
  `share_link` 3, `auth` 2, `app` 2, `search` 1, `onboarding` 1).
- Consequência para o redesenho: não existe lugar único para declarar "quais
  telas o app tem", para proteger acesso por papel, nem para testar um destino
  sem montar a tela de origem.

## Telas, dona da navegação e cobertura

| Tela | Arquivo:linha | Linhas | Como se chega | Testes que a citam |
|---|---|---:|---|---:|
| `HomePage` | `home_page.dart:29` | 2.431 | `AuthGate` → `main` | 1 (`test/ux/navigation_editor_test.dart`) |
| `_LibraryPage` | `home_page.dart:1397` | — | privada dentro da home | 0 direta |
| `_ProfilePage` | `home_page.dart:1836` | — | privada dentro da home | 0 direta |
| `SearchPage` | `search_page.dart:16` | 880 | push da home | 3 (`search_test`, `search_filters_test`, `prompt_redesign_test`) |
| `QuizPage` | `quiz_page.dart:17` | 1.501 | push da home/share | 7 (`focus_responsive_test`, `quiz_draft_exit_test`, `quiz_offline_submission_test`, `wrong_questions_retry_test`, `result_review_test`, `focus_timer_settings_test`, `navigation_editor_test`) |
| `ResultPage` | `result_page.dart:191` | 745 | push do quiz | 4 |
| `PendingResultPage` | `result_page.dart:16` | — | push do quiz (sem rede) | 1 |
| `ReviewPage` | `review_page.dart:9` | — | push do result | 1 (`result_review_test`) |
| `PublishPage` | `publish_page.dart:26` | 2.379 | push da home | 2 (`navigation_editor_test`, `prompt_redesign_test`) |
| `PdfImportPage` | `publish_page.dart:248` | — | privada, push interno | 0 |
| `PdfProcessingPage` | `publish_page.dart:428` | — | privada | 0 |
| `ImportReviewPage` | `publish_page.dart:997` | — | privada | 1 (`navigation_editor_test`) |
| `AuthPage` | `auth_page.dart:10` | 364 | `AuthGate` | 1 (`navigation_editor_test`) |
| `OnboardingPage` | `onboarding_page.dart:9` | 494 | `AuthGate` | 1 (`onboarding_responsive_test`) |
| `ShareLinkPage` | `share_link_page.dart:12` | — | **única rota declarada** | 0 |
| `QuestionDiscussion` | `question_discussion.dart` | 278 | embutida no quiz/result | 0 direta |
| `_StartupScreen` | `startup_gate.dart:92` | — | `StartupGate` | 0 |

Quatro destinos são **classes privadas** — `_LibraryPage` (`home_page.dart:1397`),
`_ProfilePage` (`:1836`), `_ExamDetails` (`:2036`) e `_StartupScreen`
(`startup_gate.dart:92`) — e **não são instanciáveis em teste**: só se chega a
eles pumpando a tela-mãe. `PdfImportPage`, `PdfProcessingPage` e
`ImportReviewPage` são públicas, mas vivem no mesmo arquivo de 2.379 linhas e
nenhuma tem teste de travessia. Isto explica a contagem de 1 teste para a home de
2.431 linhas.

## O que o fluxo crítico tem, hoje

`AGENTS.md` §21 pede importar → revisar → publicar → fazer → finalizar.

| Etapa | Tela | Teste cobrindo a travessia |
|---|---|---|
| Importar | `PdfImportPage` → `PdfProcessingPage` | testes de parser/extração em `test/` (unidade), nenhum de tela |
| Revisar | `ImportReviewPage` | 1 teste de navegação |
| Publicar | `PublishPage` | 2 testes de prompt/navegação |
| Fazer | `QuizPage` | 7 testes (timer, rascunho, offline) |
| Finalizar | `ResultPage`/`ReviewPage` | 4 + 1 |

Não existe `integration_test/`: nenhuma verificação percorre as cinco etapas
seguidas. O único teste que atravessa telas é
`test/ux/navigation_editor_test.dart`, e ele pumpa quatro páginas diferentes sem
dados reais de conteúdo.

## Distribuição da suíte (para dimensionar caracterização)

- 43 arquivos `*_test.dart`: **36 em `test/`** (unidade/domínio/backend) e **7 em
  `test/ux/`** (widget).
- Áreas com teste de unidade forte: importação/parser (11 arquivos), sync e
  rascunho, compressão/hash de payload local, timer, gabarito.
- Áreas sem teste dedicado: RLS social/Storage, distribuição e site no device,
  deep link fora do parse, discussão de questão, perfil e biblioteca.

## O que isto entrega para um redesenho global

1. **Contrato de navegação a criar:** uma tabela de rotas com os 17 destinos
   acima é pré-condição de separar `home_page.dart` em cinco telas reais.
2. **Caracterização primeiro:** antes de extrair `QuizPage`, é preciso um teste
   por destino privado (`_LibraryPage`, `_ProfilePage`, `PdfImportPage`…), hoje
   inalcançável.
3. **`ExamListTile` não é cosmético:** a home usa `ExamCard`
   (`home_page.dart:1298`) e a busca usa `ListTile` — a tela é a única fonte de
   hierarquia de lista hoje.
4. **Deep link é o único contrato externo estável** (`/provas/<uuid>`,
   `/provas/<uuid>/questoes/<uuid>`) e tem validação de UUID
   (`share_link_service.dart:33-36`) — o app novo precisa manter exatamente esta
   forma, sob pena de quebrar links já compartilhados.

## Links

[[../02 - Arquitetura/Mapa de Dependências]] ·
[[../05 - Qualidade/Validação Atual]] · [[../01 - Produto/Fluxo de Entrada e Criação]] ·
[[../09 - Auditoria/Áreas/05 - Focus Mode, timer, navegação e finalização|área 5]] ·
[[../05 - Qualidade/Critério de Prontidão para Refatoração Global]]
