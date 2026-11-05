import 'dart:io';

/// Shared plumbing for the manual corpus probes in this folder.
///
/// Probes are excluded from the automated suite: they read a corpus folder from
/// the environment and write their reports under `build/qa/probes`, which keeps
/// exam text out of CI logs and out of Git.
String? probeRoot(String variable) {
  final value = Platform.environment[variable]?.trim();
  if (value == null || value.isEmpty) return null;
  return Directory(value).absolute.path;
}

String probeSkipReason(String variable) =>
    'Manual probe. Set $variable to a local corpus folder and run '
    'qa/run_corpus_probes.sh.';

Directory probeOutputDirectory() {
  final configured = Platform.environment['PROVA_SOCIAL_PROBE_OUTPUT_DIR']
      ?.trim();
  final path = (configured == null || configured.isEmpty)
      ? 'build/qa/probes'
      : configured;
  final directory = Directory(path)..createSync(recursive: true);
  return directory.absolute;
}

File probeFile(String name) =>
    File('${probeOutputDirectory().path}${Platform.pathSeparator}$name');

String clip(String value, int length) {
  final flat = value.replaceAll('\n', ' ');
  return flat.length <= length ? flat : '${flat.substring(0, length)}…';
}

String range(List<int> numbers) {
  if (numbers.length <= 12) return '$numbers';
  return '${numbers.take(12).toList()}…(${numbers.length})';
}
