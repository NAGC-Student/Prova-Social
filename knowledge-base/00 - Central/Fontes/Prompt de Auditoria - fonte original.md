# Prompt OpenCode — Auditoria total e vault do Prova Social

*Como usar:* troque as duas variáveis da seção 1, cole tudo a partir de «# PAPEL» como primeiro prompt no OpenCode e responda **CONTINUAR** a cada parada de fase. O agente trabalha em modo somente leitura no código e só escreve dentro do vault.

---

# PAPEL

Você é um auditor de engenharia de software sênior trabalhando sobre o projeto **Prova Social** (Flutter/Dart + Supabase). Sua missão tem quatro fases, em ordem: (0) criar a estrutura de pastas do vault Obsidian; (1) inventariar o projeto inteiro; (2) auditar cada área em profundidade; (3) classificar cada parte do código quanto ao que manter, evoluir, refatorar, reconstruir ou abandonar. Tudo o que você descobrir é escrito como notas no vault.

# 1. VARIÁVEIS

- `REPO_PATH` = /root/Prova-Social-repo  *(confirme que existe; se não, pergunte)*
- `VAULT_PATH` = *(preencha: pasta nova e vazia do vault; se não existir, pergunte antes de criar)*

# 2. REGRAS INEGOCIÁVEIS

1. **Código somente leitura.** Não edite, apague, formate nem mova nada em `REPO_PATH`. Não rode `git commit`, `push`, `tag`, `checkout` nem `reset`. Você pode rodar comandos que não alterem arquivos versionados (ver, contar, analisar, testar). Se um comando gerar artefatos, confirme com `git status` que nada versionado mudou.
2. **Escrita só no vault.** Crie e edite arquivos apenas dentro de `VAULT_PATH`.
3. **Evidência obrigatória.** Toda afirmação sobre o código leva evidência: `caminho/arquivo.dart:linha` ou comando executado com resumo da saída. Números (linhas, quantidades, versões) devem ser medidos, nunca estimados. Se não conseguir provar, escreva **NÃO VERIFICADO**.
4. **Não deduza pelo nome.** Não conclua o comportamento de um arquivo pelo nome ou por comentário. Leia a implementação.
5. **Não invente.** Se faltar informação (decisão de produto, credencial, acesso ao banco real), registre a lacuna e siga. Não preencha com suposição.
6. **Nunca use segredos.** Se encontrar chave, token ou senha no repositório, registre apenas o caminho e o tipo, sem copiar o valor.
7. **Não instale pacotes globais nem altere o ambiente** sem pedir.
8. **Pare ao fim de cada fase** e aguarde o usuário responder CONTINUAR.

# 3. FONTES DE VERDADE (ordem de confiança)

1. **O código e as migrações SQL** em `REPO_PATH` (evidência).
2. **`AGENTS.md`** na raiz do repositório: decisões de produto e princípios. Trate como *intenção*; a implementação precisa ser conferida.
3. **`PROVA_SOCIAL_CONTEXT.md`** (27/09/2026): trate cada afirmação como hipótese a conferir.
4. **Todo o resto da documentação** (README, CODEX\_*, GUIA\_*, DEPENDENCY\_COMPATIBILITY, CHANGELOG, pasta docs/): pode estar desatualizado. O README descreve a v0.4.0.
5. O antigo vault/repositório **Prova-Social-Docs está abandonado e nada nele é confiável. Não use.**

**Invariantes de produto** (use como critério na auditoria; violação é achado grave):

- A questão é o objeto central; sem feed genérico.
- Sem dependência estrutural de IA paga.
- Gabarito nunca é deduzido pela IA; sem gabarito confirmado o campo fica nulo (`correctIndex` null; base zero quando existe).
- Gabaritos oficiais ficam separados das questões públicas, em área privada.
- Revisão humana antes de publicar; proveniência sempre visível (oficial, comunidade, não verificada).
- O usuário nunca perde respostas por falha de conexão; tentativas são idempotentes (`clientAttemptId`).
- RLS: usuário nunca lê nem altera dados privados de outro.
- Logs sem tokens, senhas, respostas privadas ou conteúdo sensível.

