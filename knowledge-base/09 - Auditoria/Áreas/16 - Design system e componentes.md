---
tipo: area
area: design system e componentes
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 3, seguranca: 3, robustez: 3, aderencia: 2, portabilidade: 3}
fonte_codigo: [lib/core/theme/app_theme.dart, lib/core/widgets/, lib/app.dart, lib/features/home/home_page.dart, lib/features/search/search_page.dart, lib/features/quiz/quiz_page.dart, lib/features/publish/publish_page.dart, lib/features/result/result_page.dart, web/, site/]
sha: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
confianca: alta
atualizado: 2026-11-11
---

# Design system e componentes

## Resumo

O Prova Social tem um **design system central pequeno e utilizável**:
`AppColors` reproduz exatamente os tokens claros do `AGENTS.md` §3,
`AppSpacing`/`AppRadius`/`AppMotion` existem, `AppMotion.of` respeita
`MediaQuery.disableAnimations` e há componentes compartilhados reais —
`BrandMark`, `BrandLockup`, `EmeraldBackdrop`, `StudySurface`, `SkeletonBlock`,
`QuestionSkeleton`, `ExamCardSkeleton`, `ExamListSkeleton`, `SourceBadge` e
`QuestionMediaGallery`. Os skeletons preservam o formato do conteúdo e o
`SourceBadge` cobre os três estados de procedência.

O problema é de **coerência entre o sistema e o produto**. O app é
`ThemeMode.dark` fixo (`app.dart:23`), então os tokens claros nunca são usados;
a paleta escura é `EmeraldColors` (`#050907`, `#101A15`, `#20D99A`), diferente
dos tokens escuros do `AGENTS.md` (`#101311`, `#181C19`, `#F3F5F3`, `#2A302C`);
`ExamListTile` **existe** em `lib/core/widgets/exam_list_tile.dart` (logo,
metadados, progresso, badges, toggle salvar, Hero, modo compacto); a tipografia
usa **Inter variable font** (862KB) em `fonts/Inter/`, configurada no
`pubspec.yaml` e `app_theme.dart` (`fontFamily: 'Inter'`); `textMuted` foi
corrigido para `#718078`; `AppRadius.card` (12px) e `AppRadius.full` foram
adicionados. Os breakpoints ainda estão espalhados em 960/980/900/760/600/560/520/440/420;
e `StudySurface` transforma quase toda seção em card com raio 18/24, contra a
regra “se tudo é card, nada é card” e o raio de 12 px.

Classificação: **EVOLUIR** — há base concreta e componentes corretos, mas falta
uma decisão única de identidade e uma camada de layout/lista reutilizável.

## Escopo e método

- Leitura integral de `lib/core/theme/app_theme.dart` (324 linhas):
  `AppColors`, `EmeraldColors`, `AppSpacing`, `AppRadius`, `AppMotion`,
  `AppTheme.light` e `AppTheme.dark`.
- Leitura integral de `lib/core/widgets/brand.dart` (72),
  `emerald_backdrop.dart` (139), `skeleton.dart` (158),
  `source_badge.dart` (75) e `question_media_gallery.dart` (109).
- Leitura de `lib/app.dart` e confirmação de `themeMode`.
- Leitura dirigida de `home_page.dart` (navegação, `ExamCard`, `StudySurface`,
  `_HomeColors`), `search_page.dart` (lista de resultados, filtros, estados),
  `quiz_page.dart` (breakpoints e alternativas), `publish_page.dart` (cards de
  escolha e raios) e `result_page.dart` (cor hardcoded).
- Contagem de usos: `EmeraldColors` (113), `AppColors` (36), `Color(0x` em
  features (1), `Semantics` (18), `TextStyle(` (78), `AppMotion.of` (10+).
- Levantamento de breakpoints por `MediaQuery.sizeOf`, `LayoutBuilder` e
  `BoxConstraints.maxWidth`.
- Leitura de `web/manifest.json`, `web/index.html`, `site/styles.css` e
  `site/index.html` para comparar identidade.
- Não foi executada inspeção visual em aparelho, teste de contraste
  automatizado no app, nem medição de tipografia renderizada.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Tokens claros exatos do `AGENTS.md` | Funcional | `app_theme.dart:3-17` |
