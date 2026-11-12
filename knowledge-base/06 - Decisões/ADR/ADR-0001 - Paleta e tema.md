---
tipo: adr
area: design system e tema
status: ACEITO
classificacao: VALIDADO
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/core/theme/app_theme.dart, lib/app.dart, lib/core/startup/startup_gate.dart, lib/features/result/result_page.dart, AGENTS.md, site/styles.css, test/ux/startup_test.dart]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-10
---

# ADR-0001 — Paleta e tema: dark-only com `EmeraldColors` ou light+dark com tokens do `AGENTS.md`

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 15, 16, 18
- **Urgência:** Alta

## Contexto

Há **três** paletas em uso, não duas, e o tema claro existe mas é inalcançável.

- **Paleta esmeralda (a que renderiza).** `abstract final class EmeraldColors`
  em `lib/core/theme/app_theme.dart:19-35` com **15** constantes:
  `background #050907`, `surface #101A15`, `primary #20D99A`,
  `textPrimary #F5F7F6`, `textSecondary #AAB7B0`, `textMuted #718078`,
  `border #23382E`, `error #FF6464`, entre outras. Uso medido:
  `grep -roE "EmeraldColors\." lib/ | wc -l` = **115**; `AppColors.` = **36**.
- **Paleta clara (existe, não é usada).** `AppTheme.light`
  (`app_theme.dart:66-178`) é um tema claro de verdade: `ColorScheme.light`
  (`:67`), `scaffoldBackgroundColor: AppColors.background` = `#F7F8F6`
  (`:84`), `AppColors` com 13 constantes em `:3-17`. Mas
  `lib/app.dart:21-23` passa `theme: AppTheme.light`,
  `darkTheme: AppTheme.dark` e **`themeMode: ThemeMode.dark` fixo**.
  `grep -rn "ThemeMode" lib/` retorna só `lib/app.dart:23`; não há chave de
  preferência de tema em nenhum `SharedPreferences`. O tema claro é código
  morto em execução, e `test/ux/startup_test.dart:13-46` chega a afirmar
  que nenhuma caixa com `AppColors.background` renderiza.
- **Paleta normativa (a que o site usa).** `AGENTS.md:62-65` declara tokens
  escuros `background #101311`, `surface #181C19`, `textPrimary #F3F5F3`,
  `border #2A302C`. **Nenhum** desses valores existe em `app_theme.dart`;
  `grep -rn -iE "0xFF101311|0xFF181C19|0xFFF3F5F3|0xFF2A302C" lib/` retorna
  apenas `lib/core/startup/startup_gate.dart:109`. O site, esse sim, usa os
  tokens normativos: `site/styles.css` tem `--bg:#101311` e
  `site/tests/site.test.cjs:43-49` verifica contraste AA ≥ 4,5 para
  `101311/181c19/202521` × `f3f5f3/aab2ac`. Ou seja: **site e app têm fundos
  diferentes** e só o site tem teste de contraste.
- **Cores fora do tema.** `grep -roE "Color\(0x" lib/ --include=*.dart | wc -l`
  = **37** em **3** arquivos: `app_theme.dart` 28 (definição dos tokens),
  `core/startup/startup_gate.dart` **8** (`:109,148,168,181,191,192,224,225`)
  e `features/result/result_page.dart:254` 1 (`#D7F3E7`). A nota da área 16
  está obsoleta em dois pontos: conta 113 usos de `EmeraldColors` (são 115) e
  afirma que "só há um `Color(0x...)` fora do tema"
  (`Áreas/16 - Design system e componentes.md:52,121-123`) — há **9** fora de
  `app_theme.dart`, oito em `startup_gate.dart`. O startup gate é, na
  prática, um quarto tema hardcoded.
- **Outras divergências normativas medidas.** `AGENTS.md:78` pede Inter
  "ou equivalente já adotada"; `app_theme.dart:85,199` usa
  `fontFamily: 'sans-serif'`. `AGENTS.md:69` pede botões 40–44 px;
  `app_theme.dart:116,155,284,301` usa `Size(48,48)`. Os 11 valores claros de
  `AGENTS.md:48-58` existem em `AppColors`, mas três com nome trocado
  (`textPrimary`→`ink`, `textSecondary`→`muted`, `border`→`line`).
- **Tema escuro não pinta o scaffold.** `AppTheme.dark` usa
  `scaffoldBackgroundColor: Colors.transparent` (`app_theme.dart:198`) e
  define cor de texto explícita por estilo (`:200-241`). O fundo visível vem
  de outro widget — o que explica por que `startup_gate.dart:109` precisou
  hardcodar `#101311`.

**Atualização 2026-11-10 (implementação pós-decisão):**
- **Inter variable font** adicionada em `fonts/Inter/Inter-VariableFont_slnt,wght.ttf` (862KB) e configurada no `pubspec.yaml:67-70`; `fontFamily: 'Inter'` em `app_theme.dart:85,199` (era `'sans-serif'`).
- `EmeraldColors.textMuted` corrigido de `#85938C` para `#718078` (alinhado ao `AGENTS.md:70`).
- `AppRadius.card` (12px) e `AppRadius.full` (9999px) adicionados em `app_theme.dart:57-58`.
- `startup_gate.dart` e `result_page.dart:254` ainda têm cores hardcoded (pendente migração para tokens).

