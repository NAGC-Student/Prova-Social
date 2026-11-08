---
tipo: area
area: dependências e manutenção
status: VALIDADO
classificacao: MANTER
nivel: {correcao: 0, testes: 0, acoplamento: 0, clareza: 0, seguranca: 0, robustez: 0, aderencia: 0, portabilidade: 0}
fonte_codigo: [pubspec.lock, tool/generate_dependency_matrix.py]
sha: 4f1c72b5c06d10b39d3e1856c2567eb5d17f6ccc719ec0bbc25636db78160508
confianca: alta
atualizado: 2026-11-08
---

# Matriz de dependências (gerada do lock)

> Gerada por `tool/generate_dependency_matrix.py` a partir de `pubspec.lock`.
> Não editar à mão: `python3 tool/generate_dependency_matrix.py --check` falha
> se o texto divergir do lock. Regra de pin e cadência de atualização:
> [[../03 - Domínios/Dependências e pins|Dependências e pins]].

- **SHA-256 de `pubspec.lock`:** `4f1c72b5c06d10b39d3e1856c2567eb5d17f6ccc719ec0bbc25636db78160508`
- **Data desta matriz:** 2026-11-08 — mantida enquanto o SHA-256 não muda,
  para que a nota não envelheça sozinha nem passe no `--check` por sorte.
- **Pacotes resolvidos:** 125 — 15 diretos de app,
  4 diretos de dev, 106 transitivos.
- `nivel` zerado e `classificacao: MANTER`: é inventário gerado, não auditoria
  de área. Nesta nota o campo `sha:` do frontmatter é o SHA-256 do lock, não
  um commit — a fonte medida é o conteúdo do arquivo, não um snapshot do repo.
- O lock Dart não cobre os artefatos Gradle do plugin PaddleOCR; eles estão
  em `packages/paddleocr_android/android/build.gradle` e no aviso de terceiros.

## Diretas de app

| Pacote | Versão resolvida | Origem |
|---|---|---|
| `archive` | `4.6.0` | hosted |
| `crypto` | `3.0.7` | hosted |
| `file_picker` | `13.1.0` | hosted |
| `flutter` | `0.0.0` | sdk: flutter |
| `flutter_web_plugins` | `0.0.0` | sdk: flutter |
| `google_mlkit_text_recognition` | `0.17.1` | hosted |
| `http` | `1.6.0` | hosted |
| `image` | `4.10.1` | hosted |
| `package_info_plus` | `10.2.2` | hosted |
| `paddleocr_android` | `0.1.0` | path: packages/paddleocr_android |
| `path_provider` | `2.1.6` | hosted |
| `pdfrx` | `2.6.6` | hosted |
| `shared_preferences` | `2.5.6` | hosted |
| `supabase_flutter` | `2.18.3` | hosted |
| `url_launcher` | `6.3.3` | hosted |

## Diretas de dev

| Pacote | Versão resolvida | Origem |
|---|---|---|
| `flutter_launcher_icons` | `0.14.4` | hosted |
| `flutter_lints` | `6.0.0` | hosted |
| `flutter_test` | `0.0.0` | sdk: flutter |
| `pdfium_flutter` | `0.3.1` | hosted |

## Transitivas

