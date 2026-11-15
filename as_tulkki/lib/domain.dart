import 'dart:convert';

enum EntryKind { rt, mrt, leima, jrt, at, jat, ula, maali }

class RouteEntry {
  const RouteEntry(this.id, this.label, this.kind, {this.manualTime});
  final String id;
  final String label;
  final EntryKind kind;

  /// AS2026:n asemakohtainen valinta; null käyttää ajanottotavan oletusta.
  final bool? manualTime;
  bool get isClock => const {
    EntryKind.at,
    EntryKind.jat,
    EntryKind.ula,
    EntryKind.maali,
  }.contains(kind);
  bool requiresTime(bool emit) =>
      isClock &&
      (manualTime ?? (kind == EntryKind.at || kind == EntryKind.jat || !emit));
}

class RouteSection {
  const RouteSection(this.id, this.name, this.entries);
  final String id;
  final String name;
  final List<RouteEntry> entries;
}

class CompetitionPair {
  const CompetitionPair(
    this.number,
    this.driver,
    this.navigator,
    this.emit, {
    this.routeId = 'demo',
    this.className = '',
  });
  final int number;
  final String driver;
  final String navigator;
  final bool emit;
  final String routeId;
  final String className;
}

const demoPairs = [
  CompetitionPair(101, 'Aino Malli', 'Eero Esimerkki', true),
  CompetitionPair(102, 'Sami Esimerkki', 'Kaisa Malli', false),
  CompetitionPair(103, 'Olli Malli', 'Iida Esimerkki', true),
  CompetitionPair(104, 'Laura Esimerkki', 'Matti Malli', false),
  CompetitionPair(105, 'Tuuli Malli', 'Antti Esimerkki', true),
  CompetitionPair(106, 'Jari Esimerkki', 'Salla Malli', false),
];

const demoSections = [
  RouteSection('j1', 'Jakso 1', [
    RouteEntry('j1-1', 'MRT', EntryKind.mrt),
    RouteEntry('j1-2', '08', EntryKind.rt),
    RouteEntry('j1-3', '25', EntryKind.rt),
    RouteEntry('j1-4', '25', EntryKind.rt),
    RouteEntry('j1-5', 'AT', EntryKind.at, manualTime: true),
    RouteEntry('j1-6', 'JAT', EntryKind.jat, manualTime: false),
    RouteEntry('j1-7', 'ULA', EntryKind.ula),
  ]),
  RouteSection('j2', 'Jakso 2', [
    RouteEntry('j2-1', '00', EntryKind.rt),
    RouteEntry('j2-2', 'L', EntryKind.leima),
    RouteEntry('j2-3', '13', EntryKind.rt),
    RouteEntry('j2-4', 'JRT', EntryKind.jrt),
    RouteEntry('j2-5', 'JAT', EntryKind.jat),
    RouteEntry('j2-6', 'ULA', EntryKind.ula),
  ]),
  RouteSection('j3', 'Jakso 3 · Maali', [
    RouteEntry('j3-1', '05', EntryKind.rt),
    RouteEntry('j3-2', '37', EntryKind.rt),
    RouteEntry('j3-3', '99', EntryKind.rt),
    RouteEntry('j3-4', 'M', EntryKind.maali),
  ]),
];

bool validClock(String text) {
  if (!RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(text)) return false;
  final parts = text.split(':').map(int.parse).toList();
  return parts[0] < 24 && parts[1] < 60 && parts[2] < 60;
}

String normalizeClockInput(String text, {bool ula = false}) {
  if (ula && RegExp(r'^\d{4}$').hasMatch(text)) {
    text = '${text.substring(0, 2)}:${text.substring(2)}';
  }
  if (ula && RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
    final formatted = '$text:00';
    return validClock(formatted) ? formatted : text;
  }
  if (!RegExp(r'^\d{6}$').hasMatch(text)) return text;
  final formatted =
      '${text.substring(0, 2)}:${text.substring(2, 4)}:${text.substring(4, 6)}';
  return validClock(formatted) ? formatted : text;
}

