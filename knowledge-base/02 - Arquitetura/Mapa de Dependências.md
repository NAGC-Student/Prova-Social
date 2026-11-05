---
tipo: area
area: dependências e acoplamento
status: VALIDADO
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 2, clareza: 4, seguranca: 3, robustez: 3, aderencia: 3, portabilidade: 4}
fonte_codigo: [lib/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Mapa de dependências medido

Grafo de imports internos dos 60 arquivos Dart de `lib/` (19.113 linhas), medido
por script sobre as declarações `import '...'`. É a evidência numérica que a
[[Arquitetura Alvo]] precisava para propor camadas. Não propõe nada aqui — só
mede.

## Distribuição por camada

| Camada | Arquivos | Linhas | Observação |
|---|---:|---:|---|
| `lib/features/` | 12 | 9.581 | telas; contém a lógica de produto |
| `lib/core/import/` | 16 | 4.476 | motor de importação |
| `lib/core/backend/` | 18 | 3.160 | adaptadores + serviços |
| `lib/core/widgets|theme|startup|review|navigation|update/` | 10 | 1.597 | utilidades |
| `lib/domain/models/` | **1** | **236** | todo o domínio |
| `lib/main.dart`, `lib/app.dart` | 2 | 75 | bootstrap |

## Arestas entre áreas (imports internos, contados)

| Origem | Destino | Arestas |
|---|---|---:|
| `features/publish` | `core/import` | 7 |
| `features/home` | `core/*` (widgets, theme, backend…) | 6 |
| `core/backend` | `domain` | 6 |
| `features/result` | `core/*` | 5 |
| `features/publish` | `core/backend` | 4 |
| `features/quiz` | `core/backend` | 4 |
| `features/home` | `core/backend` | 4 |
| `features/search` | `core/*` | 4 |
| `core/other` | `domain` | 3 |
| `features/*` | `domain` | 8 (uma aresta por feature, exceto `onboarding`) |

Leituras relevantes:

- **`domain` não importa ninguém** (fan-out interno 0). A pureza existe; o
  problema de `domain` é **escopo**: 236 linhas para todo o modelo. Ciclos existem,
  mas em outro lugar — ver "Ciclos — correção desta nota" abaixo.
- **`core/import` só é alcançado por `features/publish`** (7 arestas). É a única
  fronteira limpa do app — extrair a importação para um pacote próprio é
  mecanicamente possível.
- **`core/backend` é alcançado por 6 features** (`publish`, `quiz`, `home`,
  `share`, `result`, `search`, `auth`). É onde a UI e o fornecedor se misturam.

## Ciclos — correção desta nota (2026-11-05)

A frase "o problema não é ciclo" vale só para `domain` (fan-out 0, confirmado).
Rodando strongly-connected components sobre as 144 arestas internas, **existem 2
ciclos**: `quiz_page.dart` ↔ `result_page.dart`, e
`publish_page.dart → home_page.dart → auth_page.dart → publish_page.dart`. Há 16
arestas entre features vizinhas e a instabilidade por área é `domain` 0,00 /
`core/import` 0,39 / `core/backend` 0,43 / `features/publish` 0,94. Consequência:
extrair `quiz` sem tocar `result` não é refatoração, é mudança de comportamento —
pelo ADP os dois são um módulo só hoje. Medição, comandos e o item da
recomendação estão em
[[../05 - Qualidade/Auditoria de Clean Code e SOLID medida]].

## Fan-in / fan-out extremos

| Arquivo | Fan-out | Fan-in |
|---|---:|---:|
| `lib/domain/models/exam.dart` | 0 | **15** |
| `lib/core/theme/app_theme.dart` | 0 | 8 |
| `lib/features/publish/publish_page.dart` | **13** | 0 |
| `lib/features/home/home_page.dart` | **11** | 0 |
| `lib/features/quiz/quiz_page.dart` | 8 | 0 |
| `lib/core/backend/attempt_sync_service.dart` | 2 | 4 |

Os três arquivos com maior fan-out têm fan-in 0: ninguém os importa, o usuário os
abre pela rota. São, portanto, **pontos de extração seguros** — nenhum outro
módulo depende dos nomes internos deles.

## Vendor dentro das camadas erradas

Imports de pacotes externos por arquivo, fora de `core/backend` e `core/import`:

| Arquivo | Pacotes |
|---|---|
| `features/home/home_page.dart` | `supabase_flutter` |
| `features/publish/publish_page.dart` | `supabase_flutter`, `file_picker` |
| `features/share/question_discussion.dart` | `supabase_flutter` |
| `features/auth/auth_page.dart` | `supabase_flutter` |
| `main.dart` | `supabase_flutter` |
| `features/auth/auth_gate.dart`, `features/onboarding/onboarding_page.dart`, `features/search/search_page.dart` | `shared_preferences` |

Contagem total por pacote no `lib/`: `supabase_flutter` 13 arquivos,
`shared_preferences` 7, `pdfrx` 3, `image` 2, `path_provider` 2, `file_picker` 1,
`google_mlkit_text_recognition` 1, `paddleocr_android` 1.

## Singleton implícito (a regra que a Arquitetura Alvo cita, medida)

- `Supabase.instance` aparece em **10 arquivos** e **26 chamadas**: `home_page`
  (10), `question_discussion` (5), `publish_page` (3) e 8 em 7 arquivos de
  `lib/core/backend/` (`question_discussion_repository.dart` usa 2).
- **7 arquivos** resolvem o cliente com `_client ?? Supabase.instance.client` no
  construtor (`exam_repository.dart:25-26`, `attempt_repository`,
  `auth_repository`, `content_delivery_repository`, `exam_media_repository`,
  `exam_publication_service`, `question_discussion_repository`). A injeção existe
  como parâmetro opcional, mas o default garante que a produção nunca injeta.
- Nota anterior dizia "11 arquivos chamam `Supabase.instance`"; o número medido é
  10 arquivos / 26 chamadas. [[../00 - Central/Estado Atual]] e
  [[../02 - Arquitetura/Arquitetura Alvo]] devem ser corrigidos para a medição
  atual.

## Concentração de responsabilidade (classes por arquivo)

| Arquivo | Linhas | Classes | Privadas |
|---|---:|---:|---:|
| `features/home/home_page.dart` | 2.431 | 24 | 22 |
| `features/publish/publish_page.dart` | 2.379 | 12 | 8 |
| `features/quiz/quiz_page.dart` | 1.501 | 16 | 15 |
| `core/import/question_parser.dart` | 1.480 | 7 | 4 |

Composição de `home_page.dart`: 1 `HomePage`, 1 `_HomePageState`, `_LibraryPage`,
`_ProfilePage`, `_ExamDetails`, `_HomeFeed`, `_ExamGrid`, `ExamCard`,
`_OfflineDownloadButton`, `_BottomNavBar`, `_DesktopTopBar` e mais 13 widgets
auxiliares — cinco telas em um arquivo.

## O que um redesenho global ganha com estas medidas

1. A camada `domain` é pequena demais, não suja: **expandir** é mais barato que
   **limpar**.
2. `core/import` já é uma fronteira (7 arestas, 1 consumidor): pode virar pacote
   próprio sem tocar o resto.
3. Os três arquivos gigantes têm fan-in 0: dá para extrair por trás deles sem
   quebrar importadores.
4. O custo real está em `core/backend` (6 consumidores de feature + 7 defaults de
   singleton) — é a camada que precisa de portas antes de qualquer mudança de UI.
5. `test/ux/navigation_editor_test.dart` importa `HomePage`, `PublishPage`,
   `AuthPage` e `ImportReviewPage` ao mesmo tempo: qualquer extração de rota tem
   que manter esse contrato verde ou o teste precisa ser reescrito primeiro.

## Links

[[Arquitetura Alvo]] · [[Mapa de Módulos]] ·
[[../03 - Domínios/Modelo de Domínio Atual]] ·
[[../01 - Produto/Inventário de Telas e Cobertura]] ·
[[../05 - Qualidade/Critério de Prontidão para Refatoração Global]]
