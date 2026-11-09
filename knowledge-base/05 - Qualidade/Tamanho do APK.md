---
tipo: area
area: tamanho de apk e distribuição
status: VALIDADO
classificacao: MANTER
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [tool/apk_size_report.py, tool/test_apk_size_report.py, .github/workflows/flutter-ci.yml]
sha: 516a52aef8716991f0004767a13aef7faf655fb5
confianca: alta
atualizado: 2026-11-08
---

# Tamanho do APK por release

> Gerado por `tool/apk_size_report.py` a partir dos APKs compilados.
> Registro manual de um número não substitui o relatório da release.
> Decisão: [[../06 - Decisões/ADR/ADR-0011 - Tamanho de APK, modelos e componentes nativos|ADR-0011]].
> Distribuição por ABI: [[../06 - Decisões/ADR/ADR-0005 - Distribuição Android e seleção de ABI|ADR-0005]].

## Baseline publicado — v0.7.5

Medido nos assets da release `v0.7.5` com
`gh release view v0.7.5 --json assets`. São bytes **comprimidos**, ou seja, o
tamanho do arquivo que o usuário baixa — não o conteúdo descomprimido do APK.

| Artefato | Bytes | Equivalente |
| --- | ---: | ---: |
| `app-arm64-v8a-release.apk` | 82.134.581 | 78,33 MiB |
| `app-armeabi-v7a-release.apk` | 61.361.205 | 58,52 MiB |
| `app-x86_64-release.apk` | 122.968.231 | 117,27 MiB |
| `prova-social-web-<tag>.zip` | 17.255.882 | 16,46 MiB |

O universal de 248 MB citado no ADR-0011 é de um build local e **não** foi
publicado; releases novas não produzem universal (ADR-0005). O baseline acima
não mede instalação no aparelho, tempo de primeiro OCR nem uso de RAM.

## Comando de medição

Depois de `flutter build apk --release --split-per-abi`:

```bash
python3 tool/apk_size_report.py \
  --input build/app/outputs/flutter-apk \
  --json build/apk-sizes.json \
  --markdown build/apk-sizes.md
```

Saídas:

- `build/apk-sizes.json` — `schema_version`, `generated_at`, `total_bytes` e,
  por APK, `name`, `bytes` e `sha256`;
- `build/apk-sizes.md` — tabela com bytes, MiB e SHA-256, pronta para o corpo
  da release.

O SHA-256 é calculado em streaming sobre o arquivo inteiro. O relatório falha
com código 1 e não grava nada quando o diretório não existe ou não contém APK.
`python3 tool/test_apk_size_report.py` cobre os dois caminhos de falha e um
caso com dois APKs sintéticos.

## Na release

O job `android-release` de `.github/workflows/flutter-ci.yml`:

1. gera os dois relatórios logo após compilar os APKs;
2. anexa `apk-sizes.json` e `apk-sizes.md` aos assets da GitHub Release;
3. preserva as notas geradas pelo GitHub e acrescenta o Markdown ao corpo via
   `gh release edit --notes-file`.

O tamanho é **métrica registrada**, não gate: nenhum limite bloqueia a release.
Cortar uma pilha de OCR continua condicionado ao benchmark estrutural em
Android (ADR-0011); até lá, a duplicação de PaddleOCR e ML Kit permanece.

## Limites

- O relatório mede apenas os APKs presentes no diretório informado.
- Não compara com a release anterior nem alerta sobre regressão; a comparação é
  manual, olhando o histórico de releases.
- Não mede tamanho instalado, download inicial em rede móvel, RAM ou tempo de
  inicialização.
- O web zip é anexado à release, mas não entra no relatório de APKs.
