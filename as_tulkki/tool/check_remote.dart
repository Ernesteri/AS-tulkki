import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../lib/api.dart';
import '../lib/domain.dart';

int checks = 0;
void check(bool condition, String name) {
  checks++;
  if (!condition) throw StateError(name);
}

Future<void> main() async {
  final manifest = <String, dynamic>{
    'routes': [
      {
        'id': 'r1',
        'name': 'M',
        'sections': [
          {
            'id': 's1',
            'name': 'Jakso 1',
            'entries': [
              {'id': 'a', 'kind': 'rt', 'label': '15'},
              {'id': 'b', 'kind': 'rt', 'label': '15'},
              {'id': 'c', 'kind': 'at', 'label': 'AT', 'manualTime': true},
              {'id': 'd', 'kind': 'jat', 'label': 'JAT', 'manualTime': false},
              {'id': 'v', 'kind': 'rt', 'label': '99', 'voided': true},
            ],
          },
          {
            'id': 's2',
            'name': 'Maali',
            'entries': [
              {'id': 'e', 'kind': 'maali', 'label': 'M', 'manualTime': false},
            ],
          },
        ],
      },
      {
        'id': 'r2',
        'name': 'B',
        'sections': [
          {
            'id': 's3',
            'name': 'B-rata',
            'entries': [
              {'id': 'f', 'kind': 'rt', 'label': '01'},
            ],
          },
        ],
      },
    ],
    'pairs': [
      {
        'number': 101,
        'driver': 'Aino',
        'navigator': 'Eero',
        'emit': true,
        'routeId': 'r1',
      },
      {
        'number': 102,
        'driver': 'Sami',
        'navigator': 'Kaisa',
        'emit': false,
        'routeId': 'r2',
      },
    ],
  };
  final requests = <http.Request>[];
  final api = TulkkiApi(
    client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/join')) {
        check(
          request.headers['X-AS-Token'] == null,
          'Liittymiseen ei lähetetä muuta tunnusta',
        );
        return http.Response(
          jsonEncode({'competitionId': 7, 'token': 'test-session'}),
          201,
        );
      }
      check(
        request.headers['X-AS-Token'] == 'test-session',
        'Istuntotunnus kulkee otsakkeessa',
      );
      if (request.method == 'GET')
        return http.Response(
          jsonEncode({
            'id': 7,
            'name': 'Koekilpailu',
            'revision': 1,
            'manifest': manifest,
          }),
          200,
        );
      return http.Response('{"eventId":4,"replayed":true}', 200);
    }),
  );
  final remote = await api.join(
    'https://example.fi/kerho/',
    ' CODE ',
    ' Tarkistaja ',
  );
  check(remote.sectionsFor(101).length == 2, 'Parin oma rata ja jaksomäärä');
  check(
    remote.sectionsFor(102).single.id == 's3',
    'Toinen rata ei sekoitu ensimmäiseen',
  );
  final entries = remote.sectionsFor(101).first.entries;
  check(entries.length == 4, 'Mitätöityä asemaa ei tarvitse kirjata');
  check(
    entries[0].label == entries[1].label && entries[0].id != entries[1].id,
    'Toistuvat numerot erotellaan',
  );
  check(
    entries[2].requiresTime(true) && !entries[3].requiresTime(false),
    'Asemakohtaiset aikavalinnat',
  );
  final local = LocalCompetition()
    ..remote = remote
    ..reviewer = 'Tarkistaja';
  local.draft(101, 's1').setMissing('b', true);
  local.draft(101, 's1').setTime('c', '12:34:03');
  local.completeSections(remote.pairs.first, remote.sectionsFor(101));
  check(local.completed(101) == 2, 'Koko oikea rata tulkataan');
  final payload = <String, dynamic>{
    'requestId': 'same-request',
    'pairNumber': 101,
    'revision': 1,
    'sections': [],
  };
  local.outbox.add(payload);
  local.archives['demo-v1'] = (LocalCompetition()..reviewer = 'Vanha demo')
      .encode(includeArchives: false);
  final restored = LocalCompetition.decode(local.encode());
  check(restored.remote!.token == 'test-session', 'Istunto säilyy latauksessa');
  check(restored.draft(101, 's1').value('b').missing, 'Luonnos säilyy');
  check(
    restored.outbox.single['requestId'] == 'same-request',
    'Uusintalähetyksen tunniste säilyy',
  );
  check(
    LocalCompetition.decode(restored.archives['demo-v1']!).reviewer ==
        'Vanha demo',
    'Esimerkkikilpailu säilyy erillään',
  );
  await api.submit(remote, payload);
  check(
    requests.last.url.toString() == 'https://example.fi/kerho/wp-json/as-tulkki/v1/competitions/7/interpretations',
    'Alikansion rajapintaosoite',
  );
  check(
    !requests.last.url.toString().contains('test-session'),
    'Tunnus ei ole URL:ssä',
  );
  check(
    jsonDecode(requests.last.body)['requestId'] == 'same-request',
    'Uusintalähetyksen sisältö säilyy',
  );
  for (final site in [
    'http://example.fi',
    'https://u:p@example.fi',
    'https://example.fi/?token=secret',
  ]) {
    try {
      TulkkiApi.baseUrl(site);
      throw StateError('Virheellinen osoite hyväksyttiin');
    } on FormatException {
      checks++;
    }
  }
  final failing = TulkkiApi(
    client: MockClient(
      (_) async => http.Response('{"message":"Istunto vanhentui"}', 401),
    ),
  );
  try {
    await failing.submit(remote, payload);
    throw StateError('Virhe kuitattiin onnistuneeksi');
  } on StateError catch (error) {
    check(error.message == 'Istunto vanhentui', 'Palvelimen virhe näkyy');
  }
  final unacknowledged = TulkkiApi(
    client: MockClient((_) async => http.Response('{}', 200)),
  );
  try {
    await unacknowledged.submit(remote, payload);
    throw StateError('Puuttuva kuittaus hyväksyttiin');
  } on StateError catch (error) {
    check(
      error.message.toString().contains('kuittaus puuttuu'),
      'Tyhjä vastaus ei kuittaa lähetystä',
    );
  }
  api.close();
  failing.close();
  unacknowledged.close();
  print('$checks verkkotietojen tarkistusta läpäisty.');
}
