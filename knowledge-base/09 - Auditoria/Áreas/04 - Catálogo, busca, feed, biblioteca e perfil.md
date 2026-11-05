---
tipo: area
area: catálogo, busca, feed, biblioteca e perfil
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 2, clareza: 4, seguranca: 4, robustez: 2, aderencia: 2, portabilidade: 4}
fonte_codigo: [lib/features/home/home_page.dart, lib/features/search/search_page.dart, lib/core/backend/exam_repository.dart, lib/features/search/exam_source_directory.dart]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Catálogo, busca, feed, biblioteca e perfil

## Resumo

A área cobre o ciclo de descoberta: home com saudação, busca, continuação local e
provas recentes; busca global com filtros e diretório de fontes externas;
biblioteca com salvos, rascunhos, downloads, tentativas pendentes e concluídas; e
perfil com login, nome/e-mail, atalho para a biblioteca e saída. O caminho
principal funciona e os estados vazios são honestos. As lacunas são
estruturais: o `ExamListTile` exigido pelo produto não existe, os filtros rodam
em memória sobre uma página já carregada, a busca é limitada a 50 resultados sem
paginação, a home não tem assuntos seguidos nem recomendações reais, a biblioteca
não tem coleções e o perfil não tem bio, atividade ou estatísticas. A home
concentra 2.431 linhas e fala com o Supabase diretamente. Classificação:
**EVOLUIR**.

## Escopo e método

- Leitura integral de `lib/features/search/search_page.dart` (880 linhas),
  `lib/core/backend/exam_repository.dart` (287) e
  `lib/features/search/exam_source_directory.dart` (48).
- Leitura dirigida de `lib/features/home/home_page.dart` (2.431 linhas):
  navegação e abas (`30-392`), carregamento (`85-229`), feed (`986-1270`),
  `ExamCard`/`_ExamGrid` (`1272-1395`), biblioteca (`1397-1834`), perfil
  (`1836-2030`), detalhes (`2035-2244`) e `_PageScroll` (`2245-2265`).
- Leitura dos testes `test/ux/search_test.dart`,
  `test/ux/search_filters_test.dart`, `test/ux/local_exam_test.dart`,
  `test/ux/navigation_editor_test.dart` e `test/exam_repository_catalog_test.dart`.
- Não foi executada busca contra o Supabase ativo, nem teste manual de
  biblioteca/perfil em aparelho. A análise é estática.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Cinco abas no mobile e sidebar de 240 px no desktop | Funcional | `home_page.dart:224-232, 310-380` |
| Preservação de estado entre abas | Funcional | `IndexedStack` em `home_page.dart:368` |
| Catálogo público com cursor e “Carregar mais” | Funcional | `home_page.dart:132-163`; `exam_repository.dart:38-82` |
| Saudação discreta e busca em destaque | Funcional | `home_page.dart:1030-1095` |
| Continuar de onde parou | Parcial | `home_page.dart:1096-1125`; só tentativas locais |
| Provas recentes | Funcional | `home_page.dart:1127-1155` |
| Filtros por ano, categoria, fonte, assunto e autor | Parcial | `home_page.dart:118-128`; `search_page.dart:65-181` |
| Busca remota por título, descrição, categoria, fonte e tópico | Funcional | `exam_repository.dart:121-176` |
| Busca com proteção contra injeção no PostgREST | Funcional | `exam_repository.dart:125-128` |
| Diretório de fontes externas | Funcional | `exam_source_directory.dart:17-48`; `search_page.dart:620-676` |
| Biblioteca de salvos | Funcional | `home_page.dart:1660-1690`; `exam_repository.dart:102-120` |
| Biblioteca de rascunhos e downloads | Funcional | `home_page.dart:1470-1655` |
| Tentativas pendentes e concluídas | Funcional | `home_page.dart:1662-1704` |
| Perfil de visitante honesto | Funcional | `home_page.dart:1847-1900` |
| Perfil autenticado | Parcial | `home_page.dart:1902-2030` |
| `ExamListTile` | Ausente | não existe classe com esse nome; há `ExamCard` |
| Coleções personalizadas | Ausente | nenhuma referência a collection/playlist em `lib/` |
| Temas/assuntos seguidos na home ou perfil | Ausente | único “Seguir assunto” está em `question_discussion.dart:152-187` |
| Recomendações reais | Ausente | feed é apenas “Publicadas recentemente” |
| Estatísticas e atividade no perfil | Ausente | perfil só tem atalho “Seu progresso” |

