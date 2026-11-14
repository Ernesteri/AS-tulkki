import 'dart:convert';

import 'package:http/http.dart' as http;

import 'domain.dart';

class TulkkiApi {
  TulkkiApi({http.Client? client}) : client = client ?? http.Client();
  final http.Client client;
  static Uri baseUrl(String site) {
    final uri = Uri.parse(site.trim());
    if (uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Anna sivuston HTTPS-osoite.');
    }
    var path = uri.path.replaceAll(RegExp(r'/+$'), '');
    if (!path.endsWith('/wp-json/as-tulkki/v1')) {
      path += '/wp-json/as-tulkki/v1';
    }
    return uri.replace(path: '$path/');
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Uri uri, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    try {
      final request = http.Request(method, uri)..followRedirects = false;
      request.headers['Accept'] = 'application/json';
      if (token != null) request.headers['X-AS-Token'] = token;
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 20));
      final bytes = <int>[];
      await for (final chunk in streamed.stream.timeout(
        const Duration(seconds: 20),
      )) {
        bytes.addAll(chunk);
        if (bytes.length > 2 * 1024 * 1024) {
          throw const FormatException('Palvelimen vastaus on liian suuri.');
        }
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Palvelimen vastausta ei tunnistettu.');
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final message = decoded['message'];
        throw StateError(
          message is String
              ? message
              : 'Palvelin hylkäsi pyynnön (${streamed.statusCode}).',
        );
      }
      return decoded;
    } on FormatException {
      rethrow;
    } on StateError {
      rethrow;
    } catch (_) {
      throw StateError(
        'Yhteys sivustoon ei onnistunut. Tallennetut tiedot säilyvät laitteella.',
      );
    }
  }

  Future<RemoteCompetition> join(String site, String code, String name) async {
    final base = baseUrl(site);
    final session = await _request(
      'POST',
      base.resolve('join'),
      body: {'code': code.trim(), 'name': name.trim()},
    );
    final id = session['competitionId'] as int;
    final token = session['token'] as String;
    final data = await _request(
      'GET',
      base.resolve('competitions/$id'),
      token: token,
    );
    if (data['manifest'] == null || data['revision'] == 0) {
      throw StateError('Kilpailutietoja ei ole vielä lähetetty AS2026:sta.');
    }
    return RemoteCompetition(
      site: base.toString(),
      id: id,
      token: token,
      name: data['name'] as String,
      revision: data['revision'] as int,
      manifest: Map<String, dynamic>.from(data['manifest'] as Map),
    );
  }

  Future<void> submit(
    RemoteCompetition competition,
    Map<String, dynamic> body,
  ) async {
    final response = await _request(
      'POST',
      baseUrl(competition.site)
          .resolve('competitions/${competition.id}/interpretations'),
      token: competition.token,
      body: body,
    );
    if (response['eventId'] is! int || response['replayed'] is! bool) {
      throw StateError(
        'Palvelimen tallennuskuittaus puuttuu. Lähetys säilyy jonossa.',
      );
    }
  }

  Future<Map<String, dynamic>> changes(
    RemoteCompetition competition,
    int after,
  ) => _request(
    'GET',
    baseUrl(competition.site)
        .resolve('competitions/${competition.id}/interpretations?after=$after'),
    token: competition.token,
  );

  void close() => client.close();
}