class EntryValue {
  EntryValue({this.missing = false, this.time = ''});
  bool missing;
  String time;
  Map<String, Object> toJson() => {'missing': missing, 'time': time};
  factory EntryValue.fromJson(Map<String, dynamic> json) => EntryValue(
    missing: json['missing'] as bool,
    time: normalizeClockInput(json['time'] as String),
  );
}

class SectionDraft {
  final Map<String, EntryValue> values = {};
  String note = '';
  int otherErrors = 0;
  int? otherPenaltyPoints;
  static const maxOtherPenaltyPoints = 6000000;
  int get displayedPenaltyPoints => otherPenaltyPoints ?? otherErrors * 600;
  void adjustOtherPenaltyPoints(int change) {
    otherPenaltyPoints = (displayedPenaltyPoints + change).clamp(
      0,
      maxOtherPenaltyPoints,
    );
    otherErrors = 0;
  }

  bool get validOtherErrors {
    final points = otherPenaltyPoints;
    return otherErrors >= 0 &&
        otherErrors <= 10000 &&
        (points == null ||
            (otherErrors == 0 &&
                points >= 0 &&
                points <= maxOtherPenaltyPoints &&
                points % 100 == 0));
  }

  bool interpreted = false;
  String? completedAt;
  String? submissionId;
  bool synced = false;
  bool get started =>
      values.isNotEmpty ||
      note.isNotEmpty ||
      otherErrors != 0 ||
      otherPenaltyPoints != null ||
      interpreted;
  EntryValue value(String id) => values[id] ?? EntryValue();
  void changed() {
    interpreted = false;
    completedAt = null;
    synced = false;
    submissionId = null;
  }

  void setMissing(String id, bool missing) {
    final entry = values.putIfAbsent(id, EntryValue.new);
    entry.missing = missing;
    if (missing) entry.time = '';
    changed();
  }

  void setTime(String id, String time, {bool ula = false}) {
    final entry = values.putIfAbsent(id, EntryValue.new);
    entry.time = normalizeClockInput(time, ula: ula);
    entry.missing = false;
    changed();
  }

  List<RouteEntry> incomplete(RouteSection section, bool emit) =>
      section.entries.where((entry) {
        final recorded = value(entry.id);
        return entry.requiresTime(emit) &&
            !recorded.missing &&
            !validClock(recorded.time);
      }).toList();
  int missingSigns(RouteSection section) =>
      section.entries.where((e) => !e.isClock && value(e.id).missing).length;
  int missingTimes(RouteSection section) =>
      section.entries.where((e) => e.isClock && value(e.id).missing).length;
  void complete(RouteSection section, bool emit) {
    if (incomplete(section, emit).isNotEmpty) {
      throw StateError('Täydennä ajat tai merkitse ne puuttuviksi.');
    }
    interpreted = true;
    completedAt = DateTime.now().toUtc().toIso8601String();
  }

  Map<String, Object?> toJson() => {
    'values': values.map((id, value) => MapEntry(id, value.toJson())),
    'note': note,
    'otherErrors': otherErrors,
    'otherPenaltyPoints': ?otherPenaltyPoints,
    'interpreted': interpreted,
    'completedAt': completedAt,
    'submissionId': submissionId,
    'synced': synced,
  };
  factory SectionDraft.fromJson(Map<String, dynamic> json) {
    final draft = SectionDraft()
      ..note = json['note'] as String
      ..otherErrors = json['otherErrors'] as int
      ..otherPenaltyPoints = json['otherPenaltyPoints'] as int?
      ..interpreted = json['interpreted'] as bool
      ..completedAt = json['completedAt'] as String?;
    draft.submissionId = json['submissionId'] as String?;
    draft.synced = json['synced'] as bool? ?? false;
    if (!draft.validOtherErrors) {
      throw const FormatException('Virheellinen virhemäärä');
    }
    (json['values'] as Map<String, dynamic>).forEach((id, value) {
      draft.values[id] = EntryValue.fromJson(value as Map<String, dynamic>);
    });
    return draft;
  }
  SectionDraft();
}

