# Prova Social — Plano de Ação Mestre

*Documento-guia para execução por agente de IA. Base: planejamento estratégico de 03/11/2026 sobre o repositório NAGCODE-Dev/Prova-Social (Flutter/Dart, Supabase, v0.7.5+15).*

## 0. Instruções ao agente (leia primeiro)

1. **Este documento é a fonte de verdade do plano.** Execute uma fase por vez, na ordem, e uma tarefa por vez dentro da fase.
2. **Nada aqui foi verificado por você ainda.** Os números (linhas de arquivo, execuções de CI, PRs, versões) vêm de uma auditoria anterior. Antes de agir, confirme cada afirmação no código e no GitHub. Se divergir, registre a divergência e siga o que o repositório mostra.
3. **Não reescreva o app.** Toda mudança é incremental, reversível e coberta por testes. Mantenha as interfaces públicas atuais durante transições.
4. **Não apague o sistema antigo antes de comprovar o novo** (especialmente persistência).
5. **Uma tarefa = um commit/PR pequeno**, com testes, descrição do porquê e atualização da documentação afetada.
6. **Não invente.** Se faltar informação (decisão de produto, credencial, dado), pare e pergunte, listando as opções.
7. Ao terminar cada tarefa, informe: o que mudou, como foi testado, riscos restantes, próximo passo.

## 1. Visão e contexto

**Produto:** plataforma de aprendizagem baseada em provas reais e participação da comunidade. Ciclo central: *descobrir, salvar, resolver, errar, entender, discutir, melhorar, refazer.*

**Stack identificada (verificar):** Flutter/Dart (Android e Web); Supabase (backend, Auth, RLS); OCR local com Google ML Kit e pacote próprio `paddleocr_android`; PDFs com `pdfrx`; distribuição por GitHub Releases e Cloudflare Pages; fluxo social com perfis, assuntos, provas e discussões.

**Números da auditoria (verificar):** \~344 entradas na árvore Git, 73 arquivos em `lib/`, 42 de teste, 9 migrações/scripts SQL.

## 2. Regras invariantes (nunca violar)

- **A questão é o objeto central** do produto e da camada social. Sem feed genérico.
- **Independência de IA paga.** Nenhuma funcionalidade estrutural pode depender de API de IA paga. Importação e OCR seguem locais.
- **Nunca deduzir gabarito.** Se o documento não traz resposta confirmada, o campo fica nulo (`correctIndex = null`, base zero quando existe). Gabarito não é inferido pela IA.
- **Gabaritos oficiais ficam separados das questões públicas, em área privada.** Preservar essa separação em publicação, pacotes, cache e exportações.
- **Revisão humana antes de qualquer publicação.**
- **Procedência explícita:** oficial, comunitária ou não verificada.
- **Separação entre provas locais e públicas** e isolamento de dados por conta (RLS).
- **Privacidade:** logs e telemetria não armazenam conteúdo de provas nem respostas dos usuários.
- **Idempotência:** `clientAttemptId` e a fila de sincronização continuam evitando tentativas duplicadas.

## 3. Decisões estratégicas

**Manter:** Flutter e Supabase; questão como objeto central; OCR local (ML Kit, PaddleOCR, extração nativa, parser próprio); Focus Mode; offline com sincronização idempotente; pacotes de conteúdo (JSON + GZip + SHA-256, metadados separados do conteúdo); Supabase Auth e RLS; procedência; busca paginada por cursor; APKs por arquitetura; GitHub Actions com testes e verificações de segurança; Design System Study Surface.

**Adiar ou não investir agora:** reescrita completa; IA paga estrutural; gamificação infantil; feed social genérico; P2P; Turso; Cloudflare R2 (antes, medir custos e limites do Storage atual); comunidades complexas; expansão indiscriminada de dependências. **Congelar funcionalidades novas** enquanto houver falhas de confiabilidade nas funções essenciais.

## 4. Roadmap por fases

