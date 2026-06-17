# Localize This Sheet

Sync Flutter `.arb` localization files with Google Sheets — in both directions — with zero backend, zero servers, and zero team overhead.

**Built for solo developers.** One `.env`, one sheet, one person.

---

## The Rules

This tool enforces a strict single-developer workflow. Breaking these rules will cause data loss.

> **Never run `push` or `pull` without committing first.**
> The sheet is not version-controlled. Your Git history is the only source of truth.

1. **One developer, one sheet.** Concurrent edits from multiple machines will silently overwrite each other. If you need team collaboration, this is the wrong tool.
2. **Commit before every `push`.** Pushing to the sheet is destructive and irreversible. If the push corrupts data, Git is your only rollback.
3. **Commit after every `pull`.** Pulled translations must be committed immediately. An uncommitted pull followed by any other operation will lose the diff.
4. **Never edit both the sheet and local ARB files at the same time.** Divergence has no merge strategy — whichever you push/pull last wins and overwrites the other.
5. **The sheet is a working surface, not a backup.** Your Git repository is the canonical source of truth, always.

---

## How It Works

```
Your .arb files  ──push──▶  Google Sheet  (translators edit here)
Your .arb files  ◀──pull──  Google Sheet
```

`push` — reads all `.arb` files, builds a key/locale matrix, clears the sheet, writes from scratch.  
`pull` — reads the sheet, builds one `.arb` file per locale, overwrites local files.

Both operations are **full overwrites**. There is no merge, no diff, no conflict resolution.

---

## Recommended Git Workflow

```bash
# Before sending sheet to translator
git add lib/l10n/ && git commit -m "l10n: snapshot before push"
dart run l10n_this_sheet:push

# After translator finishes editing the sheet
dart run l10n_this_sheet:pull
git add lib/l10n/ && git commit -m "l10n: pull translations from sheet"
```

If a pull produces garbage or corrupts your ARB files:

```bash
git checkout -- lib/l10n/
```

---

## Setup

### 1. Google Cloud Console

