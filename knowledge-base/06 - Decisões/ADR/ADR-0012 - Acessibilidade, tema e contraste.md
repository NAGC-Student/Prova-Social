---
tipo: adr
area: acessibilidade
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/theme/app_theme.dart, lib/features/quiz/quiz_page.dart, lib/core/widgets/skeleton.dart, site/tests/site.test.cjs, test/quiz_offline_submission_test.dart, test/question_media_gallery_test.dart, AGENTS.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0012 — Acessibilidade, tema claro/escuro e meta de contraste

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 14, 16
- **Urgência:** Média

## Contexto

O contraste dos tokens declarados passa de AA; o que não existe é
verificação de acessibilidade **do app**, e o requisito normativo pede três
verificações que ninguém faz.

- **Requisito normativo.** `AGENTS.md:33`: “Acessibilidade, redução de
  movimento e conexão ruim são requisitos, não extras.” A definição de
  pronto exige “Verificação light/dark” (`AGENTS.md:613`) e “Verificação com
  fonte ampliada e redução de movimento” (`:614`).
- **Contraste calculado (WCAG 2.x, luminância relativa) para os tokens que
  renderizam** — `lib/core/theme/app_theme.dart:19-35`:

  | Par | Razão | AA 4,5 |
  |---|---:|---|
  | `background #050907` × `textPrimary #F5F7F6` | 18,61 | passa |
  | `background #050907` × `textSecondary #AAB7B0` | 9,64 | passa |
  | `background #050907` × `textMuted #718078` | 4,83 | passa (folga 0,33) |
  | `surface #101A15` × `textPrimary #F5F7F6` | 16,53 | passa |
  | `background #050907` × `primary #20D99A` | 10,92 | passa |
  | claro `#F7F8F6` × `ink #171A18` | 16,46 | passa |
  | claro `#F7F8F6` × `muted #68706B` | 4,79 | passa (folga 0,29) |

  Os dois últimos são do tema claro, que **não é alcançável**
  (`lib/app.dart:23` fixa `ThemeMode.dark`) — passam no papel, não em uso.
- **Nenhum teste de contraste no app.** O único teste com esse nome,
  `test/quiz_offline_submission_test.dart:122` (“alternativa selecionada
  mantém contraste no tema escuro”), compara **igualdade de cor**
  (`:159-166`: `BoxDecoration.color` com
  `AppTheme.dark.colorScheme.primary.withValues(alpha: .16)` e a cor do
  `RenderParagraph` com `colorScheme.onSurface`). Não calcula razão.
- **Só o site tem verificação numérica de contraste.**
  `site/tests/site.test.cjs:43-49` calcula luminância e exige ≥ 4,5 para
  `101311/181c19/202521` × `f3f5f3/aab2ac` — os tokens do `AGENTS.md`, não
  os esmeralda (ver ADR-0001). Também exige `focus-visible` e
  `prefers-reduced-motion` no CSS.
- **Semântica existe, mas esparsa.** `grep -roE "\bSemantics\(" lib/ | wc -l`
  → **17** em **10** arquivos (`quiz_page.dart` 5; publish, result e
  skeleton 2 cada; seis arquivos com 1). `semanticsLabel:` → 6.
  `ExcludeSemantics` em `lib/core/widgets/skeleton.dart:147`. A única
  verificação de semântica em teste é
  `test/question_media_gallery_test.dart:11,35`.
- **Fonte ampliada não é tratada no código, só em teste.**
  `grep -rnE "textScaler|textScaleFactor|TextScaler" lib/` → **0**.
  Nove pontos de teste exercitam escala (fatores 1,15–1,5):
  `test/source_badge_test.dart:58`, `test/ux/focus_responsive_test.dart:39`,
  `test/ux/search_filters_test.dart:145,314,352`,
  `test/ux/search_test.dart:236`, `test/ux/prompt_redesign_test.dart:74,149`,
  `test/ux/navigation_editor_test.dart:818`. São testes de layout, não de
  legibilidade.
- **Redução de movimento é atendida.** `app_theme.dart:59-62`,
  `startup_gate.dart:49,73,107` e `skeleton.dart:38` consultam a preferência
  do sistema.
- **Tipografia dividida.** `grep -roE "fontSize: [0-9]+" lib/ | wc -l` →
  **39** literais contra **88** usos de `textTheme.*`. Os literais se
  concentram em `app_theme.dart` (14, definição), `quiz_page.dart` (8),
  `result_page.dart` (5) e `home_page.dart` (5). Fonte fora do tema não
  herda ajuste central de acessibilidade.
