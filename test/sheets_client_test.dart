import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:l10n_this_sheet/src/sheets_client.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fake HTTP client helpers
// ---------------------------------------------------------------------------

/// Builds a [MockClient] that records requests and returns [responses] in order.
/// Each entry is (statusCode, body).
MockClient _mockClient(List<(int, String)> responses) {
  var i = 0;
  return MockClient((request) async {
    final (status, body) = responses[i++];
    return http.Response(body, status,
        headers: {'content-type': 'application/json'});
  });
}

/// Minimal Sheets API response for values.get.
String _valuesGetResponse(List<List<String>> rows) => jsonEncode({
      'range': 'Sheet1',
      'majorDimension': 'ROWS',
      'values': rows,
    });

/// Empty Sheets API response (no values key).
String _valuesGetEmpty() =>
    jsonEncode({'range': 'Sheet1', 'majorDimension': 'ROWS'});

/// Minimal response for values.clear.
String _clearResponse() => jsonEncode({
      'spreadsheetId': 'sid',
      'clearedRange': 'Sheet1!A1:Z1000',
    });

/// Minimal response for values.update.
String _updateResponse() => jsonEncode({
      'spreadsheetId': 'sid',
      'updatedRange': 'Sheet1!A1',
      'updatedRows': 1,
      'updatedColumns': 2,
      'updatedCells': 2,
    });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const spreadsheetId = 'test_sheet_id';
  const sheetName = 'Sheet1';

  group('readSheet', () {
    test('returns parsed rows', () async {
      final client = _mockClient([
        (200, _valuesGetResponse([
          ['Key', 'EN', 'TH'],
          ['appTitle', 'My App', 'แอปของฉัน'],
        ])),
      ]);

      final rows = await readSheet(
        httpClient: client,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
      );

      expect(rows.length, 2);
      expect(rows[0], ['Key', 'EN', 'TH']);
      expect(rows[1], ['appTitle', 'My App', 'แอปของฉัน']);
    });

    test('returns empty list when response has no values', () async {
      final client = _mockClient([(200, _valuesGetEmpty())]);

      final rows = await readSheet(
        httpClient: client,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
      );

      expect(rows, isEmpty);
    });

    test('coerces null cells to empty string', () async {
      // Sheets API can return short rows — missing trailing cells.
      final client = _mockClient([
        (200, _valuesGetResponse([
          ['Key', 'EN', 'TH'],
          ['hello', 'Hello'], // TH cell missing
        ])),
      ]);

      final rows = await readSheet(
        httpClient: client,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
      );

      // Row length will be 2; pull.dart handles short rows separately.
      expect(rows[1], ['hello', 'Hello']);
    });

    test('throws on non-200 response', () async {
      final client = _mockClient([(403, '{"error": {"message": "Forbidden"}}')]);

      expect(
        () => readSheet(
          httpClient: client,
          spreadsheetId: spreadsheetId,
          sheetName: sheetName,
        ),
        throwsA(anything),
      );
    });
  });

  group('writeSheet', () {
    test('issues clear then update requests', () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.method);
        if (request.method == 'POST') {
          return http.Response(_clearResponse(), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(_updateResponse(), 200,
            headers: {'content-type': 'application/json'});
      });

      await writeSheet(
        httpClient: client,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
        values: [
          ['Key', 'EN'],
          ['hello', 'Hello'],
        ],
      );

      // clear = POST, update = PUT
      expect(requests, containsAllInOrder(['POST', 'PUT']));
    });

    test('sends correct range in update request', () async {
      String? capturedUrl;
      final client = MockClient((request) async {
        if (request.method == 'PUT') capturedUrl = request.url.toString();
        final body = request.method == 'POST' ? _clearResponse() : _updateResponse();
        return http.Response(body, 200,
            headers: {'content-type': 'application/json'});
      });

      await writeSheet(
        httpClient: client,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
        values: [['Key', 'EN']],
      );

      expect(capturedUrl, contains('Sheet1%21A1'));
    });

    test('throws on clear failure', () async {
      final client = _mockClient([
        (403, '{"error": {"message": "Forbidden"}}'),
      ]);

      expect(
        () => writeSheet(
          httpClient: client,
          spreadsheetId: spreadsheetId,
          sheetName: sheetName,
          values: [['Key']],
        ),
        throwsA(anything),
      );
    });
  });
}