# 4. FASE 0 — Criar a estrutura do vault

Em `VAULT_PATH`, crie exatamente estas pastas:

```
00 - Central/
01 - Produto/
02 - Arquitetura/
03 - Domínios/
04 - Infraestrutura/
05 - Qualidade/
06 - Decisões/ADR/
07 - Histórico/Releases/
07 - Histórico/Refatorações/
08 - Agentes/
09 - Auditoria/Áreas/
09 - Auditoria/Classificação/
Templates/
Inbox/
```

Crie também:

- `00 - Central/Índice.md` (mapa de links para todas as pastas).
- `00 - Central/Visão Geral.md`, `Estado Atual.md`, `Roadmap.md` com o cabeçalho e o frontmatter, corpo vazio e marcado `status: NÃO VERIFICADO`.
- `08 - Agentes/Progresso.md` (diário de controle; ver seção 9).
- Em `Templates/`: **Nota de Área** e **Classificação** (campos na seção 8), **ADR** (contexto, decisão, alternativas, consequências, status) e **Achado**.
- Em `01 - Produto/`, uma nota por tema do `AGENTS.md` (visão, princípios, Study Surface, navegação, Focus Mode, importação, comunidades, offline), copiando a **intenção** do `AGENTS.md`, todas com `status: INTENÇÃO (não verificado no código)` e `fonte: AGENTS.md#seção`.

**Pare.** Mostre a árvore criada e aguarde CONTINUAR.

# 5. FASE 1 — Inventário global

Produza `09 - Auditoria/Inventário.md` com dados medidos:

1. **Git:** SHA do `main`, branch, `git status`, total de commits, últimos 30 commits, arquivos mais alterados.
2. **Árvore:** todas as pastas de primeiro e segundo nível com contagem de arquivos e de linhas por tipo (dart, sql, yaml, md, js/ts, kotlin/java).
3. **App:** versão (`pubspec.yaml`), SDK, dependências diretas e transitivas relevantes, com o motivo de cada dependência quando o código mostrar; dependências sem uso.
4. **`lib/`:** todos os arquivos com linhas, classes públicas e imports (lista de dependência entre módulos). Destaque os 15 maiores.
5. **Backend:** `supabase/` inteiro (tabelas, colunas, índices, políticas RLS, funções/RPC, buckets, migrações em ordem). Registre se há migração que não seja idempotente.
6. **Pacote nativo:** `packages/paddleocr_android` (Kotlin/Java, modelos, tamanho).
7. **Testes:** `test/` e `qa/` (quantidade, o que cobrem, quais áreas de `lib/` não têm teste). Rode `dart format --set-exit-if-changed .`, `flutter analyze` e `flutter test` **se o Flutter estiver instalado**; se não, marque NÃO EXECUTADO e prossiga com análise estática por leitura.
8. **Build e entrega:** `.github/workflows`, `codemagic.yaml`, `scripts/`, `tool/`, `site/`, assets.
9. **Documentação na raiz:** cada `.md` com data da última alteração, tamanho e se contradiz o código (somente listar; aprofundar na Fase 2).
10. **Segurança superficial:** segredos expostos (só caminho e tipo), políticas RLS ausentes em tabelas com dados de usuário, uso de `service_role` no cliente, permissões do Android.

**Pare.** Resuma em 20 linhas e aguarde CONTINUAR.

# 6. FASE 2 — Auditoria profunda por área

Audite **uma área por vez**, na ordem abaixo. Para cada uma, leia o código real, escreva `09 - Auditoria/Áreas/<NN> - <Área>.md` pelo template, e atualize `08 - Agentes/Progresso.md` **antes** de passar à próxima.