Ordem: 1 Auditoria, 2 Obsidian e arquitetura, 3 Fundação e confiabilidade, 4 Refatoração modular, 5 Importação e OCR, 6 Modelo de questões e publicação, 7 Versionamento de conteúdo, 8 Motor de aprendizagem, 9 Observabilidade (começa cedo, termina por último). As fases 5 a 9 completam o plano, que na fonte termina na fase 4.

### Fase 1 — Auditoria e congelamento

**Objetivo:** saber com precisão o que existe e o que funciona antes de mudar qualquer coisa.

**Tarefas**

1. Registrar SHA do `main`, versão (`pubspec.yaml`), estado do Git e data.
2. Inventariar todos os módulos de `lib/` (responsabilidade, dependências, tamanho, cobertura de teste).
3. Rodar a suíte de testes e o QA estático localmente; registrar resultado.
4. Classificar cada funcionalidade: *funciona / parcial / quebrada / não verificada*.
5. Criar baseline de desempenho: tempo de abertura de prova, de carregamento do catálogo, de importação de PDF de referência, tamanho médio de pacote.
6. Investigar a falha de QA estático no CI do PR (execução 100, 03/11) e confirmar se o `main` (execução 98, commit `b4d0c845`) está saudável.
7. Triar os PRs abertos: #17 (ONNX Runtime), #18 (testes de importação e layouts), #16 (Playwright). Prioridade: #18 e #17; **sem merge automático**, só após validação local.
8. Reconciliar documentação desatualizada: `PROVA_SOCIAL_CONTEXT.md` (setembro) e `DEPENDENCY_COMPATIBILITY.md` (ainda descreve a v0.5.0).
9. Verificar licença: o repositório é público e não tem licença formal identificada. Levar a decisão ao dono do projeto (não escolher sozinho).

**Entregáveis:** relatório de baseline (`Estado Atual`), matriz de funcionalidades, lista de pendências priorizada. **Critério de aceite:** todo número deste documento confirmado ou corrigido; CI do `main` verde e explicado.

### Fase 2 — Obsidian e arquitetura-alvo

**Objetivo:** documentação viva que guie as próximas fases.

**Tarefas**

1. Criar o vault exclusivo (estrutura na seção 5).
2. Documentar dependências, fluxos de dados e módulos reais (não os desejados).
3. Criar diagramas (importação, tentativa/sincronização, publicação, pacotes).
4. Registrar decisões em ADRs (um por decisão desta seção 3 e da Fase 3).
5. Definir a arquitetura-alvo em camadas: **Presentation** (telas, componentes, navegação); **Application** (casos de uso, orquestração); **Domain** (provas e questões, tentativas e resultados, importação e OCR, biblioteca e progresso, publicação e procedência, discussões e social); **Infrastructure** (Supabase, SQLite, Storage, OCR, arquivos, rede).
6. Regra de dependência: o domínio não depende de interface nem de fornecedor.

**Aceite:** novo contribuidor entende o fluxo ponta a ponta só lendo o vault. Instruções de agentes e especificações oficiais permanecem **versionadas no GitHub** (ex.: `AGENTS.md`); o vault referencia, não duplica.

### Fase 3 — Fundação e confiabilidade (prioridade muito alta)

**Problema:** `AttemptDraftStore` e `AttemptQueueStore` usam SharedPreferences, com uma estrutura JSON (pendentes, concluídas, provas iniciadas) regravada continuamente. Não escala para anos de histórico.

**Alvo de persistência**

| Dado | Destino |
| --- | --- |
| Preferências simples | SharedPreferences |
| Tentativas e respostas | SQLite |
| Fila de sincronização | SQLite |
| Provas locais | SQLite + arquivos |
| PDFs e imagens | Sistema de arquivos |
| Conteúdo público | Supabase Storage + cache local |
| Perfil e metadados | Supabase |

**Tarefas**

