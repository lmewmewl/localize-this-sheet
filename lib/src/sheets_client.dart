import 'package:googleapis/sheets/v4.dart';
import 'package:http/http.dart' as http;

/// Reads all values from [sheetName] in [spreadsheetId].
/// Returns empty list if sheet has no data.
Future<List<List<String>>> readSheet({
  required http.Client httpClient,
  required String spreadsheetId,
  required String sheetName,
}) async {
  final api = SheetsApi(httpClient);
  final response = await api.spreadsheets.values.get(spreadsheetId, sheetName);
  final values = response.values;
  if (values == null) return [];
  // Sheets API returns List<List<Object?>> — coerce to List<List<String>>.
  return values
      .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
      .toList();
}

/// Clears [sheetName] then writes [values] starting at A1.
Future<void> writeSheet({
  required http.Client httpClient,
  required String spreadsheetId,
  required String sheetName,
  required List<List<String>> values,
}) async {
  final api = SheetsApi(httpClient);

  // Clear first so shrinking data doesn't leave stale rows.
  await api.spreadsheets.values.clear(
    ClearValuesRequest(),
    spreadsheetId,
    sheetName,
  );

  await api.spreadsheets.values.update(
    ValueRange(values: values),
    spreadsheetId,
    '$sheetName!A1',
    valueInputOption: 'RAW',
  );
}
