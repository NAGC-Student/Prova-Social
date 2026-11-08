---
tipo: area
area: dependências e manutenção
status: PARCIAL
classificacao: EVOLUIR
nivel: {correcao: 3, testes: 2, acoplamento: 3, clareza: 3, seguranca: 2, robustez: 2, aderencia: 2, portabilidade: 3}
fonte_codigo: [pubspec.yaml, pubspec.lock, android/, packages/paddleocr_android/, qa/browser/package.json, .github/dependabot.yml, .github/workflows/flutter-ci.yml]
sha: 05a8fc1aab92d43f58ad7da8b24e710f9874d281
confianca: alta
atualizado: 2026-11-04
---

# Dependências e manutenção

## Resumo

O projeto tem **higiene de dependências acima da média para um app Flutter**:
`pubspec.lock` versionado, Dependabot para quatro ecossistemas, auditoria npm e
OSV em todo push/PR/schedule, lockfile Gradle gerado e auditado no CI, e
`flutter pub outdated` sem vulnerabilidades conhecidas no npm local. As versões
de Flutter, Dart, AGP, Kotlin e Gradle são modernas e coerentes entre si.

Os problemas são de **política e rastreabilidade**: quatro dependências diretas
e uma de desenvolvimento estão atrasadas, algumas com salto de versão relevante
(`pdfrx 2.6.6 → 2.11.0`); há pins exatos sem justificativa documentada
(`crypto`, `file_picker`, `google_mlkit_text_recognition`, `http`, `image`);
o APK arm64 tem **82 MB**, com 17,9 MB de ONNX Runtime, 17,1 MB de OpenCV,
11 MB de ML Kit e 6,2 MB de modelos; o `THIRD_PARTY_NOTICES.md` do Paddle
declara ONNX Runtime `1.21.1` enquanto o build usa `1.31.1`; não há `LICENSE`,
SBOM ou auditoria de licenças; e o `android/app/build.gradle.kts` versionado
assina release com a chave **debug**, sendo corrigido apenas por patch no CI.

Classificação: **EVOLUIR** — as dependências funcionam e são auditadas, mas
falta uma política de atualização, tamanho e licenças que o projeto possa
sustentar.

> **Correção datada (2026-11-08) — Onda 1 dos ADRs.** O texto abaixo foi
> preservado como estava. Quatro afirmações do resumo e dos achados deixaram de
> valer:
>
> - **"Pins exatos sem justificativa"** — a justificativa está escrita no
>   [[../../06 - Decisões/ADR/ADR-0009 - Política de dependências e pins|ADR-0009]]
>   (aceito em 2026-11-07) e em
>   [[../../03 - Domínios/Dependências e pins|Dependências e pins]]: pino exato
>   para o que toca nativo ou contrato externo, caret para o resto. Isso
>   **contradiz o Lote 2 desta nota**, que manda substituir pins por ranges —
>   o Lote 2 está superado nesse item e não deve ser executado como escrito.
> - **"Não há `LICENSE`"** — existe desde 2026-11-07, distribuição restrita,
>   todos os direitos reservados (ADR-0007, alternativa C). SBOM e auditoria
>   consolidada de licenças continuam ausentes.
> - **"`THIRD_PARTY_NOTICES.md` declara ONNX Runtime `1.21.1`"** — corrigido
>   para `1.31.1` em 2026-11-07, igual a `build.gradle:32`.
> - **"Falta uma política de atualização"** — a cadência está escrita (nativas
>   revisadas por release, Dart pelo dependabot), a matriz é gerada do lock com
>   `--check` no `qa/run_static.sh`, e `flutter pub outdated` entrou no CI como
>   passo informativo com `continue-on-error: true`.
>
> Defasagem remedida em 2026-11-08: **5** diretas + 1 dev atrasadas (o ML Kit
> aparece agora com major `0.17.1 → 1.0.1`), **9** constrainadas e **17** presas
> no lock — contra 4+1, 7 e 16 na medição de 2026-11-05 registrada abaixo.
> Nenhum upgrade foi executado. Continuam abertos: tamanho de APK
> (ADR-0005/0011), assinatura de release com chave debug, SBOM, e o par
> `pdfrx`/`pdfium_flutter` — que a regra geral de pino nativo alcançaria mas a
> lista decidida no ADR-0009 não nomeia; o ponto está registrado na nota de
> política como decisão pendente do responsável.

