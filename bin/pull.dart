import 'dart:io';

import 'package:l10n_this_sheet/src/arb.dart';
import 'package:l10n_this_sheet/src/auth_helper.dart';
import 'package:l10n_this_sheet/src/config.dart';
import 'package:l10n_this_sheet/src/sheets_client.dart';

Future<void> main() async {
  try {
    await _pull();
  } on ConfigException catch (e) {
    stderr.writeln('Config error: $e');
    exit(1);
  } on AuthException catch (e) {
    stderr.writeln('Auth error: $e');
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }

  exit(0);
}

Future<void> _pull() async {
  final env = loadEnv();
  final config = L10nConfig.fromReader(env);

  stdout.writeln('Fetching data from sheet "${config.sheetName}" ...');

  final httpClient = await getAuthenticatedClient(env);
  final List<List<String>> rows;
  try {
    rows = await readSheet(
      httpClient: httpClient,
      spreadsheetId: config.spreadsheetId,
      sheetName: config.sheetName,
    );
  } finally {
    httpClient.close();
  }

  if (rows.length < 2) {
    stdout.writeln('Sheet is empty or has no data rows. Nothing to pull.');
    return;
  }

  final header = rows.first;
  final dataRows = rows.skip(1).toList();

  // Map locale name (lowercase) → column index.
  final localeColumnMap = <String, int>{};
  for (var i = 1; i < header.length; i++) {
    final cell = header[i].trim();
    if (cell.isNotEmpty) localeColumnMap[cell.toLowerCase()] = i;
  }

  for (final locale in config.locales) {
    if (!localeColumnMap.containsKey(locale)) {
      final found = localeColumnMap.keys.join(', ');
      throw ConfigException(
        'Locale "$locale" not found in sheet header. Found: $found',
      );
    }
  }

  final localeData = <String, ArbData>{
    for (final l in config.locales) l: ArbData(),
  };

  for (final row in dataRows) {
    final key = row.isNotEmpty ? row[0].trim() : '';
    if (key.isEmpty) continue;

    for (final locale in config.locales) {
      final colIdx = localeColumnMap[locale]!;
      localeData[locale]![key] = colIdx < row.length ? row[colIdx] : '';
    }
  }

  final totalKeys = localeData.values.fold(0, (sum, d) => sum + d.length);
  if (totalKeys == 0) {
    stdout.writeln(
      'Warning: all rows had empty keys — nothing written. '
      'Check that column A of the sheet contains translation keys.',
    );
    return;
  }

  stdout.writeln('Writing ARB files to ${config.arbDir} ...');
  for (final locale in config.locales) {
    final data = localeData[locale]!;
    writeArb(config.arbDir, locale, data);
    stdout.writeln('  app_$locale.arb — ${data.length} keys written');
  }

  stdout.writeln('Done.');
}
