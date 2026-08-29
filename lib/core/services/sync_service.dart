import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

/// Thrown by SyncService methods when there is no signed-in user to
/// sync for -- previously uploadAll()/downloadAll() just silently
/// returned in that case, which the UI (account_screen._sync())
/// misread as "sync completed successfully" and showed a false
/// success message even though nothing was actually synced.
class NotSignedInException implements Exception {
  @override
  String toString() => 'Not signed in';
}

/// Collects any per-section failures that happened during an otherwise
/// "successful" upload/download so the UI can show a partial-failure
/// warning instead of silently claiming complete success.
class PartialSyncException implements Exception {
  final List<String> failedSections;
  PartialSyncException(this.failedSections);
  @override
  String toString() => 'Sync completed with errors in: ${failedSections.join(", ")}';
}

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _syncing = false;
  DateTime? _lastSyncAt;
  bool get isSyncing => _syncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  // Firestore document paths need an EVEN number of segments --
  // 'users/{uid}/settings' (3 segments) is invalid and throws
  // immediately. 'users/{uid}/data/settings' (4 segments) is correct.
  DocumentReference<Map<String, dynamic>> _doc(String path) => _db.doc('users/$_uid/data/$path');

  /// Converts a Firestore numeric field to an int, tolerating both
  /// int and double representations (Firestore/JS interop can return
  /// either depending on how a value was originally written) -- a bare
  /// `as int` cast would crash on a double and, before this fix, that
  /// crash silently aborted every remaining section of downloadAll(),
  /// which is exactly why some devices ended up with partially-restored
  /// data (e.g. tasbeeh synced but favorites/bookmarks/khatma did not).
  static int _asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  /// ROOT CAUSE FIX: uploadAll()/downloadAll() used to be single try/catch
  /// blocks around ALL sections -- one bad field in one section (a type
  /// cast error, a malformed document, etc.) threw and aborted every
  /// section after it with ZERO indication to the user of what actually
  /// made it through. This runs each named section in total isolation:
  /// a failure is logged and collected, but every other section still
  /// runs. The caller finds out via [PartialSyncException] if anything
  /// failed, instead of a full sync silently only doing part of the job.
  Future<void> _runIsolated(String name, Future<void> Function() body, List<String> failures) async {
    try {
      await body();
    } catch (e, st) {
      failures.add(name);
      AppLogger.error('Sync section "$name" failed', error: e, stackTrace: st);
      debugPrint('[SyncService] Section "$name" failed: $e');
    }
  }

  Future<void> uploadAll() async {
    if (_uid == null) throw NotSignedInException();
    _syncing = true;
    final failures = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = FieldValue.serverTimestamp();

      await _runIsolated('settings', () async {
        await _doc('settings').set({
          'themeMode': prefs.getInt('theme_mode') ?? 0,
          'locale': prefs.getString('locale') ?? 'ar',
          'fontSize': prefs.getDouble('font_size') ?? 1.0,
          'wirdTarget': prefs.getInt('wird_target_pages') ?? 5,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }, failures);

      await _runIsolated('quran_progress', () async {
        await _doc('quran_progress').set({
          'lastSurah': prefs.getInt('last_reading_surah'),
          'lastAyah': prefs.getInt('last_reading_ayah'),
          'totalPagesRead': prefs.getInt('total_pages_read') ?? 0,
          'updatedAt': now,
        }, SetOptions(merge: true));
      }, failures);

      await _runIsolated('tasbeeh', () async {
        final tasbeehData = <String, dynamic>{};
        int grandTotal = 0;
        for (final key in prefs.getKeys()) {
          if (key.startsWith('tasbeeh_total_')) {
            final phraseId = key.replaceFirst('tasbeeh_total_', '');
            final val = prefs.getInt(key) ?? 0;
            tasbeehData[phraseId] = val;
            grandTotal += val;
          }
        }
        await _doc('tasbeeh').set({'phrases': tasbeehData, 'grandTotal': grandTotal, 'updatedAt': now}, SetOptions(merge: true));
      }, failures);

      await _runIsolated('achievements', () async {
        await _doc('achievements').set({'unlockedIds': prefs.getStringList('unlocked_achievements') ?? [], 'updatedAt': now}, SetOptions(merge: true));
      }, failures);

      await _runIsolated('profile', () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _doc('profile').set({'displayName': user.displayName ?? '', 'email': user.email ?? '', 'photoUrl': user.photoURL ?? '', 'lastSyncAt': now}, SetOptions(merge: true));
        }
      }, failures);

      for (final e in {'favorites': 'favorites_data', 'bookmarks': 'bookmarks_data', 'khatma': 'khatma_plans_v2', 'prayer_log': 'prayer_log_data', 'tasbeeh_custom': 'tasbeeh_custom_phrases_v1'}.entries) {
        await _runIsolated(e.key, () async {
          final val = prefs.getString(e.value);
          if (val != null) await _doc(e.key).set({'data': val, 'updatedAt': now}, SetOptions(merge: true));
        }, failures);
      }

      _lastSyncAt = DateTime.now();
      debugPrint('[SyncService] Upload complete' + (failures.isEmpty ? '' : ' (with failures in: ${failures.join(", ")})'));
      if (failures.isNotEmpty) throw PartialSyncException(failures);
    } finally { _syncing = false; }
  }

  Future<void> downloadAll() async {
    if (_uid == null) throw NotSignedInException();
    _syncing = true;
    final failures = <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();

      await _runIsolated('settings', () async {
        final s = await _doc('settings').get();
        if (s.exists) {
          final d = s.data()!;
          if (d['themeMode'] != null) await prefs.setInt('theme_mode', _asInt(d['themeMode']));
          if (d['locale'] != null) await prefs.setString('locale', d['locale']);
          if (d['fontSize'] != null) await prefs.setDouble('font_size', (d['fontSize'] as num).toDouble());
          if (d['wirdTarget'] != null) await prefs.setInt('wird_target_pages', _asInt(d['wirdTarget']));
        }
      }, failures);

      await _runIsolated('quran_progress', () async {
        final q = await _doc('quran_progress').get();
        if (q.exists) {
          final d = q.data()!;
          if (d['lastSurah'] != null) await prefs.setInt('last_reading_surah', _asInt(d['lastSurah']));
          if (d['lastAyah'] != null) await prefs.setInt('last_reading_ayah', _asInt(d['lastAyah']));
          if (d['totalPagesRead'] != null) await prefs.setInt('total_pages_read', _asInt(d['totalPagesRead']));
        }
      }, failures);

      await _runIsolated('tasbeeh', () async {
        final t = await _doc('tasbeeh').get();
        if (t.exists) {
          for (final e in ((t.data()!['phrases'] as Map<String, dynamic>?) ?? {}).entries) {
            await prefs.setInt('tasbeeh_total_' + e.key, _asInt(e.value));
          }
        }
      }, failures);

      await _runIsolated('achievements', () async {
        final a = await _doc('achievements').get();
        if (a.exists) await prefs.setStringList('unlocked_achievements', List<String>.from(a.data()!['unlockedIds'] ?? []));
      }, failures);

      for (final e in {'favorites': 'favorites_data', 'bookmarks': 'bookmarks_data', 'khatma': 'khatma_plans_v2', 'prayer_log': 'prayer_log_data', 'tasbeeh_custom': 'tasbeeh_custom_phrases_v1'}.entries) {
        await _runIsolated(e.key, () async {
          final doc = await _doc(e.key).get();
          if (doc.exists && doc.data()!['data'] != null) await prefs.setString(e.value, doc.data()!['data']);
        }, failures);
      }

      _lastSyncAt = DateTime.now();
      debugPrint('[SyncService] Download complete' + (failures.isEmpty ? '' : ' (with failures in: ${failures.join(", ")})'));
      if (failures.isNotEmpty) throw PartialSyncException(failures);
    } finally { _syncing = false; }
  }

  static const String _localLastSyncedKey = 'sync_local_last_synced_at_ms';

  /// Reads the 'settings' document's server-written updatedAt as a proxy
  /// for cloud data freshness overall -- uploadAll() writes it in the
  /// same section as everything else.
  Future<DateTime?> _cloudLastUpdated() async {
    if (_uid == null) return null;
    try {
      final snap = await _doc('settings').get();
      final ts = snap.data()?['updatedAt'];
      if (ts is Timestamp) return ts.toDate();
    } catch (e, st) {
      AppLogger.error('Failed to read cloud updatedAt', error: e, stackTrace: st);
    }
    return null;
  }

  Future<void> _markLocalSynced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_localLastSyncedKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Was previously unconditional download-then-upload, which meant THIS
  /// device's local state always won immediately after sign-in -- even if
  /// empty/stale -- silently erasing a second device's cloud data. Now:
  /// only download (let cloud win) when the cloud was updated more
  /// recently than the last time THIS device synced; otherwise this
  /// device's data is at least as current, so push it up instead. Not a
  /// full per-field merge, but it removes the most damaging concrete
  /// scenario (signing in on a new device wiping another device's data).
  Future<void> syncOnSignIn() async {
    final cloudUpdatedAt = await _cloudLastUpdated();
    final prefs = await SharedPreferences.getInstance();
    final localLastSyncedMs = prefs.getInt(_localLastSyncedKey);

    final cloudIsNewer = cloudUpdatedAt != null &&
        (localLastSyncedMs == null || cloudUpdatedAt.millisecondsSinceEpoch > localLastSyncedMs);

    if (cloudIsNewer) {
      await downloadAll();
    } else {
      await uploadAll();
    }
    await _markLocalSynced();
  }
  Future<void> syncNow() async { await uploadAll(); await _markLocalSynced(); }

  /// Deletes all user data from Firestore (called before account deletion).
  Future<void> deleteAllCloudData() async {
    if (_uid == null) return;
    final collections = [
      'settings', 'quran_progress', 'tasbeeh', 'achievements',
      'favorites', 'bookmarks', 'khatma', 'prayer_log', 'profile',
    ];
    for (final col in collections) {
      try {
        await _doc(col).delete();
      } catch (e, st) {
        AppLogger.error('Failed to delete cloud collection "' + col + '" during account deletion', error: e, stackTrace: st);
      }
    }
    debugPrint('[SyncService] All cloud data deleted');
  }
}
