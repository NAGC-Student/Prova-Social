---
tipo: area
area: Focus Mode, timer, navegação e finalização
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 3, acoplamento: 3, clareza: 4, seguranca: 4, robustez: 3, aderencia: 2, portabilidade: 3}
fonte_codigo: [lib/features/quiz/quiz_page.dart, lib/core/backend/focus_timer_settings.dart, lib/core/backend/attempt_draft_store.dart, test/focus_timer_settings_test.dart, test/quiz_draft_exit_test.dart, test/quiz_offline_submission_test.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Focus Mode, timer, navegação e finalização

## Resumo

O Focus Mode é a área mais madura do aplicativo. Ele remove a navegação social,
mostra questão atual/total, progresso, respondidas e marcadas, preserva imagens,
oferece alternativas com resposta imediata, navegação anterior/próxima, marcação
para revisão, navegador no desktop e faixa compacta no mobile, salva cada resposta
no aparelho e retoma do ponto salvo. A finalização grava a entrega localmente
antes de tentar a rede e nunca perde a tentativa. As lacunas são de aderência ao
produto: o tempo é configurado **dentro** da prova e vale globalmente, só existe
**um** cronômetro ativo por vez, o relógio não compensa suspensão do app, não há
questão discursiva e o modal contextual só aparece ao finalizar, não ao avançar
de uma questão em branco ou marcada. Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/features/quiz/quiz_page.dart` (1.501 linhas) e
  `lib/core/backend/focus_timer_settings.dart` (94).
- Leitura dos testes `test/focus_timer_settings_test.dart` (262),
  `test/quiz_draft_exit_test.dart` (91), `test/ux/focus_responsive_test.dart`
  (53) e dos nomes/casos de `test/quiz_offline_submission_test.dart` (441).
- Inspeção de `AppMotion` em `lib/core/theme/app_theme.dart` para redução de
  movimento.
- Não foi executado o app em aparelho real, não foi testada suspensão/retomada
  do processo e não foi aberta uma prova discursiva. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Remoção de feed, notificações e navegação social | Funcional | `quiz_page.dart:208-292` |
| Questão atual, total, respondidas e marcadas | Funcional | `quiz_page.dart:932-991` |
| Barra de progresso por posição | Funcional | `quiz_page.dart:279-291` |
| Enunciado selecionável e imagens | Funcional | `quiz_page.dart:1004-1026` |
| Alternativas com letra, toque e contraste | Funcional | `quiz_page.dart:1028-1103` |
| Feedback visual de seleção | Funcional | `quiz_page.dart:1040-1099` |
| Anterior/próxima | Funcional | `quiz_page.dart:443-461, 1108-1195` |
| Marcar para revisão | Funcional | `quiz_page.dart:443-453, 1138-1149` |
| Navegador de questões no desktop | Funcional | `quiz_page.dart:1197-1254` |
| Faixa compacta no mobile | Funcional | `quiz_page.dart:1256-1289` |
| Estados sem depender só de cor | Funcional | ícone de check e borda em `quiz_page.dart:1291-1358`; legenda `1367-1406` |
| Persistência imediata da resposta | Funcional | `quiz_page.dart:428-434`; status `326-367` |
| Retomada de respostas, revisão e posição | Funcional | `quiz_page.dart:74-146` |
| Salvamento ao sair e ao pausar | Funcional | `quiz_page.dart:167-186, 490-541` |
| Cronômetro livre, total ou por questão | Parcial | `focus_timer_settings.dart:10-37`; `quiz_page.dart:671-758` |
| Ocultar/revelar cronômetro | Funcional | `quiz_page.dart:729-748` |
| Configuração antes de iniciar | Ausente | só o ícone dentro da prova, `quiz_page.dart:268-276` |
| Dois cronômetros simultâneos | Ausente | `FocusTimeLimit` é exclusivo |
| Modal ao avançar de questão em branco/marcada | Ausente | `onNext` só chama `_selectQuestion`, `quiz_page.dart:454-460` |
| Modal ao finalizar | Funcional | `quiz_page.dart:543-559, 1408-1501` |
| Entrega local antes da rede | Funcional | `quiz_page.dart:572-668` |
| Retomada de entrega pendente | Funcional | `quiz_page.dart:90-118` |
| Questão discursiva | Ausente | só `options` e `answers<int,int>` |
| Sincronização em segundo plano durante a prova | Ausente | draft é local; sync só na finalização |

## O que funciona

1. **Foco real.** A tela não tem barra de navegação, feed, notificações ou abas.
   O app bar tem sair, compartilhar a questão, cronômetro e configuração; o resto
   é a questão (`quiz_page.dart:208-292`). Isso cumpre o princípio de que a rede
   social desaparece ao iniciar a prova.
2. **Persistência imediata e observável.** Cada toque em alternativa chama
   `_persistDraft()` sem bloquear a UI e o estado aparece como “Salvando”,
   “Salvo” ou “Falha ao salvar”, com “Tentar novamente”
   (`quiz_page.dart:428-434, 326-367`). Ao sair, a tela espera a gravação
   pendente antes de fechar (`quiz_page.dart:490-541`; teste
   `quiz_draft_exit_test.dart:32-90`).
3. **Retomada fiel.** Respostas, marcadas, questão atual, tempo total e
   `clientAttemptId` são restaurados; a posição é limitada ao tamanho da prova
   (`quiz_page.dart:74-146`). Se a entrega já existe, o app vai para o resultado
   ou para a tela pendente em vez de reabrir a tentativa
   (`quiz_page.dart:90-118`).
4. **Entrega à prova de rede.** A tentativa é gravada no aparelho **antes** de
   qualquer chamada remota; se a rede falhar, a tela pendente permite continuar
   (`quiz_page.dart:601-651`). O teste cobre entrega offline sem nota nem
   gabarito (`quiz_offline_submission_test.dart:335-370`).
5. **Cronômetro sem reconstruir o enunciado.** `elapsed` e `questionElapsed` são
   `ValueNotifier<int>`; apenas `_ExamTimer` escuta o contador ativo
   (`quiz_page.dart:43-44, 148-154, 685-750`). O tick não faz `setState` na
   página nem reconstrói `_QuestionContent`. Isso atende ao requisito de
   desempenho.
6. **Ocultar/revelar exatamente como pedido.** Tocar no cronômetro troca o valor
   por “Oculto” e o ícone por olho fechado; tocar de novo revela
   (`quiz_page.dart:729-748`).
7. **Estados acessíveis.** Alternativas têm `Semantics` com letra e texto
   (`quiz_page.dart:1033-1037`); números têm rótulo “respondida/não
   respondida/marcada” (`quiz_page.dart:1306-1310`); respondida usa ícone de
   check, marcada usa borda mais espessa e a legenda repete os três estados
   (`quiz_page.dart:1343-1357, 1367-1406`). Não depende só de cor.
8. **Redução de movimento.** As animações usam `AppMotion.of`, que zera a
   duração quando `disableAnimations` está ativo
   (`app_theme.dart:53-63`; `quiz_page.dart:419-423, 1040-1042, 1314-1316`).
9. **Responsividade testada.** O teste cobre 320 px de largura com texto 1,3×
   (`focus_responsive_test.dart:9-52`) e a barra do timer cabe em 360 px
   (`focus_timer_settings_test.dart:236-261`).
10. **Finalização contextual.** O modal mostra respondidas, lista as não
    respondidas e as marcadas, permite pular para qualquer uma e oferece
    “Entregar mesmo com questões em branco” (`quiz_page.dart:1408-1501`).

## O que está parcial

### Configuração do tempo dentro da prova e global

O `AGENTS.md` §8 pede configurar **antes de iniciar**:

- tempo total ligado/desligado;
- tempo por questão ligado/desligado;
- exibição dos cronômetros.

Hoje o único acesso é o ícone no app bar **depois** de a prova já ter começado
(`quiz_page.dart:268-276`), e a escolha é global e persistida em
`SharedPreferences` (`focus_timer_settings.dart:24, 49-60`; texto “A escolha vale
para todas as provas” em `quiz_page.dart:802-806`). Não existe tela de preparação
com duração oficial da prova, escolha por tentativa, nem opção de “usar o tempo
sugerido da prova”. O `Exam.durationMinutes` existe, mas não é usado para
inicializar o cronômetro.

### Um cronômetro por vez, não dois independentes

`FocusTimeLimit` é `none | total | perQuestion`
(`focus_timer_settings.dart:10`). O editor usa `SegmentedButton` e o modelo
guarda um único `limit` (`quiz_page.dart:809-831`). Portanto:

- não é possível ligar tempo total **e** tempo por questão ao mesmo tempo;
- não há dois mostradores independentes;
- “exibição dos cronômetros” vira um único botão de ocultar, não uma preferência
  por relógio.

O `AGENTS.md` descreve dois cronômetros configuráveis separadamente. A solução
atual é mais simples, mas não é o que o produto pede.

### Cronômetro não compensa suspensão do app

O tempo é contado por `Timer.periodic` que incrementa contadores a cada segundo
(`quiz_page.dart:148-154`). Quando o app vai para segundo plano, o ciclo de vida
apenas grava o rascunho (`quiz_page.dart:167-186`); não há registro de
`DateTime` de início, nem pausa/retomada explícita, nem cálculo de tempo real
decorrido. Se o sistema suspender o isolate ou o timer atrasar, o tempo exibido
fica menor que o tempo real. O total persistido é o contador, não uma diferença
de relógio.

Isso afeta a confiança do cronômetro e a duração registrada na tentativa. A
correção natural é guardar `startedAt`/`lastResumedAt` e calcular o decorrido a
partir do relógio, mantendo o tick apenas para atualizar a tela.

### Modal contextual só na finalização

O `AGENTS.md` §8 pede modal ao **tentar finalizar ou avançar** de uma questão
marcada/não respondida. Hoje:

- avançar de uma questão em branco ou marcada simplesmente vai para a próxima
  (`quiz_page.dart:454-460`);
- o modal só aparece ao tocar em “Revisar entrega” na última questão
  (`quiz_page.dart:457-459, 543-559`).

Quem está no meio da prova não recebe lembrete algum. Além disso, ao finalizar
uma prova **totalmente respondida**, o modal ainda abre e exige um toque extra
para entregar (`quiz_page.dart:1483-1491`), contrariando “não interromper
desnecessariamente quem já respondeu”.

### Opções do modal são limitadas

O modal lista chips de questões em branco e marcadas e permite voltar a elas
(`quiz_page.dart:1440-1481`), mas não oferece “escolher alternativa” no próprio
modal, nem “manter sem resposta e pular” como ação explícita. As opções são, na
prática, “tocar em uma questão”, “entregar mesmo assim” ou “continuar revisando”.
É funcional, mas menos claro que o fluxo descrito no produto.

### Tempo por questão reinicia a cada visita

`questionElapsed` é zerado em `_selectQuestion` (`quiz_page.dart:483-488`), e o
rascunho persiste apenas `elapsedSeconds`, não o tempo por questão
(`quiz_page.dart:156-165`). Voltar para uma questão já visitada reinicia o
orçamento dela; fechar e reabrir a prova também reinicia o tempo por questão.
Para um limite “por questão” isso pode ser aceitável como “tempo desta visita”,
mas não como “tempo gasto na questão”. O comportamento não está documentado.

### Tempo esgotado não tem consequência definida

Ao esgotar, aparece um `SnackBar` “Tempo esgotado. Você pode continuar
respondendo.” (`quiz_page.dart:712-724`) e nada mais acontece: não avança, não
bloqueia, não entrega automaticamente. É uma decisão defensável (não perder
respostas), mas não está registrada como decisão de produto e não há opção de
“entregar ao esgotar”. O usuário pode continuar indefinidamente.

### Navegador desktop não é preguiçoso

O navegador usa `GridView.builder` com `shrinkWrap: true` e
`NeverScrollableScrollPhysics` dentro de um `ListView`
(`quiz_page.dart:1219-1248`). Com `shrinkWrap`, a grade precisa medir todos os
itens; para uma prova de 200 questões ela constrói todos os botões de uma vez.
A faixa mobile usa `ListView.separated` horizontal e é preguiçosa
(`quiz_page.dart:1271-1288`). O desktop deveria usar `SliverGrid` ou lista
virtualizada.

### Sem discursiva

O conteúdo só renderiza `question.options` (`quiz_page.dart:1028-1103`) e as
respostas são `Map<int, int>` (`quiz_page.dart:41`). Uma questão discursiva,
mesmo que o parser a detecte (área 9), não tem campo de texto, não pode ser
respondida e não entra no fluxo de entrega. O `AGENTS.md` §10 exige permitir
importar e publicar discursivas sem fingir correção automática; o Focus Mode
precisa de um tipo de resposta textual e de uma revisão específica.

### Sem sincronização em segundo plano durante a prova

O rascunho é local. A sincronização só acontece na finalização
(`quiz_page.dart:601-637`). O `AGENTS.md` §8 pede sincronizar em segundo plano
quando autenticado. Hoje, trocar de aparelho no meio da prova não continua a
tentativa; o rascunho fica só naquele aparelho. Isso pode ser uma decisão
consciente (evitar conflito), mas precisa estar registrada e coberta pela área 8.

## O que está ausente ou quebrado

- Tela de preparação antes de iniciar, com duração sugerida da prova.
- Dois cronômetros independentes e exibição configurável por relógio.
- Cálculo de tempo baseado em relógio real, resistente a suspensão.
- Modal ao avançar de questão em branco/marcada.
- Finalização direta quando tudo foi respondido.
- Escolha de alternativa dentro do modal contextual.
- Questão discursiva com resposta textual.
- Sincronização de rascunho em segundo plano.
- Persistência do tempo por questão.
- Navegador desktop virtualizado.
- Teste de suspensão/retomada e de mudança de relógio do sistema.
- Teste de modal ao avançar e de finalização sem interrupção.
- Teste de questão discursiva e de resposta vazia.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Antes de iniciar, permitir configurar tempo total, por questão e exibição” | Configuração só dentro da prova, global | `quiz_page.dart:268-276, 802-806` |
| “Tempo total e tempo por questão ligados/desligados” | Um único `FocusTimeLimit` exclusivo | `focus_timer_settings.dart:10`; `quiz_page.dart:809-831` |
| “Modal ao avançar de questão marcada/não respondida” | Só há modal na finalização | `quiz_page.dart:454-460` |
| “Não interromper quem já respondeu” | Finalização sempre abre o modal | `quiz_page.dart:1483-1491` |
| “Permitir discursiva sem correção automática” | Focus Mode não tem campo textual | `quiz_page.dart:1028-1103` |
| “Sincronizar em segundo plano quando autenticado” | Só sincroniza ao finalizar | `quiz_page.dart:601-637` |
| “Cronômetro confiável” | Tick não compensa suspensão | `quiz_page.dart:148-154, 167-186` |
| “Retomar exatamente do ponto salvo” | Respostas/posição sim; tempo por questão não | `quiz_page.dart:156-165, 483-488` |

## Evidência de testes

- `focus_timer_settings_test.dart:122-149` cobre preferência ausente, valor
  desconhecido e clamp de faixa.
- `focus_timer_settings_test.dart:151-182` cobre contagem livre e orçamento por
  questão com reinício.
- `focus_timer_settings_test.dart:184-204` cobre esgotamento com aviso único e
  edição posterior.
- `focus_timer_settings_test.dart:206-234` cobre persistência do tempo total.
- `focus_timer_settings_test.dart:236-261` cobre layout de 360 px.
- `quiz_draft_exit_test.dart:32-90` cobre saída esperando a gravação pendente.
- `focus_responsive_test.dart:9-52` cobre 320 px com texto ampliado.
- `quiz_offline_submission_test.dart` cobre contraste, retomada com catálogo
  alterado, conclusão local, finalização online, falha de fila, entrega offline
  sem gabarito e login retomando sincronização.
- Não há teste de suspensão do app, relógio do sistema, modal ao avançar,
  finalização sem interrupção, discursiva ou rascunho sincronizado.

## Riscos

1. **Duração errada.** Suspender o app subconta o tempo e distorce a duração da
   tentativa.
2. **Tempo por questão inconsistente.** Voltar à questão dá um novo orçamento,
   o que pode ser explorado ou confundir o usuário.
3. **Fluxo de revisão fraco.** Avançar de uma questão em branco não avisa; o
   usuário só descobre no final.
4. **Atrito na entrega.** Quem respondeu tudo ainda precisa passar pelo modal.
5. **Discursiva impossível.** O tipo central do produto não pode ser resolvido.
6. **Rascunho preso ao aparelho.** Troca de dispositivo perde o progresso.
7. **Desktop lento em provas grandes.** A grade não é virtualizada.

## Plano de refatoração da área

### Lote 1 — Cronômetro confiável

- Guardar `startedAt` e `lastResumedAt`; calcular o decorrido por diferença de
  relógio e usar o tick apenas para atualizar a UI.
- Tratar `resumed`/`paused` explicitamente, com tolerância a mudança de fuso.
- Persistir o tempo por questão e o instante de início de cada questão.
- Critério de aceite: teste com relógio fake cobre suspensão de 10 minutos,
  retomada e tempo total correto; tempo por questão não reinicia ao voltar.

### Lote 2 — Configuração antes de iniciar

- Criar uma tela/Sheet de preparação antes do QuizPage com:
  tempo total on/off, tempo por questão on/off, valores, exibição de cada
  cronômetro e opção “usar duração da prova”.
- Salvar a escolha por tentativa, usando o padrão global apenas como sugestão.
- Critério de aceite: teste de widget cobre início com dois cronômetros, com um
  e com nenhum; a prova começa com os valores escolhidos.

### Lote 3 — Revisão contextual e finalização

- Ao tocar em “Próxima” com questão em branco ou marcada, abrir um sheet com
  “Responder agora”, “Deixar em branco e avançar” e “Marcar para revisão”.
- Se todas estiverem respondidas e nenhuma marcada, ir direto para a confirmação
  de entrega.
- Incluir escolha de alternativa no sheet quando a questão for objetiva.
- Critério de aceite: testes cobrem os três caminhos e a finalização sem toque
  extra.

### Lote 4 — Discursiva

- Adicionar `QuestionType` e um campo de resposta textual com contador,
  rascunho local e revisão sem gabarito automático.
- Exibir “Resposta discursiva — correção manual” e nunca calcular acerto.
- Critério de aceite: prova mista resolve objetiva e discursiva; resultado
  separa “sem correção automática” de “sem gabarito”.

### Lote 5 — Virtualização e sync

- Trocar a grade desktop por `SliverGrid`/lista virtualizada.
- Definir se o rascunho sincroniza em segundo plano; se sim, criar fila
  idempotente e resolução de conflito por versão da prova.
- Critério de aceite: prova de 300 questões rola sem construir todos os botões;
  troca de aparelho retoma o rascunho quando a política permitir.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Fluxo principal correto; tempo e modal divergem do produto. |
| Testes | 3 | Boa cobertura de timer, rascunho e offline; faltam suspensão, modal e discursiva. |
| Acoplamento | 3 | Widgets separados, mas página de 1.501 linhas e stores diretos. |
| Clareza | 4 | Fluxo e estados compreensíveis; regra do tempo por questão não documentada. |
| Segurança | 4 | Sem segredos; rascunho local e entrega idempotente. |
| Robustez | 3 | Persistência e offline fortes; relógio e navegador desktop vulneráveis. |
| Aderência | 2 | Faltam pré-configuração, dois cronômetros, discursiva e modal ao avançar. |
| Portabilidade | 3 | Mobile e desktop responsivos; grade desktop não escala. |

Classificação resultante: **EVOLUIR** — a experiência central está de pé e é
confiável para objetivas, mas o cronômetro precisa de base temporal real e o
fluxo precisa cobrir discursiva e revisão durante a prova.

## Dependências

- Área 2 para tipo de questão, resposta discursiva e versão.
- Área 7 para persistência do rascunho e do tempo por questão.
- Área 8 para política de sincronização em segundo plano.
- Área 9 para importação de discursivas.
- Área 15 para duração oficial e metadados da prova.
- Área 16 para tokens, acessibilidade e motion.
- Decisão de produto sobre o que acontece ao esgotar o tempo.

## O que não foi verificado

- Suspensão real do app em Android/iOS e retomada após horas.
- Mudança de relógio/fuso do sistema durante a prova.
- Prova com 200+ questões no desktop.
- Prova discursiva em aparelho real.
- Leitor de tela real na questão e no modal.
- Sincronização de rascunho entre aparelhos.
- Comportamento ao esgotar tempo com a tela bloqueada.

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[06 - Tentativas, resultados e pontuação|Área 6 — Resultados]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[08 - Sincronização, offline, idempotência e conflitos|Área 8 — Sincronização]]
- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[../../01 - Produto/Focus Mode|Focus Mode — produto]]
- [[Mapa das Áreas|Mapa das Áreas]]
