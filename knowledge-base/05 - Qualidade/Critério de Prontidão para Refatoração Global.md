---
tipo: checklist
area: prontidão para refatoração global
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [knowledge-base/, lib/, test/, supabase/]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-05
---

# Critério de prontidão para a refatoração global

Pergunta que esta nota responde: **o conteúdo acumulado no vault já permite
planejar o app novo, ou ainda estamos coletando?** A resposta é uma lista com
evidência, não uma sensação.

A refatoração global é tratada aqui como "reconstruir o app sobre o que foi
aprendido", no espírito do [Plano Mestre](../00%20-%20Central/Plano%20Mestre.md)
— não como big-bang (risco 12 da [[../09 - Auditoria/Síntese da Refatoração|Síntese]]).

## Os 12 pré-requisitos e o estado hoje

| # | Pré-requisito | Onde está | Estado |
|---:|---|---|---|
| 1 | Baseline e esteira verde | [[../00 - Central/Estado Atual]], Lote 0 | **Feito local** 2026-11-05: `dart format` exit 0, `flutter analyze` limpo, 290 testes + 1 ignorado, `qa/run_static.sh` verde com testes do site incluídos; probes portáveis em `test/manual/`. **Falta:** commit, push e CI confirmarem. |
| 2 | Modelo de domínio atual inventariado | [[../03 - Domínios/Modelo de Domínio Atual]] | **Feito** — entidades, campos, 4–5 sites de pontuação, formato perdido na borda. |
| 3 | Contratos alvo especificados (C1–C7) | [[../03 - Domínios/Contratos de Domínio Alvo]] | **Feito em nível de especificação**; **não aprovado** (ADR-0002/0003 pendentes). |
| 4 | Inventário de dados e persistência | [[../04 - Infraestrutura/Inventário de Persistência e Dados]] | **Feito** para o repo; **não resolvido**: 4 tabelas usadas pelo app só existem em SQL solto; `questions` não tem `format` e força 2–8 alternativas, então **discursiva não cabe no schema**; o estado remoto do Supabase segue não verificado. |
| 5 | Mapa de dependências medido | [[../02 - Arquitetura/Mapa de Dependências]] | **Feito** — arestas, fan-in/out, vendor por camada, 26 usos de `Supabase.instance` em 10 arquivos, 7 defaults de singleton. |
| 6 | Fluxos reais com estados de falha | [[../02 - Arquitetura/Fluxos Reais]] | **Feito** — F1 importação, F2 tentativa/sync (máquina de 6 estados, backoff, idempotência), F3 publicação, F4 consumo. |
| 7 | Inventário de telas e cobertura | [[../01 - Produto/Inventário de Telas e Cobertura]] | **Feito** — 17 destinos, 34 `MaterialPageRoute`, cobertura por tela, ausências. |
| 8 | ADRs estruturais aceitos | [[../06 - Decisões/ADR/README]] | **Bloqueado em você:** 12 ADRs propostos, 0 aceitos. A refatoração não começa sem 0002 (modelo), 0003 (versão) e 0004 (persistência). |
| 9 | Testes de caracterização do comportamento que vai mudar | — | **Não existe.** Hoje há 290 testes, mas nenhum deles *congela* as 4 regras de pontuação nem a validação de publicação. Sem isso, extrair `QuizPage`/`PublishPage` muda comportamento sem sinal. |
| 10 | Teste ponta a ponta do fluxo do §21 | não há `integration_test/` | **Não existe** (ver área 14 e [[../09 - Auditoria/Síntese da Refatoração|síntese]]). |
| 11 | Orçamento não-funcional medido (APK, OCR tempo/memória, tamanho de payload, cobertura por arquivo) | — | **Não existe.** Só números pontuais (arm64 82,1 MB; universal local 248,1 MB). |
| 12 | Vault versionado com hierarquia documental | `.gitignore` já cobre `knowledge-base/.obsidian/workspace.json` | **Não feito:** `git ls-files knowledge-base` = 0. A auditoria inteira segue fora do Git. |

## Leitura honesta

**O que já dá para fazer hoje:** desenhar o app novo. As notas 2, 3, 5, 6, 7
respondem "o que o app é, onde está, como flui e o que cobre" com evidência
`arquivo:linha`. Um plano de camadas, uma tabela de rotas e um contrato de
domínio podem ser escritos agora sem adivinhação.

**O que ainda não dá:** executar a refatoração global. Os motivos, em ordem de
causa — não são burocracia, são três coisas que uma refatoração *precisa* saber e
hoje não sabe:

1. **Não existe resposta para "mudou o comportamento?"** (itens 9 e 10). A suíte
   tem 290 testes, mas nenhum congela as 4 definições de pontuação, nem a
   validação de publicação, nem a retomada de rascunho. Os 7 testes de widget em
   `test/ux/` pumpam a tela-mãe: ao extrair controllers de `QuizPage`
   (1.501 linhas, 16 classes, 15 privadas), eles **vão quebrar por construção**, e
   não há como distinguir "quebrei o teste" de "quebrei o app". Refatorar sem
   caracterização é trocar a redação sem ler o que o texto diz.
