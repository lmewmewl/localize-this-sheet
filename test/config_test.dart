import 'package:l10n_this_sheet/src/config.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, String> _valid({
  String spreadsheetId = 'sheet123',
  String sheetName = 'Sheet1',
  String arbDir = './lib/l10n',
  String defaultLocale = 'en',
  String locales = 'en,th',
}) =>
    {
      'L10N_SPREADSHEET_ID': spreadsheetId,
      'L10N_SHEET_NAME': sheetName,
      'L10N_ARB_DIR': arbDir,
      'L10N_DEFAULT_LOCALE': defaultLocale,
      'L10N_LOCALES': locales,
    };

L10nConfig _fromMap(Map<String, String> env) =>
    L10nConfig.fromReader((k) => env[k]);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('L10nConfig.fromReader — valid input', () {
    test('parses all fields correctly', () {
      final cfg = _fromMap(_valid());
      expect(cfg.spreadsheetId, 'sheet123');
      expect(cfg.sheetName, 'Sheet1');
      expect(cfg.arbDir, './lib/l10n');
      expect(cfg.defaultLocale, 'en');
      expect(cfg.locales, ['en', 'th']);
    });

    test('trims whitespace from values', () {
      final cfg = _fromMap(_valid(
        spreadsheetId: '  sheet123  ',
        locales: ' en , th , ja ',
        defaultLocale: ' en ',
      ));
      expect(cfg.spreadsheetId, 'sheet123');
      expect(cfg.locales, ['en', 'th', 'ja']);
      expect(cfg.defaultLocale, 'en');
    });

    test('supports single locale', () {
      final cfg = _fromMap(_valid(locales: 'en', defaultLocale: 'en'));
      expect(cfg.locales, ['en']);
    });

    test('preserves locale order', () {
      final cfg = _fromMap(_valid(locales: 'th,en,ja', defaultLocale: 'th'));
      expect(cfg.locales, ['th', 'en', 'ja']);
    });

    test('filters empty segments from locales', () {
      final cfg = _fromMap(_valid(locales: 'en,,th,', defaultLocale: 'en'));
      expect(cfg.locales, ['en', 'th']);
    });
  });

  group('L10nConfig.fromReader — missing required vars', () {
    for (final key in [
      'L10N_SPREADSHEET_ID',
      'L10N_SHEET_NAME',
      'L10N_ARB_DIR',
      'L10N_DEFAULT_LOCALE',
      'L10N_LOCALES',
    ]) {
      test('throws ConfigException when $key is missing', () {
        final env = _valid()..remove(key);
        expect(
          () => _fromMap(env),
          throwsA(isA<ConfigException>().having(
            (e) => e.message,
            'message',
            contains(key),
          )),
        );
      });

      test('throws ConfigException when $key is empty string', () {
        final env = _valid()..[key] = '';
        expect(() => _fromMap(env), throwsA(isA<ConfigException>()));
      });

      test('throws ConfigException when $key is whitespace only', () {
        final env = _valid()..[key] = '   ';
        expect(() => _fromMap(env), throwsA(isA<ConfigException>()));
      });
    }
  });

  group('L10nConfig.fromReader — validation', () {
    test('throws when default_locale not in locales', () {
      expect(
        () => _fromMap(_valid(defaultLocale: 'fr', locales: 'en,th')),
        throwsA(isA<ConfigException>().having(
          (e) => e.message,
          'message',
          allOf(contains('fr'), contains('en,th')),
        )),
      );
    });

    test('throws when locales resolves to empty after filtering', () {
      expect(
        () => _fromMap(_valid(locales: ' , , ')),
        throwsA(isA<ConfigException>()),
      );
    });
  });

  group('ConfigException', () {
    test('toString returns message', () {
      const e = ConfigException('bad config');
      expect(e.toString(), 'bad config');
    });
  });
}
