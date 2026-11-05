---
tipo: area
area: social, discussões, comunidades e denúncia
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 4, clareza: 4, seguranca: 3, robustez: 2, aderencia: 1, portabilidade: 4}
fonte_codigo: [lib/features/share/question_discussion.dart, lib/features/share/share_link_page.dart, lib/core/backend/question_discussion_repository.dart, supabase/prova_social_backend_v1.sql]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Social, discussões, comunidades e denúncia

## Resumo

A camada social real é mínima: comentários planos por questão, exibidos apenas na
página de link público, e “seguir assunto” por nome exato de tópico. O caminho
funciona para o que existe — leitura pública, login contextual, texto preservado
em falha e RLS coerente —, mas o produto descrito no `AGENTS.md` está em grande
parte ausente: não há comunidades, sugestão por demanda, ciclos de vida,
moderação, denúncia, votos, respostas, follow de banca/concurso/disciplina,
notificações ou feed social. O schema social está em um SQL solto
(`supabase/prova_social_backend_v1.sql`), fora das migrations versionadas, e a
publicação força todo assunto para `Geral`, o que esvazia o único follow
existente. Classificação: **EVOLUIR** — a base é pequena e correta, mas precisa
ser transformada em rede social de verdade.

## Escopo e método

- Leitura integral de `lib/features/share/question_discussion.dart` (278 linhas),
  `lib/core/backend/question_discussion_repository.dart` (137) e
  `lib/features/share/share_link_page.dart` (187).
- Leitura do bloco social de `supabase/prova_social_backend_v1.sql:1-170`
  (tópicos, follows, coleções, comentários, votos e RLS).
- Confirmação de que nenhuma migration em `supabase/migrations/` cria
  `question_comments`, `topic_follows`, `collections`, `profile_follows` ou
  `comment_votes`.
- Leitura de `test/question_discussion_repository_test.dart`.
- Não foi executado fluxo real com duas contas, nem teste de RLS, moderação ou
  denúncia. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Ler comentários visíveis de uma questão | Funcional | `question_discussion_repository.dart:39-66` |
| Limitar a 100 comentários | Funcional | `question_discussion_repository.dart:48` |
| Publicar comentário com login | Funcional | `question_discussion_repository.dart:68-86` |
| Preservar texto em falha de publicação | Funcional | `question_discussion.dart:101-109` |
| Leitura por visitante | Funcional | `question_discussion_repository.dart:39-49`; RLS `prova_social_backend_v1.sql:118-122` |
| Mostrar nome do autor | Funcional | `question_discussion_repository.dart:52-60` |
| Seguir/deixar de seguir assunto | Funcional | `question_discussion_repository.dart:88-129` |
| Não criar tópico inexistente | Funcional | `question_discussion_repository.dart:111-114` |
| Discussão na página pública da questão | Funcional | `share_link_page.dart:122-132` |
| Discussão na revisão ou no app logado | Ausente | só `share_link_page.dart` usa o componente |
| Respostas a comentário | Ausente | `parent_id` existe no SQL, não no app |
| Votos em comentário | Ausente | tabela `comment_votes` sem uso no app |
| Editar/apagar comentário | Ausente | sem UI; RLS permite update/delete |
| Denunciar conteúdo | Ausente | nenhuma tabela/UI de report |
| Moderação e papéis | Ausente | nenhum admin/moderador |
| Rate limit e antispam | Ausente | insert direto, sem limite |
| Notificação de resposta/seguidor | Ausente | nenhuma tabela ou serviço |
| Follow de banca/concurso/disciplina | Ausente | só `topic_follows` |
| Follow de perfil | Ausente | `profile_follows` sem uso |
| Coleções sociais | Ausente | `collections` sem uso |
| Comunidades | Ausente | nenhuma entidade, tela ou consulta |
| Ciclo de vida de comunidade | Ausente | nenhum `suggested/active/dormant/...` |
| Feed de assuntos seguidos | Ausente | home não consulta `topic_follows` |

## O que funciona

1. **Leitura pública sem login.** Qualquer visitante lê comentários de questão
   pública; a RLS exige que a prova esteja `published` e `is_public`
   (`prova_social_backend_v1.sql:118-122`). Isso está alinhado com “login
   opcional para explorar”.
2. **Login contextual correto.** Ao comentar sem sessão, o componente chama
   `onSignIn`, espera o retorno e só continua se houver usuário
   (`question_discussion.dart:81-86`). O mesmo vale para seguir assunto
   (`question_discussion.dart:126-137`). Não há perda do texto digitado.
3. **Falha preserva o conteúdo.** Se a publicação falhar, o texto permanece no
   campo e a mensagem diz explicitamente que ele foi preservado
   (`question_discussion.dart:101-109`). É o comportamento certo para conexão
   ruim.
