import 'dart:convert';

import '../lib/domain.dart';

void main() {
  void check(bool ok, String message) {
    if (!ok) throw StateError(message);
  }

  final manifest = <String, dynamic>{
    'routes': [
      {
        'id': 'r',
        'name': 'Koe',
        'sections': [
          {
            'id': 's',
            'name': 'Jakso 1',
            'entries': [
              {
                'id': 'rt',
                'label': '08',
                'kind': 'rt',
                'manualTime': null,
                'voided': false,
              },
              {
                'id': 'jat',
                'label': 'JAT3',
                'kind': 'jat',
                'manualTime': false,
                'voided': false,
              },
            ],
          },
        ],
      },
    ],
    'pairs': [
      {
        'number': 7,
        'driver': 'A',
        'navigator': 'B',
        'routeId': 'r',
        'emit': false,
      },
    ],
  };
  final c = LocalCompetition()
    ..remote = RemoteCompetition(
      site: 'https://example.fi/',
      id: 1,
      token: 'test',
      name: 'Koe',
      revision: 1,
      manifest: manifest,
    );
  Map<String, dynamic> event(int id, int revision, {bool pending = false}) => {
    'eventId': id,
    'pairNumber': 7,
    'revision': revision,
    'reviewer': 'Koe',
    'savedAt': '2026-11-12T12:00:00Z',
    'sections': [
      {
        'id': 's',
        'missingEntryIds': ['rt'],
        'times': <String, String>{},
        'note': 'säilyy',
        'otherErrors': 0,
        'interpreted': true,
        'pendingTimeIds': pending ? ['jat'] : [],
      },
    ],
  };
  c.receiveChanges({
    'events': [event(1, 1)],
    'nextCursor': 1,
    'hasMore': false,
  });
  c.outbox.add({
    'revision': 1,
    'pairNumber': 7,
    'sections': [
      {
        'id': 's',
        'missingEntryIds': ['rt'],
        'times': <String, String>{},
      },
    ],
  });
  final revised = jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
  revised['routes'][0]['sections'][0]['entries'][1]['manualTime'] = true;
  c.receiveChanges(
    {
      'events': [],
      'nextCursor': 1,
      'hasMore': false,
      'revision': 2,
      'manifest': revised,
    },
    editing: {'7/s'},
  );
  check(
    c.completed(7) == 1 && c.pendingTimes(7) == 1,
    'Tulkattu-tila säilyy ja vain uusi aika vaatii täydennyksen',
  );
  check(
    c.draft(7, 's').value('rt').missing &&
        !c.draft(7, 's').value('jat').missing,
    'Vanha puute säilyy eikä JAT ole automaattisesti puuttuva',
  );
  check(
    c.outbox[0]['revision'] == 1,
    'Vanha lähetysjono säilyttää pohjaversion kun uusi JAT-aika puuttuu',
  );
  c.receiveChanges({
    'events': [event(2, 2, pending: true)],
    'nextCursor': 2,
    'hasMore': false,
  });
  check(
    c.pendingTimes(7) == 1 && c.draft(7, 's').note == 'säilyy',
    'Palvelimen täydennystieto ja vanhat kirjaukset säilyvät',
  );
  c.outbox.clear();
  c.draft(7, 's').setTime('jat', '180334');
  c.completeSections(c.pairs.single, c.sectionsFor(7));
  check(
    c.pendingTimes(7) == 0 && c.draft(7, 's').value('jat').time == '18:03:34',
    'JAT voidaan täydentää kuudella numerolla',
  );
  check(
    LocalCompetition.decode(c.encode()).pendingTimes(7) == 0,
    'Täydennetty aika säilyy uudelleenavauksessa',
  );
  print(
    'PASS: JAT käsin syötettäväksi, säilyvä tulkinta ja RT-puute, täydennettävä aika, vanha lähetysjono sekä hhmmss-täydennys ja palautus',
  );
}
