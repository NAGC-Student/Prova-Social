---
tipo: area
area: CI-CD, releases, site, Web e PWA
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 3, seguranca: 3, robustez: 2, aderencia: 2, portabilidade: 3}
fonte_codigo: [.github/workflows/flutter-ci.yml, .github/workflows/supabase-keepalive.yml, site/, web/, tool/prepare_web.py, tool/generate_seo_pages.py, lib/core/update/, android/app/src/main/kotlin/dev/nagcode/prova_social/MainActivity.kt]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# CI-CD, releases, site, Web e PWA

## Resumo

O projeto tem **um único workflow** de CI/CD, como o `AGENTS.md` §19 exige, e
ele é substancialmente melhor que a média: separa auditorias de dependências
(npm, Dart, Gradle), roda QA completo em pull request e push, valida o keystore
antes de assinar, confere a impressão digital do App Links contra o certificado
real, impede sobrescrever release existente e publica APK por ABI mais o pacote
Web. O site institucional é curto, mobile-first, tem simulador honesto de
exercício didático, páginas SEO geradas apenas para provas públicas e um PWA
em `/app/` com manifest, ícones e service worker da marca.

As lacunas são de **fechamento de contrato**: a `main` está vermelha por
formatação desde o merge `05a8fc1`, o que bloqueia `web-ci` e `android-release`;
o release publica **apenas APKs por ABI**, sem o APK universal exigido pelo
`AGENTS.md` §17; o site entrega o APK `arm64-v8a` a qualquer visitante, sem
detectar a arquitetura; o workflow não compara a tag com `pubspec.yaml` nem com
o changelog; os testes do site (4, todos passando) não rodam no CI; e não há
CSP nem política de integridade dos artefatos.

Classificação: **EVOLUIR** — a esteira existe e funciona em partes, mas hoje
não é capaz de entregar uma release completa e não protege o que publica.

## Escopo e método

- Leitura integral de `.github/workflows/flutter-ci.yml` (736 linhas) e de
  `.github/workflows/supabase-keepalive.yml`.
- Leitura de `site/index.html`, `site/styles.css` (via testes), `site/app.js`,
  `site/_redirects`, `site/_headers`, `site/robots.txt`, `site/sitemap.xml` e
  `site/tests/site.test.cjs`.
- Leitura de `web/index.html`, `web/manifest.json` e do scaffold em `web/`.
- Leitura de `tool/prepare_web.py`, `tool/generate_web_icons.dart` e
  `tool/generate_seo_pages.py` (geração de páginas, redirects e sitemap).
- Leitura de `lib/core/update/github_release_service.dart`,
  `lib/core/update/update_gate.dart` e do canal de ABI em `MainActivity.kt`.
- Consulta ao GitHub Actions (`gh run list`, `gh run view`) e aos assets das
  releases `v0.7.5` e `v0.7.4`.
- Verificação do site publicado com `curl` em 2026-11-05: `/`, `/app/`,
  `/app/version.json`, `/app/` (robots/theme-color) e
  `/.well-known/assetlinks.json`.