bool compatibleRowChange(
  Map<String, dynamic> old,
  Map<String, dynamic> incoming,
) {
  try {
    final expected = jsonDecode(jsonEncode(old)) as Map<String, dynamic>;
    for (var i = 0; i < (expected['pairs'] as List).length; i++) {
      final name = incoming['pairs'][i]['className'];
      if (name != null) expected['pairs'][i]['className'] = name;
    }
    bool clock(dynamic e) => ['at', 'jat', 'ula', 'maali'].contains(e['kind']);
    for (var ri = 0; ri < (expected['routes'] as List).length; ri++) {
      final route = expected['routes'][ri];
      for (var si = 0; si < (route['sections'] as List).length; si++) {
        final section = route['sections'][si];
        final before = section['entries'] as List;
        final after = incoming['routes'][ri]['sections'][si]['entries'] as List;
        final oldClocks = before.where(clock).toList();
        final clockIds = oldClocks.map((e) => e['id']).toSet();
        final retained = after
            .where(clock)
            .where((e) => e['kind'] != 'ula' || clockIds.contains(e['id']))
            .toList();
        if (jsonEncode(oldClocks) != jsonEncode(retained)) return false;
        for (var i = 0; i < after.length; i++) {
          if (after[i]['kind'] == 'ula' &&
              !clockIds.contains(after[i]['id']) &&
              (i == 0 ||
                  after[i - 1]['kind'] != 'jat' ||
                  (i + 1 < after.length && after[i + 1]['kind'] == 'ula')))
            return false;
        }
        for (final e in before) {
          final n = after.where((n) => n['id'] == e['id']).firstOrNull;
          if (e['voided'] == true && (n == null || n['voided'] != true))
            return false;
          if (n != null && (e['kind'] != n['kind'] || e['label'] != n['label']))
            return false;
        }
        section['entries'] = after;
      }
    }
    return jsonEncode(expected) == jsonEncode(incoming);
  } catch (_) {
    return false;
  }
}

class LocalCompetition {
  int remoteCursor = 0;
  final List<Map<String, dynamic>> history = [];
  final Map<String, Map<String, dynamic>> remoteSections = {};

  /// Palvelimen viimeisin jakso säilyy erillään paikallisesta luonnoksesta.
  bool receiveChanges(
    Map<String, dynamic> page, {
    Set<String> editing = const {},
  }) {
    final next = LocalCompetition.decode(encode(includeArchives: false));
    final changed = next._receiveChanges(page, editing: editing);
    if (changed) {
      remote = next.remote;
      remoteCursor = next.remoteCursor;
      history
        ..clear()
        ..addAll(next.history);
      remoteSections
        ..clear()
        ..addAll(next.remoteSections);
      drafts
        ..clear()
        ..addAll(next.drafts);
      outbox = next.outbox;
    }
    return changed;
  }