- **Cobertura de teste.** `ls test/*.dart | wc -l` → **40** arquivos na
  raiz (a nota da área 14 diz 41 em `:18` — obsoleta), `test/ux/` com 7
  arquivos e `test/manual/` com 5 probes de corpus, nenhum de
  acessibilidade. Não existe `integration_test/`.

**Limites.** As razões acima foram calculadas sobre cores **declaradas**,
não sobre pixels renderizados: não cobrem alpha (`withValues`, p.ex.
`lib/features/home/home_page.dart:711,716,759`), gradiente, imagem de fundo
ou o efeito de `scaffoldBackgroundColor: Colors.transparent`
(`app_theme.dart:198`). Não houve execução com TalkBack/VoiceOver, nem
verificação de ordem de foco, nem renderização do tema claro. “Passa AA”
aqui significa “o par declarado passa”, não “a tela passa”.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — AA com folga + teste de token no app**. A
decisão é:

1. **Fixar a meta em AA (4,5 para texto normal, 3,0 para texto grande e
   componentes de UI), com folga mínima de 0,5** — porque os dois pares mais
   fracos medidos têm folga de 0,33 e 0,29 e qualquer ajuste de token os
   derruba. A meta foi aprovada em 2026-11-07; o número medido é o argumento.
2. **Transformar a meta em teste do app**, não só do site: uma rotina de
   luminância em Dart que percorre os pares de token realmente usados e
   falha abaixo da meta. O site já tem o equivalente
   (`site/tests/site.test.cjs:43-49`); o app tem um teste com nome de
   contraste que não mede contraste.
3. **Decidir o tema claro junto com o ADR-0001.** Se ele continua
   inalcançável, a “verificação light/dark” do `AGENTS.md:613` deve ser
   marcada como não aplicável por decisão, não como pendente eterna.
4. **Trazer os 25 `fontSize` literais fora de `app_theme.dart` para o
   tema**, para que escala e ajuste de acessibilidade tenham um ponto só.
5. **Registrar o que não foi verificado** (leitor de tela, ordem de foco,
   alpha) como limite explícito da definição de pronto, em vez de afirmar
   conformidade WCAG.

## Alternativas

- **A — AA com folga + teste de token no app (escolhida).** Prós: custo
  baixo (uma função de luminância e um teste), fecha a lacuna entre nome de
  teste e o que ele mede, protege contra regressão de paleta. Contras: não
  cobre alpha nem renderização; dá falsa sensação de conformidade se for
  divulgado como “WCAG AA” sem o limite escrito.
- **B — AAA (7,0) para texto.** Prós: mais legível, especialmente em prova
  longa. Contras: `textMuted` (4,83) e `muted` claro (4,79) falham, exigindo
  redesenho de token; texto secundário e placeholders ficariam mais
  “pesados” visualmente; é decisão de design, não de conformidade.
- **C — Auditoria manual com leitor de tela + teste automatizado de
  contraste.** Prós: cobre o que cálculo não cobre (ordem de foco, anúncio
  de estado, navegação por gesto). Contras: exige dispositivo e tempo
  recorrente; não há `integration_test/` nem laboratório de device no
  projeto hoje; sem automação, a verificação não acontece a cada release.
- **D — Não fazer.** Prós: custo zero. Contras: a definição de pronto
  continua pedindo três verificações que não existem; o teste chamado
  “mantém contraste” continua não medindo contraste; fonte ampliada
  continua sem tratamento no código.
- **E — Adotar a paleta normativa e herdar o teste do site.** Prós: um
  conjunto de tokens e um teste já escrito. Contras: depende do ADR-0001
  decidir pela migração dos 115 usos de `EmeraldColors`; o teste do site é
  CSS, não Dart, e teria que ser reescrito de qualquer forma.

## Consequências e reversão

- **Positivas:** meta de contraste escrita e testada; regressão de paleta
  passa a falhar a esteira; a definição de pronto ganha um item verificável
  em vez de uma intenção; tipografia centralizada facilita escala.
- **Negativas/custos:** fixar folga de 0,5 pode reprovar token atual
  (`textMuted` 4,83 sobre `#050907` tem folga 0,33 sobre 4,5 — passaria na
  meta 4,5, mas não na folga 0,5 sobre `surface`, dependendo do par);
  migrar 25 literais de `fontSize` toca quatro telas grandes, que são
  justamente as que o plano strangler quer extrair — fazer antes da
  caracterização aumenta o diff.
