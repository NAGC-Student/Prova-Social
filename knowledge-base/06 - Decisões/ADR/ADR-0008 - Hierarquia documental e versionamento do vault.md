---
tipo: adr
area: documentação e hierarquia
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, README.md, .gitignore, knowledge-base/, docs/historico/, git log]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0008 — Hierarquia documental e versionamento do vault

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 18
- **Urgência:** Alta

## Contexto

Três correções ao que a auditoria registrou, todas medidas hoje:

- **O vault está versionado.** `git ls-files knowledge-base | wc -l` = **78**
  arquivos, dos quais **72** `.md` e **13.198** linhas no total
  (`find knowledge-base -name "*.md" -exec cat {} + | wc -l`). Medida **antes**
  deste lote: com os 12 ADRs commitados são **90** arquivos (**84** `.md`).
  Entrou no Git
  em `eebb2b0` (“docs(vault): versiona a knowledge-base dentro do repositório
  do app”). A nota da área 18 ainda afirma `git ls-files knowledge-base` = 0
  (`Áreas/18 - Documentação e divergências código × docs.md:56-57,81,147`) —
  **está obsoleta** e é corrigida por este ADR.
- **O estado de dispositivo está ignorado, sim.** Não existe `.gitignore`
  dentro do vault, mas o `.gitignore` da raiz cobre o caso:
  `.gitignore:67-70` ignora `knowledge-base/.obsidian/workspace.json`,
  `workspace-mobile.json`, `.obsidian/cache/` e `knowledge-base/.trash/`.
  `git check-ignore -v knowledge-base/.obsidian/workspace.json` casa em
  `.gitignore:67`. Os 6 arquivos `.obsidian` rastreados são configuração
  compartilhável (`app`, `appearance`, `community-plugins`, `core-plugins`,
  `graph`, `templates`), e `community-plugins.json` contém `[]`. A conclusão
  da área 18 de que “sem `.gitignore` a regra não é aplicável” procede de
  procurar o arquivo no lugar errado.
- **A raiz não guarda mais os relatórios.** Depois de `e084ef6`, os 16 `.md`
  soltos foram para `docs/historico/` (`git ls-files docs/historico | wc -l`
  = 16) e a raiz tem apenas `README.md` e `AGENTS.md`. A instrução
  `AGENTS.md:741` (“Mantenha relatórios e guias existentes **na raiz** como
  fontes históricas”) agora aponta para um lugar que não os contém.

Divergências que continuam abertas:

- **Numeração duplicada no normativo.** `AGENTS.md:483` é
  `## 15. Offline e sincronização` e `AGENTS.md:706` é
  `## 15. Base de conhecimento do projeto`. Duas seções 15, e as seguintes
  (16 a 24) já foram usadas antes da segunda 15 aparecer.
- **Hierarquia declarada, mas sem regra de conflito.** `AGENTS.md:716-718`
  diz que o `AGENTS.md` “continua sendo a fonte normativa para princípios e
  requisitos do produto” e que as notas do vault “resumem, relacionam e
  auditam essas diretrizes, sem substituí-las”. Não há regra escrita para o
  caso em que uma nota auditada contradiz o normativo (é o caso de
  `AGENTS.md:365` × publicação só objetiva, e de `AGENTS.md:62` ×
  `app_theme.dart:20`).
- **Conteúdo divergente não resolvido.** `docs/historico/DESIGN_SYSTEM.md:18`
  declara fundo escuro `#101311`; `lib/core/theme/app_theme.dart:20` usa
  `#050907`. `docs/historico/DEPENDENCY_COMPATIBILITY.md:1` declara
  “Prova Social 0.5.0”; `pubspec.yaml:4` é `0.7.5+15`. Mover os arquivos não
  corrigiu o conteúdo, e nenhum dos dois tem banner de histórico.
- **Volume concentrado.** A auditoria é a maior parte do vault; a nota
  [[../../09 - Auditoria/Síntese da Refatoração|Síntese da Refatoração]] tem
  524 linhas e as áreas 13, 14 e 15 são as mais longas. Não há nota de
  entrada que diga “leia isto primeiro e ignore o resto por enquanto” além
  do [[../../00 - Central/Índice|Índice]].

**Limites.** A contagem de linhas é do estado de trabalho em `e084ef6`; não
há medição de quantas notas estão obsoletas além das citadas aqui. Não foi
verificado se o vault aberto no Obsidian de outro dispositivo tem estado
divergente — isso é local por definição.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **manter o vault versionado no repositório do app e
corrigir a hierarquia documental** — não separar o vault (B), não apagar os
históricos (C) e não abandonar o Obsidian (D). A decisão, em ordem de custo,
é:

1. **Corrigir o normativo sem reescrevê-lo:** renomear a segunda seção 15
   para 25 (ou inserir como 15-A) e atualizar `AGENTS.md:741` para apontar
   `docs/historico/`. Mudança de duas linhas, sem tocar em requisitos.
