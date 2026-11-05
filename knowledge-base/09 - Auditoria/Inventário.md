---
tipo: area
area: inventário global
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 3, testes: 3, acoplamento: 2, clareza: 2, seguranca: 2, robustez: 2, aderencia: 3, portabilidade: 2}
fonte_codigo: [pubspec.yaml, lib/, test/, supabase/, packages/paddleocr_android/, .github/workflows/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-03
---

# Inventário Global — baseline

> **Nota de consolidação (2026-11-04):** este inventário é a fotografia inicial
> de 2026-11-03. A auditoria profunda das **18 áreas** foi concluída depois; o
> estado consolidado está em
> [[Síntese da Refatoração|Síntese da Refatoração]] e
> [[Áreas/Mapa das Áreas|Mapa das Áreas]]. Números desta nota continuam válidos
> como baseline, mas não são o único retrato do repositório.

## Git e versão

- Branch `main`; SHA `05a8fc1aab92d43f58ad7da8b24e710f9874d281`.
- Worktree limpo antes da criação deste vault; 104 commits alcançáveis; 275
  arquivos rastreados.
- Versão `0.7.5+15`; Dart `>=3.13.0 <4.0.0`; Flutter `>=3.47.0`.
- Flutter instalado: 3.47.6; Dart: 3.13.5.
- `origin/main` está 5 commits atrás do checkout; `upstream/main` coincide com o
  checkout no momento da medição. Não sincronizar sem autorização.
- PRs no upstream: #16 Playwright, #17 ONNX Runtime e #18 testes/importação
  estão mesclados.

## Árvore e contagem

| Área | Medida |
|---|---:|
| `lib/` | 60 arquivos Dart; 19.113 linhas |
| `test/` | 48 arquivos Dart |
| `qa/` | 11 arquivos rastreados |
| `supabase/migrations/` | 9 migrations |
| `supabase/**/*.sql` | 15 arquivos SQL |
| `packages/paddleocr_android` | módulo Flutter/Android do OCR |

O repositório também contém Android, Web, assets de marca, scripts, site e
workflows. O comando de inventário contou todos os arquivos rastreados e linhas
por extensão; diretórios gerados (`build`, `.dart_tool`, `node_modules`) não
foram tratados como fonte.

## Maiores componentes Dart

| Arquivo | Linhas |
|---|---:|
| `lib/features/home/home_page.dart` | 2.431 |
| `lib/features/publish/publish_page.dart` | 2.379 |
| `lib/features/quiz/quiz_page.dart` | 1.501 |
| `lib/core/import/question_parser.dart` | 1.480 |
| `lib/features/search/search_page.dart` | 880 |
| `lib/features/result/result_page.dart` | 745 |
| `lib/core/import/pdf_text_extractor.dart` | 588 |
| `lib/core/backend/attempt_sync_service.dart` | 578 |

Ver [[../02 - Arquitetura/Mapa de Módulos]].

## Dependências diretas

Lista de `pubspec.yaml`; versões resolvidas medidas por `flutter pub deps
--style=compact`:

- arquivo/imagem/PDF: `file_picker 13.1.0`, `image 4.10.1`, `pdfrx 2.6.6`,
  `archive 4.6.0`, `crypto 3.0.7`;
- OCR: `google_mlkit_text_recognition 0.17.1`, `paddleocr_android 0.1.0` local;
- backend/rede: `supabase_flutter 2.18.3`, `http 1.6.0`, `url_launcher 6.3.3`;
- cache/ambiente: `shared_preferences 2.5.6`, `path_provider 2.1.6`,
  `package_info_plus 10.2.2`.

Dev dependencies incluem Flutter test/lints, ícones e `pdfium_flutter`. Uso e
necessidade precisam ser revisados na auditoria de dependências. A
[matriz versionada](../../DEPENDENCY_COMPATIBILITY.md) está desatualizada e
declara v0.5.0.

## Supabase e persistência

Há 9 migrations, 15 SQL no total e scripts de backend/testes. A migration mais
recente é `20261101002428_exam_media_publication.sql`. O remoto não foi
consultado. O app tem stores locais para tentativas, conteúdo e mídia; detalhes
e risco em [[../04 - Infraestrutura/Dados e Segurança]].

## Testes, QA e entrega

- 48 arquivos de teste Dart; a suíte local passou com 296 testes e 1 opcional
  ignorado.
- `qa/` tem 11 arquivos rastreados, incluindo browser tests; `find qa` sem
  filtrar dependências não é uma medida confiável porque `node_modules` existe.
- Workflow principal `.github/workflows/flutter-ci.yml`; keepalive Supabase em
  workflow separado.
- CI run #104 está falhando no format check dos 3 probes de corpus; teste local
  e analyzer passam.
- Build APKs presentes são datados de 01/11/2026 e não correspondem ao SHA
  `05a8fc1`.

## Docs e licença

- `PROVA_SOCIAL_CONTEXT.md` declara atualização em 27/09/2026.
- `DEPENDENCY_COMPATIBILITY.md` declara v0.5.0 e versões que divergem dos
  resolved dependencies atuais.
- Não há arquivo de licença na raiz; há LICENSE apenas em
  `packages/paddleocr_android/`.
- Decisão de licença do aplicativo é do responsável, não inferível pelo código.

## Segurança superficial

`.env.p0` e `.env.supabase.json` estão locais e ignorados; valores não lidos.
Os probes de corpus incluem paths absolutos locais e escrevem texto extraído em
`/tmp` e stdout; avaliar remoção/isolamento e impedir logging de conteúdo.

## Não verificado

Cobertura percentual, dependências realmente mortas, schema remoto/RLS ativo,
inventário coluna a coluna, tamanho médio real de pacotes, startup/catalog
latency em aparelhos, tamanho médio de build válido no SHA atual, permissão para
redistribuir fixtures e licença do produto.