1. Create or select a project at [console.cloud.google.com](https://console.cloud.google.com).
2. Enable **Google Sheets API** → *APIs & Services → Library*.
3. Create credentials → *OAuth client ID* → **Desktop app**.
4. Copy the **Client ID** and **Client Secret**.
5. Add your Google account as a **Test user** under *OAuth consent screen* (required while app is in Testing mode).

### 2. `.env` file

Create `.env` in your Flutter project root:

```dotenv
# OAuth — from Google Cloud Console
GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-your_secret_here

# Sheet
L10N_SPREADSHEET_ID=your_spreadsheet_id_from_url
L10N_SHEET_NAME=Sheet1

# ARB
L10N_ARB_DIR=./lib/l10n
L10N_DEFAULT_LOCALE=en
L10N_LOCALES=en,th
```

Add `.env` to `.gitignore` immediately:

```bash
echo ".env" >> .gitignore
git add .gitignore && git commit -m "chore: ignore .env"
```

| Variable | Description |
|----------|-------------|
| `GOOGLE_CLIENT_ID` | OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | OAuth Client Secret |
| `L10N_SPREADSHEET_ID` | The ID in the sheet URL: `.../spreadsheets/d/`**`THIS_PART`**`/edit` |
| `L10N_SHEET_NAME` | Tab name inside the spreadsheet (default: `Sheet1`) |
| `L10N_ARB_DIR` | Path to your ARB directory |
| `L10N_DEFAULT_LOCALE` | Primary locale — its keys define row order in the sheet |
| `L10N_LOCALES` | Comma-separated list; must include `L10N_DEFAULT_LOCALE` |

### 3. ARB file naming

Files must follow the convention `app_{locale}.arb`:

```
lib/l10n/
├── app_en.arb
└── app_th.arb
```

### 4. Install

```bash
dart pub global activate --source path /path/to/l10n_this_sheet
```

Or use directly from your Flutter project with `dart run`:

```bash
dart run l10n_this_sheet:push
dart run l10n_this_sheet:pull
```

---

## First Run — OAuth

On first run:

1. The tool prints the authorization URL.
2. Your default browser opens the Google OAuth consent screen.
3. After granting access, the browser redirects to a local server (`http://127.0.0.1:<port>`).
4. Tokens are saved to `~/.config/l10n_this_sheet/credentials.json` (Unix permissions: `600`).

Subsequent runs reuse saved tokens and refresh silently when expired.

To force re-authentication:

```bash
rm ~/.config/l10n_this_sheet/credentials.json
```

---

## Sheet Format

The sheet header row is written by `push` and read by `pull`. Column order does not matter — columns are matched by name (case-insensitive).

If a column exists in the sheet but is **not** in `L10N_LOCALES`, `pull` will automatically create an ARB file for it — but only if at least one translation cell in that column is non-empty. The `.env` file is **not** updated automatically. Add the new locale to `L10N_LOCALES` manually so future `push` and `pull` runs include it consistently.

```
| Key             | EN             | TH                |
|-----------------|----------------|-------------------|
| appTitle        | My App         | แอปของฉัน          |
| greeting        | Hello, {name}! | สวัสดี, {name}!    |
| logoutButton    | Log Out        | ออกจากระบบ         |
```

Metadata keys (`@appTitle`, `@@locale`, etc.) are stripped on push and not written on pull.

---

## Commands

```bash
dart run l10n_this_sheet:push   # local ARB → Google Sheet
dart run l10n_this_sheet:pull   # Google Sheet → local ARB
```

### `push` behavior

- Reads `app_{locale}.arb` for each locale in `L10N_LOCALES`.
- Strips `@`-prefixed metadata keys.
- Default locale keys appear first; extra keys from other locales follow in config order.
- Clears the sheet, then writes the full matrix.
- **Aborts** if all ARB files are empty — prevents accidental data loss.

### `pull` behavior

- Reads all rows from the sheet.
- Matches columns to locales by header name (case-insensitive).
- Skips rows with a blank key (column A).
- **Aborts** if all rows have blank keys — prevents silent overwrite with empty data.
- Overwrites `app_{locale}.arb` for each locale in `L10N_LOCALES`.
- **Auto-creates** `app_{locale}.arb` for any sheet column not in `L10N_LOCALES`, if the column has at least one non-empty translation.
- **Does not update `.env`** — add new locales to `L10N_LOCALES` manually after they appear in the sheet.

---

## Troubleshooting

| Error | Fix |
|-------|-----|
| `GOOGLE_CLIENT_ID not set` | Add `GOOGLE_CLIENT_ID=...` to `.env` |
| `GOOGLE_CLIENT_SECRET not set` | Add `GOOGLE_CLIENT_SECRET=...` to `.env` |
| `L10N_SPREADSHEET_ID not set` | Add the missing variable to `.env` |
| `L10N_DEFAULT_LOCALE not in L10N_LOCALES` | The default locale must appear in the locales list |
| `Locale "th" not found in sheet header` | Sheet header must have a column named `TH` (case-insensitive) |
| `No keys found in any ARB file` | Check `L10N_ARB_DIR` path; files must be named `app_{locale}.arb` |
| `Token refresh failed. Re-authenticating...` | Delete `~/.config/l10n_this_sheet/credentials.json` |
| Browser does not open | URL is printed to terminal — copy and open manually |
| Translations lost after pull | Restore from Git: `git checkout -- lib/l10n/` |

---

## Project Structure

```
l10n_this_sheet/
├── bin/
│   ├── push.dart              # dart run l10n_this_sheet:push
│   └── pull.dart              # dart run l10n_this_sheet:pull
├── lib/src/
│   ├── auth_helper.dart       # OAuth 2.0 flow, token cache, .env loader
│   ├── config.dart            # .env parsing, L10nConfig
│   ├── arb.dart               # ARB file read/write
│   └── sheets_client.dart     # Google Sheets API v4 wrapper
├── test/
│   ├── arb_test.dart
│   ├── config_test.dart
│   └── sheets_client_test.dart
└── pubspec.yaml
```

---

## License

MIT