## O que funciona

1. **Navegação fiel ao produto.** As cinco abas são Início, Explorar, Publicar,
   Biblioteca e Perfil, com o mesmo modelo mental no mobile e no desktop
   (`home_page.dart:224-232, 310-380`). O desktop troca a barra inferior por uma
   sidebar de 240 px, como o `AGENTS.md` pede.
2. **Catálogo paginado por cursor.** A consulta usa `created_at` + `id` como
   cursor, limita `pageSize + 1` para saber se há mais e ordena questões por
   posição (`exam_repository.dart:38-82`). É melhor que offset e evita duplicar
   itens ao carregar mais.
3. **Busca sem interpolar o termo no OR do PostgREST.** O comentário e o código
   deixam claro que cada campo é consultado separadamente justamente para não
   injetar sintaxe no filtro (`exam_repository.dart:121-140`), e `%`, `_` e `\`
   são escapados. Isso é uma decisão de segurança correta.
4. **Somente conteúdo público.** Catálogo, busca e prova por ID filtram
   `status = published` e `is_public = true` (`exam_repository.dart:50-52, 86-88,
   128-131`).
5. **Estados vazios úteis.** A home sem catálogo oferece explorar ou publicar; a
   busca sem resultado explica que o catálogo pode não ter a prova e oferece
   fontes oficiais; a biblioteca de visitante separa favoritos públicos de
   provas locais (`home_page.dart:1168-1188, 1523-1545`;
   `search_page.dart:590-616`).
6. **Biblioteca cobre mais que “salvos”.** Ela reúne favoritos, rascunhos
   privados, downloads offline, tentativas em andamento, tentativas pendentes de
   sincronização e resultados concluídos (`home_page.dart:1397-1434,
   1547-1704`). Isso atende boa parte do ciclo “salvar → fazer → revisar”.
7. **Busca externa com responsabilidade.** O diretório externo abre uma busca
   `site:` no Google e avisa que o usuário deve baixar o arquivo no site de
   origem e conferir licença, em vez de fingir que importa sozinho
   (`exam_source_directory.dart:11-14`; `search_page.dart:656-676`).
8. **Perfil de visitante não inventa dados.** O visitante vê um convite para
   entrar e a explicação de que fazer provas continua liberado
   (`home_page.dart:1847-1900`).

## O que está parcial

### `ExamListTile` não existe; o feed usa `ExamCard`

O `AGENTS.md` §6 define o `ExamListTile` como componente prioritário, com
brasão opcional, banca e procedência, título e ano, número de questões e
duração, disciplinas resumidas, progresso quando iniciado, estado
começar/continuar/concluída e salvar, em layout compacto.

O que existe é `ExamCard` (`home_page.dart:1296-1394`), uma linha com ícone
genérico de livro, título, `SourceBadge`, ano · categoria, “N questões · N min ·
autor” e botão de salvar. Não há:

- brasão ou imagem da banca;
- banca e instituição como campos separados (o modelo só tem `category` e
  `author`, ver área 2);
- disciplinas resumidas (só a categoria);
- progresso ou estado começar/continuar/concluída;
- indicação de quantas tentativas o usuário fez.

A busca usa outro layout, um `ListTile` próprio (`search_page.dart:715-760`),
também sem progresso. Ou seja, o componente reconhecível e reutilizável que o
produto exige não foi construído; cada tela desenha sua própria linha.

### Filtros em memória sobre dados parciais

Tanto a home quanto a busca aplicam filtros **client-side** sobre o que já foi
carregado:

- a home avisa literalmente “Filtros aplicados às N provas já carregadas”
  (`home_page.dart:1155-1163`) e o botão só habilita se `exams` não estiver
  vazio (`home_page.dart:1082-1095`);
- a busca aplica `ExamSearchFilters` sobre `_results`
  (`search_page.dart:213-220`), e `_results` vem de uma consulta limitada a 50
  (`exam_repository.dart:121-176`).

Consequências: um filtro pode dizer “nenhuma prova combina” quando existem
provas no servidor que combinariam; carregar mais provas muda o resultado do
mesmo filtro; e não há filtro por banca, concurso, instituição ou tipo de
questão. Para escalar, o filtro precisa ir para a consulta (ou para uma RPC com
paginação).

### Busca limitada, sem paginação e sem ranking

`ExamRepository.search` faz quatro consultas `ilike` (título, descrição,
categoria, fonte), mais uma em `questions.topic`, cada uma com `limit(50)`,
mescla por ID, ordena por data e corta em 50 (`exam_repository.dart:121-176`).
Não há:

- paginação ou “carregar mais”;
- ranking por relevância (título exato antes de descrição, por exemplo);
- normalização de acentos (`ilike` no Postgres é case-insensitive, mas não
  accent-insensitive);
- busca por banca/instituição, que não existem no modelo;
- busca full-text ou índice dedicado.

O limite de 50 por campo também significa que uma prova muito antiga pode nunca
aparecer, mesmo sendo o melhor resultado. A UI não informa que o resultado foi
truncado.

### Home sem personalização real

O `AGENTS.md` §6 pede recomendações reais, assuntos seguidos e provas recentes.
A home atual tem:

- saudação;
- busca;
- “Continuar de onde parou” (somente provas com tentativa local,
  `home_page.dart:1096-1125`);
- “Publicadas recentemente” (`home_page.dart:1127-1155`).

Não há assuntos seguidos, recomendações por histórico, provas de bancas seguidas
nem uma seção separada de provas recentes. O feed é cronológico. O único
“Seguir assunto” do app está na discussão de uma questão
(`question_discussion.dart:152-187`) e não alimenta a home.

### Biblioteca sem coleções, abas e histórico próprio

A biblioteca é uma página única com seções empilhadas
(`home_page.dart:1436-1834`). O `AGENTS.md` §6 pede salvas, em andamento,
concluídas, coleções, histórico e coleções personalizadas semelhantes a
playlists. Hoje:

- salvos, downloads, rascunhos, em andamento, pendentes e concluídos existem;
- **coleções e playlists não existem**;
- **histórico** não é uma seção separada; resultados concluídos aparecem como
  uma lista;
- não há busca, filtro ou ordenação dentro da biblioteca;
- a seção “Salvas” depende de `savedExams` carregado por rede; sem conexão, os
  favoritos públicos não aparecem (os downloads continuam).

### Perfil mínimo

O perfil autenticado mostra iniciais, nome, e-mail, um cartão “Seu progresso”
que leva à biblioteca, um atalho “Biblioteca e resultados”, “Sobre” e “Sair da
conta” (`home_page.dart:1902-2030`). O `AGENTS.md` §6 pede nome, avatar, bio
curta, temas seguidos, atividade, salvos, publicados, coleções e estatísticas
reais e discretas.

Não há:

- bio, edição de perfil ou upload de avatar;
- temas/bancas/concursos seguidos;
- lista de publicações do usuário;
- atividade recente;
- estatísticas (tentativas, acertos, sequência etc.);
- coleções;
- preferências (tema, cronômetros, privacidade);
- exclusão de conta.

O nome vem de `userMetadata['display_name']` e cai para “Estudante” quando
ausente (`home_page.dart:1902-1917`); não há consulta à tabela `profiles`.

### Acoplamento e tamanho da home

`HomePage` tem 2.431 linhas, cria `ExamRepository` e `AttemptSyncService`
diretamente (`home_page.dart:36-37`), usa `Supabase.instance.client.auth` em
muitos pontos e contém feed, biblioteca, perfil, detalhes e downloads no mesmo
arquivo. Cada troca de aba para 0, 1 ou 3 dispara `_loadContent()`
(`home_page.dart:387-391`), refazendo consultas de catálogo e favoritos sem
cache. Isso dificulta teste, reuso e evolução independente de cada aba.

## O que está ausente ou quebrado

- `ExamListTile` e o estado começar/continuar/concluída no item do catálogo.
- Filtros server-side por banca, concurso, instituição, ano, disciplina e tipo.
- Paginação e ranking na busca; aviso de truncamento em 50.
- Normalização de acentos e busca full-text.
- Assuntos seguidos e recomendações reais na home.
- Coleções personalizadas e histórico como seção própria.
- Busca/filtro dentro da biblioteca.
- Bio, avatar editável, publicações, atividade e estatísticas no perfil.
- Preferências de conta e exclusão de conta.
- Cache de catálogo/favoritos entre trocas de aba.
- Testes de biblioteca, perfil, visitante e estado vazio da home.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “ExamListTile prioritário com brasão, banca, progresso e estado” | Só existe `ExamCard` compacto, sem progresso nem banca | `home_page.dart:1296-1394` |
| “Filtros por banca, concurso, disciplina, ano e tipo” | Filtros são ano, categoria, fonte, assunto e autor, em memória | `search_page.dart:65-181` |
| “Resultados em lista compacta, não cards gigantes” | A busca usa `ListTile`; a home usa cartões com borda | `search_page.dart:715-760`; `home_page.dart:1296` |
| “Recomendações reais e assuntos seguidos” | Feed cronológico, sem seguir nem recomendar | `home_page.dart:1127-1155` |
| “Biblioteca com coleções e histórico” | Sem coleções; histórico não é seção | `home_page.dart:1436-1834` |
| “Perfil com bio, temas seguidos, atividade e estatísticas” | Só nome, e-mail, atalhos e sair | `home_page.dart:1902-2030` |
| “Estatísticas reais e discretas” | Nenhuma estatística no perfil | `home_page.dart:1980-2030` |
| “Login opcional para explorar e pesquisar” | Funciona; busca e catálogo são públicos | `exam_repository.dart:50-52, 128-131` |

## Evidência de testes

- `test/ux/search_test.dart` cobre busca remota por título, categoria, fonte e
  tópico e restringe a conteúdo público.
- `test/ux/search_filters_test.dart` cobre filtros em memória e o seletor
  compartilhado.
- `test/exam_repository_catalog_test.dart` cobre paginação por cursor e
  mapeamento do catálogo.
- `test/ux/navigation_editor_test.dart` cobre navegação, mas não biblioteca nem
  perfil.
- `test/ux/local_exam_test.dart` cobre prova local, não a biblioteca.
- Não há teste de `HomePage` visitante, biblioteca vazia, perfil autenticado,
  perfil visitante, coleções, busca truncada, filtro server-side ou troca de
  aba com cache.

## Riscos

1. **Filtro enganoso.** O usuário pode concluir que não existe prova compatível
   quando o filtro só olhou a página carregada.
2. **Resultado invisível.** Uma prova relevante fora dos 50 primeiros nunca é
   encontrada, sem aviso.
3. **Catálogo sem identidade.** Sem `ExamListTile` e sem banca/instituição, a
   lista não transmite procedência nem progresso, que são centrais no produto.
4. **Perfil vazio.** A aba “Perfil” não entrega o que o produto promete e não
   tem como editar dados.
5. **Biblioteca dependente de rede.** Favoritos públicos desaparecem offline;
   só downloads e rascunhos continuam.
6. **Home monolítica.** 2.431 linhas e múltiplas responsabilidades aumentam o
   custo de qualquer mudança e o risco de regressão.
7. **Consulta repetida.** Trocar de aba refaz consultas e pode piscar conteúdo ou
   consumir rede desnecessariamente.

## Plano de refatoração da área

### Lote 1 — `ExamListTile` e estados do catálogo

- Extrair um `ExamListTile` reutilizável com brasão opcional, `SourceBadge`,
  banca/instituição quando existirem, título, ano, questões, duração,
  disciplinas resumidas, progresso e estado começar/continuar/concluída.
- Usar o mesmo componente na home, na busca e na biblioteca.
- Critério de aceite: um teste de widget cobre os três estados e a ausência de
  banca sem quebrar o layout; home e busca passam a usar o mesmo componente.

### Lote 2 — Busca e filtros no servidor

- Mover os filtros para a consulta (ou RPC) com paginação por cursor.
- Adicionar banca, concurso, instituição, tipo e disciplina quando o modelo
  permitir (depende da área 2).
- Implementar ranking simples (título > tópico > categoria > descrição) e
  normalização de acentos.
- Informar quando o resultado foi truncado e oferecer “carregar mais”.
- Critério de aceite: filtro por ano retorna o mesmo conjunto independentemente
  do que já foi carregado; busca de termo antigo encontra a prova; teste cobre
  acento e caixa.

### Lote 3 — Home personalizada

- Alimentar “assuntos seguidos” a partir de `topic_follows` (área 11) e mostrar
  provas desses assuntos.
- Criar recomendações reais baseadas em histórico local/remoto, com estado
  vazio explícito quando não houver base.
- Separar “Continuar”, “Seguindo” e “Recentes” em seções claras.
- Critério de aceite: usuário sem histórico vê estado vazio honesto; usuário com
  histórico vê recomendação explicável; nenhum dado é inventado.

### Lote 4 — Biblioteca e perfil

- Adicionar coleções personalizadas (criar, renomear, adicionar/remover prova,
  ordenar) e uma seção de histórico.
- Adicionar busca/filtro na biblioteca e cache local dos favoritos.
- Completar o perfil: bio, avatar, temas seguidos, publicações, atividade e
  estatísticas reais; preferências de tema/cronômetro.
- Critério de aceite: biblioteca funciona offline para salvos baixados; perfil
  visitante continua honesto; estatísticas só aparecem com dados reais.

### Lote 5 — Quebrar a home

- Separar `HomePage` em feed, biblioteca, perfil, detalhes e downloads, com
  repositórios/serviços injetados.
- Evitar recarregar tudo a cada troca de aba; usar cache com invalidação
  explícita.
- Critério de aceite: cada aba tem teste próprio; troca de aba não dispara
  consulta duplicada sem necessidade.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Catálogo, busca e biblioteca funcionam, mas filtros parciais e limite 50 enganam. |
| Testes | 2 | Busca e filtros têm boa cobertura; biblioteca, perfil e visitante não têm. |
| Acoplamento | 2 | Home de 2.431 linhas cria serviços e usa Supabase direto. |
| Clareza | 4 | Nomes e seções compreensíveis; falta o componente unificador. |
| Segurança | 4 | Escaping correto, somente conteúdo público, sem segredos. |
| Robustez | 2 | Filtro client-side, busca truncada, favoritos dependem de rede, sem cache. |
| Aderência | 2 | Faltam `ExamListTile`, banca/instituição, seguir, recomendar, coleções e perfil completo. |
| Portabilidade | 4 | Layout responsivo com sidebar, barra inferior e largura máxima. |

Classificação resultante: **EVOLUIR** — a base de descoberta existe e é segura,
mas precisa de um componente de lista unificado, filtros reais no servidor e as
funções sociais e pessoais que o produto promete.

## Dependências

- Área 2 para banca, instituição, disciplinas, tipo e progresso no modelo.
- Área 3 para sessão, perfil e intenção pós-login.
- Área 7 para cache local de favoritos e histórico.
- Área 9 para importação e publicação do catálogo.
- Área 11 para `topic_follows`, discussões e comunidades.
- Área 12 para RPC de busca/filtro paginado e RLS de favoritos.
- Área 16 para `ExamListTile`, tokens e estados visuais.
- Decisão de produto sobre recomendações e o que significa “seguir”.

## O que não foi verificado

- Busca real contra o Supabase ativo, incluindo acentos e termos antigos.
- Volume real do catálogo e comportamento acima de 50 resultados.
- Biblioteca e perfil em aparelho pequeno, offline e com fonte ampliada.
- Cache de imagem/brasão e licença de imagens de banca.
- Estatísticas disponíveis no backend para o perfil.
- Comportamento de favoritos ao perder sessão no meio da navegação.

## Links

- [[02 - Domínio, modelos e regras|Área 2 — Domínio]]
- [[03 - Autenticação, visitante e deep links|Área 3 — Autenticação]]
- [[07 - Persistência local, backups e provas locais|Área 7 — Persistência]]
- [[11 - Social, discussões, comunidades e denúncia|Área 11 — Social]]
- [[12 - Supabase, schema, RLS e RPCs|Área 12 — Backend]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[../../01 - Produto/Navegação e Visitante|Navegação e Visitante]]
- [[../../01 - Produto/Navegação e Visitante|Navegação e visitante]]
- [[Mapa das Áreas|Mapa das Áreas]]