- Execução local de `node --test site/tests/site.test.cjs` (4/4 aprovados).
- Não foi executado deploy, nem build Android completo nesta auditoria.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| Workflow único de CI/CD | Funcional | `.github/workflows/flutter-ci.yml` |
| Auditoria npm | Funcional | job `npm-security-audit` (`:35-56`) |
| Auditoria Dart/OSV | Funcional | job `osv-security-audit` (`:57-65`) |
| Geração e auditoria do lockfile Gradle | Funcional | jobs `android-gradle-lock` e `osv-android-gradle-audit` (`:66-129`) |
| QA completo em PR/push/tag | Funcional | job `qa-full` (`:131-200`) |
| QA completo ignorado no schedule | Decisão explícita | `:134` |
| Verificação de readiness Cloudflare | Funcional | job `cloudflare-deploy-readiness` (`:202-233`) |
| Build e deploy Web em push para `main` | Funcional | job `web-ci` (`:235-413`) |
| Geração de SEO apenas para provas públicas | Funcional | `tool/generate_seo_pages.py:241-462` |
| `assetlinks.json` conferido após deploy | Funcional | `:354-403` |
| Publicação de release em tag `v*` | Funcional | job `android-release` (`:415-736`) |
| Validação de secrets de assinatura | Funcional | `:438-472` |
| Fingerprint do App Link conferido com o certificado | Funcional | `:600-652` |
| Release existente não é sobrescrita | Funcional | `:733-736` |
| APKs por ABI publicados | Funcional | assets de `v0.7.5` |
| Pacote Web zipado na release | Funcional | `:709-710, :730` |
| App consulta release com timeout | Funcional | `github_release_service.dart:38-43` |
| App escolhe APK pela ABI do aparelho | Funcional | `github_release_service.dart:69-96`; `MainActivity.kt:13-17` |
| Atualização não bloqueia abertura | Funcional | `update_gate.dart:22-44` |
| PWA com manifest e ícones da marca | Funcional | `web/manifest.json`; `tool/prepare_web.py` |
| Flutter Web com `noindex,follow` | Funcional | `web/index.html`; `build/web/index.html` |
| Site indexável e canônico | Funcional | `site/index.html:6-9`; `site/robots.txt` |
| Simulador do site com estado acessível | Funcional | `site/app.js:1-40`; `aria-pressed` |
| Testes do site passam | Funcional | 4/4 via `node --test` |
| Testes do site no CI | Ausente | nenhuma referência em workflow/qa |
| APK universal assinado | Ausente | releases só têm 3 ABIs |
| Verificação tag × `pubspec.yaml` | Ausente | nenhum passo compara versão |
| Checksums dos artefatos | Ausente | `gh release create` sem `.sha256` |
| CSP e security headers no site | Ausente | `site/_headers` só tem cache |
| `main` verde | Quebrado | run `41760190392`, `QA estático` |

## O que funciona

1. **Workflow único e organizado.** O `AGENTS.md` §19 pede GitHub Actions como
   única CI/CD. Há um workflow principal e apenas o keepalive do Supabase em
   separado, com responsabilidade clara.
2. **Auditorias de dependências em paralelo.** npm, Dart/OSV e Gradle/OSV rodam
   antes do QA e da release. O lockfile Gradle é gerado no CI, publicado como
   artefato e reutilizado no build, o que evita resolução divergente entre
   auditoria e compilação.
3. **QA com timeout e artefatos.** `qa-full` tem `timeout-minutes: 20`, roda
   estático, testes Flutter, PGlite, build Web e Playwright, e publica logs,
   traces e relatórios mesmo em falha (`:194-200`).
4. **Preparação determinística do Flutter Web.** `flutter create . --platforms=web`
   preserva `pubspec.lock`, remove o `widget_test.dart` padrão e aplica
   `tool/prepare_web.py`, que fixa marca, manifest, ícones e `noindex`
   (`:252-259`).
5. **SEO honesto.** `generate_seo_pages.py` só cria páginas para provas
   públicas, injeta canonical, Open Graph, JSON-LD e rotas em `_redirects`, e
   gera sitemap fatiado. Quando não há prova pública, o sitemap contém apenas a
   home — comportamento coberto por teste (`tool/test_generate_seo_pages.py:161`).
6. **App Links verificado de ponta a ponta.** O build confere se o SHA-256 do
   certificado de release corresponde ao segredo e, depois do deploy, baixa
   `/.well-known/assetlinks.json` e valida conteúdo, pacote e fingerprint
   (`:600-652, :354-403`). É uma proteção above-average contra link quebrado.
7. **Assinatura com validação prévia.** O job recusa prosseguir sem keystore,
   alias e senhas; não há keystore no Git.
8. **Release imutável.** Antes de criar, o job verifica se a release já existe e
   falha em vez de sobrescrever (`:733-736`). Isso atende ao §19.
9. **APKs por ABI e fallback no app.** As releases `v0.7.4` e `v0.7.5` contêm
   `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`,
   `app-x86_64-release.apk` e o zip Web. O app lê `Build.SUPPORTED_ABIS` e
   escolhe o asset exato, com fallback para universal em releases antigas
   (`github_release_service.dart:69-96`).