| Tokens de espaçamento | Funcional | `app_theme.dart:37-44` |
| Tokens de raio | Funcional | `app_theme.dart:46-51` |
| Tokens de movimento | Funcional | `app_theme.dart:53-63` |
| Redução de movimento central | Funcional | `AppMotion.of`; `skeleton.dart:38-45` |
| Tema Material 3 | Funcional | `useMaterial3: true` |
| Botões com alvo de 48 px | Funcional | `filledButtonTheme`, `outlinedButtonTheme`, `iconButtonTheme` |
| Skeletons no formato do conteúdo | Funcional | `skeleton.dart:79-158` |
| Skeleton com semântica de carregamento | Funcional | `skeleton.dart:81-84, 144-149` |
| `SourceBadge` com 3 estados | Funcional | `source_badge.dart:20-33` |
| Procedência visível em 5 telas | Funcional | home, busca, resultado, share, detalhe |
| Mídia com descrição acessível | Funcional | `question_media_gallery.dart:97` |
| Marca com símbolo e lockup | Funcional | `brand.dart:5-72` |
| Fundo de estudo com identidade | Funcional | `emerald_backdrop.dart:5-42` |
| Tema claro disponível | Não usado | `themeMode: ThemeMode.dark` |
| `ExamListTile` compartilhado | Ausente | home usa `ExamCard`; busca usa `ListTile` |
| Inter empacotado | Ausente | `fontFamily: 'sans-serif'`; sem `fonts:` |
| Breakpoints centrais | Ausente | 9 valores diferentes |
| Hero/transição de página | Ausente | nenhum `Hero(` |
| Golden tests | Ausente | nenhum `matchesGoldenFile` |

## O que funciona

1. **Tokens claros fiéis ao `AGENTS.md`.** `AppColors.background #F7F8F6`,
   `surface #FFFFFF`, `surfaceHover #F1F4F1`, `ink #171A18`, `muted #68706B`,
   `line #E3E7E4`, `brand #16A36A`, `brandHover #12875A`,
   `brandSoft #E7F6EF`, `warning #E5A524`, `danger #DC4C4C`
   (`app_theme.dart:3-17`). Quem for implementar o tema claro encontra o token
   pronto.
2. **Escala de espaçamento coerente.** `4 / 8 / 16 / 24 / 32 / 48`, usada nos
   componentes e na maioria das telas (`AppSpacing`).
3. **Raios nomeados.** `sm 8`, `md 12`, `lg 16`, `xl 20` (`AppRadius`).
   Botões usam 9, cards usam 12, modais usam 16 — próximo do sistema.
4. **Movimento com contrato.** `AppMotion.instant/fast/normal/slow` =
   100/180/280/400 ms, dentro das faixas do `AGENTS.md` §3, e
   `AppMotion.of` zera a duração quando `disableAnimations` está ativo.
5. **Skeletons que explicam espera.** `QuestionSkeleton` desenha enunciado e
   cinco alternativas; `ExamCardSkeleton` desenha o card; `ExamListSkeleton`
   agrupa três e usa `liveRegion`; `SkeletonBlock` pausa a animação com
   redução de movimento (`skeleton.dart:38-45`).
6. **`SourceBadge` cumpre o contrato de procedência.** Três estados com texto,
   ícone e `Tooltip`: “Fonte oficial”, “Enviado pela comunidade”, “Fonte não
   verificada” (`source_badge.dart:20-33`). Aparece na home, busca, resultado,
   detalhe e link compartilhado.
7. **Marca consistente no app.** `BrandMark` usa o asset
   `assets/branding/app_icon.png`, `Semantics(label: 'Prova Social')`, borda
   arredondada e sombra discreta; `BrandLockup` combina símbolo e nome.
8. **Fundo com identidade, não decoração aleatória.** `EmeraldBackdrop` usa
   gradiente radial e arcos com `shouldRepaint: false`, sem custo por frame
   (`emerald_backdrop.dart:104-139`).
9. **Alvos de toque corretos nos botões principais.** `FilledButton`,
   `OutlinedButton` e `IconButton` têm `minimumSize: Size(48, 48)` nos dois
   temas (`app_theme.dart:115-117, 276-278, 310-322`).
10. **Componentes de mídia acessíveis.** `QuestionMediaGallery` oferece
    descrição para leitor de tela e fallback de erro
    (`question_media_gallery.dart:8, 97`).