## Escopo e método

- Leitura de `pubspec.yaml`, `pubspec.lock` e `pubspec.lock` resolvido.
- Execução de `flutter pub outdated` e `npm audit --omit=dev` em `qa/browser`.
- Leitura de `android/settings.gradle.kts`, `android/build.gradle.kts`,
  `android/app/build.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`,
  `android/app/proguard-rules.pro` e `AndroidManifest.xml`.
- Leitura de `packages/paddleocr_android/android/build.gradle`,
  `build.gradle.bak`, `THIRD_PARTY_NOTICES.md` e `LICENSE`.
- Leitura de `.github/dependabot.yml` e das versões de actions no workflow.
- Inspeção do conteúdo dos APKs em `build/app/outputs/flutter-apk/`
  (arm64, armeabi-v7a, x86_64 e universal) com `unzip -l`.
- Verificação de lockfiles rastreados com `git ls-files`.
- Não foi executado `flutter pub upgrade`, build limpo, nem auditoria de CVE
  por pacote Dart além do OSV do CI.

## O que faz de fato

| Comportamento | Estado | Evidência |
|---|---|---|
| `pubspec.lock` versionado | Funcional | `git ls-files pubspec.lock` |
| Dependabot para GitHub Actions | Funcional | `.github/dependabot.yml:2-8` |
| Dependabot para npm do QA | Funcional | `:10-15` |
| Dependabot para pub | Funcional | `:17-22` |
| Dependabot para Gradle do Paddle | Funcional | `:24-29` |
| Auditoria npm no CI | Funcional | job `npm-security-audit` |
| Auditoria OSV Dart/Flutter | Funcional | job `osv-security-audit` |
| Auditoria OSV Gradle | Funcional | job `osv-android-gradle-audit` |
| Lockfile Gradle gerado no CI | Funcional | job `android-gradle-lock` |
| `npm audit` local sem vulnerabilidades | Funcional | 0 vulnerabilities |
| Versões coerentes de toolchain | Funcional | Flutter 3.47.6; Dart 3.13.5; AGP 9.1.0; Kotlin 2.4.0; Gradle 9.3.1 |
| SDK Android moderno | Funcional | compile/target 36; min 26 |
| Java 17 | Funcional | `android/app/build.gradle.kts:10-13` |
| ProGuard com `dontwarn` do ML Kit | Funcional | `proguard-rules.pro` |
| `LICENSE` do projeto | Ausente | nenhum na raiz |
| SBOM / lista de licenças | Ausente | nenhum arquivo |
| Política de atualização | Ausente | nenhum documento |
| Lockfile Gradle versionado | Ausente | gerado só no CI |
| Assinatura release no repositório | Quebrado | usa `signingConfigs.getByName("debug")` |

## O que funciona

1. **Lockfile Dart versionado e usado com `--enforce-lockfile`.** O CI falha se
   a resolução divergir do lock (`flutter-ci.yml:263, 671`). Isso protege
   contra atualização silenciosa.
2. **Quatro ecossistemas no Dependabot.** GitHub Actions, npm do QA, pub e
   Gradle do Paddle têm atualização semanal com limite de 5 PRs. É uma base
   real de manutenção.
3. **Três auditorias independentes no CI.** npm, Dart/OSV e Gradle/OSV rodam
   inclusive no schedule, então vulnerabilidades conhecidas são verificadas
   mesmo sem push.
4. **OSV com lockfile real.** O job gera o lockfile Gradle com
   `releaseRuntimeClasspath`, publica como artefato e o scanner usa exatamente
   esse arquivo (`flutter-ci.yml:88-129`). Não é uma lista estática.
5. **Toolchain moderna e coerente.** Flutter 3.47.6, Dart 3.13.5, AGP 9.1.0,
   Kotlin 2.4.0, Gradle 9.3.1, Java 17, compile/target SDK 36. Não há mistura
   de versões antigas de build.