4. **Validação em comprimento e vazio.** O repositório rejeita corpo vazio ou
   acima de 2000 caracteres (`question_discussion_repository.dart:73-76`), e a
   constraint do banco repete o limite (`prova_social_backend_v1.sql:61`).
5. **Identidade vem da sessão.** O `author_id` é preenchido com o usuário atual,
   não com valor arbitrário do cliente (`question_discussion_repository.dart:69-84`),
   e a RLS exige `author_id = auth.uid()` (`prova_social_backend_v1.sql:123-125`).
6. **Seguir assunto é idempotente por chave.** `topic_follows` tem PK
   `(user_id, topic_id)` e políticas de dono
   (`prova_social_backend_v1.sql:22-28, 96-98`). Inserir duas vezes falha, mas
   não duplica.
7. **Tópico não é criado pelo cliente.** `setTopicFollow` falha se o tópico não
   existir (`question_discussion_repository.dart:111-114`), evitando lixo de
   “assunto” digitado errado. O teste cobre isso
   (`question_discussion_repository_test.dart:79-103`).
8. **Mensagens humanas e estados vazios.** “Ainda não há comentários nesta
   questão”, erro com “Tentar novamente” e `Semantics` de região viva
   (`question_discussion.dart:192-222`). Não há skeleton, mas o spinner tem
   rótulo.
9. **Discussão integrada à questão compartilhável.** A página pública mostra
   enunciado, mídia, alternativas e a discussão antes de “Resolver esta questão”
   (`share_link_page.dart:98-160`). A questão é tratada como objeto social, não
   como item de lista.

## O que está parcial

### Comentário plano, sem conversa

O modelo tem `parent_id` e a tabela tem índice para ele
(`prova_social_backend_v1.sql:55-64, 78`), mas o app:

- não envia `parent_id`;
- não renderiza árvore;
- não tem “responder”;
- não ordena por relevância;
- não carrega mais que 100;
- não atualiza em tempo real;
- não permite editar nem apagar pela UI.

A experiência é um mural linear, não uma discussão. Para uma questão com muita
procura, os 100 comentários mais antigos são os únicos visíveis
(`order created_at ascending`), então comentários novos podem nunca aparecer
quando o limite é atingido.

### Votos e sinal de qualidade existem no banco, não no produto

`comment_votes` tem tabela, RLS e índice
(`prova_social_backend_v1.sql:66-72, 79, 132-134`), mas nenhum código Dart a usa.
Não há “útil”, ordenação por votos, nem indicação de resposta aceita. O
comentário mais útil e o mais popular têm o mesmo peso.

### Seguir assunto não alimenta nada

O único uso de `topic_follows` está na própria discussão
(`question_discussion_repository.dart:88-129`). A home não consulta os tópicos
seguidos, não há tela “assuntos que você segue”, nem notificação. Além disso:

- o vínculo é por **nome exato** do tópico (`_findTopic` usa `.eq('name', ...)`),
  então “matemática” e “Matemática” são coisas diferentes;
- a publicação força todas as questões para `Geral`
  (`exam_publication_service.dart:64`), mas `Geral` não está na seed de tópicos
  (`prova_social_backend_v1.sql:157-165`), então seguir o assunto da questão
  publicada pelo app geralmente não encontra tópico;
- não há follow de banca, concurso, instituição ou disciplina, que é o que o
  `AGENTS.md` §6 pede em Explorar.

O recurso existe, mas é um botão isolado sem consequência no produto.

### Discussão só existe no link público

O componente `QuestionDiscussion` só é instanciado em
`share_link_page.dart:122`. Não aparece:

- na tela de resultado/revisão;
- no Focus Mode durante a prova;
- no catálogo ou na página da prova;
- no perfil ou em uma aba social.

Ou seja, o usuário logado que faz uma prova dentro do app não vê a discussão
daquela questão em lugar nenhum, a menos que abra o link público. A rede social
está desconectada do ciclo principal “fazer → errar → entender → discutir”.

### Schema social fora das migrations

`question_comments`, `topic_follows`, `topics`, `collections`, `profile_follows`
e `comment_votes` estão em `supabase/prova_social_backend_v1.sql`, um arquivo
solto. Nenhuma migration em `supabase/migrations/` cria essas tabelas. O README
já reconhece parte disso para coleções e follows de perfil, mas o app **depende**
de `question_comments` e `topic_follows` em produção. Se o banco foi montado só
com migrations, a discussão quebra; se foi montado à mão, não há histórico
versionado do schema social.

### Sem moderação, denúncia ou bloqueio

Não existe:

