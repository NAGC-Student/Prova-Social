---
tipo: area
area: arquitetura
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-04
---

# Mapa de Módulos

Esta classificação foi confrontada com a auditoria das **18 áreas**. Ela resume
a estrutura do checkout, não substitui as notas de área. O placar está em
[[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e a ordem de
refatoração em [[../09 - Auditoria/Síntese da Refatoração|Síntese da
Refatoração]].

## Estrutura real

- `lib/main.dart`, `lib/app.dart`: bootstrap e raiz do app.
- `lib/core/backend/`: repositórios e serviços Supabase/local (15 arquivos).
- `lib/core/import/`: OCR, PDF, layout, normalização, perfil de banca, parser,
  gabarito e quality gate (16 arquivos, 4.476 linhas). Cobre PDF/JSON/manual;
  não cobre câmera/galeria nem fila de feedback. Ver
  [[../09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate|auditoria da área 9]].
- `lib/core/navigation/`, `review/`, `startup/`, `theme/`, `update/`, `widgets/`.
- `lib/domain/models/exam.dart`: modelos principais de prova/questão/tentativa.
- `lib/features/`: auth, home, onboarding, publish, quiz, result, search, share.
- 60 arquivos Dart no `lib/`, total de 19.113 linhas medido.

## Maiores arquivos

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

## Arquitetura-alvo do Plano Mestre (proposta, não aprovada)

Presentation → Application → Domain → Infrastructure. Domínio não deve
depender de UI nem de fornecedor. Primeiro auditar importações e contratos,
depois validar a proposta em ADR; não migrar código por esta nota.

## Riscos

Telas e parser concentram múltiplas responsabilidades. Antes da extração,
escrever testes de caracterização, medir dependências e separar uma
responsabilidade por lote.

## Evidência

Contagens medidas em `git ls-files`, `find lib -name '*.dart'`, `wc -l` e
`rg`/leitura de imports. A auditoria profunda das 18 áreas foi concluída; o
maior risco estrutural é a concentração de responsabilidades em `home_page.dart`
(2.431 linhas), `publish_page.dart` (2.379), `quiz_page.dart` (1.501) e
`question_parser.dart` (1.480), tratado nos lotes 2–5 da síntese.