  bool _receiveChanges(
    Map<String, dynamic> page, {
    Set<String> editing = const {},
  }) {
    var manifestChanged = false;
    if (page['manifest'] is Map &&
        page['revision'] is int &&
        (page['revision'] != remote!.revision ||
            jsonEncode(page['manifest']) != jsonEncode(remote!.manifest))) {
      final incoming = Map<String, dynamic>.from(page['manifest'] as Map);
      final activeById = <String, dynamic>{
        for (final r in incoming['routes'] as List)
          for (final s in r['sections'] as List)
            for (final e in s['entries'] as List) e['id'] as String: e,
      };
      for (final r in remote!.manifest['routes'] as List) {
        for (final s in r['sections'] as List) {
          for (final e in s['entries'] as List) {
            if (e['voided'] == true && activeById[e['id']]?['voided'] != true)
              throw const FormatException('Mitätöintiä ei voi perua');
          }
        }
      }
      final compatible = compatibleRowChange(remote!.manifest, incoming);
      if ((!compatible &&
              (startedAny || outbox.isNotEmpty || editing.isNotEmpty)) ||
          (page['revision'] as int) < remote!.revision) {
        throw const FormatException(
          'Rata tai kilpailuparit ovat muuttuneet. Liity kilpailuun uudelleen.',
        );
      }
      final labels = <String, String>{};
      for (final r in remote!.manifest['routes'] as List) {
        for (final s in r['sections'] as List) {
          for (final (i, e) in (s['entries'] as List).indexed) {
            labels[e['id'] as String] = '${e['label']} (rivi ${i + 1})';
          }
        }
      }
      for (final event in history) {
        event['originalSections'] ??= jsonDecode(jsonEncode(event['sections']));
        event['originalLabels'] ??= <String, String>{
          for (final s in event['originalSections'] as List)
            for (final id in [
              ...s['missingEntryIds'] as List,
              ...s['times'] is Map ? (s['times'] as Map).keys : <String>[],
            ])
              if (labels.containsKey(id)) id as String: labels[id]!,
        };
      }
      final old = remote!;
      if (!compatible) {
        drafts.clear();
        remoteSections.clear();
      }
      remote = RemoteCompetition(
        site: old.site,
        id: old.id,
        token: old.token,
        name: old.name,
        revision: page['revision'] as int,
        manifest: incoming,
      );
      Set<String> activeFor(String key) {
        final pair = int.parse(key.split('/').first);
        final section = key.substring(key.indexOf('/') + 1);
        return sectionsFor(pair)
            .firstWhere((s) => s.id == section)
            .entries
            .map((e) => e.id)
            .toSet();
      }

      for (final entry in drafts.entries) {
        final active = activeFor(entry.key);
        entry.value.values.removeWhere((id, _) => !active.contains(id));
      }
      for (final entry in remoteSections.entries) {
        final active = activeFor(entry.key);
        (entry.value['values'] as Map).removeWhere(
          (id, _) => !active.contains(id),
        );
      }
      for (final payload in outbox) {
        var pendingClock = false;
        for (final section in payload['sections'] as List) {
          final active = activeFor(
            key(payload['pairNumber'] as int, section['id'] as String),
          );
          (section['missingEntryIds'] as List).removeWhere(
            (id) => !active.contains(id),
          );
          (section['times'] as Map).removeWhere(
            (id, _) => !active.contains(id),
          );
          final pair = pairs.firstWhere(
            (p) => p.number == payload['pairNumber'],
          );
          final definition = sectionsFor(pair.number)
              .firstWhere((s) => s.id == section['id']);
          pendingClock |= definition.entries.any(
            (e) =>
                e.requiresTime(pair.emit) &&
                !(section['missingEntryIds'] as List).contains(e.id) &&
                !(section['times'] as Map).containsKey(e.id),
          );
        }
        if (!pendingClock) payload['revision'] = remote!.revision;
      }
      manifestChanged = true;
    }
    final next = page['nextCursor'] as int;
    if (next < remoteCursor)
      throw const FormatException('Virheellinen tulkintojen kohdistin');
    final updates = <String, Map<String, dynamic>>{};
    var previous = remoteCursor;
    for (final raw in page['events'] as List) {
      final event = Map<String, dynamic>.from(raw as Map);
      final id = event['eventId'] as int;
      if (id <= previous || id > next)
        throw const FormatException('Virheellinen tulkintojen järjestys');
      previous = id;
      history.add(event);
      if (event['revision'] != remote!.revision)
        throw const FormatException(
          'Kilpailun oikea rivi on muuttunut. Liity kilpailuun uudelleen.',
        );
      final pair = pairs.firstWhere((p) => p.number == event['pairNumber']);
      for (final rawSection in event['sections'] as List) {
        final data = Map<String, dynamic>.from(rawSection as Map);
        final section = sectionsFor(pair.number)
            .firstWhere((s) => s.id == data['id']);
        final missing = (data['missingEntryIds'] as List)
            .cast<String>()
            .toSet();
        final times = Map<String, dynamic>.from(data['times'] as Map);
        final known = section.entries.map((e) => e.id).toSet();
        if (!known.containsAll(missing) ||
            !known.containsAll(times.keys) ||
            times.values.any((v) => v is! String || !validClock(v)) ||
            missing.any(times.containsKey) ||
            data['interpreted'] != true ||
            (data['otherErrors'] as int) < 0) {
          throw const FormatException('Palvelimen tulkintaa ei tunnistettu');
        }
        final draft = SectionDraft()
          ..note = data['note'] as String
          ..otherErrors = data['otherErrors'] as int
          ..otherPenaltyPoints = data['otherPenaltyPoints'] as int?
          ..interpreted = true
          ..synced = true
          ..completedAt = event['savedAt'] as String;
        if (!draft.validOtherErrors) {
          throw const FormatException(
            'Palvelimen virhepisteitä ei tunnistettu',
          );
        }
        for (final entry in section.entries) {
          if (missing.contains(entry.id) || times.containsKey(entry.id)) {
            draft.values[entry.id] = EntryValue(
              missing: missing.contains(entry.id),
              time: times[entry.id] as String? ?? '',
            );
          }
        }
        final pending = (data['pendingTimeIds'] as List? ?? [])
            .cast<String>()
            .toSet();
        final incomplete = draft
            .incomplete(section, pair.emit)
            .map((e) => e.id)
            .toSet();
        if (pending.length != incomplete.length ||
            !pending.containsAll(incomplete) ||
            pending.any(
              (id) => !section.entries.any(
                (e) => e.id == id && e.kind == EntryKind.ula,
              ),
            ))
          throw const FormatException('Palvelimen tulkinnan ajat puuttuvat');
        updates[key(pair.number, section.id)] = draft
            .toJson()
            .cast<String, dynamic>();
      }
    }
    var changed = manifestChanged || next != remoteCursor;
    remoteSections.addAll(updates);
    remoteCursor = next;
    final pending = <String>{
      for (final payload in outbox)
        for (final section in payload['sections'] as List)
          key(payload['pairNumber'] as int, section['id'] as String),
    };
    for (final entry in remoteSections.entries) {
      final local = drafts[entry.key];
      if (editing.contains(entry.key) ||
          pending.contains(entry.key) ||
          (local != null && local.started && !local.synced))
        continue;
      if (jsonEncode(local?.toJson()) != jsonEncode(entry.value)) {
        drafts[entry.key] = SectionDraft.fromJson(entry.value);
        changed = true;
      }
    }
    return changed;
  }

