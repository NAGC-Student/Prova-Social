---
tipo: area
area: hipóteses
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 3, testes: 3, acoplamento: 2, clareza: 2, seguranca: 2, robustez: 2, aderencia: 3, portabilidade: 2}
fonte_codigo: [lib/, test/, .github/workflows/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-03
---

# Hipóteses do Plano Mestre

> **Nota de consolidação (2026-11-04):** as hipóteses abaixo foram verificadas
> nas auditorias das 18 áreas. O resultado consolidado, com achados
> transversais e ordem de lotes, está em
> [[Síntese da Refatoração|Síntese da Refatoração]]. Esta tabela permanece como
> registro do que foi levantado antes da leitura profunda.

| Hipótese | Estado | Evidência / limite |
|---|---|---|
| Draft e fila usam SharedPreferences e JSON | **CONFIRMADA** | `attempt_draft_store.dart:40–54, 75–130`; `attempt_sync_service.dart:61–100`. Serialização/estrutura de persistência confirmada; capacidade e corrupção precisam de teste. |
| `quiz_page.dart` e `question_parser.dart` são grandes (~1.234 e ~1.097 linhas) | **CONFIRMADA, tamanho divergiu** | Foram medidos 1.501 e 1.480 linhas. |
| OCR decide por limiar de ~20 caracteres nativos | **CONFIRMADA** | `ocr_router.dart:30–38`, `minimumNativeTextLength = 20`. |
| Publicação exige gabarito; duas alternativas ou mais; força `Geral` | **CONFIRMADA** | `exam_publication_service.dart:49–69`: valida de 2 a 8 opções, `correctIndex` não nulo e grava topic literal `Geral`. |
| Score divide acertos pelo total mesmo sem gabarito | **REFUTADA no SHA auditado** | `exam.dart:137–150` usa `correctableCount`; teste em `test/exam_result_test.dart:115–134`. |
| Há PDF sintético de 80 questões em duas colunas e fixture VUNESP 2024 | **CONFIRMADA** | `test/synthetic_pdf_import_test.dart:19–92`; `test/vunesp_2024_import_test.dart:20–102`. Direito de redistribuição do fixture real não é provado pelo teste. |
| PRs #16, #17 e #18 estão abertos | **REFUTADA no SHA auditado** | Os três aparecem mesclados no upstream; commits de merge `4195b39`, `d76571c`, `05a8fc1`. |
| CI run #100 falha no QA estático e main anterior #98 passa | **CONFIRMADA COM RESSALVA** | #100 falha em `dart format`; #98 é evento agendado e job QA completo foi ignorado. Run #104 falha igualmente. |
| Não existe licença formal de raiz | **CONFIRMADA** | `git ls-files` encontra somente `packages/paddleocr_android/LICENSE`; escolha de licença não cabe ao agente. |

## Próximas hipóteses

- Testar se a entrada de tópico existe no formulário mas é descartada no serviço.
- Provar isolamento RLS com dois usuários em ambiente de teste isolado.
- Auditar payload e retomada após encerramento abrupto.
- Medir custo do JSON regravado em centenas/milhares de respostas.

Não usar esses achados para alterar regras ainda; ver [[../00 - Central/Plano Mestre]].