- **Riscos:** afirmar conformidade WCAG a partir de cálculo de token é
  exatamente o tipo de divergência código × docs que a área 18 registra.
  Mitigação: o teste deve se chamar “contraste dos tokens declarados”, e o
  limite deve estar na nota.
- **Reversão:** teste e meta são Dart/texto — `git revert`. Mudar token para
  atingir a meta é reversível, mas altera a identidade visual e precisa do
  ADR-0001 junto.

## Implementação

**Executada em 2026-11-08, no escopo local (sem publicação).**

- `AppColors` e `AppTheme.light` foram removidos; o app usa somente
  `AppTheme.dark` com `EmeraldColors` (commit `dc2e2df`, Tarefa 2.1). O site
  continua com a paleta clara e teste próprio.
- `EmeraldColors.textMuted` passou de `#718078` para `#85938C`; o par mais
  fraco em uso — `textMuted` sobre `surfaceElevated` — mede 5,09.
- `test/accessibility/contrast_test.dart` mede os pares realmente usados com
  piso de 5,0 para texto normal e 3,5 para texto grande/componentes (commit
  `6a0e437`). O teste de `quiz_offline_submission_test.dart` foi renomeado
  para “usa superfície e texto do tema escuro”, porque ele compara igualdade
  de cor, não razão de contraste.
- `AppTypography` centraliza os tamanhos de fonte; `fontSize` literal fora de
  `app_theme.dart` falha em `tool/test_design_tokens.py` (commit `edf66b9`).
- **Verificação light/dark:** não aplicável ao app por decisão do ADR-0001; o
  site mantém a paleta clara coberta por `site/tests/site.test.cjs`.
- **Não verificado nesta rodada:** leitor de tela (TalkBack/VoiceOver), ordem
  de foco, contraste composto por alpha, contraste sobre imagens/gradientes e
  pixels renderizados. Esses limites estão registrados no `AGENTS.md` e no
  [[../../05 - Qualidade/Critério de Prontidão para Refatoração Global|Critério de Prontidão]].
- **Testes executados:** `flutter test test/accessibility/contrast_test.dart`,
  `flutter test test/quiz_offline_submission_test.dart`,
  `python3 tool/test_design_tokens.py`, `flutter analyze`.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/14 - Testes, QA e benchmark|Área 14]],
  [[../../09 - Auditoria/Áreas/16 - Design system e componentes|Área 16]].
- Código: [app_theme.dart](../../../lib/core/theme/app_theme.dart),
  [skeleton.dart](../../../lib/core/widgets/skeleton.dart),
  [quiz_page.dart](../../../lib/features/quiz/quiz_page.dart),
  [site/tests/site.test.cjs](../../../site/tests/site.test.cjs),
  [AGENTS.md](../../../AGENTS.md).
- Testes: [quiz_offline_submission_test.dart](../../../test/quiz_offline_submission_test.dart),
  [question_media_gallery_test.dart](../../../test/question_media_gallery_test.dart),
  [test/ux/focus_responsive_test.dart](../../../test/ux/focus_responsive_test.dart),
  [test/ux/search_filters_test.dart](../../../test/ux/search_filters_test.dart),
  [source_badge_test.dart](../../../test/source_badge_test.dart).
- **Exigido antes de implementar:** meta aprovada pelo responsável; teste de
  luminância em Dart com os pares realmente usados (incluindo os compostos
  por alpha, ou exclusão explícita deles); caracterização das quatro telas
  antes de migrar `fontSize`; para C, roteiro de leitor de tela escrito e
  executado ao menos uma vez, com resultado registrado.
- Comando de reprodução do cálculo (luminância WCAG):
  ```bash
  python3 - <<'PY'
  def lum(h):
      c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
      c=[v/12.92 if v<=0.04045 else ((v+0.055)/1.055)**2.4 for v in c]
      return 0.2126*c[0]+0.7152*c[1]+0.0722*c[2]
  def cr(a,b):
      la,lb=lum(a),lum(b); hi,lo=max(la,lb),min(la,lb)
      return round((hi+0.05)/(lo+0.05),2)
  print(cr('050907','718078'))  # 4.83
  PY
  ```
- Relacionados: [[ADR-0001 - Paleta e tema|ADR-0001]],
  [[ADR-0008 - Hierarquia documental e versionamento do vault|ADR-0008]],
  [[../../05 - Qualidade/Critério de Prontidão para Refatoração Global|Critério de Prontidão]].