import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_payload_store.dart';

/// Migra uma chave do `SharedPreferences` para o armazenamento por arquivo.
///
/// O legado só é removido depois de a gravação nova ser confirmada. Se a
/// gravação falhar, a leitura continua devolvendo o valor antigo.
Future<String?> readMigratingPayload(
  LocalPayloadStore store,
  String key,
) async {
  final stored = await store.read(key);
  if (stored != null) return stored;

  final legacy = await SharedPreferences.getInstance();
  final value = legacy.getString(key);
  if (value == null) return null;

  final saved = await store.write(key, value);
  if (!saved) {
    debugPrint(
      '[PAYLOAD_MIGRATION] não foi possível migrar $key; legado preservado',
    );
    return value;
  }
  try {
    await legacy.remove(key);
  } catch (error, stackTrace) {
    debugPrint(
      '[PAYLOAD_MIGRATION] migrou $key; limpeza do legado falhou: ${error.runtimeType}',
    );
    debugPrint('[PAYLOAD_MIGRATION] stack: $stackTrace');
  }
  return value;
}

/// Grava na porta nova. Se a plataforma não persistir, usa o legado como
/// último recurso e mantém o valor recuperável na próxima leitura.
Future<void> writeMigratingPayload(
  LocalPayloadStore store,
  String key,
  String value,
) async {
  if (await store.write(key, value)) return;
  final legacy = await SharedPreferences.getInstance();
  final saved = await legacy.setString(key, value);
  if (!saved) {
    throw StateError('Não foi possível salvar no aparelho.');
  }
  debugPrint(
    '[PAYLOAD_MIGRATION] arquivo indisponível para $key; fallback em preferences',
  );
}

Future<void> removeMigratingPayload(LocalPayloadStore store, String key) async {
  final stored = await store.remove(key);
  final legacy = await SharedPreferences.getInstance();
  final hadLegacy = legacy.containsKey(key);
  final legacyRemoved = hadLegacy ? await legacy.remove(key) : true;
  if (!stored && !legacyRemoved) {
    throw StateError('Não foi possível remover do aparelho.');
  }
}