- botão “denunciar”;
- tabela `reports`;
- fila de moderação;
- estado `hidden` acionável por moderador (a coluna existe, mas só o autor pode
  mudar para `deleted`);
- bloqueio/mute de usuário;
- palavra-chave, limite de frequência ou captcha;
- registro de quem moderou e por quê.

A RLS permite que qualquer autenticado insira comentário visível em qualquer
questão pública, sem limite de quantidade. Um script pode inundar a discussão.
Como não há denúncia, o único caminho é o autor apagar o próprio comentário.

### Sem comunidades

O `AGENTS.md` §13 descreve um subsistema inteiro:

- criação sugerida quando duas ou mais pessoas demonstram intenção semelhante;
- normalização por entidade (prova, questão, banca, disciplina, intenção);
- estados `suggested`, `active`, `dormant`, `archived`, `reopened`;
- proteção contra duplicata, fusão com histórico, rate limit, denúncia;
- comunidades inativas somente leitura e pesquisáveis.

Nada disso existe no código ou no schema. Não há tabela `communities`, nem
`community_candidates`, nem `community_members`, nem tela. A única coisa
próxima é “seguir assunto”, que é um follow simples, não uma comunidade com
membros, tópicos e moderação.

### Sem notificações nem atividade social

Não há notificação de resposta, de novo comentário, de novo seguidor ou de
comunidade reaberta. Também não há feed de atividade. O usuário não tem motivo
para voltar à discussão depois de comentar.

## O que está ausente ou quebrado

- Respostas encadeadas e votos.
- Paginação/carregamento de mais comentários.
- Edição e exclusão pela UI.
- Denúncia, moderação, bloqueio e rate limit.
- Discussão no resultado, na revisão e na página da prova.
- Feed de assuntos seguidos e tela de assuntos seguidos.
- Follow de banca, concurso, instituição, disciplina e perfil.
- Coleções sociais e compartilhamento de coleção.
- Comunidades, sugestão, lifecycle, membros e fusão.
- Notificações e atividade.
- Schema social em migration versionada.
- Teste de widget da discussão (vazio, erro, login, post).
- Teste de RLS de comentário e follow com duas contas.
- Teste de limite de 100 e ordenação.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Cada questão publicada deve possuir discussão própria” | Existe comentário, mas só no link público | `share_link_page.dart:122` |
| “Seguir assuntos, bancas, concursos e disciplinas” | Só assunto, por nome exato | `question_discussion_repository.dart:88-136` |
| “Comunidades sugeridas com ciclo de vida” | Nenhuma entidade ou tela | ausência total |
| “Denúncia e moderação” | Nenhuma tabela/UI | ausência total |
| “Respostas e estatísticas agregadas” | Sem resposta, voto ou estatística | `question_comments` sem uso de `parent_id` |
| “Feed de assuntos seguidos” | Follow não alimenta a home | `home_page.dart` não consulta `topic_follows` |
| “Schema versionado” | Social está em SQL solto | `supabase/prova_social_backend_v1.sql` |
| “Assunto da questão preservado” | Publicação força `Geral` | `exam_publication_service.dart:64` |

## Evidência de testes

- `test/question_discussion_repository_test.dart:10-48` cobre leitura de
  comentários visíveis, nome público e limite 100.
- `:50-77` cobre identidade vinda da sessão e trim do texto.
- `:79-103` cobre visitante rejeitado e tópico inexistente.
- Não há teste de widget de `QuestionDiscussion`.
- Não há teste de `share_link_page`, de follow, de comentário com falha de rede,
  de moderação, de denúncia, de paginação ou de RLS.
- Não há teste de comunidades porque não há implementação.

## Riscos

1. **Discussão morta.** Só quem abre o link público vê comentários; o usuário do
   app não participa.
2. **Spam sem freio.** Sem rate limit, denúncia ou moderação, uma conta pode
   inundar qualquer questão.
3. **Conteúdo abusivo sem saída.** A vítima não tem botão de denúncia; o autor
   controla o próprio comentário.
4. **Follow inútil.** Seguir assunto não muda a home e o assunto publicado é
   sempre `Geral`.
5. **Schema invisível.** Ambiente novo pode não ter as tabelas sociais.
6. **Comunidade improvisada.** Sem modelo, qualquer tentativa futura corre o
   risco de criar duplicatas e perder histórico.
7. **Limite de 100.** Comentários novos podem ficar invisíveis em questões
   populares.

## Plano de refatoração da área

### Lote 1 — Discussão utilizável

- Adicionar respostas com `parent_id`, votos “útil” e ordenação por relevantes
  ou recentes.
