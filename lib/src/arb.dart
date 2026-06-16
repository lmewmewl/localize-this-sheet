import 'dart:convert';
import 'dart:io';

typedef ArbData = Map<String, String>;

/// Reads app_{locale}.arb from [arbDir]. Returns empty map if file absent.
/// Strips metadata keys (starting with '@') and non-string values.
ArbData readArb(String arbDir, String locale) {
  final file = File('$arbDir/app_$locale.arb');

  if (!file.existsSync()) return {};

  final Map<String, dynamic> parsed;
  try {
    parsed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    throw ArbException('Invalid JSON in ${file.path}');
  }

  return Map.fromEntries(
    parsed.entries
        .where((e) => !e.key.startsWith('@') && e.value is String)
        .map((e) => MapEntry(e.key, e.value as String)),
  );
}

/// Writes [data] to app_{locale}.arb in [arbDir] as pretty-printed JSON.
void writeArb(String arbDir, String locale, ArbData data) {
  final dir = Directory(arbDir);
  if (!dir.existsSync()) dir.createSync(recursive: true);

  final file = File('$arbDir/app_$locale.arb');
  file.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(data)}\n',
  );
}

class ArbException implements Exception {
  final String message;
  const ArbException(this.message);

  @override
  String toString() => message;
}