10. **Atualização resiliente.** Timeout de 8 s, `releases/latest` (que exclui
    draft/prerelease), comparação semântica e falha silenciosa que nunca impede
    a abertura (`update_gate.dart:22-44`).
11. **PWA correta na marca.** `web/manifest.json` tem nome, descrição,
    orientação, `theme_color` e ícones normais e maskable; o build contém
    `flutter_service_worker.js` e `flutter_bootstrap.js`.
12. **Site com testes reais.** `site/tests/site.test.cjs` cobre simulador,
    fallback de download, redirect de `/provas/*` e contraste AA dos tokens
    escuros, além de garantir que não há dado falso de prova (FUVEST, 90% etc.).
13. **Site publicado e coerente.** Em 2026-11-05, `/` e `/app/` respondem 200;
    `/app/version.json` informa `0.7.5+15`, build 96, de 2026-11-01;
    `/app/` tem `noindex,follow` e `theme-color` `#050907`; `assetlinks.json`
    responde 200.
14. **Keepalive do Supabase separado.** Usa apenas URL e chave publicável, sem
    service role, e não interfere no build.

## O que está parcial

### A `main` vermelha bloqueia Web e release

O run `41760190392` (push em `main`, merge `05a8fc1`) falhou no job
`QA Completo`, passo `QA estático`. A causa local é reproduzível:
`dart format --output=none --set-exit-if-changed lib test tool packages`
retorna **exit 1** por causa de três arquivos `test/_corpus_*_probe_test.dart`.

Consequências em cadeia:

- `web-ci` tem `needs: [qa-full, ...]` e não roda;
- `android-release` tem `needs: [qa-full, ...]` e não roda em tag;
- o site publicado continua na versão de **2026-11-01** (build 96), anterior
  ao merge atual;
- o schedule noturno “passa” porque `qa-full` é ignorado em `schedule`
  (`:134`), o que pode dar falsa sensação de saúde.

O nightly roda apenas auditorias de dependências e keepalive. Não há job
noturno de testes, benchmark ou build. Uma regressão de código só é vista em
PR/push.

### Release sem APK universal

O `AGENTS.md` §17 exige:

> APK universal assinado; APKs por arquitetura quando úteis; Flutter Web;
> GitHub Release versionada.

O job compila apenas:

```sh
flutter build apk --release --split-per-abi
```

(`:688-691`) e publica exatamente três APKs por ABI mais o zip Web
(`:726-731`). As releases `v0.7.4` e `v0.7.5` confirmam: não existe
`app-release.apk` nem `prova-social-android.apk`.

O `README.md:159` reconhece a mudança (“APKs menores… o atualizador escolhe o
compatível”), mas isso não altera o requisito do `AGENTS.md`. O fallback do app
para universal só funciona em releases antigas; um aparelho com ABI não
suportada (por exemplo, um Android x86 antigo ou ABI exótica) não recebe
atualização.

### Site escolhe APK sem detectar a arquitetura

`site/app.js:44-57` busca `releases/latest` e escolhe:

1. o primeiro asset que case `/arm64-v8a.*\.apk$/i`;
2. senão, `/prova-social.*\.apk$/i`;
3. senão, qualquer `.apk`.

Como as releases atuais só têm `app-arm64-v8a-release.apk`,
`app-armeabi-v7a-release.apk` e `app-x86_64-release.apk`, o passo 1 sempre
vence. Um visitante em aparelho **32-bit** baixa o APK arm64 e a instalação
falha. O app nativo faz certo; o site não.

Não há:

- `navigator.userAgentData`/`navigator.platform` para estimar ABI;
- página de escolha manual (“meu aparelho é 32-bit”);
- link para a release completa;
- aviso de que o APK é por arquitetura;
- verificação de tamanho/hash do download.

O fallback do `catch` para a página de releases é correto, mas não resolve o
caso de sucesso com ABI errada.

### Workflow não valida tag, versão e changelog

Em tag `v*`, o job:

- não compara `GITHUB_REF_NAME` com `version:` de `pubspec.yaml`;
- não verifica se existe `CHANGELOG_<versão>.md`;
- não usa o changelog como corpo da release;
- usa `--generate-notes`, que produz notas a partir de commits.

