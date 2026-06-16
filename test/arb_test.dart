import 'dart:io';

import 'package:l10n_this_sheet/src/arb.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmpDir;

  setUp(() => tmpDir = Directory.systemTemp.createTempSync('arb_test_'));
  tearDown(() => tmpDir.deleteSync(recursive: true));

  group('readArb', () {
    test('returns empty map when file absent', () {
      final result = readArb(tmpDir.path, 'en');
      expect(result, isEmpty);
    });

    test('reads key-value pairs', () {
      _write(tmpDir, 'app_en.arb', '{"hello": "Hello", "bye": "Goodbye"}');
      final result = readArb(tmpDir.path, 'en');
      expect(result, {'hello': 'Hello', 'bye': 'Goodbye'});
    });

    test('strips @ metadata keys', () {
      _write(tmpDir, 'app_en.arb', '''
{
  "hello": "Hello",
  "@hello": {"description": "greeting"},
  "@@locale": "en"
}''');
      final result = readArb(tmpDir.path, 'en');
      expect(result, {'hello': 'Hello'});
    });

    test('strips non-string values', () {
      _write(tmpDir, 'app_en.arb', '{"key": "val", "count": 42, "flag": true}');
      final result = readArb(tmpDir.path, 'en');
      expect(result, {'key': 'val'});
    });

    test('throws ArbException on invalid JSON', () {
      _write(tmpDir, 'app_en.arb', 'NOT JSON');
      expect(() => readArb(tmpDir.path, 'en'), throwsA(isA<ArbException>()));
    });

    test('returns empty map for empty ARB object', () {
      _write(tmpDir, 'app_en.arb', '{}');
      expect(readArb(tmpDir.path, 'en'), isEmpty);
    });
  });

  group('writeArb', () {
    test('writes pretty-printed JSON with trailing newline', () {
      writeArb(tmpDir.path, 'th', {'a': '1', 'b': '2'});
      final content = File('${tmpDir.path}/app_th.arb').readAsStringSync();
      expect(content, endsWith('\n'));
      expect(content, contains('  "a": "1"'));
      expect(content, contains('  "b": "2"'));
    });

    test('creates arbDir if missing', () {
      final nested = '${tmpDir.path}/lib/l10n';
      writeArb(nested, 'en', {'k': 'v'});
      expect(File('$nested/app_en.arb').existsSync(), isTrue);
    });

    test('overwrites existing file', () {
      writeArb(tmpDir.path, 'en', {'old': 'data'});
      writeArb(tmpDir.path, 'en', {'new': 'data'});
      final result = readArb(tmpDir.path, 'en');
      expect(result, {'new': 'data'});
      expect(result, isNot(contains('old')));
    });

    test('roundtrip: write then read returns same data', () {
      final data = {'title': 'My App', 'greeting': 'Hello, {name}!'};
      writeArb(tmpDir.path, 'en', data);
      expect(readArb(tmpDir.path, 'en'), data);
    });

    test('writes empty map as empty JSON object', () {
      writeArb(tmpDir.path, 'en', {});
      final result = readArb(tmpDir.path, 'en');
      expect(result, isEmpty);
    });
  });
}

void _write(Directory dir, String name, String content) =>
    File('${dir.path}/$name').writeAsStringSync(content);
