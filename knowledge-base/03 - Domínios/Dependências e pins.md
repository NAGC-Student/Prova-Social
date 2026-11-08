---
tipo: guia
area: dependências e manutenção
status: VALIDADO
classificacao: MANTER
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.yaml, pubspec.lock, .github/dependabot.yml, .github/workflows/flutter-ci.yml, packages/paddleocr_android/android/build.gradle, tool/generate_dependency_matrix.py, qa/run_static.sh]
sha: 36c899d6cef8b9b424927af7a3c233ecd63dd4f0
confianca: alta
atualizado: 2026-11-08
---

# Dependências e pins (ADR-0009)

Nota **normativa**: a regra de pin que o projeto já praticava sem escrever, a
cadência de atualização e o gate que impede a matriz de apodrecer. Materializa a
alternativa **A** do [[../06 - Decisões/ADR/ADR-0009 - Política de dependências e pins|ADR-0009]],
aceito em 2026-11-07. Os números abaixo são medidos, não estimados; a matriz
completa é gerada em [[../05 - Qualidade/Matriz de dependências]].

## Regra de pin

1. **Pino exato** para o que toca nativo ou contrato externo: ML Kit,
   `file_picker`, `http`, `crypto`, `image`, o plugin local PaddleOCR e os
   artefatos Gradle que ele embarca.
2. **Caret** para o restante — pacote Dart puro ou plugin cuja superfície é
   estável o bastante para o lock resolver.
3. **`pubspec.lock` é commitado e enforced.** O CI roda
   `flutter pub get --enforce-lockfile` em quatro pontos
   (`.github/workflows/flutter-ci.yml:92`, `:159`, `:267`, `:675`): uma mudança
   de lock sem intenção falha a esteira. Caret **não** significa "versão solta"
   — significa "o lock decide, e o lock é revisado".
4. **Nada de `flutter pub upgrade --major-versions` no pipeline.** A regra vem
   do documento histórico e continua valendo; o passo informativo do CI é
   `flutter pub outdated`, que não altera arquivo nenhum.
5. **Atualização entra como PR do dependabot**, um lote por vez, com esteira
   verde. Não há `renovate.json` no repositório.

`nivel` zerado: esta nota é regra e medição de dependências, não auditoria de
área do código.

## Inventário medido em 2026-11-08

15 dependências diretas de app e 4 de dev (`pubspec.yaml:10-35`), 125 pacotes
resolvidos no lock (15 `direct main`, 4 `direct dev`, 106 transitivos). Nenhum
`any`, nenhum `git`.

| Pacote | Constraint | Resolvido | Regra aplicável |
|---|---|---|---|
| `crypto` | `3.0.7` (`pubspec.yaml:12`) | 3.0.7 | exato — contrato externo |
| `file_picker` | `13.1.0` (`:13`) | 13.1.0 | exato — nativo |
| `google_mlkit_text_recognition` | `0.17.1` (`:18`) | 0.17.1 | exato — nativo/OCR |
| `http` | `1.6.0` (`:19`) | 1.6.0 | exato — contrato externo |
| `image` | `4.10.1` (`:20`) | 4.10.1 | exato — contrato externo |
| `paddleocr_android` | path (`:22-23`) | 0.1.0 | caminho — exato por natureza |
| `archive` | `^4.3.0` (`:11`) | 4.6.0 | caret |
| `package_info_plus` | `^10.2.2` (`:21`) | 10.2.2 | caret |
| `path_provider` | `^2.1.6` (`:24`) | 2.1.6 | caret |
| `pdfrx` | `^2.6.5` (`:25`) | 2.6.6 | caret — **ver ponto aberto** |
| `shared_preferences` | `^2.5.6` (`:26`) | 2.5.6 | caret |
| `supabase_flutter` | `^2.18.0` (`:27`) | 2.18.3 | caret |
| `url_launcher` | `^6.3.2` (`:28`) | 6.3.3 | caret |
| `flutter`, `flutter_web_plugins` | SDK (`:14-17`) | 0.0.0 | SDK do Flutter |
| `flutter_lints` | `^6.0.0` (`:33`) | 6.0.0 | caret (dev) |
| `flutter_launcher_icons` | `^0.14.4` (`:34`) | 0.14.4 | caret (dev) |
| `pdfium_flutter` | `^0.3.0` (`:35`) | 0.3.1 | caret (dev) — **ver ponto aberto** |
| `flutter_test` | SDK (`:31-32`) | 0.0.0 | SDK do Flutter |

