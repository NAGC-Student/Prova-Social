---
tipo: area
area: sincronização, offline, idempotência e conflitos
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 4, testes: 4, acoplamento: 3, clareza: 4, seguranca: 5, robustez: 3, aderencia: 3, portabilidade: 3}
fonte_codigo: [lib/core/backend/attempt_sync_service.dart, lib/core/backend/attempt_repository.dart, lib/core/backend/attempt_submission.dart, lib/features/result/result_page.dart, supabase/migrations/20261008181438_require_authenticated_attempts.sql]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Sincronização, offline, idempotência e conflitos

## Resumo

A sincronização é bem projetada para o caminho principal. A entrega é gravada
no aparelho antes de qualquer rede, a fila sobrevive a reinício, o
`clientAttemptId` é um UUID v4 seguro, reenvios simultâneos compartilham a mesma
operação, o servidor tem índice único e compara o payload para rejeitar
reutilização divergente, e a resposta de correção é validada campo a campo antes
de virar resultado. As lacunas são de operação contínua e conflito: não há
observador de conectividade nem sincronização ao voltar ao app pela home; um item
corrompido interrompe os demais; sessão expirada vira erro permanente; taxa
limitada não tem tratamento; e uma prova alterada no servidor não tem fluxo de
resolução — vira “requer atenção”. Classificação: **EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/core/backend/attempt_sync_service.dart` (578 linhas),
  `attempt_repository.dart` (182) e `attempt_submission.dart` (37).
- Leitura de `PendingResultPage` em `lib/features/result/result_page.dart:16-189`
  e do carregamento de tentativas em `lib/features/home/home_page.dart:196-220`.
- Leitura da RPC `submit_exam_attempt` em
  `supabase/migrations/20261008181438_require_authenticated_attempts.sql:1-175`
  e do índice idempotente em
  `supabase/migrations/202609210003_attempt_idempotency.sql:7-13`.
- Leitura dos testes `test/attempt_sync_service_test.dart`,
  `test/attempt_repository_test.dart` e `test/quiz_offline_submission_test.dart`.
- Não foi executada sincronização real contra o Supabase ativo, nem teste de rede
  instável, rate limit ou prova alterada no servidor. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Gravar entrega antes da rede | Funcional | `quiz_page.dart:601-610`; `attempt_sync_service.dart:291-296` |
| Fila persistida em `SharedPreferences` | Funcional | `attempt_sync_service.dart:52-74` |
| ID de tentativa UUID v4 seguro | Funcional | `attempt_sync_service.dart:280-289` |
| Estados de sincronização | Funcional | `attempt_sync_service.dart:11-18` |
| Backoff 30 s → 1 h | Funcional | `attempt_sync_service.dart:416-419` |
| Reenvio manual | Funcional | `result_page.dart:174-179` |
| Reenvio ao voltar ao app na tela pendente | Funcional | `result_page.dart:44-47` |
| Reenvio após login | Funcional | `result_page.dart:91-96` |
| Sincronização ao carregar a home | Parcial | `home_page.dart:196-220` |
| Deduplicação de reenvios simultâneos | Funcional | `attempt_sync_service.dart:298-324` |
| Índice único no servidor | Funcional | `202609210003_attempt_idempotency.sql:7-13` |
| Comparação de payload no servidor | Funcional | `20261008181438...sql:43-60, 132-136` |
| Validação da correção recebida | Funcional | `attempt_repository.dart:55-101` |
| Erro transitório vs permanente | Parcial | `attempt_repository.dart:141-179` |
| Sessão expirada pede login | Quebrado | `attempt_repository.dart:135-140` |
| Retry de rate limit | Ausente | nenhum tratamento de 429 |
| Resolução de conflito de versão | Ausente | só `requiresAttention` |
| Sincronização em segundo plano real | Ausente | só enquanto a UI executa |
| Pull de tentativas de outro aparelho | Ausente | fila é só de envio |
| Cancelar/descartar entrega com problema | Ausente | só “Tentar agora” |
| Um item ruim não bloqueia os demais | Quebrado | `syncDue` sem try/catch por item |

## O que funciona

1. **Entrega local primeiro.** `_finish` grava a submissão com
   `saveForSync` antes de chamar a rede; se a gravação falhar, o rascunho é
   mantido e a prova continua (`quiz_page.dart:601-610, 638-664`). O teste cobre
   falha de fila sem apagar o rascunho
   (`quiz_offline_submission_test.dart:306-333`).
2. **Idempotência real de ponta a ponta.** O ID é gerado com `Random.secure` e
   formato UUID v4 (`attempt_sync_service.dart:280-289`); o servidor tem índice
   único parcial (`202609210003_attempt_idempotency.sql:7-13`), faz
   `on conflict do nothing` e, no conflito, compara `exam_id`, `answers`,
   `review_question_ids` e `duration_seconds` com o payload gravado
   (`20261008181438...sql:43-60, 96-136`). Reutilizar o ID com conteúdo diferente
   é rejeitado no cliente e no servidor.
3. **Concorrência controlada.** Reenvios do mesmo ID compartilham a mesma
   `Future`; IDs diferentes no mesmo armazenamento são serializados; storages
   diferentes não se bloqueiam (`attempt_sync_service.dart:264-324`). Os testes
   cobrem os três casos.
4. **Validação rigorosa da correção.** O cliente confere quantidade de questões,
   unicidade de IDs, limites de índice, respostas selecionadas, marcação de
   revisão, total e contagem de acertos antes de aceitar o resultado
   (`attempt_repository.dart:55-101`). É uma defesa forte contra resposta
   truncada, trocada ou malformada.
5. **Separação entre local e remoto.** Prova local nunca entra na fila
   (`attempt_sync_service.dart:291-296, 127-142`); prova pública exige
   autenticação (`attempt_repository.dart:21-29`) e o servidor também exige
   `auth.uid()` (`20261008181438...sql:27-29`).
6. **Estados humanos na tela pendente.** “Enviando”, “Requer atenção”, “Entre
   para sincronizar”, “Entrega sincronizada” e “Aguardando conexão” têm texto e
   ícone próprios, com `Semantics` de região viva (`result_page.dart:105-188`).
7. **Backoff sem tempestade.** 30 s, 2 min, 10 min, 30 min, 1 h, com teto
   (`attempt_sync_service.dart:416-419`). O agendamento é persistido em
   `nextAttemptAt` e retomado após reinício.
8. **Snapshot antes de esperar.** `enqueue` serializa a submissão antes de entrar
   na fila, então alterar o mapa de respostas depois não muda o que será enviado
   (`attempt_sync_service.dart:144-148`; teste
   `attempt_sync_service_test.dart:115-137`).
9. **Entrega concluída é cache.** `completed` guarda o resultado e evita reenviar
   uma tentativa já corrigida (`attempt_sync_service.dart:326-350`). O teste de
   reinício confirma que a entrega volta sem acesso ao servidor.
10. **Fila não perde item em falha de escrita.** `enqueue` só altera o JSON
    depois de `_write`; se a escrita falhar, o `started` permanece
    (`attempt_sync_service_test.dart:152-165, 556-...`).

## O que está parcial

### Sem observador de conectividade nem retomada global

O app não usa `connectivity_plus` nem um serviço de fundo. A fila é acionada:

- ao carregar a home (`home_page.dart:210`);
- ao abrir a tela pendente (`result_page.dart:41`);
- ao voltar ao app **na tela pendente** (`result_page.dart:45-47`);
- após login na tela pendente (`result_page.dart:91-96`);
- manualmente em “Tentar agora”.

A home **não** observa `AppLifecycleState.resumed`. Se o usuário fecha e reabre o
app na home, `_loadAttempts` roda no `initState` e chama `syncDue`; mas se o app
apenas volta do background, a fila não é acionada até alguma navegação que
recarregue tentativas. Não há sincronização periódica enquanto a home está
aberta. Para o requisito “sincronizar em segundo plano”, o comportamento é
parcial: sincroniza quando a tela certa está ativa, não de forma global.

### Um item com erro interrompe a fila

`syncDue` percorre os pendentes e faz `await sync(...)` sem `try/catch` por item
(`attempt_sync_service.dart:406-414`). Se `sync` lançar — por exemplo, fila
corrompida em `store.pending()` ou `store.find()` —, o loop aborta e os itens
seguintes não são tentados. Em `_loadAttempts`, a exceção é engolida e a
biblioteca “tentará novamente depois” (`home_page.dart:196-220`), sem indicar qual
item falhou. Uma única entrega problemática pode impedir todas as outras.

### Sessão expirada vira erro permanente

`AuthException` é convertida em `AttemptSubmissionException(transient: false)`
sem `requiresAuthentication: true` (`attempt_repository.dart:135-140`). O
serviço então marca `requiresAttention` (`attempt_sync_service.dart:385-392`),
que não é reenviado automaticamente e mostra “Entrega requer atenção”, em vez de
“Entre para sincronizar” com botão de login. O caminho de autenticação só é
acionado pela pré-checagem de `currentUser` (`attempt_repository.dart:21-29`).
Se o token expirar entre a pré-checagem e a RPC, o usuário recebe o estado
errado.

### Rate limit e indisponibilidade parcial

Não há tratamento específico para HTTP 429, `Retry-After` ou limites do
PostgREST. Um erro de rate limit pode cair em `PostgrestException` com código
não listado como transitório e virar `requiresAttention` permanente. Também não
há jitter no backoff: todos os clientes tentam nos mesmos 30 s, 2 min etc.

### Conflito de versão da prova

A submissão envia `p_exam_id` e respostas por `question_id`, mas não envia
`examVersionId` nem hash da versão resolvida. O servidor corrige contra as
questões e chaves **atuais** (`20261008181438...sql:62-86`). Se a prova mudou
entre o início e a entrega:

- questão removida → `v_total` menor e `review` menor que o exam local; o
  cliente rejeita com `invalidReview` permanente
  (`attempt_repository.dart:70-74`);
- alternativa alterada → o índice selecionado pode apontar para outra
  alternativa;
- questão sem chave → o `join private.question_keys` a exclui do total e do
  review; o cliente também rejeita por tamanho.

Não há tela para “sua prova mudou; veja o que fazer”, nem opção de manter a
versão antiga, refazer ou exportar a entrega. O estado final é
`requiresAttention` com mensagem do servidor.

### Questão sem gabarito ou sem ID quebra a sincronização

`AttemptRepository` só envia respostas de questões com `id` não vazio
(`attempt_repository.dart:30-37`). O servidor devolve `review` apenas para
questões com chave (`20261008181438...sql:62-86`). O cliente exige que o review
tenha exatamente o mesmo número de questões do exame local
(`attempt_repository.dart:70-74`). Portanto:

- uma prova publicada com questão sem gabarito não sincroniza;
- uma questão com ID vazio não sincroniza;
- uma prova com questão removida no servidor não sincroniza.

Isso é coerente com “objetiva sem gabarito não pode ser publicada” (área 9), mas
o backend não garante essa invariante no momento da publicação; a falha aparece
só na entrega, como erro permanente.

### Sem pull de histórico

A sincronização é só de envio. Resultados concluídos ficam no armazenamento
local (`completed`), não são baixados do servidor em outro aparelho. Trocar de
dispositivo ou reinstalar perde o histórico, mesmo com a tentativa corrigida no
backend. O `AGENTS.md` fala em sincronização e retomada; a leitura de tentativas
remotas não existe.

### Sem descarte ou exportação de entrega problemática

Uma entrega em `requiresAttention` só oferece “Tentar agora”
(`result_page.dart:173-179`). Não há “copiar detalhes”, “exportar JSON”,
“descartar” ou “corrigir e reenviar”. Se o erro for permanente por conteúdo
inválido, o item fica na biblioteca para sempre.

## O que está ausente ou quebrado

- Observador global de conectividade e retomada ao voltar ao app.
- Sincronização periódica/em segundo plano de verdade.
- `try/catch` por item em `syncDue`.
- `requiresAuthentication` para `AuthException`.
- Tratamento de 429/`Retry-After` e jitter.
- Versão da prova na submissão e fluxo de conflito.
- Pull de tentativas e resultados do servidor.
- Descarte/exportação de entrega com problema.
- Garantia de gabarito completo no momento da publicação.
- Teste de sessão expirada, rate limit, prova alterada e fila com item ruim.
- Teste de sincronização ao voltar ao app pela home.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Sincronizar em segundo plano quando autenticado” | Só com a tela pendente ativa ou carga da home | `result_page.dart:41-47`; `home_page.dart:210` |
| “Resolução explícita de conflitos” | Não há; vira `requiresAttention` | `attempt_sync_service.dart:385-392` |
| “Entrega/finalização tolera falha temporária” | Sim, com fila e backoff | `attempt_sync_service.dart:291-419` |
| “Sessão expirada pede login” | `AuthException` não marca `requiresAuthentication` | `attempt_repository.dart:135-140` |
| “Fila confiável” | Forte, mas um item ruim aborta `syncDue` | `attempt_sync_service.dart:406-414` |
| “Histórico sincronizado” | Só envio; não há pull | `attempt_sync_service.dart:244-255` |
| “Idempotência” | Sim, cliente + índice único + payload | `202609210003...sql:7-13`; `20261008181438...sql:96-136` |
| “Correção confiável” | Validação campo a campo no cliente | `attempt_repository.dart:55-101` |

## Evidência de testes

- `test/attempt_sync_service_test.dart:97-114` cobre serialização por storage sem
  bloquear storages independentes.
- `:115-137` cobre captura de respostas antes de esperar gravações anteriores.
- `:139-151` cobre conteúdo iniciado sobrevivendo ao reinício.
- `:152-165` cobre falha de enqueue preservando `started`.
- `:210-248` cobre resultado online e offline com backoff.
- `:249-286` cobre visitante aguardando login e sincronizando com o mesmo ID.
- `:287-316` cobre reinício e reenvio.
- `:317-347` cobre duplicidade e reutilização divergente de ID.
- `:348-428` cobre reenvios simultâneos e storages independentes.
- `:472-496` cobre erro permanente sem reenvio automático.
- `:533-555` cobre teto de backoff.
- `test/attempt_repository_test.dart` cobre validação da correção e erros de
  transporte.
- `test/quiz_offline_submission_test.dart:282-330` cobre finalização online,
  falha de fila e entrega offline; `:372-440` cobre login retomando sincronização.
- Não há teste de sessão expirada, 429, prova alterada, item ruim no meio da
  fila, pull de histórico ou descarte.

## Riscos

1. **Entrega presa para sempre.** Erro permanente sem opção de descartar ou
   corrigir.
2. **Fila bloqueada.** Um item corrompido impede os demais.
3. **Login não solicitado.** Sessão expirada aparece como “requer atenção”.
4. **Prova alterada.** Correção pode ficar impossível ou incorreta.
5. **Histórico perdido.** Reinstalar ou trocar de aparelho apaga resultados.
6. **Rate limit tratado como permanente.** Usuário precisa tocar manualmente.
7. **Prova sem gabarito publicada.** Só falha na entrega, depois do esforço.
8. **Sem sync em background.** Voltar ao app pode não enviar até nova navegação.

## Plano de refatoração da área

### Lote 1 — Retomada global e fila resiliente

- Observar `AppLifecycleState.resumed` na home e chamar `syncDue` com
  debounce; opcionalmente usar conectividade para acionar ao voltar a rede.
- Envolver cada item de `syncDue` em `try/catch`, registrar o erro e continuar.
- Critério de aceite: dois pendentes, o primeiro com erro, o segundo sincroniza;
  voltar ao app na home dispara a fila.

### Lote 2 — Autenticação e rate limit

- Marcar `AuthException` como `requiresAuthentication: true`.
- Tratar 429/`Retry-After` como transitório com atraso mínimo e jitter.
- Diferenciar “token expirado” de “sem permissão”.
- Critério de aceite: sessão expirada mostra “Entrar e sincronizar”; 429 agenda
  retry com jitter; testes cobrem os dois.

### Lote 3 — Versão e conflito

- Enviar `examVersionId`/hash da versão resolvida na submissão.
- Se a versão mudou, criar estado `conflict` com opções: revisar mudanças,
  manter respostas por ID quando possível, refazer ou exportar.
- Critério de aceite: prova com questão removida não vira erro genérico; o
  usuário vê o conflito e escolhe; teste cobre versão antiga.

### Lote 4 — Pull de histórico e descarte

- Criar leitura paginada de tentativas do usuário no backend e mesclar com o
  histórico local por `clientAttemptId`.
- Oferecer “Descartar entrega” e “Exportar detalhes” para `requiresAttention`.
- Critério de aceite: reinstalar e entrar recupera resultados; descartar remove
  o item da fila e da biblioteca com confirmação.

### Lote 5 — Invariante de publicação

- Garantir no backend/publicação que toda prova objetiva publicada tem gabarito
  para todas as questões e IDs estáveis.
- Se a política permitir questão sem gabarito, o contrato de entrega precisa
  aceitar review parcial e marcar “sem correção automática”.
- Critério de aceite: prova publicada sempre sincroniza; teste de publicação
  rejeita conjunto incompleto.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 4 | Caminho principal e idempotência corretos; conflito e auth falham. |
| Testes | 4 | Cobertura forte de fila, concorrência, idempotência e offline. |
| Acoplamento | 3 | Serviço claro, mas home e telas criam instâncias próprias. |
| Clareza | 4 | Estados e mensagens compreensíveis; conflito não é explicado. |
| Segurança | 5 | UUID seguro, auth obrigatória, payload comparado, RLS na RPC. |
| Robustez | 3 | Excelente no caminho normal; item ruim e sessão expirada quebram. |
| Aderência | 3 | Offline e idempotência fortes; falta sync global e conflito explícito. |
| Portabilidade | 3 | Sem dependência de plataforma; `SharedPreferences` limita o Web. |

Classificação resultante: **EVOLUIR** — a espinha dorsal de entrega é confiável e
deve ser mantida; faltam retomada global, tratamento de autenticação/rate limit e
um fluxo humano para conflito de versão.

## Dependências

- Área 2 para versão de prova e IDs estáveis.
- Área 7 para backup e resiliência da fila.
- Área 9 para garantia de gabarito na publicação.
- Área 12 para RPC, índice único, RLS e contrato de resposta.
- Área 14 para testes de caos e rede instável.
- Decisão de produto sobre conflito, descarte e pull de histórico.

## O que não foi verificado

- Sincronização real com o Supabase ativo.
- Comportamento de token expirado no meio da RPC.
- Rate limit real do projeto.
- Prova alterada entre início e entrega em produção.
- Fila com dezenas de pendentes e um item corrompido.
- Sincronização ao voltar do background pela home.
- Consumo de bateria/rede do backoff.
- Pull de tentativas em outro aparelho (não implementado).

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[05 - Focus Mode, timer, navegação e finalização|Área 5 — Focus Mode]]
- [[06 - Tentativas, resultados e pontuação|Área 6 — Resultados]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[09 - Importação, OCR, parser e quality gate|Área 9 — Importação]]
- [[12 - Supabase, schema, RLS e RPCs|Área 12 — Backend]]
- [[../../02 - Arquitetura/Mapa de Módulos|Mapa de Módulos]]
- [[Mapa das Áreas|Mapa das Áreas]]