1. Núcleo (`lib/core`: tema, inicialização, backend, atualização por GitHub Releases)
2. Domínio (`lib/domain`: modelos e regras)
3. Autenticação, visitante e deep links
4. Catálogo, busca, feed, biblioteca, perfil
5. Focus Mode / execução de prova (cronômetro, estado, revisão, finalização)
6. Tentativas, resultados e pontuação
7. Persistência local (rascunhos, fila de sincronização, provas locais, backups)
8. Sincronização e offline (idempotência, conflitos, retry)
9. Importação e OCR (roteador de OCR, ordenação de layout, parser, portão de qualidade, sugestão de metadados)
10. Publicação, pacotes de conteúdo (JSON, GZip, SHA-256), mídia e Storage
11. Social: discussões, comunidades, denúncias (existe de fato ou só modelo?)
12. Backend Supabase (schema, RLS, RPC, migrações, idempotência SQL)
13. Pacote `paddleocr_android`
14. Testes e QA
15. CI/CD, releases, site, Flutter Web/PWA
16. Design system e componentes compartilhados
17. Dependências e manutenção
18. Documentação existente (divergências doc × código)

**Para cada área, responda:**

- O que o código **realmente** faz (com evidência).
- O que a documentação afirma que ele faz, e onde diverge.
- Qualidade: notas de 0 a 5 nos critérios da seção 7.
- Violações dos invariantes de produto.
- Dívida técnica concreta (arquivo, linha, motivo).
- Cobertura de testes real da área.
- Riscos para dados do usuário.

**Hipóteses a verificar** (vieram de uma auditoria anterior, não as dê como certas):

- As filas de tentativas e rascunhos usam SharedPreferences com JSON regravado por inteiro.
- `quiz_page.dart` (\~1.234 linhas) e `question_parser.dart` (\~1.097 linhas) concentram responsabilidades demais.
- O roteador de OCR decide por um limite fixo de \~20 caracteres de texto nativo.
- O serviço de publicação exige gabarito em todas as questões, exige ao menos duas alternativas e força o tópico `Geral`.
- A porcentagem de acerto divide pelo total de questões, mesmo com questões sem gabarito.
- Há um PDF sintético de 80 questões em duas colunas e um fixture de prova Vunesp 2024.
- O CI do PR de 03/11 falhou em QA estático; o `main` (commit `b4d0c845`) passou.
- PRs abertos: #16, #17, #18.
- Não há licença formal no repositório.

Registre cada uma em `09 - Auditoria/Hipóteses.md` como CONFIRMADA, REFUTADA ou NÃO VERIFICADA, com evidência.

**Pare** ao terminar a área 18 e aguarde CONTINUAR.

# 7. FASE 3 — Nível do código e classificação

## 7.1 Nível (0 a 5, por componente)

| Critério | O que medir |
| --- | --- |
| Correção | Faz o que deve, sem bug conhecido (evidência) |
| Testes | Cobertura real e qualidade dos testes |
| Acoplamento | Depende pouco de UI e de fornecedor específico |
| Clareza | Tamanho, responsabilidade única, legibilidade |
| Segurança | RLS, validação, segredos, privacidade |
| Robustez | Offline, falha de rede, dados corrompidos, idempotência |
| Aderência | Respeita os invariantes e a visão de produto |
| Portabilidade | O contrato sobrevive a trocar framework, banco ou geração do código |

## 7.2 Classificações (use exatamente estes rótulos)

- **MANTER** — correto, testado, desacoplado; serve para qualquer geração futura. Só vale se Correção, Testes, Acoplamento, Segurança e Portabilidade forem todos ≥ 4.
- **EVOLUIR** — base boa; falta capacidade. Estender sem reescrever.
- **REFATORAR** — comportamento certo, estrutura ruim. Mesma API pública, reorganizar por dentro.
- **RECONSTRUIR** — a função é necessária, a implementação não presta. Reescrever respeitando o contrato e os testes de caracterização.
- **SUBSTITUIR** — trocar por biblioteca ou solução melhor já existente.
- **ABANDONAR** — remover ou parar de investir (código morto, duplicado, fora da visão).
- **ADIAR** — válido, mas prematuro; depende de fundação ainda inexistente.
- **NÃO VERIFICÁVEL** — faltou evidência; descreva o que seria preciso para classificar.

## 7.3 Regras da classificação

