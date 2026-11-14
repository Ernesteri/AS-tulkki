import 'dart:convert';

import '../lib/domain.dart';

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main() {
  final c = LocalCompetition()
    ..remote = RemoteCompetition(
      site: 'https://example.fi/',
      id: 1,
      token: 'test',
      name: 'Koe',
      revision: 1,
      manifest: {
        'routes': [
          {
            'id': 'r',
            'sections': [
              {
                'id': 's',
                'name': 'Jakso 1',
                'entries': [
                  {'id': 'a', 'label': '08', 'kind': 'rt'},
                  {'id': 'b', 'label': '08', 'kind': 'rt'},
                  {'id': 'at', 'label': 'AT', 'kind': 'at', 'manualTime': true},
                ],
              },
            ],
          },
        ],
        'pairs': [
          {
            'number': 3,
            'driver': 'A',
            'navigator': 'B',
            'emit': false,
            'routeId': 'r',
          },
        ],
      },
    );
  Map<String, dynamic> page(
    int id, {
    bool missing = true,
    String note = 'Palvelimelta',
  }) => {
    'events': [
      {
        'eventId': id,
        'revision': 1,
        'pairNumber': 3,
        'savedAt': '2026-11-11T12:00:00Z',
        'sections': [
          {
            'id': 's',
            'missingEntryIds': missing ? ['b'] : [],
            'times': {'at': '12:34:56'},
            'note': note,
            'otherErrors': 2,
            'interpreted': true,
          },
        ],
      },
    ],
    'nextCursor': id,
    'hasMore': false,
  };
  check(c.receiveChanges(page(1)), 'Uusi tulkinta');
  check(c.completed(3) == 1, 'Pari tulkattu');
  check(
    c.draft(3, 's').value('b').missing && !c.draft(3, 's').value('a').missing,
    'Samannumeroiset RT erillään',
  );
  check(c.draft(3, 's').value('at').time == '12:34:56', 'Aika');
  check(c.draft(3, 's').otherErrors == 2, 'Muut virheet');
  final restored = LocalCompetition.decode(c.encode());
  check(restored.history.length == 1, 'Historia tallentuu uudelleenavaukseen');
  check(
    restored.remoteCursor == 1 && restored.completed(3) == 1,
    'Uudelleenavaus',
  );
  c.draft(3, 's').setMissing('a', true);
  c.receiveChanges(page(2, missing: false));
  check(
    c.history.length == 2 &&
        (c.history.first['sections'] as List).first['missingEntryIds'].contains(
          'b',
        ),
    'Korvattu tulkinta säilyy historiassa',
  );
  check(c.draft(3, 's').value('a').missing, 'Luonnosta ei ylikirjoiteta');
  c.draft(3, 's').synced = true;
  c.receiveChanges(
    {'events': [], 'nextCursor': 2, 'hasMore': false},
    editing: {'3/s'},
  );
  check(c.draft(3, 's').value('a').missing, 'Auki oleva editori säilyy');
  c.outbox.add({
    'pairNumber': 3,
    'sections': [
      {'id': 's'},
    ],
  });
  c.receiveChanges({'events': [], 'nextCursor': 2, 'hasMore': false});
  check(c.draft(3, 's').value('a').missing, 'Lähetysjono säilyy');
  c.outbox.clear();
  c.receiveChanges({'events': [], 'nextCursor': 2, 'hasMore': false});
  check(
    !c.draft(3, 's').value('a').missing && !c.draft(3, 's').value('b').missing,
    'Odotettu uusi palvelintieto otetaan mukaan',
  );
  final before = c.encode();
  final invalid = page(3);
  (invalid['events'] as List).first['sections'].first['times'] = {
    'at': '99:99:99',
  };
  try {
    c.receiveChanges(invalid);
    throw StateError('Virhe hyväksyttiin');
  } on FormatException {}
  check(
    c.encode() == before,
    'Virheellinen sivu ei muuta dataa tai kohdistinta',
  );
  final m = jsonDecode(jsonEncode(c.remote!.manifest)) as Map<String, dynamic>;
  m['routes'][0]['sections'][0]['entries'][0]['voided'] = true;
  c.draft(3, 's').setMissing('a', true);
  c.draft(3, 's').setMissing('b', true);
  c.outbox.add({
    'pairNumber': 3,
    'revision': 1,
    'sections': [
      {
        'id': 's',
        'missingEntryIds': ['a', 'b'],
        'times': {'at': '12:34:56'},
      },
    ],
  });
  c.receiveChanges(
    {
      'events': [],
      'nextCursor': 2,
      'hasMore': false,
      'revision': 2,
      'manifest': m,
    },
    editing: {'3/s'},
  );
  check(
    c.remote!.revision == 2 &&
        c.sectionsFor(3)[0].entries.every((e) => e.id != 'a'),
    'Mitätöity RT poistuu avoimelta riviltä',
  );
  check(
    !c.draft(3, 's').values.containsKey('a') &&
        c.draft(3, 's').value('b').missing,
    'Paikallinen luonnos säilyy muilta osin',
  );
  check(
    c.outbox[0]['revision'] == 2 &&
        (c.outbox[0]['sections'][0]['missingEntryIds'] as List).single == 'b',
    'Jonossa olevan tulkinnan kohdistus säilyy',
  );
  final stable = c.encode();
  final restore = jsonDecode(jsonEncode(m));
  restore['routes'][0]['sections'][0]['entries'][0]['voided'] = false;
  try {
    c.receiveChanges({
      'events': [],
      'nextCursor': 2,
      'hasMore': false,
      'revision': 3,
      'manifest': restore,
    });
    throw StateError('Mitätöinti peruttiin');
  } on FormatException {}
  check(
    c.encode() == stable,
    'Mitätöintiä ei voi perua eikä ristiriita muuta dataa',
  );
  print(
    'PASS: palvelintulkinta, puuttuvat RT:t, ajat, muut virheet, uudelleenavaus, luonnosten/editorin/jonon suojaus ja virheellisen vastauksen atomisuus',
  );
  final revised =
      jsonDecode(jsonEncode(restored.remote!.manifest)) as Map<String, dynamic>;
  final entries = revised['routes'][0]['sections'][0]['entries'] as List;
  entries.removeWhere((e) => e['id'] == 'a');
  entries.insert(0, {'id': 'new', 'label': '09', 'kind': 'rt'});
  restored.outbox.add({
    'revision': 1,
    'pairNumber': 3,
    'sections': [
      {
        'id': 's',
        'missingEntryIds': ['b'],
        'times': {'at': '12:34:56'},
      },
    ],
  });
  restored.receiveChanges(
    {
      'events': [],
      'nextCursor': 1,
      'hasMore': false,
      'revision': 2,
      'manifest': revised,
    },
    editing: {'3/s'},
  );
  check(
    restored.completed(3) == 1 &&
        restored.draft(3, 's').value('b').missing &&
        !restored.draft(3, 's').value('new').missing,
    'Korjaus säilyttää tulkinnan ja kohdistetun puutteen, uusi kilpi löytyy',
  );
  check(
    restored.draft(3, 's').value('at').time == '12:34:56' &&
        restored.outbox[0]['revision'] == 2,
    'Ajat ja lähetysjono säilyvät korjauksessa',
  );
  final third = jsonDecode(jsonEncode(revised)) as Map<String, dynamic>;
  (third['routes'][0]['sections'][0]['entries'] as List).removeWhere(
    (e) => e['id'] == 'b',
  );
  restored.receiveChanges({
    'events': [],
    'nextCursor': 1,
    'hasMore': false,
    'revision': 3,
    'manifest': third,
  });
  check(
    restored.completed(3) == 1 &&
        !restored.draft(3, 's').values.containsKey('b') &&
        (restored.outbox[0]['sections'][0]['missingEntryIds'] as List).isEmpty,
    'Poistettu kilpi poistuu puutteista ja jonosta ilman uudelleentulkkausta',
  );
  check(
    restored.history[0]['originalLabels']['b'] == '08 (rivi 2)' &&
        (restored.history[0]['originalSections'][0]['missingEntryIds'] as List)
            .contains('b'),
    'Historiassa säilyy alkuperäinen puuttuva kilpi nimineen',
  );
  final stableRevision = restored.encode();
  final wrong = jsonDecode(jsonEncode(third)) as Map<String, dynamic>;
  (wrong['routes'][0]['sections'][0]['entries'] as List).last['label'] = 'AT9';
  try {
    restored.receiveChanges({
      'events': [],
      'nextCursor': 1,
      'hasMore': false,
      'revision': 4,
      'manifest': wrong,
    });
    throw StateError('Asema vaihtui');
  } on FormatException {}
  check(
    restored.encode() == stableRevision,
    'Aika-aseman vaihtoa ei hyväksytä tulkinnan alta',
  );
  print(
    'PASS: korjattu rivi, säilyvä tulkattu-tila, uudet ja poistetut RT:t, ajat, lähetysjono, alkuperäinen historia ja aika-asemien suojaus',
  );
}