| Pacote | Versão resolvida | Origem |
|---|---|---|
| `android_file_picker` | `2.1.2` | hosted |
| `app_links` | `7.2.2` | hosted |
| `app_links_linux` | `1.0.4` | hosted |
| `app_links_platform_interface` | `2.0.4` | hosted |
| `app_links_web` | `1.0.5` | hosted |
| `args` | `2.7.0` | hosted |
| `async` | `2.13.1` | hosted |
| `boolean_selector` | `2.1.2` | hosted |
| `characters` | `1.4.1` | hosted |
| `checked_yaml` | `2.0.4` | hosted |
| `cli_util` | `0.4.2` | hosted |
| `clock` | `1.1.3` | hosted |
| `code_assets` | `1.2.1` | hosted |
| `collection` | `1.19.1` | hosted |
| `convert` | `3.1.2` | hosted |
| `cross_file` | `0.3.5+5` | hosted |
| `cupertino_ui` | `1.1.5` | hosted |
| `dart_jsonwebtoken` | `3.4.1` | hosted |
| `dbus` | `0.8.0` | hosted |
| `fake_async` | `1.3.3` | hosted |
| `ffi` | `2.2.0` | hosted |
| `ffi_leak_tracker` | `0.1.2` | hosted |
| `file` | `7.0.1` | hosted |
| `file_picker_darwin` | `2.4.1` | hosted |
| `file_picker_linux` | `2.0.2` | hosted |
| `file_picker_platform_interface` | `4.2.0` | hosted |
| `file_picker_web` | `4.2.0` | hosted |
| `flutter_localizations` | `0.0.0` | sdk: flutter |
| `functions_client` | `2.7.1` | hosted |
| `google_mlkit_commons` | `0.13.0` | hosted |
| `gotrue` | `2.27.3` | hosted |
| `hooks` | `2.0.2` | hosted |
| `http_parser` | `4.1.2` | hosted |
| `intl` | `0.20.3` | hosted |
| `jni` | `1.1.1` | hosted |
| `jni_flutter` | `1.0.4+1` | hosted |
| `jni_util` | `1.0.0` | hosted |
| `json_annotation` | `4.12.0` | hosted |
| `leak_tracker` | `11.0.2` | hosted |
| `leak_tracker_flutter_testing` | `3.0.10` | hosted |
| `leak_tracker_testing` | `3.0.2` | hosted |
| `lints` | `6.1.0` | hosted |
| `logging` | `1.3.0` | hosted |
| `matcher` | `0.12.20` | hosted |
| `material_color_utilities` | `0.13.0` | hosted |
| `material_ui` | `1.9.0` | hosted |
| `meta` | `1.18.3` | hosted |
| `mime` | `2.1.0` | hosted |
| `objective_c` | `9.5.0` | hosted |
| `package_config` | `3.0.0` | hosted |
| `package_info_plus_platform_interface` | `4.1.0` | hosted |
| `passkeys_platform_interface` | `2.10.0` | hosted |
| `path` | `1.9.1` | hosted |
| `path_provider_android` | `2.3.1` | hosted |
| `path_provider_foundation` | `2.6.0` | hosted |
| `path_provider_linux` | `2.2.2` | hosted |
| `path_provider_platform_interface` | `2.1.3` | hosted |
| `path_provider_windows` | `2.3.0` | hosted |
| `pdfium_dart` | `0.3.1` | hosted |
| `pdfrx_engine` | `0.6.1` | hosted |
| `petitparser` | `7.0.2` | hosted |
| `platform` | `3.2.0` | hosted |
| `plugin_platform_interface` | `2.1.8` | hosted |
| `pointycastle` | `4.0.0` | hosted |
| `posix` | `6.5.4` | hosted |
| `postgrest` | `2.9.1` | hosted |
| `pub_semver` | `2.2.1` | hosted |
| `realtime_client` | `2.13.2` | hosted |
| `record_use` | `0.6.0` | hosted |
| `rxdart` | `0.28.0` | hosted |
| `shared_preferences_android` | `2.5.4` | hosted |
| `shared_preferences_foundation` | `2.5.7` | hosted |
| `shared_preferences_linux` | `2.4.1` | hosted |
| `shared_preferences_platform_interface` | `2.4.2` | hosted |
| `shared_preferences_web` | `2.4.3` | hosted |
| `shared_preferences_windows` | `2.4.1` | hosted |
| `sky_engine` | `0.0.0` | sdk: flutter |
| `source_span` | `1.10.2` | hosted |
| `stack_trace` | `1.12.2` | hosted |
| `storage_client` | `2.8.1` | hosted |
| `stream_channel` | `2.1.4` | hosted |
| `string_scanner` | `1.4.1` | hosted |
| `supabase` | `2.16.5` | hosted |
| `supabase_common` | `0.1.2` | hosted |
| `synchronized` | `3.5.0` | hosted |
| `term_glyph` | `1.2.2` | hosted |
| `test_api` | `0.7.12` | hosted |
| `typed_data` | `1.4.0` | hosted |
| `url_launcher_android` | `6.3.33` | hosted |
| `url_launcher_ios` | `6.4.2` | hosted |
| `url_launcher_linux` | `3.2.3` | hosted |
| `url_launcher_macos` | `3.2.6` | hosted |
| `url_launcher_platform_interface` | `2.3.2` | hosted |
| `url_launcher_web` | `2.4.3` | hosted |
| `url_launcher_windows` | `3.1.6` | hosted |
| `vector_math` | `2.4.0` | hosted |
| `vm_service` | `15.4.0` | hosted |
| `web` | `1.1.2` | hosted |
| `web_socket` | `1.0.1` | hosted |
| `web_socket_channel` | `3.0.3` | hosted |
| `win32` | `6.4.0` | hosted |
| `windows_file_picker` | `2.0.1` | hosted |
| `xdg_directories` | `1.1.0` | hosted |
| `xml` | `7.0.1` | hosted |
| `yaml` | `3.1.4` | hosted |
| `yet_another_json_isolate` | `2.1.1` | hosted |

## SDKs

| SDK | Constraint resolvida |
|---|---|
| `dart` | `>=3.13.0 <4.0.0` |
| `flutter` | `>=3.47.0` |

## Como regenerar

```sh
python3 tool/generate_dependency_matrix.py
python3 tool/generate_dependency_matrix.py --check
```

O `--check` roda no `qa/run_static.sh`. A matriz só muda quando o lock muda:
aceitar PR do dependabot exige regenerar a nota no mesmo commit.