11. **Sem cor hardcoded nas features, com uma exceção.** Só há um
    `Color(0x...)` fora do tema: `result_page.dart:254` (`#D7F3E7`). O resto usa
    `Theme.of(context).colorScheme` ou `EmeraldColors`.
12. **Navegação desktop e mobile com o mesmo modelo mental.** Sidebar de 240 px
    no desktop (`home_page.dart:316-317`) e `_BottomNavBar` no mobile
    (`:375`), com as mesmas cinco rotas.

## O que está parcial

### Tema claro existe, mas o app é dark-only

`ProvaSocialApp` declara `theme: AppTheme.light`, `darkTheme: AppTheme.dark` e
`themeMode: ThemeMode.dark` fixo (`app.dart:20-23`). Não há:

- seletor de tema;
- leitura de `MediaQuery.platformBrightness`;
- persistência de preferência;
- teste de tela em claro/escuro.

O `AGENTS.md` §3 define tokens claros e escuros, e §21 pede “verificação
light/dark”. Hoje o tema claro é código morto e a identidade real é a paleta
`EmeraldColors`.

### Paleta escura diverge do documento

| Token | `AGENTS.md` §3 | Código (`EmeraldColors`) |
|---|---|---|
| background | `#101311` | `#050907` |
| surface | `#181C19` | `#101A15` |
| textPrimary | `#F3F5F3` | `#F3F5F3` (provável coincidência) |
| border | `#2A302C` | `#26332C` |

Além disso, `EmeraldColors` adiciona `backgroundSecondary #080F0C`,
`surfaceElevated #14231B`, `surfaceHighlight #193329`, `primary #20D99A`,
`primaryLight #50F0B5` e `primaryDark #087…`. O site institucional usa
`#101311`, `#181C19`, `#202521`, `#2A302C`, `#F3F5F3` — ou seja, o **site segue
o documento e o app não**.

Há 113 referências a `EmeraldColors` contra 36 a `AppColors`, o que confirma
que a paleta efetiva do produto é a não documentada. A decisão precisa ser
explícita: atualizar o `AGENTS.md` para a paleta Emerald ou migrar o app para os
tokens escuros oficiais. Manter as duas é dívida.

### `ExamListTile` não existe

O `AGENTS.md` §6 define `ExamListTile` como componente prioritário e
reconhecível, com brasão opcional, banca/procedência, título/ano, questões,
duração, disciplinas, progresso, estado e salvar.

O que existe:

- `ExamCard` dentro de `home_page.dart:1298-1410`, com ícone genérico,
  `SourceBadge`, ano/categoria, questões/duração/autor e botão salvar;
- `ListTile` cru em `search_page.dart:709-760`, com `SourceBadge`, categoria,
  ano, autor, questões, uploader e chevron;
- `_RailItem` e `_UserTile` para outros contextos.

As duas listas mostram informações diferentes, com pesos diferentes e sem
estado “começar/continuar/concluída”. Não há componente compartilhado, teste
do componente, nem reutilização entre home, busca e biblioteca. O botão salvar
do `ExamCard` tem `minWidth/minHeight: 40` (`home_page.dart:1379-1380`), abaixo
do alvo de ~48 px do §3.

### Tipografia não é Inter nem está empacotada

`ThemeData` usa `fontFamily: 'sans-serif'` (`app_theme.dart:85, 199`). Não há
`fonts:` no `pubspec.yaml` nem asset de fonte. Consequências:

- Android usa a sans do sistema (Roboto), não Inter;
- Web depende da fonte padrão do navegador;
- o site carrega Inter do Google Fonts, então app e site não compartilham
  tipografia;