6. **`minSdk 26` explícito.** O app não finge suportar Android antigo; o
   requisito está no Gradle e é aplicado no CI (`flutter-ci.yml:551-552`).
7. **ProGuard mínimo e intencional.** As regras só silenciam avisos de scripts
   ML Kit não usados (`proguard-rules.pro`), sem desligar ofuscação global.
8. **Nenhuma dependência de IA paga.** O OCR é local (Paddle/ML Kit), o que
   atende ao princípio 12 do `AGENTS.md`.
9. **Pacote Paddle isolado.** O SDK vendorizado fica em
   `packages/paddleocr_android`, com `pubspec.yaml` próprio, licença Apache 2.0
   e notices. Isso limita o acoplamento ao resto do app.
10. **npm do QA limpo.** `npm audit --omit=dev` retorna 0 vulnerabilidades para
    o Playwright.

## O que está parcial

### Dependências diretas atrasadas

`flutter pub outdated` em 2026-11-05:

| Pacote | Atual | Resolvível | Última | Observação |
|---|---:|---:|---:|---|
| `crypto` | 3.0.7 | 3.0.8 | 3.0.8 | patch |
| `file_picker` | 13.1.0 | 13.3.2 | 13.3.2 | minor |
| `image` | 4.10.1 | 4.12.0 | 4.12.0 | minor |
| `pdfrx` | 2.6.6 | 2.11.0 | 2.11.0 | minor com mudança de engine |
| `pdfium_flutter` (dev) | 0.3.1 | 0.4.1 | 0.4.1 | precisa casar com `pdfrx` |

O relatório também aponta **7 dependências constrainadas a versões mais antigas
que a resolvível** e 16 presas no lock. Não são vulnerabilidades, mas indicam
que a política de atualização não está sendo executada.

`pdfrx` é a mais delicada: 2.6.6 → 2.11.0 provavelmente muda a API de
renderização/engine, e `pdfium_flutter 0.3.1` está acoplado. Atualizar exige
rodar os testes de importação de PDF e validar o Wasm/Web.

### Pins exatos sem justificativa

`pubspec.yaml` usa versão exata para:

- `crypto: 3.0.7`;
- `file_picker: 13.1.0`;
- `google_mlkit_text_recognition: 0.17.1`;
- `http: 1.6.0`;
- `image: 4.10.1`.

O `AGENTS.md` §19 pede “constraints justificadas, não pins arbitrários”. Não há
comentário, ADR ou teste que explique por que esses pacotes não podem subir de
patch/minor. Em alguns casos pode haver motivo real (ML Kit e file_picker são
sensíveis a plataforma), mas o motivo não está registrado.

### `pdfrx` e `pdfium_flutter` formam um par frágil

`pdfrx` usa `pdfium` nativo no Android e Wasm no Web; `pdfium_flutter` é a
dependência de teste que fornece o runtime. As versões atuais são antigas e
precisam subir juntas. Não há teste de fumaça do PDFium no CI além do
`tool/prepare_pdfium_test_runtime.dart`, e o ENEM/PDF real não roda no runner.

### Sem licença, notices e SBOM do projeto

Não existe `LICENSE` na raiz. O único notice é
`packages/paddleocr_android/THIRD_PARTY_NOTICES.md`, que cobre PaddleOCR,
modelos e dependências Android daquele pacote.

Faltam:

- licença do app (mesmo que proprietário, deve haver termos);
- lista consolidada de licenças de Dart, Android e Web;
- SBOM (CycloneDX/SPDX) anexado à release;
- verificação automática de licença incompatível;
- aviso de componentes proprietários (ML Kit, Google Play Services).

O `AGENTS.md` §20 fala em segurança e privacidade, e §17 em distribuição; um
app publicado com APK e Web deve conseguir responder “o que há dentro”.

### Notice do Paddle diverge do build

`THIRD_PARTY_NOTICES.md:21` declara ONNX Runtime Android `1.21.1`; o
`android/build.gradle` usa `1.31.1`. O `build.gradle.bak` (versionado, sem uso)
usa `1.21.1`, provavelmente a origem da divergência. Já registrado na área 13,
mas o impacto é de manutenção: o SBOM/notice não corresponde ao artefato.

