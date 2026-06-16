class L10nConfig {
  final String spreadsheetId;
  final String sheetName;
  final String arbDir;
  final String defaultLocale;
  final List<String> locales;

  const L10nConfig({
    required this.spreadsheetId,
    required this.sheetName,
    required this.arbDir,
    required this.defaultLocale,
    required this.locales,
  });

  /// Pass any [String? Function(String)] lookup — use [loadEnv] from auth_helper.
  factory L10nConfig.fromReader(String? Function(String) get) {
    String require(String key, {String? hint}) {
      final v = get(key);
      if (v == null || v.trim().isEmpty) {
        throw ConfigException(
          '$key not set in .env.\n'
          'Add it to .env in your Flutter project root:\n'
          '  $key=${hint ?? 'value'}',
        );
      }
      return v.trim();
    }

    final spreadsheetId = require('L10N_SPREADSHEET_ID',
        hint: 'your_spreadsheet_id');
    final sheetName = require('L10N_SHEET_NAME', hint: 'Sheet1');
    final arbDir = require('L10N_ARB_DIR', hint: './lib/l10n');
    final defaultLocale = require('L10N_DEFAULT_LOCALE', hint: 'en');
    final rawLocales = require('L10N_LOCALES', hint: 'en,th');

    final locales = rawLocales
        .split(',')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (locales.isEmpty) {
      throw const ConfigException(
        'L10N_LOCALES must be a comma-separated list, e.g. en,th',
      );
    }

    if (!locales.contains(defaultLocale)) {
      throw ConfigException(
        'L10N_DEFAULT_LOCALE ("$defaultLocale") must be present in L10N_LOCALES ("$rawLocales")',
      );
    }

    return L10nConfig(
      spreadsheetId: spreadsheetId,
      sheetName: sheetName,
      arbDir: arbDir,
      defaultLocale: defaultLocale,
      locales: locales,
    );
  }
}

class ConfigException implements Exception {
  final String message;
  const ConfigException(this.message);

  @override
  String toString() => message;
}