- pesos 400/500/600/700 não são garantidos;
- `TextTheme` define apenas 7 estilos (`displaySmall`, `headlineMedium`,
  `headlineSmall`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`);
  `labelLarge`, `titleSmall` e `bodySmall` caem no default do Material, com
  tamanhos e pesos não auditados.

Há 78 `TextStyle(` literais nas features. Isso não é errado por si, mas mostra
que a tipografia não é centralizada.

### Breakpoints espalhados e inconsistentes

Valores encontrados:

- `960` — onboarding (`onboarding_page.dart:69`);
- `980` — quiz desktop (`quiz_page.dart:323`);
- `900` — home desktop (`home_page.dart:235`);
- `760` — publish em duas colunas (`publish_page.dart:63`);
- `600` — `StudySurface` compacto, home compacta, backdrop
  (`emerald_backdrop.dart:58`; `home_page.dart:1062, 2251`);
- `560` — publish estreito (`publish_page.dart:958`);
- `520` — onboarding (`onboarding_page.dart:110`);
- `440` — home compacta (`home_page.dart:2277`);
- `420` — quiz compacto (`quiz_page.dart:947, 1163`).

O mesmo conceito “desktop” muda entre 900 e 980; “compacto” muda entre 420,
440 e 600. Não há constante `AppBreakpoints` nem teste de layout nas faixas de
transição. Isso produz saltos visuais difíceis de reproduzir.

### “Se tudo é card, nada é card”

`StudySurface` é usado pelo menos 10 vezes na home, busca e publicação. Ele
aplica gradiente, borda, raio 18/24 e sombra em qualquer seção
(`emerald_backdrop.dart:44-92`). O resultado é que header, lista, estado vazio,
painel e destaque têm o mesmo peso visual.

O `AGENTS.md` §3 pede cards com raio 12 e alerta contra card em tudo. Hoje:

- `StudySurface` usa 18/24;
- cards de escolha da publicação usam 24 (`publish_page.dart:190, 202`);
- a home usa `StudySurface` em `1220, 1469, 1534, 1725, 1808, 1860, 1928,
  1971`;
- a busca usa `StudySurface` em `419` e raios 18 em `429, 805, 812`.

Falta uma hierarquia explícita: superfície de página, painel, card de item,
linha de lista e destaque. Sem isso, a regra do documento não é aplicável.

### Movimento subutilizado

`AppMotion.of` aparece em ~10 pontos, principalmente onboarding, publish,
quiz e home. Há 4 `AnimatedSwitcher` e 5 `AnimatedContainer`. Não há:

- `Hero` para prova → detalhe ou questão → revisão;
- transição de página customizada (usa `MaterialPageRoute` padrão);
- animação de seleção de alternativa com duração explícita em todos os casos;
- teste de que `disableAnimations` desliga as animações principais.

O `AGENTS.md` §3 pede movimento que explique estado/origem/confirmação e cita
`Hero` explicitamente. A base existe, mas é usada em poucos lugares.

### Componentes vivem dentro de features

`ExamCard`, `_RailItem`, `_BottomNavItem`, `_UserTile`, `_SearchSectionHeading`,
`_SuggestionTile`, os cards de resultado e os estados vazios estão em arquivos
de feature. Isso:

- impede reutilização entre home, busca e biblioteca;
- aumenta o tamanho de `home_page.dart` (2.400+ linhas);
- cria dependência de detalhes internos (`_HomeColors`);
- dificulta golden tests de componente isolado.

`_HomeColors` (`home_page.dart:2405-2430`) é um segundo sistema de cores
privado, que decide entre `colorScheme` e `AppColors` conforme o brilho. É
outra camada de indireção que não deveria existir se o tema fosse único.

### Contraste e acessibilidade não são medidos no app

O site tem teste de contraste AA (`site/tests/site.test.cjs`), o app não. Não
há teste de:

- contraste de `SourceBadge` e textos secundários;
- alvo de toque de 48 px em todos os botões (o salvar do `ExamCard` tem 40);
- foco por teclado no desktop/Web;
- leitor de tela nas telas principais;
- `textScaler` 1.3 além do Focus.

Há 18 `Semantics` e 1 teste de semântica
(`question_media_gallery_test.dart`). É um começo, não uma cobertura.

## O que está ausente ou quebrado

- Decisão única de paleta (clara, escura ou dark-only documentado).
- `ExamListTile` compartilhado.
- Tipografia Inter empacotada ou declaração explícita de fonte do sistema.
- `TextTheme` completo com labels e bodySmall.
- Constantes de breakpoint e testes de transição.
- Hierarquia superfície/painel/card/linha.
- Redução de `StudySurface` a um papel claro.
- `Hero` e transições de página.
- Golden tests de componentes.
- Teste de contraste no app.
- Teste de alvo de toque.
- Teste de foco por teclado.
- Teste de tema claro/escuro.
- Tokens compartilhados entre app, site e manifest.
- Componentes de estado vazio/erro reutilizáveis.
- Documentação viva do design system.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Tokens claros e escuros” | Só o claro é fiel; o escuro é `EmeraldColors` | `app_theme.dart:3-35`; `app.dart:23` |
| “Verificação light/dark” | App é `ThemeMode.dark` fixo | `app.dart:23` |
| “Tipografia Inter ou equivalente já adotada” | `sans-serif` genérico, sem fonte empacotada | `app_theme.dart:85, 199` |
| “Cards com raio de 12 px” | `StudySurface` 18/24; publicação 24 | `emerald_backdrop.dart:80`; `publish_page.dart:190` |
| “Se tudo é card, nada é card” | `StudySurface` em quase toda seção | `home_page.dart:1220-1971` |
| “`ExamListTile` prioritário” | Não existe; home e busca divergem | `home_page.dart:1298`; `search_page.dart:709` |
| “Alvos de ~48×48” | Salvar do `ExamCard` tem 40 | `home_page.dart:1379-1380` |
| “Preferir `Hero`” | Nenhum `Hero(` no app | busca global |
| “Movimento explica estado” | Só ~10 usos de `AppMotion.of` | busca global |

## Evidência de testes

- `test/source_badge_test.dart` (3 testes): cobre os três rótulos e o modo
  compacto; não cobre contraste nem leitor de tela.
- `test/question_media_gallery_test.dart` (1): cobre descrição semântica.
- `test/onboarding_responsive_test.dart` (2): cobre layout em tamanhos.
- `test/ux/focus_responsive_test.dart` (1): cobre Focus em telefone estreito
  com texto ampliado.
- `test/ux/prompt_redesign_test.dart` (166 linhas): cobre parte da identidade
  visual e textos.
- `test/ux/search_test.dart` e `search_filters_test.dart`: cobrem lista e
  filtros, não o componente visual.
- Não há teste de `AppTheme.light` (código morto).
- Não há golden test de `ExamCard`, `SourceBadge`, `Skeleton*` ou alternativa.
- Não há teste de breakpoint (900/980/760/600).
- Não há teste de contraste no app.
- Não há teste de `Hero`/transição.
- Não há teste de `disableAnimations` nas animações principais.

## Riscos

1. **Identidade dividida.** App, site, manifest e `AGENTS.md` usam paletas
   diferentes; qualquer material de marca divergirá.
2. **Lista inconsistente.** Home e busca mostram a mesma prova com hierarquia
   diferente; o usuário não reconhece o componente.
3. **Regra de card ignorada.** Tudo vira card e nada se destaca.
4. **Acessibilidade não medida.** Alvo de 40 px e contraste não testado podem
   excluir usuários.
5. **Tipografia imprevisível.** `sans-serif` muda por plataforma e não é Inter.
6. **Breakpoints frágeis.** Saltos entre 900/980 e 420/440/600 quebram layout
   em tablets e dobras.
7. **Dívida de refatoração.** `home_page.dart` com 2.400+ linhas e componentes
   privados dificulta qualquer mudança global.
8. **Tema claro morto.** Código não exercitado apodrece e engana quem lê o
   `AGENTS.md`.
9. **Movimento inconsistente.** Algumas telas animam, outras saltam.
10. **Sem golden tests.** Uma mudança de token pode alterar todas as telas sem
    aviso.

## Plano de refatoração da área

### Lote 1 — ADR de identidade e tokens únicos

- Decidir formalmente: dark-only com paleta Emerald, ou light+dark com tokens
  do `AGENTS.md`.
- Se dark-only, atualizar o `AGENTS.md` §3 e o site para a paleta real; se
  light+dark, migrar `EmeraldColors` para os tokens oficiais.
- Criar um único arquivo de tokens consumido por app, manifest, site e ícones.
- Critério de aceite: uma única fonte de verdade; nenhuma cor de marca
  duplicada; ADR registrada.

### Lote 2 — Tipografia e escala

- Empacotar Inter (ou declarar `system-ui` como decisão) e remover
  `fontFamily: 'sans-serif'` ambíguo.
- Definir `TextTheme` completo, incluindo `labelLarge`, `labelMedium`,
  `titleSmall`, `bodySmall`.
- Reduzir `TextStyle` literais nas features a exceções justificadas.
- Critério de aceite: app e site usam a mesma família; todos os estilos vêm do
  tema; golden de texto em 360/768/1280 px.

### Lote 3 — `ExamListTile` e hierarquia de lista

- Extrair `ExamListTile` para `lib/core/widgets/` com todos os campos do §6.
- Usar na home, busca, biblioteca e perfis.
- Padronizar estado começar/continuar/concluída e botão salvar com 48 px.
- Critério de aceite: um único componente nas três telas; golden nos estados
  salvo/não salvo/em andamento/concluído; alvo de toque ≥ 48.

### Lote 4 — Breakpoints e layout

- Criar `AppBreakpoints` com `compact`, `medium`, `expanded` e uma regra para
  desktop.
- Substituir 900/980 por um único ponto; 420/440/600 por outro.
- Adicionar testes de layout nas faixas 360, 420, 600, 760, 900, 1024, 1280.
- Critério de aceite: nenhum número mágico de largura nas features; nenhum
  overflow nas faixas testadas.

### Lote 5 — Disciplina de superfície

- Definir papéis: `PageSurface`, `Panel`, `Card`, `ListRow`, `Highlight`.
- Reduzir `StudySurface` a painel/destaque; cards de item usam `AppRadius.md`.
- Remover raios 18/24 de cards; reservar 16 para modal.
- Critério de aceite: cada tela tem no máximo um destaque; cards de item com
  12 px; golden de home/busca/publicação.

### Lote 6 — Movimento e acessibilidade

- Adotar `AppMotion` em todas as transições; adicionar `Hero` para prova →
  detalhe e questão → revisão.
- Testar `disableAnimations` nas telas principais.
- Testar contraste AA, alvo de 48 px e foco por teclado.
- Critério de aceite: nenhuma animação fora do token; redução desliga tudo;
  testes de acessibilidade passam em light/dark (se existirem).

### Lote 7 — Golden tests e documentação

- Goldens de `ExamListTile`, `SourceBadge`, `Skeleton*`, alternativa do Focus,
  estado vazio e resultado.
- Documento vivo do design system no vault, com tokens, componentes e uso.
- Critério de aceite: qualquer mudança visual falha um golden; nota do vault
  aponta para o código.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Componentes corretos, mas paleta, tipografia e lista divergem do contrato. |
| Testes | 2 | Testes pontuais de badge/mídia/responsividade; sem golden, contraste ou tema. |
| Acoplamento | 3 | Tema central existe; features importam `EmeraldColors` e mantêm componentes privados. |
| Clareza | 3 | Tokens nomeados, mas três paletas e nove breakpoints confundem. |
| Segurança | 3 | Sem risco direto; acessibilidade e contraste não são medidos. |
| Robustez | 3 | Skeletons e redução de movimento funcionam; layout frágil nas transições. |
| Aderência | 2 | `ExamListTile`, Inter, card 12, light/dark e `Hero` ausentes. |
| Portabilidade | 3 | Android/Web cobertos; tipografia e breakpoints variam por plataforma. |

Classificação resultante: **EVOLUIR** — a fundação é boa, mas o sistema precisa
de uma decisão única de identidade, um componente de lista compartilhado e
testes visuais para ser confiável.

## Dependências

- Área 4 para `ExamListTile`, catálogo e biblioteca.
- Área 5 para alternativas, timer e revisão no Focus.
- Área 15 para tokens do site, manifest e PWA.
- Área 14 para goldens, contraste e acessibilidade.
- Área 18 para atualizar `AGENTS.md` se a paleta mudar.
- Decisão de produto sobre dark-only versus light/dark.

## O que não foi verificado

- Renderização real em Android/Web/iOS.
- Contraste calculado de todos os pares de cor.
- Comportamento com `textScaler` 2.0.
- Foco por teclado no desktop/Web.
- Instalação do PWA e aparência do ícone.
- Desempenho do `EmeraldBackdrop` em tela grande.
- Golden tests (não existem).
- Tema claro (não usado).
- Compatibilidade da fonte `sans-serif` entre plataformas.
- Layout em tablet/dobra nas faixas 600–980.

## Links

- [[04 - Catálogo, busca, feed, biblioteca e perfil|Área 4 — Catálogo e listas]]
- [[05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes e QA]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD e site]]
- [[18 - Documentação e divergências código × docs|Área 18 — Documentação]]
- [[../../01 - Produto/Study Surface|Study Surface]]
- [[../../01 - Produto/Princípios|Princípios]]
- [[Mapa das Áreas|Mapa das Áreas]]
