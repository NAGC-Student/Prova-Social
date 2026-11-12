# Inventário de Arquivos Markdown — Prova Social

Esta é a entrega da **Fase 1.1**: o inventário completo de todos os arquivos `.md` relevantes para a auditoria, incluindo o repositório principal, o vault Obsidian (`knowledge-base/`) e os guias históricos em `docs/historico/`.

## A. Repositório principal (raiz e docs/)

| # | Caminho | Tipo | Observação |
|---|---------|------|------------|
| 1 | `AGENTS.md` | Fonte normativa | Diretrizes do produto e processo. Fonte normativa #1. Inclui §13 sobre não armazenar/redistribuir provas completas. |
| 2 | `README.md` | Produto | Landing/produto. Inclui aviso sobre não armazenar provas completas; ainda promete câmera/galeria que não existem. |
| 3 | `LICENSE` | Legal | Distribuição restrita (ADR-0007, alternativa C). |
| 4 | `SOLUTION_SUMMARY.md` | Relatório | Sumário de solução executado previamente. |
| 5 | `docs/DIAGNOSTICO_ATUAL.md` | Diagnóstico | Fotografia do estado em 26/09 e 09/10/2026. |
| 6 | `docs/RELATORIO_P0_20260926.md` | Relatório P0 | Relatório de execução P0. |
| 7 | `docs/REVISAO_EXTERNA_20260926.md` | Revisão externa | Revisão externa de 26/09/2026. |
| 8 | `docs/REVISAO_MIGRATION_REMOTA.md` | Revisão migration | Migração remota aplicada com rollback. |
| 9 | `docs/ROADMAP_EXECUCAO.md` | Roadmap | Plano de execução. |
| 10 | `docs/TESTES_POSTGRES_LOCAL.md` | Testes | Testes Postgres local/PGlite. |
| 11 | `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md` | Integração | Rotas, deploy, limites de importação/compartilhamento. |
| 12 | `docs/UX_LOCAL_SEARCH.md` | UX | Busca local. |
| 13 | `docs/historico/AUDIT.md` | Histórico | Auditoriam congelada em 03/11/2026; não reflete 0.7.5+15. |
| 14 | `docs/historico/CHANGELOG_0.6.0.md` | Histórico | Changelog v0.6.0. |
| 15 | `docs/historico/CHANGELOG_0.7.2.md` | Histórico | Changelog v0.7.2. |
| 16 | `docs/historico/CHANGELOG_0.7.3.md` | Histórico | Changelog v0.7.3. |
| 17 | `docs/historico/CHANGELOG_0.7.4.md` | Histórico | Changelog v0.7.4. |
| 18 | `docs/historico/CHANGELOG_0.7.5.md` | Histórico | Changelog v0.7.5. |
| 19 | `docs/historico/CODEX_P0_GOAL.md` | Histórico | Goal P0 (congelado 07/11/2026). |
| 20 | `docs/historico/CODEX_QA_COMPLETO_PROVA_SOCIAL.md` | Histórico | QA completo (congelado 07/11/2026). |
| 21 | `docs/historico/DEPENDENCY_COMPATIBILITY.md` | Histórico | Declara v0.5.0; desatualizado. |
| 22 | `docs/historico/DESIGN_SYSTEM.md` | Histórico | Declara `#101311`; divergente do app (`#050907`). |
| 23 | `docs/historico/GOOGLE_AUTH_SETUP.md` | Histórico | Configuração Google Auth. |
| 24 | `docs/historico/GUIA_ACODE_SUPABASE.md` | Histórico | Guia Supabase. |
| 25 | `docs/historico/GUIA_REDIRECT_LOGIN.md` | Histórico | Redirect login. |
| 26 | `docs/historico/IMPLEMENTATION_REPORT.md` | Histórico | Relatório de implementação. |
| 27 | `docs/historico/PROVA_SOCIAL_CONTEXT.md` | Histórico | Contexto de 27/09/2026. |
| 28 | `docs/historico/SECOND_PHASE_REPORT.md` | Histórico | Relatório fase 2 (benchmark 46 PDFs). |
| 29 | `docs/project-knowledge/README.md` | Base conhecimento | README da base de conhecimento. |

## B. Vault Obsidian — `knowledge-base/`

### 00 — Central