O OpenCV `4.5.3` é de 2021, tem 17,1 MB no APK e não tem política de
atualização. É o componente mais pesado e mais antigo do app.

### Assinatura de release com debug no repositório

`android/app/build.gradle.kts:38` contém:

```kotlin
signingConfig = signingConfigs.getByName("debug")
```

O CI corrige isso com um patch textual que cria `signingConfigs.release` e
troca a linha (`flutter-ci.yml:535-577`). O patch funciona, mas:

- um build local `flutter build apk --release` produz APK assinado com debug;
- o repositório não representa o build de produção;
- o patch é frágil a mudanças de template/AGP;
- o `key.properties` gerado no CI não é usado pelo Gradle versionado;
- o TODO do template (“Add your own signing config”) continua no código.

O segredo não está no Git, o que é correto. O problema é a configuração
versionada não ser a de release.

### Lockfile Gradle fora do repositório

`android/app/gradle.lockfile` e
`packages/paddleocr_android/android/gradle.lockfile` não são rastreados; são
gerados no job `android-gradle-lock` e baixados pelo build. Isso garante que a
auditoria e o build usem o mesmo arquivo **dentro do CI**, mas:

- build local resolve versões diferentes das auditadas;
- não há histórico/revisão do lockfile;
- se o artefato expirar, o build não tem fallback versionado;
- o lockfile do app não é coberto pelo Dependabot Gradle (que aponta só para
  `packages/paddleocr_android/android`).

### Actions fixadas por tag, não por SHA

Cinco actions são referenciadas por tag móvel:

- `actions/checkout@v4`;
- `actions/setup-java@v4`;
- `actions/setup-node@v4`;
- `actions/upload-artifact@v4`;
- `actions/download-artifact@v4`;
- `subosito/flutter-action@v2`.

Apenas o OSV é fixado por commit
(`a345acffa64b0eaede81a3d9aae6141214d9c8fc`). Tags podem ser movidas; para
supply chain de release, SHA é mais seguro. Dependabot atualiza, mas não
converte tag em SHA sozinho.

### Tamanho do APK não é medido nem limitado

APKs presentes em `build/app/outputs/flutter-apk/` (build de 2026-11-01):

| Artefato | Tamanho |
|---|---:|
| `app-armeabi-v7a-release.apk` | **61,4 MB** |
| `app-arm64-v8a-release.apk` | **82,1 MB** |
| `app-x86_64-release.apk` | **123,0 MB** |
| `app-release.apk` (universal) | **248,1 MB** |
| `app-debug.apk` | **284,2 MB** |

Composição do arm64:

| Componente | Tamanho |
|---|---:|
| `libonnxruntime.so` | 17,9 MB |
| `libopencv_java4.so` | 17,1 MB |
| `libflutter.so` | 11,7 MB |
| `libmlkit_google_ocr_pipeline.so` | 11,1 MB |
| `libapp.so` | 7,9 MB |
| `libpdfium.so` | 6,4 MB |
| modelos ONNX (det + rec) | 6,2 MB |
| `classes.dex` | 1,7 MB |

O `AGENTS.md` P4 pede “medir tamanho e desempenho do APK”. Não há orçamento,
gráfico, comparação entre ABIs ou gate de regressão. Um APK de 82 MB é caro
para conexão móvel e para o público de concurseiros, que muitas vezes tem
aparelho modesto e plano de dados limitado.

O universal de 248 MB é exatamente o que o site poderia oferecer como fallback
se o APK universal voltasse a ser publicado; o custo precisa entrar na decisão
da área 15.

### Sem política de atualização e compatibilidade

Não há documento que diga:

- quando atualizar dependências (mensal? por CVE?);
- como validar `pdfrx`/`pdfium` e ML Kit;
- qual versão mínima de Android é suportada;
- como tratar breaking changes de Flutter;
- quando remover um pacote;
- quem aprova um upgrade de risco.

O Dependabot abre PRs, mas sem critério de merge. O resultado é a mistura atual
de pins antigos com dependências em `^`.

## O que está ausente ou quebrado