- Paginar comentários (cursor por `created_at` + `id`) e mostrar “carregar mais”.
- Permitir editar e apagar o próprio comentário com confirmação.
- Exibir a discussão também no resultado/revisão e na página da prova.
- Critério de aceite: comentário respondido aparece encadeado; voto altera a
  ordem; 150 comentários podem ser navegados; teste de widget cobre vazio, erro,
  login e post.

### Lote 2 — Segurança e moderação

- Criar `reports` com motivo, alvo, autor e estado; botão “Denunciar” em
  comentário e perfil.
- Criar fila de moderação com `hidden`/`deleted` e registro de auditoria.
- Aplicar rate limit por usuário e por questão; bloquear repetição idêntica.
- Definir política de bloqueio/mute e de conteúdo proibido.
- Critério de aceite: denúncia cria item; moderador oculta; autor não consegue
  contornar; spam em rajada é recusado; RLS testada com duas contas.

### Lote 3 — Follow com consequência

- Consultar `topic_follows` na home e mostrar “Seguindo” com provas recentes.
- Normalizar nome/slug do tópico e impedir duplicata semântica.
- Adicionar follow de banca, concurso, instituição e disciplina quando o modelo
  permitir (área 2).
- Preservar o assunto real na publicação (dependência da área 10).
- Critério de aceite: seguir um assunto muda a home; publicar questão com assunto
  real permite segui-lo; teste cobre follow e feed.

### Lote 4 — Comunidades com lifecycle

- Antes de codificar, criar ADR com o critério de “duas ou mais pessoas com
  intenção semelhante”, normalização por entidade e definição de atividade.
- Modelar `communities`, `community_members`, `community_candidates` e estados
  `suggested/active/dormant/archived/reopened`.
- Implementar sugestão, entrada/saída, somente leitura quando dormente,
  reabertura por nova procura e fusão com histórico.
- Critério de aceite: duas intenções equivalentes geram uma sugestão; comunidade
  dormente continua pesquisável e somente leitura; fusão preserva posts; teste
  cobre cada transição.

### Lote 5 — Notificações e atividade

- Notificar resposta, voto, novo seguidor e reabertura de comunidade.
- Criar feed de atividade discreto, sem gamificação infantil.
- Critério de aceite: resposta gera notificação only para o autor; usuário pode
  silenciar; nenhum dado privado vaza.

### Lote 6 — Schema versionado

- Mover o schema social para migrations idempotentes em
  `supabase/migrations/`, com RLS e grants.
- Criar teste de RLS para comentário, voto, follow e denúncia.
- Critério de aceite: ambiente criado só com migrations tem todo o schema
  social; `supabase db reset` reproduz o estado.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Comentário e follow funcionam; falta o resto do produto social. |
| Testes | 2 | Só repositório; sem widget, RLS ou fluxo completo. |
| Acoplamento | 4 | Repositório e widget pequenos e separados. |
| Clareza | 4 | Nomes, mensagens e estados compreensíveis. |
| Segurança | 3 | RLS de leitura/autoria correta; sem rate limit, denúncia ou moderação. |
| Robustez | 2 | Limite 100 sem paginação, schema fora de migration, sem retry de follow. |
| Aderência | 1 | Comunidades, denúncia, votos, respostas e feed ausentes. |
| Portabilidade | 4 | Sem dependência de plataforma. |

Classificação resultante: **EVOLUIR** — a base de comentário e follow é correta e
deve ser mantida, mas a área precisa virar uma rede social completa, com
moderação e comunidades, em vez de um mural isolado.

## Dependências

- Área 2 para assunto, banca, instituição e tipos de entidade.
- Área 4 para feed, busca e “seguindo”.
- Área 10 para assunto real e procedência na publicação.
- Área 12 para migrations, RLS, RPCs e moderação.
- Área 14 para testes de RLS, spam e caos.
- Área 16 para componentes de comentário, denúncia e comunidade.
- ADR de produto sobre critério de comunidade, moderação e notificações.

## O que não foi verificado

- Se as tabelas sociais existem no Supabase ativo.
- RLS real com duas contas e comentário em prova privada.
- Comportamento com 100+ comentários.
- Rate limit do projeto.
- Fluxo de denúncia (não implementado).
- Notificações (não implementadas).
- Uso real de `topic_follows` por usuários.
- Nomes de exibição duplicados ou vazios em produção.

## Links

- [[04 - Catálogo, busca, feed, biblioteca e perfil|Área 4 — Catálogo]]
- [[10 - Publicação, pacotes, mídia e Storage|Área 10 — Publicação]]
- [[12 - Supabase, schema, RLS e RPCs|Área 12 — Backend]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[../../03 - Domínios/Fluxos Principais|Fluxos Principais]]
- [[Mapa das Áreas|Mapa das Áreas]]
