---
tipo: area
area: documentação e divergências
status: PARCIAL
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [AGENTS.md, PROVA_SOCIAL_CONTEXT.md, DEPENDENCY_COMPATIBILITY.md, pubspec.yaml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Documentação e Divergências Conhecidas

## Precedência atual

1. `AGENTS.md`: requisitos normativos atuais de produto e processo.
2. Código, migrations e testes no SHA citado: implementação observável.
3. Plano Mestre fornecido: plano de trabalho cuja execução exige confirmar fatos.
4. Relatórios de auditoria existentes: evidência datada, não estado remoto atual.
5. Documentação legada: hipótese até ser confrontada com o código.

## Divergências confirmadas na inspeção inicial

- `PROVA_SOCIAL_CONTEXT.md` diz ter sido atualizado em 27/09/2026 e contém
  estados de produto daquele momento.
- `DEPENDENCY_COMPATIBILITY.md` se intitula v0.5.0 e data versões em
  17/09/2026; o app está em `0.7.5+15`, e versões resolvidas variam. Não
  substituir a matriz sem revalidar restrições e lockfile.
- Relatórios `AUDIT.md` e `SECOND_PHASE_REPORT.md` foram escritos em execução
  anterior. As afirmações sobre o benchmark e código têm escopo e limites
  descritos neles; o CI remoto mudou depois, conforme [[../00 - Central/Estado Atual]].
- `docs/URLS_COMPARTILHADAS_E_IMPORTACAO.md` registra os cortes de 80%/99% e
  revisão obrigatória antes de publicar como comportamento de produto. A
  inspeção de `question_parser.dart` e `import_quality_gate.dart` confirma esses
  números como heurísticas que afetam estados de revisão, não scores calibrados
  contra ground truth. Para o desenho atual, eles não serão apresentados como
  porcentagens de acurácia nem usados sozinhos para excluir questões. A nota
  histórica permanece preservada; a análise técnica atual está em
  [[../01 - Produto/Importação e OCR]].
- **Scanner (área 9):** a UI ainda mostra “confiança ≥ 99%” e “confiança X%”
  (`publish_page.dart:732, 1733, 2057`), contrariando a decisão de não exibir
  porcentagem. `fieldConfidence` existe no modelo, mas o parser nunca o
  preenche. A publicação exige alternativas e gabarito em todas as questões
  (`publish_page.dart:1333-1343`), bloqueando discursivas e rascunho objetivo
  sem chave. Câmera/galeria e fila de feedback não existem. Evidência e
  critérios de aceite em
  [[Áreas/09 - Importação, OCR, parser e quality gate|auditoria da área 9]].
- `docs/DIAGNOSTICO_ATUAL.md` afirma que o PDF VUNESP não atinge 80 questões. O
  teste atual `vunesp_2024_import_test.dart` exige 80 e passa; a afirmação
  histórica está desatualizada e não deve ser usada como estado atual.
- O `AGENTS.md` anterior apontava para um vault externo não montado neste
  ambiente. Por instrução atual, a base ativa foi criada em `knowledge-base/`;
  não houve importação do repositório de docs externo.

## Consolidação da área 18 (2026-11-04)

- As **18 áreas** foram auditadas; a documentação foi confrontada com o código
  em cada uma. O acervo está em
  [[../09 - Auditoria/Áreas/Mapa das Áreas|Mapa das Áreas]] e a síntese em
  [[Síntese da Refatoração|Síntese da Refatoração]].
- **Divergências confirmadas:** o `AGENTS.md` tem duas seções 15; o vault é
  chamado de versionado, mas `git ls-files knowledge-base` = 0 e não há
  `.gitignore` no vault; o `README.md` promete importação de imagens e “modo de
  demonstração” inexistentes e diz “código aberto” sem `LICENSE`; o
  `DESIGN_SYSTEM.md` declara `#101311` e o app usa `#050907`;
  `DEPENDENCY_COMPATIBILITY.md` é da versão 0.5.0; relatórios da raiz competem
  com o vault sem banner de histórico.
- **Atualização 2026-11-05:** três dessas divergências deixaram de existir — o
  vault está versionado (`eebb2b0`, com `.gitignore` para estado de dispositivo),
  e os 16 `.md` soltos da raiz foram para `docs/historico/` (branch
  `docs/md-historicos`), ficando na raiz só `README.md` e `AGENTS.md`. As demais
  (duas seções 15, README prometendo o que não existe, cores `#101311` ×
  `#050907`, matriz 0.5.0) **continuam em aberto**: são conteúdo, não localização.
- **Links:** 9 alvos quebrados foram encontrados; 7 corrigidos (4 para a área 18,
  que passou a existir, 2 nomes antigos da área 15 e 1 link de produto); 2
  placeholders da fonte original foram preservados.
- **Plano detalhado:** [[Áreas/18 - Documentação e divergências código × docs|Área
  18 — Documentação]].

## Pendências

- Auditar os Markdown restantes da raiz e de `docs/` que ainda não foram
  confrontados com o código, especialmente os guias operacionais.
- Atualizar a matriz de dependências com versões/constraints medidos e linkar
  evidências de `pubspec.lock`.
- Não eliminar fontes históricas; adicionar banner, data e link para a nota
  vigente antes de substituir afirmações.
- Criar `.gitignore` no vault e versioná-lo com autorização.
- Adicionar verificação automática de links, frontmatter e segredos no CI.
- Corrigir a numeração do `AGENTS.md` e registrar a hierarquia documental.
- Decidir licença do app e política de fixtures de terceiros.
- Registrar ADRs de paleta, distribuição, persistência, câmera e dependências.

**Resolução em 2026-11-07, atualizada em 2026-11-08** (lista original preservada acima):

| Recomendação | Estado |
|---|---|
| Banner em fonte histórica | Feito — 16 arquivos em `docs/historico/` com banner datado |
| `.gitignore` no vault e versionamento | Feito por outro caminho — vault versionado desde `eebb2b0`; estado de dispositivo coberto pelo `.gitignore:67-70` da raiz |
| Verificação automática no CI | **Parcial** — `tool/test_docs_links.py` cobre links relativos, wikilinks, numeração do `AGENTS.md` e banner, e roda no `qa/run_static.sh`; frontmatter e segredos **não** são verificados |
| Numeração do `AGENTS.md` e hierarquia | Feito — segunda seção 15 virou 25; precedência escrita no `AGENTS.md` e no `knowledge-base/README.md` (ADR-0008) |
| Licença do app | Feito — distribuição restrita, todos os direitos reservados, `LICENSE` na raiz (ADR-0007, alternativa C) |
| Política de fixtures de terceiros | Feito — `licenseStatus`, `allowedForTesting` e `allowedForProductContent` obrigatórios em toda entrada do corpus, `test/fixture_license_policy_test.dart` no lugar, `.backup` removido e ONNX corrigido para `1.31.1` no notice (ADR-0007, Tarefa 1.4) |
| Matriz de dependências vigente | Feito em 2026-11-08 — `Matriz de dependências` gerada do `pubspec.lock` com SHA-256 e data, `--check` e teste do gerador no `qa/run_static.sh`, regra de pin e cadência em `Dependências e pins`, `flutter pub outdated` informativo no CI (ADR-0009, alternativa A) |
| ADRs de paleta, distribuição, persistência, câmera, dependências | Feito — 12 ADRs aceitos em 2026-11-07 |