2. **A refatoração é obrigada a escolher uma regra que é decisão de produto**
   (item 8). `blank` conta no denominador? `unknownAnswer` entra na prova de
   erros? discursiva é publicável? Hoje cada lugar do código responde diferente
   ([[../03 - Domínios/Modelo de Domínio Atual]] mede 4–5 sitios). Um refactor não
   pode "manter o comportamento" porque o
   comportamento é contraditório — escolher é escrever ADR-0002/0003/0004, e isso
   cabe ao responsável, não ao agente.
3. **O destino dos dados é desconhecido** (item 4). `answers` é mapa posicional
   (`attempt_draft_store.dart:15`); convertê-lo para `QuestionId` é migração de
   dados, e o schema autoritativo não existe no repo: 4 tabelas lidas pelo app só
   aparecem em SQL solto que nenhum script aplica, `media_assets`/`exam_media`
   estão definidos nas duas trilhas, e `questions` **não tem coluna `format` e
   impõe 2–8 alternativas** (`202609210001_core.sql:44-46`) — ou seja, o produto
   alvo não cabe no banco atual sem migration. Migração sobre schema desconhecido
   é chute.

Agravante operacional: **nada do Lote 0 está commitado**. `main` continua
vermelha no SHA publicado, então qualquer commit de refatoração cai sobre baseline
vermelha e uma falha nova não é atribuível.

## O que NÃO está validado (limite honesto desta etapa)

- **Tudo que está escrito aqui vem de leitura estática** de imports, SQL, Dart e
  testes no worktree. Nada foi executado em Android/iOS, navegador real, leitor de
  tela ou Supabase remoto.
- **O worktree está sujo** (`git status`: Lote 0 + vault). As medidas valem para
  `05a8fc1` + essas alterações, não para o `main` publicado.
- **O vault continua fora do Git** (`git ls-files knowledge-base` = 0): as 7 notas
  novas podem ser perdidas.
- **Números que eu errei e corrigi nesta verificação:** chamadas de
  `Supabase.instance` são **26** em 10 arquivos (eu havia escrito 24); destinos em
  classe privada são **4** (havia dito 5). A queda 296 → 290 testes foi
  conferida: os 4 probes movidos continham exatamente 6 `test()`.
- **Não verificado:** se `format` sobrevive de verdade ao ciclo completo
  importação → publicação → download (a publicação não envia `format`, mas isto é
  inferência da leitura de `exam_publication_service.dart:63-69`, não teste
  executado).

## Gatilho sugerido para encerrar esta etapa de investigação

Encerrar "investigar e acumular" e abrir "planejar a refatoração" quando:

- [ ] ADR-0002, 0003 e 0004 existirem como arquivos com status `aceito`.
- [ ] Houver teste de caracterização nomeado para: cada uma das 4 regras de
      pontuação, a validação de publicação da tela e do serviço, e a retomada de
      rascunho após recriar o widget.
- [ ] As migrations reproduzirem 100 % das tabelas que o cliente toca (nenhuma
      dependência de SQL solto), com `local_db_test.sh` no CI.
- [ ] O vault estiver commitado.
- [ ] Houver um `integration_test/` mínimo (documento sintético) percorrendo
      importar → revisar → publicar → fazer → finalizar.

Sem esses cinco, a etapa continua sendo a correta: acumular conteúdo. Com eles, o
conteúdo vira plano executável.

## O que esta etapa já produziu (2026-11-05)

| Nota | Conteúdo | Status |
|---|---|---|
| [[../03 - Domínios/Modelo de Domínio Atual]] | domínio real, 236 linhas, políticas espalhadas | VALIDADO |
| [[../03 - Domínios/Contratos de Domínio Alvo]] | C1–C7 com invariantes e testes exigidos | INTENÇÃO |
| [[../04 - Infraestrutura/Inventário de Persistência e Dados]] | 3 trilhas de SQL, chaves locais, RPCs | VALIDADO |
| [[../02 - Arquitetura/Mapa de Dependências]] | arestas, vendor, singletons, classes por arquivo | VALIDADO |
| [[../02 - Arquitetura/Fluxos Reais]] | F1–F4 com estados de falha | VALIDADO |
| [[../01 - Produto/Inventário de Telas e Cobertura]] | 17 telas, navegação, cobertura | VALIDADO |

## Links

[[../00 - Central/Roadmap]] · [[../09 - Auditoria/Síntese da Refatoração]] ·
[[../06 - Decisões/ADR/README]] · [[../00 - Central/Estado Atual]] ·
[[Validação Atual]]