2. **Escrever a regra de precedência em uma frase:** normativo vence nota;
   nota auditada com evidência `file:line` vence documento histórico;
   documento histórico só é corrigido com banner de data, nunca em silêncio.
   Registrar isso no `AGENTS.md` e no `README` do vault.
3. **Dar banner de histórico aos 16 arquivos movidos** (ou pelo menos aos
   dois que ainda contradizem o código: `DESIGN_SYSTEM.md` e
   `DEPENDENCY_COMPATIBILITY.md`), dizendo “congelado em `<data>`, não
   reflete `0.7.5+15`, fonte viva é o vault”.
4. **Manter o versionamento como está:** vault no mesmo repositório do app,
   `.gitignore` da raiz cobrindo estado de dispositivo. Não criar
   `.gitignore` dentro do vault (duplicaria a regra) e não separar o vault em
   repositório próprio (quebraria a consulta conjunta código × evidência que
   o `AGENTS.md:711-712` pede).

## Alternativas

A decisão não adota B (vault separado), C (apagar históricos) nem D
(abandonar o Obsidian); mantém o arranjo atual e corrige a hierarquia.

- **A — Não fazer.** Prós: custo zero. Contras: a área 18 continua afirmando
  que o vault não está versionado (falso), o `AGENTS.md` continua com duas
  seções 15 e mandando manter relatórios numa raiz que não os tem, e quem
  chegar pelo `DESIGN_SYSTEM.md` implementa a cor errada.
- **B — Vault em repositório separado.** Prós: histórico de docs limpo,
  permissões independentes. Contras: perde a consulta conjunta com o código
  no mesmo SHA, que é a razão declarada em `AGENTS.md:711-712`; exige
  sincronizar dois repositórios e dois `sha` de frontmatter; hoje os 78
  arquivos já estão rastreadados e referenciados por caminho relativo.
- **C — Consolidar tudo no vault e apagar os históricos.** Prós: uma fonte
  só. Contras: destrói evidência de auditoria (os relatórios registram o que
  foi medido em versões anteriores) e contradiz `AGENTS.md:741-743`, que
  manda não apagar nem substituir silenciosamente.
- **D — Consolidar tudo num `docs/` gerado e abandonar o Obsidian.** Prós:
  formato universal, sem configuração de editor. Contras: perde wikilinks,
  grafo e templates que o vault já usa; retrabalho de 72 notas; nenhum
  ganho de correção.

## Consequências e reversão

- **Positivas:** uma regra de precedência explícita encerra a classe de
  divergência “doc diz X, código faz Y” sem exigir que alguém adivinhe qual
  vale; a numeração do normativo volta a ser única; os históricos param de
  induzir erro sem deixar de existir.
- **Negativas/custos:** banner em 16 arquivos é trabalho mecânico mas
  diff grande; renomear seção do `AGENTS.md` muda âncoras usadas por
  outras notas (precisa varrer links); a regra de precedência pode
  “congelar” requisitos que o responsável queria mudar — por isso a
  aprovação foi registrada em 2026-11-07.
- **Riscos:** corrigir a área 18 sem registrar a data faria a auditoria
  parecer sempre certa; toda correção precisa de carimbo e do comando que a
  sustenta.
- **Reversão:** tudo é Markdown — `git revert` desfaz. Nenhum dado de
  usuário, nenhum schema, nenhum artefato publicado envolvido. A única
  ação irreversível seria apagar históricos (alternativa C), e por isso ela
  não é recomendada.

## Evidências e validação

- Área: [[../../09 - Auditoria/Áreas/18 - Documentação e divergências código × docs|Área 18]]
  e [[../../09 - Auditoria/Documentação e Divergências|Documentação e Divergências]].
- Documentos: [AGENTS.md](../../../AGENTS.md), [README.md](../../../README.md),
  [.gitignore](../../../.gitignore), [knowledge-base/README.md](../../README.md),
  [docs/historico/DESIGN_SYSTEM.md](../../../docs/historico/DESIGN_SYSTEM.md),
  [docs/historico/DEPENDENCY_COMPATIBILITY.md](../../../docs/historico/DEPENDENCY_COMPATIBILITY.md).
- **Exigido antes de implementar:** varredura de links depois de qualquer
  renomeação (o verificador de links relativos usado na auditoria deve
  retornar 0 quebrados); `git check-ignore -v` para cada arquivo de estado
  de dispositivo que se queira manter fora do Git; conferência de que
  nenhuma nota nova contradiz o normativo sem ADR correspondente.
- Comandos de reprodução:
  `git ls-files knowledge-base | wc -l` → 78;
  `git ls-files docs/historico | wc -l` → 16;
  `grep -n "^## 15\." AGENTS.md` → 483 e 706;
  `git check-ignore -v knowledge-base/.obsidian/workspace.json` → `.gitignore:67`;
  `git log --oneline -1 eebb2b0`.
- Relacionados: [[ADR-0001 - Paleta e tema|ADR-0001]] (cor declarada × cor
  usada), [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]]
  (declaração de “código aberto” sem licença), [[ADR-0009 - Política de dependências e pins|ADR-0009]]
  (matriz de compatibilidade congelada em 0.5.0).