| # | Caminho | Tipo |
|---|---------|------|
| 30 | `knowledge-base/README.md` | README do vault |
| 31 | `knowledge-base/00 - Central/Índice.md` | Índice central |
| 32 | `knowledge-base/00 - Central/Estado Atual.md` | Estado atual (validado) |
| 33 | `knowledge-base/00 - Central/Plano Mestre.md` | Plano mestre |
| 34 | `knowledge-base/00 - Central/Roadmap.md` | Roadmap |
| 35 | `knowledge-base/00 - Central/Visão Geral.md` | Visão geral |
| 36 | `knowledge-base/00 - Central/Fontes/Plano de Ação Mestre - fonte original.md` | Fonte original |
| 37 | `knowledge-base/00 - Central/Fontes/Prompt de Auditoria - fonte original.md` | Fonte original |
| 38 | `knowledge-base/00 - Central/Fontes/README.md` | Fontes |

### 01 — Produto

| # | Caminho | Tipo |
|---|---------|------|
| 39 | `knowledge-base/01 - Produto/Comunidades.md` | Produto |
| 40 | `knowledge-base/01 - Produto/Entrada por imagem e câmera.md` | Produto |
| 41 | `knowledge-base/01 - Produto/Fluxo de Entrada e Criação.md` | Produto |
| 42 | `knowledge-base/01 - Produto/Focus Mode.md` | Produto |
| 43 | `knowledge-base/01 - Produto/Importação e OCR.md` | Produto (importação/OCR) |
| 44 | `knowledge-base/01 - Produto/Inventário de Telas e Cobertura.md` | Produto |
| 45 | `knowledge-base/01 - Produto/Navegação e Visitante.md` | Produto |
| 46 | `knowledge-base/01 - Produto/Offline e Sincronização.md` | Produto |
| 47 | `knowledge-base/01 - Produto/Princípios.md` | Produto |
| 48 | `knowledge-base/01 - Produto/Study Surface.md` | Produto (design) |
| 49 | `knowledge-base/01 - Produto/Visão do Produto.md` | Produto |

### 02 — Arquitetura

| # | Caminho | Tipo |
|---|---------|------|
| 50 | `knowledge-base/02 - Arquitetura/Arquitetura Alvo.md` | Arquitetura |
| 51 | `knowledge-base/02 - Arquitetura/Fluxos Propostos.md` | Arquitetura |
| 52 | `knowledge-base/02 - Arquitetura/Fluxos Reais.md` | Arquitetura |
| 53 | `knowledge-base/02 - Arquitetura/Mapa de Dependências.md` | Arquitetura |
| 54 | `knowledge-base/02 - Arquitetura/Mapa de Módulos.md` | Arquitetura |

### 03 — Domínios

| # | Caminho | Tipo |
|---|---------|------|
| 55 | `knowledge-base/03 - Domínios/Contratos de Domínio Alvo.md` | Domínio |
| 56 | `knowledge-base/03 - Domínios/Dependências e pins.md` | Domínio |
| 57 | `knowledge-base/03 - Domínios/Fluxos Principais.md` | Domínio |
| 58 | `knowledge-base/03 - Domínios/Modelo de Domínio Atual.md` | Domínio |

### 04 — Infraestrutura

| # | Caminho | Tipo |
|---|---------|------|
| 59 | `knowledge-base/04 - Infraestrutura/Dados e Segurança.md` | Infraestrutura |
| 60 | `knowledge-base/04 - Infraestrutura/Inventário de Persistência e Dados.md` | Infraestrutura |

### 05 — Qualidade

| # | Caminho | Tipo |
|---|---------|------|
| 61 | `knowledge-base/05 - Qualidade/Auditoria de Clean Code e SOLID medida.md` | Qualidade |
| 62 | `knowledge-base/05 - Qualidade/Benchmark de OCR.md` | Qualidade (OCR) |
| 63 | `knowledge-base/05 - Qualidade/Critério de Prontidão para Refatoração Global.md` | Qualidade |
| 64 | `knowledge-base/05 - Qualidade/Critérios de Qualidade de Código.md` | Qualidade |
| 65 | `knowledge-base/05 - Qualidade/Matriz de dependências.md` | Qualidade |
| 66 | `knowledge-base/05 - Qualidade/Tamanho do APK.md` | Qualidade |
| 67 | `knowledge-base/05 - Qualidade/Validação Atual.md` | Qualidade |