Hoje `v0.7.5` coincide com `0.7.5+15`, mas nada impede uma tag `v0.8.0` em um
`pubspec.yaml` `0.7.5+15`. O `AGENTS.md` §19 pede atualização coerente de
`pubspec.yaml`, changelog e tag. Falta um gate.

### Testes do site fora do CI

`site/tests/site.test.cjs` tem 4 testes e passa localmente, mas nenhum job o
executa:

- não há `package.json` na raiz com script de teste;
- `qa/run_all.sh` não chama `node --test site/tests`;
- o workflow não tem passo de teste do site;
- o job `web-ci` só roda em push para `main`, então um PR pode quebrar o site
  sem falhar nada.

O teste de contraste é particularmente valioso e está desconectado do gate.

### Sem CSP nem política de headers de segurança

`site/_headers` só define `Cache-Control` para quatro caminhos. O site
publicado responde com `x-content-type-options` e `referrer-policy` gerados
pelo Cloudflare, mas **não** há:

- `Content-Security-Policy`;
- `Strict-Transport-Security` explícito;
- `Permissions-Policy`;
- `X-Frame-Options`/`frame-ancestors`;
- política para o Google Fonts (o site carrega Inter de `fonts.googleapis.com`,
  dependência externa e rastreável).

O Flutter Web em `/app/` também não tem CSP. Para um app que lida com conteúdo
gerado por usuário e links públicos, CSP é defesa em profundidade, não enfeite.

### Sem integridade dos artefatos

A release publica APKs e zip Web sem:

- `.sha256` por arquivo;
- assinatura/attestation;
- SBOM anexado;
- tamanho declarado;
- verificação de que os APKs foram assinados com o certificado esperado
  (o fingerprint é conferido contra o keystore, mas não contra o APK final).

O `AGENTS.md` §14 fala em hash de integridade para pacotes de conteúdo, não
necessariamente para APK, mas a release é o ponto de distribuição e merece o
mesmo cuidado. Hoje o usuário baixa e instala sem conferir nada.

### Builds duplicados

O Flutter Web é compilado **três vezes** no mesmo push/tag:

1. `qa-full` → `qa/run_web.sh` para o Playwright;
2. `web-ci` → `flutter build web` para o site;
3. `android-release` → `flutter build web` para o zip da release.

O APK é compilado uma vez, mas o custo de Web e a chance de divergência entre
artefatos existem. O `AGENTS.md` §19 pede evitar dois builds Android completos;
a mesma lógica vale para Web.

### PWA e tokens divergentes

O shell do app e o manifest usam `#050907` (`web/index.html`,
`web/manifest.json`, `tool/prepare_web.py`). O site institucional usa
`#101311` (`site/styles.css:1`), que é o token escuro do `AGENTS.md` §3. O app
usa a paleta `EmeraldColors` (`#050907`, `#101A15`, `#20D99A`), diferente dos
tokens escuros oficiais (`#101311`, `#181C19`, `#F3F5F3`, `#2A302C`).

Não é um bug de CI, mas é uma divergência de identidade que a área 16 precisa
resolver com uma decisão explícita: ou o `AGENTS.md` muda, ou o app converge.

### Site depende de fonte externa

O site carrega Inter via Google Fonts (`site/index.html:35-37`). Isso:

- adiciona dependência de terceiro e requisição a `fonts.gstatic.com`;
- pode atrasar first paint em conexão ruim;
- expõe IP do visitante ao Google;
- não tem fallback declarado além de `system-ui` no CSS.

O app usa `fontFamily: 'sans-serif'`, sem Inter empacotado. A identidade
tipográfica não é consistente entre site e app.

## O que está ausente ou quebrado