- `LICENSE` do projeto.
- SBOM e inventário consolidado de licenças.
- Auditoria automática de licenças.
- Política de atualização e compatibilidade.
- Justificativa para pins exatos.
- Atualização de `pdfrx`/`pdfium_flutter`.
- Atualização de `file_picker`, `image` e `crypto`.
- Remoção do `build.gradle.bak`.
- Notice alinhado ao ONNX Runtime real.
- Assinatura release no Gradle versionado.
- Lockfile Gradle versionado ou política explícita.
- Actions fixadas por SHA.
- Dependabot para `android/app`.
- Orçamento e gate de tamanho de APK.
- Medição de memória/tempo do OCR no aparelho.
- Teste de atualização de dependência nativa.
- Matriz de compatibilidade Android/Web.

## Divergências documentação × código

| Afirmação | Realidade no SHA | Evidência |
|---|---|---|
| “Constraints justificadas, não pins arbitrários” | 5 pins exatos sem justificativa | `pubspec.yaml:10-24` |
| “Notices conferem com o build” | ONNX `1.21.1` no notice, `1.31.1` no Gradle | `THIRD_PARTY_NOTICES.md:21`; `build.gradle:32` |
| “Assinatura de release configurada” | Gradle versionado usa debug; CI patcheia | `android/app/build.gradle.kts:38`; `flutter-ci.yml:535-577` |
| “Lockfile reproduzível” | Gradle gerado só no CI | `flutter-ci.yml:66-111` |
| “Medir tamanho do APK” | Nenhum gate ou relatório | nenhum script |
| “Dependências compatíveis entre si” | `pdfrx`/`pdfium` antigos e acoplados | `pubspec.yaml`; `pubspec.lock` |
| “Licenças rastreáveis” | Sem `LICENSE`/SBOM do projeto | raiz |

## Evidência de testes

- `flutter pub outdated`: 4 diretas + 1 dev desatualizadas; 7 constrainadas;
  16 presas no lock.
- `npm audit --omit=dev` em `qa/browser`: 0 vulnerabilidades.
- OSV Dart/Gradle: jobs existem, mas não foi possível confirmar o resultado
  mais recente nesta auditoria.
- `pubspec.lock` é usado com `--enforce-lockfile` no CI.
- Não há teste de:
  - upgrade de `pdfrx`/`pdfium`;
  - licença;
  - SBOM;
  - tamanho de APK;
  - assinatura do APK final;
  - compatibilidade de versão mínima;
  - regressão de dependência nativa.

## Riscos

1. **APK enorme.** 82 MB por ABI e 248 MB universal inviabilizam download em
   conexão ruim e aumentam abandono.
2. **OpenCV antigo.** 17 MB e versão de 2021 sem política de atualização.
3. **Notice incorreto.** Auditoria de licença e SBOM não correspondem ao
   artefato distribuído.
4. **Assinatura debug local.** Um build local de release pode ser distribuído
   com chave errada.
5. **Lockfile ausente.** Build local não reproduz o auditado.
6. **Pins sem motivo.** Atualização futura fica travada ou quebra sem aviso.
7. **Actions por tag.** Supply chain de CI menos resistente.
8. **Sem licença.** Distribuição e contribuição ficam juridicamente ambíguas.
9. **Dependabot sem critério.** PRs acumulam ou são ignorados.
10. **`pdfrx` major sem teste.** Atualização pode quebrar importação de PDF.

## Plano de refatoração da área

### Lote 1 — Inventário, licença e SBOM

- Adicionar `LICENSE` (ou termo proprietário explícito).
- Gerar SBOM (CycloneDX/SPDX) no CI e anexar à release.
- Consolidar licenças de Dart, Android e Web em `THIRD_PARTY_NOTICES.md`.
- Adicionar verificação de licença incompatível.
- Critério de aceite: release tem SBOM; `LICENSE` existe; notice cobre todos os
  componentes; CI falha em licença proibida.

### Lote 2 — Política de atualização

- Documentar cadência, critérios e responsáveis.
- Substituir pins exatos por ranges justificados ou comentários no
  `pubspec.yaml`.
- Atualizar `crypto`, `file_picker` e `image` com testes.
- Planejar `pdfrx 2.11` + `pdfium_flutter 0.4` em PR isolado, com benchmark de
  PDF.