### 06 — Decisões (ADRs)

| # | Caminho | Tipo |
|---|---------|------|
| 68 | `knowledge-base/06 - Decisões/ADR/ADR-0001 - Paleta e tema.md` | ADR |
| 69 | `knowledge-base/06 - Decisões/ADR/ADR-0002 - Modelo de questão, gabarito e publicação.md` | ADR |
| 70 | `knowledge-base/06 - Decisões/ADR/ADR-0003 - Versionamento de conteúdo e vínculo da tentativa.md` | ADR |
| 71 | `knowledge-base/06 - Decisões/ADR/ADR-0004 - Persistência local e durabilidade.md` | ADR |
| 72 | `knowledge-base/06 - Decisões/ADR/ADR-0005 - Distribuição Android e seleção de ABI.md` | ADR |
| 73 | `knowledge-base/06 - Decisões/ADR/ADR-0006 - Escopo de importação por câmera.md` | ADR |
| 74 | `knowledge-base/06 - Decisões/ADR/ADR-0007 - Licença do app e fixtures de terceiros.md` | ADR |
| 75 | `knowledge-base/06 - Decisões/ADR/ADR-0008 - Hierarquia documental e versionamento do vault.md` | ADR |
| 76 | `knowledge-base/06 - Decisões/ADR/ADR-0009 - Política de dependências e pins.md` | ADR |
| 77 | `knowledge-base/06 - Decisões/ADR/ADR-0010 - Comunidades, moderação e ciclo de vida.md` | ADR |
| 78 | `knowledge-base/06 - Decisões/ADR/ADR-0011 - Tamanho de APK, modelos e componentes nativos.md` | ADR |
| 79 | `knowledge-base/06 - Decisões/ADR/ADR-0012 - Acessibilidade, tema e contraste.md` | ADR |
| 80 | `knowledge-base/06 - Decisões/ADR/ADR-0017 - Pilha OCR PaddleOCR e ML Kit.md` | ADR |
| 81 | `knowledge-base/06 - Decisões/ADR/ADR.md` | ADR |
| 82 | `knowledge-base/06 - Decisões/ADR/README.md` | ADR (índice) |

### 07 — Histórico

| # | Caminho | Tipo |
|---|---------|------|
| 83 | `knowledge-base/07 - Histórico/Refatorações/README.md` | Histórico |
| 84 | `knowledge-base/07 - Histórico/Releases/README.md` | Histórico |

### 08 — Agentes

| # | Caminho | Tipo |
|---|---------|------|
| 85 | `knowledge-base/08 - Agentes/Progresso.md` | Progresso dos agentes |

### 09 — Auditoria