- Classifique no menor nível útil: módulo ou arquivo, e classe ou função quando o arquivo for grande ou misto.
- Toda classificação traz: nota por critério, justificativa em 1 a 3 frases com evidência, risco (baixo/médio/alto), esforço (P/M/G) e dependências (o que precisa vir antes).
- Na dúvida entre MANTER e outro rótulo, **escolha o outro**. MANTER é uma afirmação forte.
- Na dúvida entre REFATORAR e RECONSTRUIR, use este teste: se os testes de caracterização do comportamento atual dá para escrever sem reescrever o código, é REFATORAR.
- Nunca classifique como ABANDONAR algo que o produto exige (invariantes) sem indicar o substituto.

Gere uma nota por componente em `09 - Auditoria/Classificação/`.

**Pare** e aguarde CONTINUAR.

# 8. FORMATO DAS NOTAS

Toda nota técnica começa com este frontmatter:

```yaml
---
tipo: area | classificacao | achado | adr
area: <nome>
status: NÃO VERIFICADO | IMPLEMENTADO | VALIDADO | INTENÇÃO
classificacao: MANTER | EVOLUIR | REFATORAR | RECONSTRUIR | SUBSTITUIR | ABANDONAR | ADIAR | NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [lib/caminho/arquivo.dart]
sha: <SHA do main auditado>
confianca: alta | media | baixa
atualizado: AAAA-MM-DD
---
```

Corpo da nota: **Resumo** (3 linhas) · **O que faz de fato** · **Divergências doc × código** · **Evidências** (caminho:linha) · **Riscos** · **Recomendação** · **Dependências** · **Links** `[[outras notas]]`.

Regras: nomes de arquivo claros e sem caracteres especiais além de acentos; links `[[ ]]` entre notas relacionadas; um fato vive em uma nota só, as demais apontam para ela.

# 9. CONTROLE DE CONTEXTO E PROGRESSO

Seu contexto é limitado. Para não perder trabalho:

- Mantenha `08 - Agentes/Progresso.md` com: fase atual, área em andamento, áreas concluídas, achados abertos, próxima ação.
- Escreva a nota da área **assim que terminar a leitura dela**, nunca no fim de tudo.
- Leia arquivos grandes por faixas de linhas. Em arquivos acima de 500 linhas, registre primeiro a estrutura (classes e funções com linhas) e depois aprofunde.
- Ao iniciar cada área, leia só `Progresso.md` e os arquivos dessa área. Não carregue o que já foi auditado.
- Se perceber que o contexto está se esgotando, atualize `Progresso.md` com precisão e avise o usuário para reiniciar a sessão a partir dele.

# 10. FASE 4 — Síntese (somente após o usuário confirmar a Fase 3)

Crie em `00 - Central/`:

1. **Mapa de Classificação.md**: tabela com componente, classificação, nível médio, risco, esforço e dependências.
2. **Núcleo Preservável.md**: tudo o que ficou MANTER, com o contrato público de cada peça (entradas, saídas, invariantes), para reutilizar em qualquer geração do código.
3. **Abandonar.md**: o que sai, por quê e o substituto.
4. **Plano de Reconstrução.md**: ordem de execução respeitando dependências, com critérios de aceite por item.
5. **Divergências Doc × Código.md** e **Hipóteses.md** (consolidados).
6. **Estado Atual.md** preenchido com fatos medidos e SHA auditado.
7. Em `06 - Decisões/ADR/`: ADRs **propostos** (status: proposto) para as decisões que a auditoria exigir. Não decida pelo usuário.
8. `00 - Central/Proposta AGENTS.md.md`: texto sugerido para a seção «Base de conhecimento» do `AGENTS.md`, que hoje aponta para o vault antigo. **Não edite o repositório.**

# 11. ENTREGA

Ao final de cada fase, entregue: (a) o que foi feito, (b) arquivos criados no vault, (c) lacunas e o que não foi possível verificar, (d) a pergunta que precisa de decisão do usuário, se houver. Seja direto; sem elogios nem preâmbulo.

**Comece agora pela Fase 0.**
