---
tipo: adr
area: distribuição android
status: INTENÇÃO
classificacao: NÃO VERIFICÁVEL
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [android/app/build.gradle.kts, .github/workflows/flutter-ci.yml, site/app.js, site/index.html, lib/core/update/github_release_service.dart, android/app/src/main/kotlin/, README.md]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: media
atualizado: 2026-11-07
---

# ADR-0005 — Distribuição Android: APK universal + splits e seleção de ABI no site

- **Status:** aceito
- **Data:** 2026-11-07
- **Responsável pela aprovação:** NAGCODE-Dev (responsável pelo projeto)
- **Áreas:** 15, 17
- **Urgência:** Alta

## Contexto

O app escolhe ABI corretamente; o site não. E não existe APK universal
publicado.

- **CI publica só splits.** `.github/workflows/flutter-ci.yml:688` roda
  `flutter build apk --release --split-per-abi`; os assets de release em
  `:726-731` são `app-armeabi-v7a-release.apk`,
  `app-arm64-v8a-release.apk`, `app-x86_64-release.apk` e
  `prova-social-web-<tag>.zip`. **Nenhum universal.**
- **Tamanhos medidos na release `v0.7.5`** (`gh release view v0.7.5 --json
  assets`): arm64 **82.134.581 B**, armv7 **61.361.205 B**, x86_64
  **122.968.231 B**, web zip 17.255.882 B. Build local de 1º/11 (não
  rastreado, `git ls-files build/` vazio) tem universal
  `app-release.apk` com **248.086.768 B** — cerca de 3× o arm64.
- **`android/app/build.gradle.kts` não configura splits.** Arquivo de 52
  linhas, sem bloco `splits`/`abiFilters`; a divisão vem só da flag do CI.
  `minSdk = 26` (`:22`), `compileSdk`/`targetSdk`/`ndkVersion` delegados ao
  Flutter (`:9-10,23`). O CI reafirma minSdk 26 em
  `.github/workflows/flutter-ci.yml:551-552`.
- **Release assinada com chave de debug.** `build.gradle.kts:36-38`:
  comentário “TODO: Add your own signing config for the release build” e
  `signingConfig = signingConfigs.getByName("debug")`. Há ainda
  `proguardFiles` duplicado em `:34-35`. Isso afeta instalação e atualização
  tanto quanto a escolha de ABI.
- **O atualizador interno escolhe por ABI.**
  `lib/core/update/github_release_service.dart:85-102` recebe `abi`, aceita
  apenas `{'arm64-v8a','armeabi-v7a','x86_64'}` e procura
  `app-$abi-release.apk`; o fallback (`:95-99`) procura
  `prova-social-android.apk` ou `app-release.apk` — **nomes que a release
  atual não publica**. A ABI vem do canal nativo
  `MainActivity.kt:15-16` (`Build.SUPPORTED_ABIS.firstOrNull()`).
- **O site não detecta ABI.** `site/app.js:47` escolhe o primeiro asset que
  casa `/arm64-v8a.*\.apk$/i`, senão `/prova-social.*\.apk$/i`, senão qualquer
  `.apk`, e aplica a **todos** os botões (`site/index.html:37,80`). Não há
  `userAgentData` nem `platform` no arquivo (57 linhas). Um aparelho apenas
  armv7 recebe o link do arm64.
- **O README promete o fallback.** `README.md:159` diz que releases novas
  distribuem só os APKs por arquitetura e que “o APK universal continua como
  fallback para releases antigas”. Para releases novas não há fallback
  algum: nem universal publicado, nem nome que o atualizador reconheça.

**Limites.** Os tamanhos de release foram lidos da API do GitHub para
`v0.7.5`; o universal de 248 MB é de um build local de 1º/11 e pode não
corresponder byte a byte ao código de `0.7.5+15`. Não foi feito teste de
instalação em aparelho armv7 ou x86_64. Não há tamanho de APK registrado em
documento rastreado — só nos artefatos e na nota da área 17.

## Decisão

**Aprovada em 2026-11-07 pelo responsável pelo projeto (NAGCODE-Dev).**
Alternativa escolhida: **A — splits only + seleção por ABI no site e fallback
coerente**, sem publicar universal por padrão. A decisão é manter splits como
artefato principal e corrigir a seleção na ponta:

1. Site: escolher o asset pela ABI detectada (`navigator.userAgentData`
   quando disponível, senão heurística de `userAgent`), e na impossibilidade
   de detectar oferecer os três links nomeados em vez de impor arm64.