  String reviewer = '';
  RemoteCompetition? remote;
  List<Map<String, dynamic>> outbox = [];
  Map<String, String> archives = {};
  List<CompetitionPair> get pairs => remote?.pairs ?? demoPairs;
  List<RouteSection> sectionsFor(int pair) =>
      remote?.sectionsFor(pair) ?? demoSections;
  String get identity =>
      remote == null ? 'demo-v1' : '${remote!.site}|${remote!.id}';
  bool get startedAny => drafts.values.any((d) => d.started);
  final Map<String, SectionDraft> drafts = {};
  String key(int pair, String section) => '$pair/$section';
  SectionDraft draft(int pair, String section) =>
      drafts.putIfAbsent(key(pair, section), SectionDraft.new);
  int completed(int pair) =>
      sectionsFor(pair)
          .where((s) => drafts[key(pair, s.id)]?.interpreted ?? false)
          .length;
  int pendingTimes(int pair) {
    final emit = pairs.firstWhere((p) => p.number == pair).emit;
    return sectionsFor(pair)
        .where((s) => drafts[key(pair, s.id)]?.interpreted ?? false)
        .fold(0, (n, s) => n + draft(pair, s.id).incomplete(s, emit).length);
  }

  bool started(int pair) =>
      sectionsFor(pair).any((s) => drafts[key(pair, s.id)]?.started ?? false);
  void completeSections(CompetitionPair pair, List<RouteSection> sections) {
    // Tarkista kaikki ennen tilojen muuttamista: keskeneräinen jakso ei saa
    // aiheuttaa koko kilpailun osittaista vahvistusta.
    if (sections.any(
      (s) => draft(pair.number, s.id).incomplete(s, pair.emit).isNotEmpty,
    )) {
      throw StateError('Täydennä ajat tai merkitse ne puuttuviksi.');
    }
    for (final section in sections) {
      draft(pair.number, section.id).complete(section, pair.emit);
    }
  }

