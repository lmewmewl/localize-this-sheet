import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;

/// Loads .env once. Pass the returned reader to both [getAuthenticatedClient]
/// and [L10nConfig.fromReader] to avoid parsing the file twice.
String? Function(String) loadEnv() {
  final env = DotEnv(includePlatformEnvironment: true)..load(['.env']);
  return (key) => env[key];
}

ClientId _loadClientId(String? Function(String) get) {
  final id = get('GOOGLE_CLIENT_ID');
  final secret = get('GOOGLE_CLIENT_SECRET');

  if (id == null || id.trim().isEmpty) {
    throw AuthException(
      'GOOGLE_CLIENT_ID not set.\n'
      'Add it to .env in your Flutter project root:\n'
      '  GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com',
    );
  }
  if (secret == null || secret.trim().isEmpty) {
    throw AuthException(
      'GOOGLE_CLIENT_SECRET not set.\n'
      'Add it to .env in your Flutter project root:\n'
      '  GOOGLE_CLIENT_SECRET=GOCSPX-...',
    );
  }

  return ClientId(id.trim(), secret.trim());
}

const _scopes = ['https://www.googleapis.com/auth/spreadsheets'];

final _credentialsDir = () {
  final home = Platform.environment['HOME'] ??
      Platform.environment['USERPROFILE'] ??
      '.';
  return Directory('$home/.config/l10n_this_sheet');
}();

final _credentialsFile = File('${_credentialsDir.path}/credentials.json');

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Returns an authenticated HTTP client, re-using saved credentials when
/// possible and launching the browser OAuth flow when needed.
Future<http.Client> getAuthenticatedClient(String? Function(String) get) async {
  final clientId = _loadClientId(get);

  final saved = _loadSavedCredentials();

  if (saved != null) {
    // If access token still valid (with 5-min buffer), use as-is.
    final buffer = const Duration(minutes: 5);
    if (saved.accessToken.expiry.isAfter(DateTime.now().add(buffer))) {
      return authenticatedClient(http.Client(), saved,
          closeUnderlyingClient: true);
    }

    // Attempt silent refresh.
    if (saved.refreshToken != null) {
      final tempClient = http.Client();
      try {
        final refreshed = await refreshCredentials(clientId, saved, tempClient);
        _saveCredentials(refreshed);
        return authenticatedClient(http.Client(), refreshed,
            closeUnderlyingClient: true);
      } catch (_) {
        stderr.writeln('Token refresh failed. Re-authenticating...');
      } finally {
        tempClient.close();
      }
    }
  }

  // Full browser OAuth flow.
  final credentials = await _runBrowserFlow(clientId);
  _saveCredentials(credentials);
  return authenticatedClient(http.Client(), credentials,
      closeUnderlyingClient: true);
}

// ---------------------------------------------------------------------------
// Browser OAuth flow with dynamic loopback port
// ---------------------------------------------------------------------------