Os cinco pinos exatos batem com a lista da regra; o plugin local é exato por ser
`path`. SDK: `">=3.13.0 <4.0.0"` e Flutter `">=3.47.0"` (`pubspec.yaml:6-8`,
iguais no bloco `sdks:` do lock).

## O que o lock Dart não cobre

O plugin PaddleOCR embarca artefatos Gradle próprios
(`packages/paddleocr_android/android/build.gradle:32-34`):

- `com.microsoft.onnxruntime:onnxruntime-android:1.31.1`
- `com.quickbirdstudios:opencv:4.5.3`
- `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0`

O Dart não resolve nada disso. A cobertura vem de outro lado:
`dependencyLocking { lockAllConfigurations() }` (`build.gradle:27-28`) e o job
`android-gradle-lock` do CI, que resolve com `--write-locks`, exige
`app/gradle.lockfile` e `packages/paddleocr_android/android/gradle.lockfile`
não vazios e publica os dois como artefato
(`.github/workflows/flutter-ci.yml:66-113`). O job
`osv-android-gradle-audit` (`:115`) consome esse artefato. Os lockfiles do
Gradle são gerados no CI, não commitados — quem audita versão nativa lê o
`build.gradle` e o artefato da run, não o lock Dart.

As versões e licenças desses artefatos estão declaradas em
`packages/paddleocr_android/THIRD_PARTY_NOTICES.md`, conferido contra o
`build.gradle` em 2026-11-07 (ADR-0007).

## Cadência

- **Nativas (ML Kit, PaddleOCR/ONNX/OpenCV, PDFium): revisar a cada release.**
  São as que mudam tamanho de APK e comportamento de OCR; a revisão exige
  rebuild Android e importação de prova real antes e depois, não só
  `flutter test` (ver [[../06 - Decisões/ADR/ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]]).
- **Dart: fluxo do dependabot**, semanal, limite de 5 PRs abertos por
  ecossistema (`.github/dependabot.yml`: `github-actions` na raiz, `npm` em
  `/qa/browser`, `pub` na raiz, `gradle` em `/packages/paddleocr_android/android`).
- **Defasagem: visível, não corrigida automaticamente.** O passo
  `Defasagem de dependências (informativo, ADR-0009)` roda
  `flutter pub outdated` com `continue-on-error: true`
  (`.github/workflows/flutter-ci.yml:172-174`). Ele informa; não atualiza.

## Defasagem medida em 2026-11-08

`flutter pub outdated` executado localmente, exit 0, **sem alterar o lock**
(SHA-256 conferido antes e depois: `4f1c72b5c06d10b39d3e1856c2567eb5d17f6ccc719ec0bbc25636db78160508`).
Saída resumida — `Current` é o que está no lock, `Latest` o publicado:

| Pacote | Current | Latest | Observação |
|---|---|---|---|
| `crypto` | 3.0.7 | 3.0.8 | pino exato; bump é decisão |
| `file_picker` | 13.1.0 | 13.3.2 | pino exato; nativo |
| `google_mlkit_text_recognition` | 0.17.1 | **1.0.1** | major; nativo/OCR |
| `image` | 4.10.1 | 4.12.0 | pino exato |
| `pdfrx` | 2.6.6 | 2.12.0 | caret já permite; o lock segura |
| `pdfium_flutter` (dev) | 0.3.1 | 0.4.1 | nativo PDFium |

