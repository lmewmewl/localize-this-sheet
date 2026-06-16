import 'dart:io';

import 'package:l10n_this_sheet/src/arb.dart';
import 'package:l10n_this_sheet/src/auth_helper.dart';
import 'package:l10n_this_sheet/src/config.dart';
import 'package:l10n_this_sheet/src/sheets_client.dart';

Future<void> main() async {
  try {
    await _push();
  } on ConfigException catch (e) {
    stderr.writeln('Config error: $e');
    exit(1);
  } on AuthException catch (e) {
    stderr.writeln('Auth error: $e');
    exit(1);
  } on ArbException catch (e) {
    stderr.writeln('ARB error: $e');
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }

  exit(0);
}

Future<void> _push() async {
  final env = loadEnv();
  final config = L10nConfig.fromReader(env);

  stdout.writeln('Reading ARB files from ${config.arbDir} ...');

  final localeData = <String, ArbData>{};
  for (final locale in config.locales) {
    localeData[locale] = readArb(config.arbDir, locale);
    stdout.writeln('  app_$locale.arb — ${localeData[locale]!.length} keys');
  }

  // Default locale keys first, then extra keys from other locales in config order.
  final keySet = <String>{
    ...localeData[config.defaultLocale]?.keys ?? [],
    for (final locale in config.locales)
      if (locale != config.defaultLocale) ...?localeData[locale]?.keys,
  };

  if (keySet.isEmpty) {
    throw const ArbException(
      'No keys found in any ARB file. '
      'Aborting push to avoid overwriting sheet with empty data.',
    );
  }

  final header = ['Key', ...config.locales.map((l) => l.toUpperCase())];
  final rows = keySet.map((key) => [
        key,
        ...config.locales.map((locale) => localeData[locale]?[key] ?? ''),
      ]).toList();

  final matrix = [header, ...rows];

  stdout.writeln('\nPushing ${keySet.length} keys to sheet "${config.sheetName}" ...');

  final httpClient = await getAuthenticatedClient(env);
  try {
    await writeSheet(
      httpClient: httpClient,
      spreadsheetId: config.spreadsheetId,
      sheetName: config.sheetName,
      values: matrix,
    );
  } finally {
    httpClient.close();
  }

  stdout.writeln('Done. ${keySet.length} rows written to Google Sheets.');
}