2. Atualizador: alinhar o fallback com o que a release publica, ou publicar
   um asset universal com o nome que o fallback já procura. As duas pontas
   precisam concordar — hoje não concordam.
3. Resolver a assinatura de release (chave própria) antes de qualquer
   mudança de distribuição: trocar signing config depois de usuários
   instalados quebra a atualização.

Universal + splits (publicar os quatro) fica como alternativa explícita, com
custo de ~248 MB por release e tempo de build maior.

## Alternativas

- **A — Splits only + seleção por ABI no site e fallback coerente
  (escolhida).** Prós: menor download (61–123 MB em vez de 248 MB),
  aproveita o canal nativo que já existe, nenhum artefato novo. Contras:
  exige detecção de ABI no browser (imperfeita em iOS/desktop e em navegadores
  sem `userAgentData`); aparelho fora das três ABIs fica sem opção.
- **B — Universal + splits.** Publicar os quatro assets. Prós: um link que
  funciona em qualquer aparelho; o fallback do atualizador volta a fazer
  sentido; site pode oferecer um botão só. Contras: +248 MB por release,
  build mais longo, e o site continua escolhendo arm64 se não for corrigido
  (publicar universal não resolve a seleção).
- **C — Universal only.** Prós: pipeline e site mais simples, um artefato.
  Contras: todo usuário baixa ~248 MB, incluindo bibliotecas nativas de outras
  ABIs (ver ADR-0011: ONNX 17,9 MB, OpenCV 17,1 MB, ML Kit 11,1 MB por ABI);
  regride o que o `README.md:159` já promete.
- **D — Não fazer.** Prós: custo zero. Contras: usuário armv7 baixa APK que
  não instala; aparelho sem ABI reconhecida não atualiza; release assinada
  com chave de debug continua sendo publicada.
- **E — App Bundle (AAB) em loja.** Prós: distribuição por ABI resolvida
  pela loja, assinatura gerenciada. Contras: exige conta de loja, revisão e
  política de privacidade; o projeto distribui por GitHub e site
  (`README.md:157-160`), então é mudança de canal, não de empacotamento.

## Consequências e reversão

- **Positivas:** o link do site passa a instalar no aparelho de quem clicou;
  o atualizador para de procurar asset inexistente; a decisão de assinatura
  fica registrada antes de haver base instalada maior.
- **Negativas/custos:** detecção de ABI no browser é heurística e vai errar
  em alguns casos — o plano precisa incluir a saída manual (três links);
  publicar universal dobra o storage de releases; trocar signing config
  exige que a transição seja planejada (assinatura diferente = instalação
  nova, não atualização).
- **Riscos:** mudar nomes de assets quebra o atualizador de versões antigas
  já instaladas. Mitigação: manter os nomes atuais e adicionar, não renomear.
- **Reversão:** A é reversível por `git revert` no site e no Dart; B e C
  envolvem artefatos publicados — reverter o workflow não remove assets já
  anexados a releases existentes, e isso precisa ser dito antes de publicar.

## Evidências e validação

- Áreas: [[../../09 - Auditoria/Áreas/15 - CI-CD, releases, site, Web e PWA|Área 15]],
  [[../../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]].
- Código e config: [build.gradle.kts](../../../android/app/build.gradle.kts),
  [flutter-ci.yml](../../../.github/workflows/flutter-ci.yml),
  [site/app.js](../../../site/app.js), [site/index.html](../../../site/index.html),
  [github_release_service.dart](../../../lib/core/update/github_release_service.dart),
  [README.md](../../../README.md).
- Testes: [github_release_service_test.dart](../../../test/github_release_service_test.dart)
  (cobre `selectApkAsset`), [site/tests/site.test.cjs](../../../site/tests/site.test.cjs).
- **Exigido antes de implementar:** teste de `selectApkAsset` para ABI
  desconhecida e para release sem universal (afirmar o comportamento atual
  antes de mudá-lo); teste do site com release simulada contendo só armv7;
  instalação real em pelo menos um aparelho armv7; decisão sobre signing
  config registrada separadamente.
- Comandos de reprodução:
  `gh release view v0.7.5 --json assets`;
  `grep -n "split-per-abi" .github/workflows/flutter-ci.yml` → 688;
  `grep -n "signingConfig" android/app/build.gradle.kts` → 38;
  `sed -n '47p' site/app.js`.
- Relacionados: [[ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]],
  [[ADR-0009 - Política de dependências e pins|ADR-0009]],
  [[ADR-0007 - Licença do app e fixtures de terceiros|ADR-0007]].