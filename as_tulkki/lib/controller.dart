import 'package:flutter/foundation.dart';

import 'dart:async';
import 'dart:math';

import 'domain.dart';
import 'api.dart';

abstract interface class DraftStore {
  Future<String?> read();
  Future<void> write(String value);
}

class TulkkiController extends ChangeNotifier {
  TulkkiController(this.store, {TulkkiApi? api}) : api = api ?? TulkkiApi();
  final DraftStore store;
  final TulkkiApi api;
  Timer? _retry;
  bool refreshing = false;
  String? refreshError;
  DateTime? lastContact;
  final Set<String> editing = {};
  bool _disposed = false;
  bool sending = false;
  String? syncError;
  bool get onlineCompetition => competition.remote != null;
  LocalCompetition competition = LocalCompetition();
  Future<void> _tail = Future.value();
  int _pending = 0;
  bool get saving => _pending > 0;
  String? saveError;

  Future<void> load() async {
    final saved = await store.read();
    if (saved != null) competition = LocalCompetition.decode(saved);
    _retry ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(synchronize()),
    );
    if (competition.outbox.isNotEmpty) unawaited(sendPending());
    if (onlineCompetition) unawaited(refresh());
  }

  Future<void> synchronize() async {
    await sendPending();
    await refresh();
  }

  Future<void> refresh() async {
    final current = competition;
    final remote = current.remote;
    if (_disposed || refreshing || sending || remote == null) return;
    refreshing = true;
    notifyListeners();
    try {
      var more = true;
      while (more && !_disposed && identical(current, competition)) {
        final before = current.remoteCursor;
        final page = await api.changes(remote, before);
        if (_disposed || !identical(current, competition)) return;
        more = page['hasMore'] as bool;
        if (more && (page['nextCursor'] as int) <= before) {
          throw const FormatException('Tulkintojen nouto ei edennyt');
        }
        if (current.receiveChanges(page, editing: editing)) await persist();
        if (saveError != null) return;
      }
      refreshError = null;
      lastContact = DateTime.now();
    } catch (error) {
      if (!_disposed && identical(current, competition)) {
        refreshError =
            'Tulkintojen päivitys epäonnistui: ${error.toString().replaceFirst(RegExp(r"^(Bad state: |FormatException: )"), "")}';
      }
    } finally {
      refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Jokainen tilannekuva kirjoitetaan järjestyksessä. Vanhempi hidas kirjoitus
  /// ei saa korvata uudempaa. Virhe säilyy näkyvissä onnistuneeseen tallennukseen.
  Future<void> persist() {
    final snapshot = competition.encode();
    _pending++;
    notifyListeners();
    _tail = _tail.then((_) async {
      try {
        await store.write(snapshot);
        saveError = null;
      } catch (_) {
        saveError =
            'Tallennus epäonnistui. Älä sulje sovellusta ennen uutta yritystä.';
      } finally {
        _pending--;
        notifyListeners();
      }
    });
    return _tail;
  }

  Future<void> update(void Function(LocalCompetition competition) change) {
    change(competition);
    return persist();
  }

  Future<void> flush() => _tail;

  Future<void> join(String site, String code, String reviewer) async {
    if (reviewer.trim().isEmpty || code.trim().isEmpty) {
      throw StateError('Anna liittymiskoodi ja tarkastajan nimi.');
    }
    if (sending || refreshing) {
      throw StateError('Odota käynnissä olevan lähetyksen valmistumista.');
    }
    final remote = await api.join(site, code, reviewer);
    final identity = '${remote.site}|${remote.id}';
    final old = competition;
    if (old.outbox.isNotEmpty &&
        (old.identity != identity || old.reviewer != reviewer.trim())) {
      throw StateError(
        'Lähetä jonossa olevat tulkinnat ennen kilpailun tai tarkastajan vaihtamista.',
      );
    }
    final archives = {
      ...old.archives,
      old.identity: old.encode(includeArchives: false),
    };
    final restored = old.identity == identity
        ? old
        : archives.containsKey(identity)
        ? LocalCompetition.decode(archives[identity]!)
        : LocalCompetition();
    if (restored.remote != null &&
        restored.remote!.revision != remote.revision &&
        restored.startedAny) {
      restored.receiveChanges({
        'manifest': remote.manifest,
        'revision': remote.revision,
        'events': [],
        'nextCursor': restored.remoteCursor,
        'hasMore': false,
      });
    }
    restored.remote = remote;
    restored.reviewer = reviewer.trim();
    restored.archives = archives;
    competition = restored;
    syncError = null;
    refreshError = null;
    await persist();
    if (saveError != null) throw StateError(saveError!);
    unawaited(sendPending());
    await refresh();
  }

  Future<void> openDemo(String name) async {
    if (competition.outbox.isNotEmpty || sending) {
      throw StateError('Lähetä jonossa olevat tulkinnat ensin.');
    }
    final old = competition;
    final archives = {
      ...old.archives,
      old.identity: old.encode(includeArchives: false),
    };
    competition = old.remote == null
        ? old
        : archives.containsKey('demo-v1')
        ? LocalCompetition.decode(archives['demo-v1']!)
        : LocalCompetition();
    competition.archives = archives;
    competition.reviewer = name.trim();
    syncError = null;
    refreshError = null;
    await persist();
  }

  Future<void> complete(
    CompetitionPair pair,
    List<RouteSection> sections,
  ) async {
    competition.completeSections(pair, sections);
    final remote = competition.remote;
    if (remote != null) {
      final random = Random.secure();
      final requestId =
          'app-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      final payload = <String, dynamic>{
        'requestId': requestId,
        'revision': remote.revision,
        'pairNumber': pair.number,
        'sections': sections.map((section) {
          final draft = competition.draft(pair.number, section.id);
          draft.submissionId = requestId;
          draft.synced = false;
          return {
            'id': section.id,
            'missingEntryIds': section.entries
                .where((e) => draft.value(e.id).missing)
                .map((e) => e.id)
                .toList(),
            'times': {
              for (final entry in section.entries)
                if (entry.requiresTime(pair.emit) &&
                    !draft.value(entry.id).missing)
                  entry.id: draft.value(entry.id).time,
            },
            'note': draft.note,
            'otherErrors': draft.otherErrors,
            'otherPenaltyPoints': ?draft.otherPenaltyPoints,
          };
        }).toList(),
      };
      competition.outbox.add(payload);
    }
    // Koko lähetys tallennetaan ennen verkkoon lähettämistä.
    await persist();
    if (saveError == null) await sendPending();
  }

  Future<void> sendPending() async {
    final remote = competition.remote;
    if (sending || remote == null || competition.outbox.isEmpty) return;
    sending = true;
    notifyListeners();
    try {
      // Myös aiempi epäonnistunut paikallinen kirjoitus on saatava talteen ensin.
      await persist();
      if (saveError != null) return;
      while (competition.outbox.isNotEmpty) {
        final payload = competition.outbox.first;
        await api.submit(remote, payload);
        lastContact = DateTime.now();
        competition.outbox.removeAt(0);
        for (final section in payload['sections'] as List) {
          final draft = competition.draft(
            payload['pairNumber'] as int,
            section['id'] as String,
          );
          if (draft.submissionId == payload['requestId']) draft.synced = true;
        }
        syncError = null;
        await persist();
        if (saveError != null) break;
      }
    } catch (error) {
      syncError = error.toString().replaceFirst(
        RegExp(r'^(Bad state: |FormatException: )'),
        '',
      );
    } finally {
      sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    api.close();
    super.dispose();
  }
}