- `main` verde e gate de formatação cumprido.
- APK universal assinado na release.
- Verificação tag × `pubspec.yaml` × changelog.
- Checksums/SBOM dos artefatos.
- Testes do site no CI.
- CSP e headers de segurança.
- Detecção de ABI no site.
- Job noturno de testes/benchmark.
- Build Web único e reutilizado entre jobs.
- Validação de que o APK publicado é o assinado com o certificado esperado.
- Teste de instalação do APK em aparelho 32-bit e 64-bit.
- Teste do fluxo de atualização com release real.
- Página de download com escolha de arquitetura.
- Política de retenção de artefatos.
- Documentação de rollback de release.
- Deploy de preview por PR (o site só publica em `main`).
- Smoke test do site publicado após deploy (hoje só `assetlinks.json` é
  conferido).

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “APK universal assinado” | Só 3 APKs por ABI | `flutter-ci.yml:688-731`; assets de `v0.7.5` |
| “Atualizador escolhe o APK correto” | App escolhe; site não | `github_release_service.dart:69-96` vs `site/app.js:44-57` |
| “Cada build válida produz release” | `qa-full` vermelho bloqueia release | run `41760190392` |
| “Tag, pubspec e changelog coerentes” | Nenhum gate compara | `flutter-ci.yml:721-736` |
| “Site atualizado aponta para artefatos atuais” | Site está em build 96 de 2026-11-01 | `curl /app/version.json` |
| “Testes do site” | Existem, mas não rodam no CI | `site/tests/site.test.cjs` |
| “Headers de segurança” | Só cache; CSP ausente | `site/_headers`; resposta HTTP |
| “Flutter Web é o PWA instalável” | Manifest e SW existem; instalação não testada | `web/manifest.json`; `build/web/flutter_service_worker.js` |
| “Cores escuras oficiais” | App usa `EmeraldColors`; site usa `#101311` | `app_theme.dart:19-35`; `site/styles.css:1` |

## Evidência de testes

- `node --test site/tests/site.test.cjs`: **4/4 aprovados** em 2026-11-05.
  Cobre simulador, fallback de release, redirect de prova pública e contraste
  AA dos tokens escuros.
- `tool/test_generate_seo_pages.py`: cobre sitemap, canonical, rotas e sharding
  (executado por `qa/run_static.sh:20`, portanto no CI).
- `test/github_release_service_test.dart`: 2 testes de comparação de versão e
  seleção de asset; não cobre o site nem o download real.
- Playwright: 2 testes de shell/canvas; não cobre site institucional, PWA,
  download, login ou Focus.
- `qa/run_p0.sh`: PGlite, não relacionado a release.
- Não há teste de:
  - `gh release create`;
  - assets publicados;
  - assinatura do APK;
  - instalação em aparelho;
  - tag × versão;
  - CSP/headers;
  - deploy Cloudflare;
  - atualização do app.

## Riscos

1. **Nenhuma release sai.** QA vermelho bloqueia `android-release`; uma tag
   `v*` falha e deixa a versão sem distribuição.
2. **Site desatualizado.** `web-ci` bloqueado mantém o PWA em build antiga,
   mesmo com correções em `main`.
3. **APK incompatível.** Site entrega arm64 para aparelho 32-bit.
4. **Regressão silenciosa no site.** Testes existem, mas não protegem PR.
5. **Supply chain do APK.** Sem checksum/SBOM, o usuário não verifica o que
   instala.
6. **XSS/clickjacking no site.** Sem CSP/frame-ancestors, qualquer injeção
   futura tem menos barreiras.
7. **Versão inconsistente.** Tag pode divergir de `pubspec.yaml` e do
   changelog sem falhar.
8. **Custo e divergência de builds.** Web compilado três vezes.
9. **Falsa saúde noturna.** Schedule “verde” sem testes.
10. **Identidade dividida.** App e site usam paletas e fontes diferentes.

## Plano de refatoração da área

### Lote 1 — Destravar a esteira

- Corrigir `dart format` nos três probes e removê-los da suíte padrão
  (ver área 14).
- Adicionar ao `qa/run_static.sh` um teste do site
  (`node --test site/tests/site.test.cjs`).
- Rodar `qa-full` também no schedule, ou criar job noturno de testes.
- Critério de aceite: `main` verde; site testado em PR; schedule executa
  testes de verdade.

### Lote 2 — Release completa e verificável

- Compilar `flutter build apk --release` (universal) além de
  `--split-per-abi`, ou gerar o universal a partir dos splits.
- Publicar `app-release.apk` com nome estável.
- Gerar `.sha256` de cada asset e anexar à release.
- Validar `GITHUB_REF_NAME == version` de `pubspec.yaml` e existência de
  `CHANGELOG_<versão>.md`.