1. Definir o esquema SQLite (tentativas, respostas, fila, provas locais) com chaves estáveis e coluna de conta (isolamento por usuário).
2. Implementar camada de repositório atrás de interfaces; manter as stores atuais funcionando.
3. Sistema de migrações de esquema versionado, com testes de cada migração.
4. Escritas transacionais e atômicas; recuperação após interrupção (app morto no meio da gravação).
5. **Migração gradual dos dados:** copiar de SharedPreferences para SQLite, validar contagens e integridade, manter o formato antigo como leitura de fallback por pelo menos uma versão. Só remover após comprovação.
6. Sincronização idempotente via `clientAttemptId`; testes de reenvio duplicado.
7. Testes de concorrência (gravação simultânea, troca de conta, fila com falha de rede).
8. Revisar segurança e RLS: um usuário nunca lê nem escreve dados de outro; testes SQL de idempotência continuam passando.
9. Verificação de integridade dos pacotes (SHA-256) em todos os pontos de carga.

**Aceite:** simulação de milhares de respostas sem perda; corte de energia simulado sem corrupção; migração reversível; nenhuma regressão no fluxo offline.

### Fase 4 — Refatoração modular

**Objetivo:** reduzir concentração de responsabilidades sem mudar comportamento.

**`quiz_page.dart` (\~1.234 linhas)** separar em: estado da tentativa; persistência; cronômetro; navegação; finalização; UI da questão; UI de revisão. Resultado: Focus Mode com componentes pequenos e testáveis.

**`question_parser.dart` (\~1.097 linhas)** separar em: normalização; identificação de layouts; segmentação de questões; alternativas; gabaritos; material de apoio; avaliação de confiança.

**Método:** (a) escrever testes de caracterização do comportamento atual; (b) extrair uma responsabilidade por vez; (c) manter a API pública; (d) comparar saídas antes e depois com as provas de referência. Sem mudar regras de negócio nesta fase.

**Aceite:** testes de caracterização verdes antes e depois; nenhum arquivo central acima de um limite acordado (sugestão: \~400 linhas).

### Fase 5 — Importação e OCR (prioridade muito alta)

**Componentes existentes:** `OcrRouter`, `OcrLayoutOrderer`, `ImportQualityGate`, `QuestionParser`, `ExamMetadataSuggester`.

**Tarefas**

1. **Decisão de OCR por página:** hoje o `OcrRouter` usa um limite de 20 caracteres de texto nativo. Substituir por análise combinada: quantidade de texto, cobertura da página, distribuição dos blocos, imagens com texto, regiões detectadas, confiança do reconhecimento. Manter o limite antigo como fallback até a nova regra provar ser melhor.
2. **Melhorar reconhecimento de:** duas ou mais colunas; questões que continuam na página seguinte; tabelas; imagens associadas; cabeçalhos e rodapés; numeração inconsistente; alternativas em linhas diferentes.
3. **Conjunto permanente de provas de teste** (reais e sintéticas), ampliando o PDF sintético de 80 questões em duas colunas e o fixture Vunesp 2024. Variar bancas, estilos, escaneadas e com camada de texto parcial.
4. **Regra de regressão:** toda falha encontrada vira um teste. Medir taxa de questões corretamente identificadas por prova.
5. Garantir que o `ImportQualityGate` marque baixa confiança para revisão humana em vez de publicar.

**Aceite:** métrica de acerto por prova registrada e não regressiva; falhas novas sempre acompanhadas de teste.

### Fase 6 — Modelo de questões e publicação

**Divergência encontrada:** `ExamPublicationService` exige ao menos duas alternativas e gabarito em todas as questões, e força o tópico `Geral`, ignorando o tópico importado. O `AGENTS.md` prevê discursivas e conteúdo sem correção objetiva.

**Tarefas**

1. Suportar formalmente os tipos: múltipla escolha (alternativas + gabarito); certo ou errado (duas alternativas); discursiva (resposta textual); resposta curta (campo de resposta); análise de material (texto, imagem ou tabela de apoio).
2. Permitir questões **sem gabarito**, identificadas explicitamente (nunca preenchidas por dedução), mantendo gabaritos oficiais em área privada.
3. Preservar o tópico importado na publicação; `Geral` só como valor padrão quando não houver tópico.
4. Corrigir `ExamResult.scorePercent`: calcular sobre as questões **corrigíveis**, não sobre o total. Exibir quantas ficaram sem correção.
5. Revisar domínio, banco (migrações), publicação, pacotes e telas de resultado de forma coerente.