  String encode({bool includeArchives = true}) => jsonEncode({
    'schema': 2,
    'remoteCursor': remoteCursor,
    'history': history,
    'remoteSections': remoteSections,
    'competition': identity,
    'remote': remote?.toJson(),
    'outbox': outbox,
    'archives': includeArchives ? archives : <String, String>{},
    'reviewer': reviewer,
    'drafts': drafts.map((key, value) => MapEntry(key, value.toJson())),
  });
  static LocalCompetition decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if ((json['schema'] != 1 && json['schema'] != 2) ||
        (json['schema'] == 1 && json['competition'] != 'demo-v1')) {
      throw const FormatException('Tallennuksen versiota ei tunnisteta');
    }
    final competition = LocalCompetition()
      ..reviewer = json['reviewer'] as String;
    competition.remoteCursor = json['remoteCursor'] as int? ?? 0;
    competition.history.addAll(
      (json['history'] as List? ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    (json['remoteSections'] as Map? ?? {}).forEach((key, value) {
      competition.remoteSections[key as String] = Map<String, dynamic>.from(
        value as Map,
      );
    });
    if (json['remote'] != null) {
      competition.remote = RemoteCompetition.fromJson(
        json['remote'] as Map<String, dynamic>,
      );
    }
    competition.outbox = (json['outbox'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    competition.archives = Map<String, String>.from(
      json['archives'] as Map? ?? {},
    );
    (json['drafts'] as Map<String, dynamic>).forEach((key, value) {
      if (!competition.pairs.any(
        (p) => competition
            .sectionsFor(p.number)
            .any((s) => key == competition.key(p.number, s.id)),
      )) {
        throw const FormatException('Tuntematon kilpailupari tai jakso');
      }
      competition.drafts[key] = SectionDraft.fromJson(
        value as Map<String, dynamic>,
      );
    });
    return competition;
  }
}

class RemoteCompetition {
  RemoteCompetition({
    required this.site,
    required this.id,
    required this.token,
    required this.name,
    required this.revision,
    required this.manifest,
  }) {
    final routeIds = <String>{};
    final entryIds = <String>{};
    for (final route in manifest['routes'] as List) {
      final rid = route['id'] as String;
      if (!routeIds.add(rid)) throw const FormatException('Rata toistuu');
      final sectionIds = <String>{};
      final sections = <RouteSection>[];
      for (final section in route['sections'] as List) {
        final sid = section['id'] as String;
        if (!sectionIds.add(sid)) throw const FormatException('Jakso toistuu');
        final entries = <RouteEntry>[];
        for (final entry in section['entries'] as List) {
          final eid = entry['id'] as String;
          if (!entryIds.add(eid)) {
            throw const FormatException('Asematunniste toistuu');
          }
          final kind = EntryKind.values.byName(entry['kind'] as String);
          if (entry['voided'] == true) continue;
          entries.add(
            RouteEntry(
              eid,
              entry['label'] as String,
              kind,
              manualTime: entry['manualTime'] as bool?,
            ),
          );
        }
        sections.add(RouteSection(sid, section['name'] as String, entries));
      }
      if (sections.isEmpty) {
        throw const FormatException('Radalla ei ole jaksoja');
      }
      _routes[rid] = sections;
    }
    final numbers = <int>{};
    for (final pair in manifest['pairs'] as List) {
      final number = pair['number'] as int;
      final rid = pair['routeId'] as String;
      if (!numbers.add(number) || !_routes.containsKey(rid)) {
        throw const FormatException('Kilpailuparin tiedot ovat virheelliset');
      }
      pairs.add(
        CompetitionPair(
          number,
          pair['driver'] as String,
          pair['navigator'] as String,
          pair['emit'] as bool,
          routeId: rid,
          className: pair['className'] as String? ?? '',
        ),
      );
    }
    if (pairs.isEmpty || revision < 1 || id < 1 || token.isEmpty) {
      throw const FormatException('Kilpailutiedot puuttuvat');
    }
  }
  final String site, token, name;
  final int id, revision;
  final Map<String, dynamic> manifest;
  final List<CompetitionPair> pairs = [];
  final Map<String, List<RouteSection>> _routes = {};
  List<RouteSection> sectionsFor(int number) =>
      _routes[pairs.firstWhere((p) => p.number == number).routeId]!;
  Map<String, Object> toJson() => {
    'site': site,
    'id': id,
    'token': token,
    'name': name,
    'revision': revision,
    'manifest': manifest,
  };
  factory RemoteCompetition.fromJson(Map<String, dynamic> json) =>
      RemoteCompetition(
        site: json['site'] as String,
        id: json['id'] as int,
        token: json['token'] as String,
        name: json['name'] as String,
        revision: json['revision'] as int,
        manifest: Map<String, dynamic>.from(json['manifest'] as Map),
      );
}