- Usar o changelog como corpo da release.
- Critério de aceite: release contém universal + 3 ABIs + Web + checksums;
  tag divergente falha antes do build; `gh release view` comprova os assets.

### Lote 3 — Download correto no site

- Detectar ABI de forma conservadora ou oferecer escolha manual.
- Nunca entregar arm64 como padrão para todos.
- Adicionar link “ver todas as versões” e texto sobre arquitetura.
- Se o APK universal existir, usá-lo como padrão no site.
- Critério de aceite: teste do `app.js` cobre arm64, armv7, x86_64 e
  desconhecido; aparelho 32-bit recebe APK compatível ou página de escolha.

### Lote 4 — Headers, CSP e integridade

- Definir CSP compatível com Flutter Web (scripts/wasm, fonts, Supabase,
  GitHub API) e `frame-ancestors 'none'`.
- Adicionar HSTS, Permissions-Policy e política de referrer.
- Auto-hospedar Inter ou remover a dependência externa.
- Publicar SBOM e checksums.
- Critério de aceite: `curl -I` mostra CSP; site funciona com CSP; Lighthouse
  de segurança sem achados altos; SBOM anexado.

### Lote 5 — Build único e cache

- Reutilizar o build Web de `qa-full` em `web-ci` e `android-release` por
  artefato, com hash.
- Reutilizar o lockfile já feito (isso já acontece no Android).
- Critério de aceite: um único `flutter build web` por commit/tag; artefato
  idêntico entre QA, site e zip.

### Lote 6 — Observabilidade e rollback

- Smoke test pós-deploy do site: home, `/app/`, manifest, version.json,
  `assetlinks.json`, sitemap.
- Alertar se `version.json` ficar atrás de `pubspec.yaml` por mais de um push.
- Documentar rollback de Pages e de release.
- Critério de aceite: deploy falha se smoke test falhar; runbook de rollback
  escrito e testado.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Esteira completa no papel; release sem universal e site com ABI errada. |
| Testes | 2 | Site tem 4 testes bons, mas fora do CI; release e atualização não testadas. |
| Acoplamento | 3 | Jobs separados por responsabilidade; build Web duplicado e lógica de ABI em dois lugares. |
| Clareza | 3 | Workflow legível, mas longo e com validações espalhadas. |
| Segurança | 3 | Keystore e App Links bem tratados; sem CSP, checksum ou SBOM. |
| Robustez | 2 | `main` vermelha, release bloqueada, schedule sem testes. |
| Aderência | 2 | §17 pede universal; §19 pede tag/changelog coerentes; ambos ausentes. |
| Portabilidade | 3 | Android e Web cobertos; site não distingue ABI; iOS fora do escopo. |

Classificação resultante: **EVOLUIR** — a base é boa e próxima do exigido, mas
hoje não entrega release completa nem protege o site e o download.

## Dependências

- Área 14 para desbloquear o QA e testar o site.
- Área 16 para decidir tokens, tipografia e identidade entre app e site.
- Área 17 para SBOM, CVEs e integridade de dependências.
- Área 18 para atualizar README, changelog e decisões.
- Decisão de produto sobre APK universal versus apenas splits.
- Decisão de produto sobre fonte externa no site.

## O que não foi verificado

- Execução do workflow após correção do `dart format`.
- Build Android completo e assinatura nesta máquina.
- Instalação dos APKs em aparelho 32-bit e 64-bit.
- Deploy Cloudflare nesta auditoria.
- Funcionamento do service worker e instalação do PWA.
- CSP (não existe).
- Atualização do app com release real.
- Tamanho dos APKs e do zip Web.
- Retenção e expiração de artefatos do Actions.
- Rollback de release.
- Compatibilidade do site com navegadores antigos.
- Licença e disponibilidade futura do Google Fonts.

## Links

- [[13 - OCR Android, PaddleOCR e digitalização|Área 13 — OCR Android]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes e QA]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[17 - Dependências e manutenção|Área 17 — Dependências]]
- [[18 - Documentação e divergências código × docs|Área 18 — Documentação]]
- [[../../00 - Central/Roadmap|Roadmap]]
- [[Mapa das Áreas|Mapa das Áreas]]