| # | Caminho | Tipo |
|---|---------|------|
| 86 | `knowledge-base/09 - Auditoria/Inventário.md` | Inventário global |
| 87 | `knowledge-base/09 - Auditoria/Documentação e Divergências.md` | Doc × código |
| 88 | `knowledge-base/09 - Auditoria/Hipóteses.md` | Hipóteses |
| 89 | `knowledge-base/09 - Auditoria/Síntese da Refatoração.md` | Síntese |
| 90 | `knowledge-base/09 - Auditoria/Áreas/_Briefing das Auditorias.md` | Contrato de área |
| 91 | `knowledge-base/09 - Auditoria/Áreas/Mapa das Áreas.md` | Mapa das 18 áreas |
| 92 | `knowledge-base/09 - Auditoria/Áreas/01 - Núcleo, inicialização, backend e atualizações.md` | Área 1 |
| 93 | `knowledge-base/09 - Auditoria/Áreas/02 - Domínio, modelos e regras.md` | Área 2 |
| 94 | `knowledge-base/09 - Auditoria/Áreas/03 - Autenticação, visitante e deep links.md` | Área 3 |
| 95 | `knowledge-base/09 - Auditoria/Áreas/04 - Catálogo, busca, feed, biblioteca e perfil.md` | Área 4 |
| 96 | `knowledge-base/09 - Auditoria/Áreas/05 - Focus Mode, timer, navegação e finalização.md` | Área 5 |
| 97 | `knowledge-base/09 - Auditoria/Áreas/06 - Tentativas, resultados e pontuação.md` | Área 6 |
| 98 | `knowledge-base/09 - Auditoria/Áreas/07 - Persistência local, backups e provas locais.md` | Área 7 |
| 99 | `knowledge-base/09 - Auditoria/Áreas/08 - Sincronização, offline, idempotência e conflitos.md` | Área 8 |
| 100 | `knowledge-base/09 - Auditoria/Áreas/09 - Importação, OCR, parser e quality gate.md` | Área 9 |
| 101 | `knowledge-base/09 - Auditoria/Áreas/10 - Publicação, pacotes, mídia e Storage.md` | Área 10 |
| 102 | `knowledge-base/09 - Auditoria/Áreas/11 - Social, discussões, comunidades e denúncia.md` | Área 11 |
| 103 | `knowledge-base/09 - Auditoria/Áreas/12 - Supabase, schema, RLS e RPCs.md` | Área 12 |
| 104 | `knowledge-base/09 - Auditoria/Áreas/13 - OCR Android, PaddleOCR e digitalização.md` | Área 13 |
| 105 | `knowledge-base/09 - Auditoria/Áreas/14 - Testes, QA e benchmark.md` | Área 14 |
| 106 | `knowledge-base/09 - Auditoria/Áreas/15 - CI-CD, releases, site, Web e PWA.md` | Área 15 |
| 107 | `knowledge-base/09 - Auditoria/Áreas/16 - Design system e componentes.md` | Área 16 |
| 108 | `knowledge-base/09 - Auditoria/Áreas/17 - Dependências e manutenção.md` | Área 17 |
| 109 | `knowledge-base/09 - Auditoria/Áreas/18 - Documentação e divergências código × docs.md` | Área 18 |
| 110 | `knowledge-base/09 - Auditoria/Classificação/Guia de Classificação.md` | Guia de classificação |

### 10 — Anexos

| # | Caminho | Tipo |
|---|---------|------|
| 111 | `knowledge-base/10 - Anexos/Capturas/README.md` | Anexo |
| 112 | `knowledge-base/10 - Anexos/Diagramas/README.md` | Anexo |
| 113 | `knowledge-base/10 - Anexos/Exportações/README.md` | Anexo |
| 114 | `knowledge-base/10 - Anexos/README.md` | Anexo |

### Corpus

| # | Caminho | Tipo |
|---|---------|------|
| 115 | `knowledge-base/Corpus/prova-social-corpus/reports/synthetic-benchmark.md` | Relatório benchmark sintético |

### Inbox / Templates

| # | Caminho | Tipo |
|---|---------|------|
| 116 | `knowledge-base/Inbox/README.md` | Inbox |
| 117 | `knowledge-base/Templates/Achado.md` | Template |
| 118 | `knowledge-base/Templates/ADR.md` | Template ADR |
| 119 | `knowledge-base/Templates/Classificação.md` | Template classificação |
| 120 | `knowledge-base/Templates/Nota de Área.md` | Template nota de área |

## Resumo do inventário

- Total de arquivos `.md` mapeados: **126** (incluindo 5 arquivos de auditoria na raiz e `SOLUTION_SUMMARY.md`)
- Fontes normativas ativas: `AGENTS.md`, `knowledge-base/`
- Documentos históricos congelados: `docs/historico/` (18 arquivos) — com banner de congelamento
- Áreas de auditoria documentadas: 18 (todas mapeadas no `Mapa das Áreas.md`)
- Documentos com divergências confirmadas: `DEPENDENCY_COMPATIBILITY.md`, `DESIGN_SYSTEM.md`, `docs/DIAGNOSTICO_ATUAL.md`, `README.md`

## Observações da Fase 1.1

- Não há arquivos `.md` fora do repositório principal e do vault `knowledge-base/`.
- O vault estava anteriormente referenciado como externo e não montado; atualmente está versionado dentro do repositório.
- `docs/historico/` contém 16 arquivos movidos da raiz (branch `docs/md-historicos`), todos com banner de congelamento.
- `DEPENDENCY_COMPATIBILITY.md` declara v0.5.0; app está em `0.7.5+15` — divergência documental.
- `DESIGN_SYSTEM.md` declara `#101311`; app usa `#050907` (EmeraldColors) — divergência de identidade visual.
- `README.md` inclui aviso sobre não armazenar provas completas, mas ainda promete câmera/galeria que não existem.