O rodapé da saída registra **17** dependências "upgradable" presas no lock e
**9** cuja constraint é mais velha que a versão resolvível. Nenhuma foi
atualizada nesta rodada: o ADR-0009 escolheu tornar a defasagem visível, e o
major do ML Kit cai no gate de benchmark em aparelho do ADR-0011, ainda
pendente de dispositivo. O caso `pdfrx` mostra por que a regra 3 importa: com
caret, quem decide a versão é o lock, não o `pubspec.yaml`.

## Matriz gerada e gate

- `tool/generate_dependency_matrix.py` lê `pubspec.lock`, calcula o SHA-256 do
  arquivo e escreve [[../05 - Qualidade/Matriz de dependências]] com data,
  contagens e as três tabelas (diretas de app, diretas de dev, transitivas) mais
  os SDKs. Só stdlib — o gerador não depende de PyYAML nem do Flutter.
- **A data não envelhece sozinha.** Enquanto o SHA-256 do lock não muda, o
  gerador preserva o `atualizado:` gravado; quando o lock muda, estampa o dia.
  Sem isso o `--check` falharia todo dia por motivo nenhum.
- **`--check`** compara o texto gravado com o que o lock produz e falha se
  divergir — inclusive se alguém editou a nota à mão. Roda no
  `qa/run_static.sh`, junto do teste do gerador
  (`tool/test_generate_dependency_matrix.py`, 15 testes com lock temporário
  mínimo: origem hosted/path/sdk, lock malformado, pacote repetido, data
  preservada, matriz editada, matriz ausente).
- Nesta nota gerada o campo `sha:` do frontmatter é o **SHA-256 do lock**, não
  um commit: a fonte medida é o conteúdo do arquivo. É exceção declarada à
  convenção de `sha: <SHA do main auditado>`, registrada aqui e no corpo da
  matriz.
- Aceitar PR do dependabot exige regenerar a matriz **no mesmo commit** do
  lock; caso contrário o gate estático falha.

Comandos:

```sh
python3 tool/generate_dependency_matrix.py
python3 tool/generate_dependency_matrix.py --check
python3 tool/test_generate_dependency_matrix.py
flutter pub outdated
```

## Ponto aberto: PDFium com caret

A regra diz "pino exato para o que toca nativo", mas a lista decidida no
ADR-0009 nomeia ML Kit, `file_picker`, `http`, `crypto`, `image` e o plugin
PaddleOCR. `pdfrx` (^2.6.5) e `pdfium_flutter` (^0.3.0, dev) carregam PDFium
nativo e **não** estão na lista — hoje são caret. Há duas saídas coerentes e a
escolha é do responsável: incluí-los no conjunto de pino exato, ou registrar a
exceção com o motivo. Esta nota não muda `pubspec.yaml` para resolver a
ambiguidade por conta própria; enquanto a decisão não vem, o lock enforced é o
que impede movimento silencioso, e o gate de release do ADR-0011 cobre o
comportamento.

## Limites

- O `flutter pub outdated` acima foi medido nesta máquina em 2026-11-08; não é
  consulta agendada. A cadência real continua sendo a do dependabot.
- Não foi verificado se o dependabot está ativo no repositório upstream — isso
  é configuração de plataforma, não arquivo.
- Não houve build Android limpo nesta tarefa: o lock do Gradle foi lido no
  `build.gradle` e no job do CI, não resolvido localmente.
- Nenhum upgrade, bump ou edição de `pubspec.yaml`/`pubspec.lock` foi feito.

## Links

- [[../06 - Decisões/ADR/ADR-0009 - Política de dependências e pins|ADR-0009]] — decisão e alternativas.
- [[../05 - Qualidade/Matriz de dependências]] — as 125 versões resolvidas.
- [[../02 - Arquitetura/Mapa de Dependências]] — grafo de imports internos, assunto diferente.
- [[../09 - Auditoria/Áreas/17 - Dependências e manutenção|Área 17]] — auditoria que levantou o problema.
- [docs/historico/DEPENDENCY_COMPATIBILITY.md](../../docs/historico/DEPENDENCY_COMPATIBILITY.md) — matriz de 0.5.0, congelada.