- Critério de aceite: `flutter pub outdated` sem atraso injustificado; todo pin
  tem motivo; upgrade de PDF passa nos fixtures.

### Lote 3 — Tamanho e componentes nativos

- Medir APK por ABI e criar orçamento (ex.: ≤ 50 MB arm64).
- Avaliar substituir OpenCV por pré-processamento em Dart/Image ou versão
  enxuta; medir ganho.
- Avaliar se ML Kit e Paddle precisam coexistir no mesmo APK.
- Considerar download sob demanda de modelos (respeitando offline).
- Critério de aceite: relatório de tamanho no CI; nenhuma release acima do
  orçamento sem aprovação.

### Lote 4 — Reprodutibilidade

- Decidir lockfile Gradle versionado ou gerado com fallback documentado.
- Corrigir `android/app/build.gradle.kts` para ler `key.properties` e falhar
  sem keystore em release.
- Remover `build.gradle.bak` e o TODO de assinatura.
- Alinhar notice do ONNX e versão do OpenCV.
- Critério de aceite: build local de release usa a mesma configuração do CI;
  notice e lockfile conferem; nenhum `.bak` versionado.

### Lote 5 — Supply chain do CI

- Fixar actions por SHA.
- Estender Dependabot para `android/app`.
- Adicionar revisão de PR de dependência com checklist.
- Critério de aceite: todas as actions por SHA; Dependabot cobre o app Android;
  PR de dependência tem teste e rollback descritos.

## Classificação por critério

| Critério | Nota | Justificativa |
|---|---:|---|
| Correção | 3 | Dependências funcionam; atrasos e pins sem justificativa. |
| Testes | 2 | OSV/npm audit bons; sem licença, SBOM, tamanho ou upgrade testado. |
| Acoplamento | 3 | Paddle isolado; `pdfrx`/`pdfium` acoplados e build Android patcheado. |
| Clareza | 3 | Dependabot e locks claros; pins e notice divergente confundem. |
| Segurança | 2 | Auditorias boas; assinatura debug, actions por tag, OpenCV antigo. |
| Robustez | 2 | Lockfile só no CI; atualização sem política; APK gigante. |
| Aderência | 2 | §19 pede constraints justificadas e P4 pede medir APK; ambos parciais. |
| Portabilidade | 3 | Android/Web cobertos; libs nativas e ML Kit limitam plataformas. |

Classificação resultante: **EVOLUIR** — a base de auditoria é boa, mas falta
política de licença, tamanho, atualização e reprodutibilidade para sustentar
distribuição.

## Dependências

- Área 13 para Paddle, ONNX, OpenCV e notices.
- Área 14 para testes de upgrade e benchmark.
- Área 15 para release, SBOM, APK universal e site.
- Área 16 para impacto visual de fontes e ícones.
- Área 18 para documentar a política.
- Decisão de produto sobre tamanho máximo de APK e modelos sob demanda.

## O que não foi verificado

- CVEs específicas de OpenCV `4.5.3` e ONNX Runtime `1.31.1`.
- Resultado mais recente do OSV no CI.
- Compatibilidade de `pdfrx 2.11` com o código atual.
- Build limpo após atualização.
- Assinatura do APK publicado (além do fingerprint do keystore).
- Licenças de todas as dependências transitivas.
- Tamanho do APK após remoção de componentes.
- Memória e tempo de inicialização em aparelho de entrada.
- Funcionamento do ML Kit sem Google Play Services.
- Política de atualização do Flutter 3.47.6.

## Links

- [[13 - OCR Android, PaddleOCR e digitalização|Área 13 — OCR Android]]
- [[14 - Testes, QA e benchmark|Área 14 — Testes e QA]]
- [[15 - CI-CD, releases, site, Web e PWA|Área 15 — CI/CD e distribuição]]
- [[16 - Design system e componentes|Área 16 — Design system]]
- [[18 - Documentação e divergências código × docs|Área 18 — Documentação]]
- [[../../04 - Infraestrutura/Dados e Segurança|Dados e Segurança]]
- [[Mapa das Áreas|Mapa das Áreas]]