**Aceite:** prova mista (objetiva, discursiva, sem gabarito) importa, publica, é resolvida e pontuada corretamente.

### Fase 7 — Versionamento de conteúdo

- Evoluir o `schemaVersion` dos pacotes e versionar provas publicadas: original, correção de enunciado, de alternativas, de gabarito, alteração de mídia.
- Toda tentativa fica vinculada à **versão efetivamente resolvida**; correções posteriores não alteram resultados passados.
- Definir política de migração e de exibição de "prova corrigida" ao usuário.

### Fase 8 — Motor de aprendizagem (determinístico, sem IA)

Ciclo: **Resolver** (registrar respostas e desempenho) → **Identificar dificuldades** (disciplinas e assuntos com mais erros) → **Organizar revisões** (erradas, dúvidas, pendentes) → **Refazer** (novas tentativas a partir das dificuldades) → **Comparar evolução** (por assunto e período).

Construir sobre a prova de revisão já existente, com dados estruturados e regras determinísticas. IA só poderá ser considerada depois, como opcional.

### Fase 9 — Observabilidade

Métricas: tempo médio de importação; taxa de questões identificadas corretamente; questões que exigiram revisão; falhas de sincronização; tempo de abertura de provas; tempo de carga do catálogo; erros de publicação; tamanho médio de pacote. **Sem armazenar conteúdo privado** de provas nem respostas. Começar a instrumentar já na Fase 3 e consolidar aqui.

## 5. Estrutura do vault Obsidian

```
Prova Social/
├── 00 - Central/        Visão Geral, Estado Atual, Roadmap
├── 01 - Produto/        Visão, Público Alvo, Funcionalidades, Experiência
├── 02 - Arquitetura/    Arquitetura Geral, Módulos, Dependências, Fluxos de Dados
├── 03 - Domínios/       Questões, Provas, Tentativas, Importação, OCR, Social, Sincronização
├── 04 - Infraestrutura/ Supabase, SQLite, Storage, CI-CD
├── 05 - Qualidade/      Testes, Bugs, Performance, Segurança
├── 06 - Decisões/ADR/
└── 07 - Histórico/      Releases, Refatorações
```

O Obsidian é o centro de conhecimento; `AGENTS.md` e as especificações técnicas oficiais continuam no GitHub. Cada nota aponta para o arquivo-fonte, nunca o copia.

## 6. Pendências de engenharia (checklist)

- [ ] Confirmar CI do `main` verde e explicar a falha da execução 100.
- [ ] Validar e decidir PR #18 (testes de importação) e PR #17 (ONNX Runtime); PR #16 (Playwright) depois.
- [ ] Atualizar `PROVA_SOCIAL_CONTEXT.md` e `DEPENDENCY_COMPATIBILITY.md` para a versão atual.
- [ ] Decidir licença do repositório (decisão do dono).
- [ ] Manter: CI com análise estática e testes, QA P0 e testes de navegador, auditoria de dependências Dart/npm/Android, lockfiles Gradle, Dependabot, testes de idempotência SQL, releases versionadas.

## 7. Definição de pronto (por tarefa)

1. Testes novos e antigos passando; QA estático limpo.
2. Sem regressão no fluxo offline, na sincronização e na importação das provas de referência.
3. Documentação e vault atualizados; ADR criado se houve decisão.
4. Nenhum dado privado em logs; RLS e separação de gabaritos preservadas.
5. Plano de reversão descrito no PR.

## 8. Primeira ação

Executar a **Fase 1, tarefas 1 a 3**, e responder com: SHA e versão confirmados, resultado dos testes locais, divergências encontradas em relação a este documento e proposta de ordem para as tarefas 4 a 9.