Future<AccessCredentials> _runBrowserFlow(ClientId clientId) async {
  final server = await _bindLoopbackServer();
  final redirectUri = 'http://127.0.0.1:${server.port}';

  final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId.identifier,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': _scopes.join(' '),
    'access_type': 'offline',
    'prompt': 'consent',
  });

  stdout.writeln('Opening browser for Google OAuth authorization...');
  _openBrowser(authUrl.toString());
  stdout.writeln('Waiting for authorization on $redirectUri ...');

  final code = await _awaitAuthCode(server);

  // Exchange code for tokens.
  final response = await http.post(
    Uri.parse('https://oauth2.googleapis.com/token'),
    body: {
      'code': code,
      'client_id': clientId.identifier,
      if (clientId.secret != null) 'client_secret': clientId.secret!,
      'redirect_uri': redirectUri,
      'grant_type': 'authorization_code',
    },
  );

  if (response.statusCode != 200) {
    throw AuthException('Token exchange failed (${response.statusCode}): ${response.body}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  return _credentialsFromTokenResponse(json);
}

Future<HttpServer> _bindLoopbackServer() async {
  // Port 0 → OS picks a free port.
  return HttpServer.bind(InternetAddress.loopbackIPv4, 0);
}

Future<String> _awaitAuthCode(HttpServer server) async {
  final completer = Completer<String>();

  final timer = Timer(const Duration(minutes: 5), () {
    if (!completer.isCompleted) {
      completer.completeError(
        AuthException('Authorization timed out after 5 minutes'),
      );
      server.close(force: true);
    }
  });

  server.listen(
    (HttpRequest request) async {
    final code = request.uri.queryParameters['code'];
    final error = request.uri.queryParameters['error'];

    if (error != null) {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.html
        ..write('<h1>Authorization failed</h1><p>You may close this tab.</p>');
      await request.response.close();
      await server.close(force: true);
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(AuthException('OAuth error: $error'));
      }
      return;
    }

    if (code == null || code.isEmpty) {
      request.response
        ..statusCode = 400
        ..headers.contentType = ContentType.html
        ..write('<h1>Missing authorization code</h1><p>You may close this tab.</p>');
      await request.response.close();
      await server.close(force: true);
      timer.cancel();
      if (!completer.isCompleted) {
        completer.completeError(AuthException('OAuth callback missing code parameter'));
      }
      return;
    }

    request.response
      ..statusCode = 200
      ..headers.contentType = ContentType.html
      ..write(
        '<h1>Authorization successful!</h1>'
        '<p>You may close this tab and return to the terminal.</p>',
      );
    await request.response.close();
    await server.close(force: true);
    timer.cancel();
    if (!completer.isCompleted) completer.complete(code);
  },
    onError: (Object err) {
      timer.cancel();
      server.close(force: true);
      if (!completer.isCompleted) {
        completer.completeError(AuthException('OAuth server error: $err'));
      }
    },
    cancelOnError: true,
  );

  return completer.future;
}

void _openBrowser(String url) {
  stdout.writeln('\nIf the browser does not open automatically, visit:\n  $url\n');
  try {
    if (Platform.isMacOS) {
      Process.runSync('open', [url]);
    } else if (Platform.isWindows) {
      Process.runSync('cmd', ['/c', 'start', '', url]);
    } else {
      Process.runSync('xdg-open', [url]);
    }
  } catch (_) {
    // URL already printed above — user can open manually.
  }
}

// ---------------------------------------------------------------------------
// Credential persistence
// ---------------------------------------------------------------------------

AccessCredentials? _loadSavedCredentials() {
  if (!_credentialsFile.existsSync()) return null;

  try {
    final json = jsonDecode(_credentialsFile.readAsStringSync()) as Map<String, dynamic>;
    return _credentialsFromJson(json);
  } catch (_) {
    stderr.writeln(
      'Warning: credentials file at ${_credentialsFile.path} is corrupt and will be removed.',
    );
    try {
      _credentialsFile.deleteSync();
    } catch (_) {}
    return null;
  }
}

void _saveCredentials(AccessCredentials credentials) {
  if (!_credentialsDir.existsSync()) {
    _credentialsDir.createSync(recursive: true);
  }
  _credentialsFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(_credentialsToJson(credentials)),
  );
  // Restrict file permissions on Unix.
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['600', _credentialsFile.path]);
  }
}

// ---------------------------------------------------------------------------
// JSON <-> AccessCredentials
// ---------------------------------------------------------------------------

Map<String, dynamic> _credentialsToJson(AccessCredentials c) => {
      'access_token': c.accessToken.data,
      'expiry': c.accessToken.expiry.toIso8601String(),
      'refresh_token': c.refreshToken,
      'scopes': c.scopes,
    };

AccessCredentials _credentialsFromJson(Map<String, dynamic> j) {
  return AccessCredentials(
    AccessToken(
      'Bearer',
      j['access_token'] as String,
      DateTime.parse(j['expiry'] as String).toUtc(),
    ),
    j['refresh_token'] as String?,
    (j['scopes'] as List<dynamic>).cast<String>(),
  );
}

AccessCredentials _credentialsFromTokenResponse(Map<String, dynamic> json) {
  final rawExpiry = json['expires_in'];
  if (rawExpiry == null) {
    throw AuthException(
      'Token response missing "expires_in" field. '
      'Response keys: ${json.keys.join(', ')}',
    );
  }
  final expiresIn = (rawExpiry as num).toInt();
  final accessToken = json['access_token'];
  if (accessToken == null) {
    throw AuthException('Token response missing "access_token" field.');
  }
  return AccessCredentials(
    AccessToken(
      'Bearer',
      accessToken as String,
      DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
    ),
    json['refresh_token'] as String?,
    _scopes,
  );
}


class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
