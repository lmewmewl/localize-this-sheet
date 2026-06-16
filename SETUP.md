# Localize This Sheet — Setup Guide

Sync Flutter `.arb` localization files ↔ Google Sheets with zero backend.

---

## 1. Google Cloud Console — Create OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (or select existing).
3. Enable the **Google Sheets API**: *APIs & Services → Library → Google Sheets API → Enable*.
4. Create credentials: *APIs & Services → Credentials → Create Credentials → OAuth client ID*.
   - Application type: **Desktop app**
   - Name: anything (e.g. `l10n_this_sheet`)
5. Copy the **Client ID** and **Client Secret**.
6. Under *OAuth consent screen*, add your Google account as a **Test user** (if app is in Testing mode).

---

## 2. Configure `.env`

In the **root of your Flutter project**, create `.env`:

```dotenv
# OAuth credentials (from Google Cloud Console)
GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your_secret_here

# Spreadsheet config
L10N_SPREADSHEET_ID=your_spreadsheet_id_here
L10N_SHEET_NAME=Sheet1
L10N_ARB_DIR=./lib/l10n
L10N_DEFAULT_LOCALE=en
L10N_LOCALES=en,th
```

Add `.env` to `.gitignore` — never commit it:

```
# .gitignore
.env
```

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | OAuth Client ID from Google Cloud Console |
| `GOOGLE_CLIENT_SECRET` | OAuth Client Secret |
| `L10N_SPREADSHEET_ID` | ID from the Google Sheets URL |
| `L10N_SHEET_NAME` | Tab name inside the spreadsheet |
| `L10N_ARB_DIR` | Path to your ARB files directory |
| `L10N_DEFAULT_LOCALE` | Primary locale — keys from this file lead row order |
| `L10N_LOCALES` | Comma-separated list; must include `L10N_DEFAULT_LOCALE` |

ARB files must follow the naming convention `app_{locale}.arb` (e.g. `app_en.arb`, `app_th.arb`).

---

## 3. Prepare the Google Sheet

1. Create a Google Sheet (or use an existing one).
2. Copy the **Spreadsheet ID** from the URL:
   `https://docs.google.com/spreadsheets/d/`**`THIS_IS_THE_ID`**`/edit`
3. Set `L10N_SHEET_NAME` to match the tab name (default: `Sheet1`).

---

## 4. Install the Tool

In your Flutter project root:

```bash
dart pub global activate --source path /path/to/l10n_this_sheet
```

Or add as a dev dependency and use `dart run`:

```bash
# From your Flutter project root
dart run l10n_this_sheet:push
dart run l10n_this_sheet:pull
```

---

## 5. First Run — OAuth Authorization

On first run the tool will:
1. Print the authorization URL (in case auto-open fails).
2. Open your default browser to the Google OAuth consent screen.
3. After you grant access, the browser redirects to `http://127.0.0.1:<port>` (a local temporary server).
4. Tokens are saved to `~/.config/l10n_this_sheet/credentials.json` (mode `600`).

Subsequent runs reuse saved tokens and silently refresh when expired — no browser prompt needed.

To force re-authentication, delete the credentials file:

```bash
rm ~/.config/l10n_this_sheet/credentials.json
```

---

## 6. Usage

### Push local ARB → Sheet

```bash
dart run l10n_this_sheet:push
```

Behavior:
- Reads all `app_{locale}.arb` files listed in `locales`.
- Strips metadata keys (`@`-prefixed).
- Builds a 2D matrix: first row is `Key | EN | TH | ...`, subsequent rows are translation entries.
- **Clears** the target sheet range, then writes the matrix. Shrinking data won't leave stale rows.
- Aborts with an error if all ARB files are empty (prevents accidental data loss).

### Pull Sheet → local ARB

```bash
dart run l10n_this_sheet:pull
```

Behavior:
- Reads all rows from the sheet.
- Uses the first row as header; matches column names (case-insensitive) to configured `locales`.
- Writes/overwrites `app_{locale}.arb` for each locale as pretty-printed JSON (2-space indent).
- Skips rows with an empty key cell.

---

## 7. Sheet Format

```
| Key             | EN                  | TH               |
|-----------------|---------------------|------------------|
| appTitle        | My App              | แอปของฉัน         |
| greetingMessage | Hello, {name}!      | สวัสดี, {name}!   |
| logoutButton    | Log Out             | ออกจากระบบ        |
```

Column order doesn't matter — the tool matches by header name. Extra columns are ignored.

---

## 8. Project Structure

```
l10n_this_sheet/
├── bin/
│   ├── push.dart          # dart run l10n_this_sheet:push
│   └── pull.dart          # dart run l10n_this_sheet:pull
├── lib/
│   ├── l10n_this_sheet.dart
│   └── src/
│       ├── auth_helper.dart   # OAuth 2.0 flow + token persistence
│       ├── config.dart        # .env parsing
│       ├── arb.dart           # ARB file read/write
│       └── sheets_client.dart # Google Sheets API wrapper
├── pubspec.yaml
└── SETUP.md
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `GOOGLE_CLIENT_ID not set` | Add `GOOGLE_CLIENT_ID=...` to `.env` in Flutter project root |
| `GOOGLE_CLIENT_SECRET not set` | Add `GOOGLE_CLIENT_SECRET=...` to `.env` |
| `L10N_SPREADSHEET_ID not set` | Add missing var to `.env` |
| `Token refresh failed. Re-authenticating...` | Delete `~/.config/l10n_this_sheet/credentials.json` |
| `Locale "th" not found in sheet header` | Sheet header must contain column named `TH` (case-insensitive) |
| `No keys found in any ARB file` | Check `L10N_ARB_DIR` path; files must be named `app_{locale}.arb` |
| Browser doesn't open | URL is printed to terminal — copy and open manually |
| `L10N_DEFAULT_LOCALE not in L10N_LOCALES` | `L10N_DEFAULT_LOCALE` value must appear in `L10N_LOCALES` list |