**Limites.** Nenhuma paleta foi renderizada e fotografada para comparação; os
números são de leitura estática e `grep`. Não foi medido contraste de cores
compostas por alpha (`withValues`). A escolha de paleta é decisão de produto
e de marca, não de engenharia — este ADR não pode decidi-la sozinho.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — dark-only esmeralda**. A paleta oficial do app
passa a ser `EmeraldColors`, porque é a que renderiza, a que tem 115 usos e a
que tem contraste medido (ver ADR-0012). A decisão inclui:

1. Emendar `AGENTS.md:62-65` para os valores esmeralda **ou** declarar
   explicitamente que os tokens normativos valem para o **site** e os
   esmeralda para o **app**, com a razão escrita.
2. Remover `AppTheme.light` e `AppColors` do caminho de execução, ou tornar o
   tema claro alcançável por preferência — as duas coisas são aceitáveis,
   manter como está não é.
3. Trazer as 8 cores de `startup_gate.dart` e a de `result_page.dart:254`
   para tokens, para que o startup deixe de ser um tema paralelo.

Se o responsável preferir a paleta normativa, o trabalho é o inverso e é
maior: migrar 115 usos de `EmeraldColors` para os tokens do `AGENTS.md`,
refazer o contraste e alinhar o site — que já está certo nesse cenário.

## Alternativas

- **A — Dark-only esmeralda (escolhida).** Prós: zero migração visual,
  contraste já medido (18,61 para texto primário), site pode continuar com
  sua paleta se a separação for declarada. Contras: contradiz os tokens
  escritos no normativo enquanto ele não for emendado; abandona o tema claro
  que `AGENTS.md:33,613-614` pede verificar.
- **B — Light+dark com tokens do `AGENTS.md`.** Prós: cumpre o normativo e o
  requisito de tema claro; alinha app e site numa paleta só; o teste de
  contraste do site passa a valer para os dois. Contras: migrar 115 usos,
  reescrever `AppTheme.dark` (hoje com scaffold transparente), medir contraste
  de novo, e decidir o que fazer com `EmeraldColors.primary #20D99A`, que não
  tem equivalente normativo.
- **C — Light+dark com as duas paletas atuais (esmeralda escuro + `AppColors`
  claro).** Prós: aproveita código que já existe; nenhum valor novo. Contras:
  app e site continuam diferentes; o tema claro nunca foi renderizado nem
  testado, então "existe" não significa "funciona"; exige preferência de tema
  persistida e teste de troca.
- **D — Não fazer.** Prós: custo zero. Contras: três paletas convivendo, uma
  delas morta, o normativo descrevendo cores que o app não usa, e o startup
  gate como fonte de verdade acidental do fundo. Qualquer refactor de
  componente herda a ambiguidade.

## Consequências e reversão

- **Positivas:** uma paleta declarada por superfície; fim do tema morto;
  startup e resultado passam a usar tokens, o que reduz o blast radius de
  qualquer mudança visual futura; o teste de contraste do site ganha
  equivalente no app (ADR-0012).
- **Negativas/custos:** emenda normativa aprovada em 2026-11-07, mas ainda
  precisa ser executada; remover `AppTheme.light` apaga trabalho já feito (e o teste
  `test/ux/startup_test.dart:13-46` precisaria ser revisto, não removido);
  trocar paleta muda a identidade percebida do produto.
- **Riscos:** mudar `scaffoldBackgroundColor` de `transparent` para uma cor
  pode alterar telas que dependem de um fundo pintado por trás (gradient,
  imagem). Mitigação: caracterização visual antes, não depois.
- **Reversão:** A e C são só Dart — `git revert`. B também, mas depois de
  migrar 115 usos o revert é grande e conflita com qualquer trabalho visual
  feito em cima; por isso B pede um commit único e isolado.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/16 - Design system e componentes|Área 16]],
  [[../../09 - Auditoria/Áreas/15 - CI-CD, releases, site, Web e PWA|Área 15]],
  [[../../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|Área 18]].
- Código: [app_theme.dart](../../../lib/core/theme/app_theme.dart),
  [app.dart](../../../lib/app.dart),
  [startup_gate.dart](../../../lib/core/startup/startup_gate.dart),
  [result_page.dart](../../../lib/features/result/result_page.dart),
  [site/styles.css](../../../site/styles.css), [AGENTS.md](../../../AGENTS.md).
- Testes: [test/ux/startup_test.dart](../../../test/ux/startup_test.dart),
  [site/tests/site.test.cjs](../../../site/tests/site.test.cjs),
  [onboarding_responsive_test.dart](../../../test/onboarding_responsive_test.dart).
- **Exigido antes de implementar:** decisão explícita do responsável sobre
  qual paleta vale para qual superfície; renderização do tema claro se ele
  for mantido; teste de contraste no app (hoje só o site tem); caracterização
  do fundo do scaffold antes de trocar `Colors.transparent`.
- Comandos de reprodução:
  `grep -roE "EmeraldColors\." lib/ | wc -l` → 115;
  `grep -roE "Color\(0x" lib/ --include=*.dart | wc -l` → 37;
  `grep -rlE "Color\(0x" lib/ --include=*.dart` → 3 arquivos;
  `grep -rn "ThemeMode" lib/` → só `lib/app.dart:23`.
- Relacionados: [[ADR-0012 - Acessibilidade, tema e contraste|ADR-0012]],
  [[ADR-0008 - Hierarquia documental e versionamento do vault|ADR-0008]],
  [[../../01 - Produto/Study Surface|Study Surface]].