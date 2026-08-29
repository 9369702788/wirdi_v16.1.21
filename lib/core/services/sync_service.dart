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

  Future<void> uploadAll() async {
    if (_uid == null) throw NotSignedInException();
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();
      batch.set(_doc('settings'), {'themeMode': prefs.getInt('theme_mode') ?? 0, 'locale': prefs.getString('locale') ?? 'ar', 'fontSize': prefs.getDouble('font_size') ?? 1.0, 'wirdTarget': prefs.getInt('wird_target_pages') ?? 5, 'updatedAt': now}, SetOptions(merge: true));
      batch.set(_doc('quran_progress'), {'lastSurah': prefs.getInt('last_reading_surah'), 'lastAyah': prefs.getInt('last_reading_ayah'), 'totalPagesRead': prefs.getInt('total_pages_read') ?? 0, 'updatedAt': now}, SetOptions(merge: true));
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
      batch.set(_doc('tasbeeh'), {'phrases': tasbeehData, 'grandTotal': grandTotal, 'updatedAt': now}, SetOptions(merge: true));
      batch.set(_doc('achievements'), {'unlockedIds': prefs.getStringList('unlocked_achievements') ?? [], 'updatedAt': now}, SetOptions(merge: true));
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) batch.set(_doc('profile'), {'displayName': user.displayName ?? '', 'email': user.email ?? '', 'photoUrl': user.photoURL ?? '', 'lastSyncAt': now}, SetOptions(merge: true));
      for (final e in {'favorites': 'favorites_data', 'bookmarks': 'bookmarks_data', 'khatma': 'khatma_plans_v2', 'prayer_log': 'prayer_log_data', 'tasbeeh_custom': 'tasbeeh_custom_phrases_v1'}.entries) {
        final val = prefs.getString(e.value);
        if (val != null) batch.set(_doc(e.key), {'data': val, 'updatedAt': now}, SetOptions(merge: true));
      }
      await batch.commit();
      _lastSyncAt = DateTime.now();
      debugPrint('[SyncService] Upload complete');
    } catch (e) { debugPrint('[SyncService] Upload error: ' + e.toString()); rethrow; }
    finally { _syncing = false; }
  }

  Future<void> downloadAll() async {
    if (_uid == null) throw NotSignedInException();
    _syncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = await _doc('settings').get();
      if (s.exists) {
        final d = s.data()!;
        if (d['themeMode'] != null) await prefs.setInt('theme_mode', d['themeMode']);
        if (d['locale'] != null) await prefs.setString('locale', d['locale']);
        if (d['fontSize'] != null) await prefs.setDouble('font_size', (d['fontSize'] as num).toDouble());
        if (d['wirdTarget'] != null) await prefs.setInt('wird_target_pages', d['wirdTarget']);
      }
      final q = await _doc('quran_progress').get();
      if (q.exists) {
        final d = q.data()!;
        if (d['lastSurah'] != null) await prefs.setInt('last_reading_surah', d['lastSurah']);
        if (d['lastAyah'] != null) await prefs.setInt('last_reading_ayah', d['lastAyah']);
        if (d['totalPagesRead'] != null) await prefs.setInt('total_pages_read', d['totalPagesRead']);
      }
      final t = await _doc('tasbeeh').get();
      if (t.exists) {
        for (final e in ((t.data()!['phrases'] as Map<String, dynamic>?) ?? {}).entries) {
          await prefs.setInt('tasbeeh_total_' + e.key, e.value as int);
        }
      }
      final a = await _doc('achievements').get();
      if (a.exists) await prefs.setStringList('unlocked_achievements', List<String>.from(a.data()!['unlockedIds'] ?? []));
      for (final e in {'favorites': 'favorites_data', 'bookmarks': 'bookmarks_data', 'khatma': 'khatma_plans_v2', 'prayer_log': 'prayer_log_data', 'tasbeeh_custom': 'tasbeeh_custom_phrases_v1'}.entries) {
        final doc = await _doc(e.key).get();
        if (doc.exists && doc.data()!['data'] != null) await prefs.setString(e.value, doc.data()!['data']);
      }
      _lastSyncAt = DateTime.now();
      debugPrint('[SyncService] Download complete');
    } catch (e) { debugPrint('[SyncService] Download error: ' + e.toString()); rethrow; }
    finally { _syncing = false; }
  }

  static const String _localLastSyncedKey = 'sync_local_last_synced_at_ms';

  /// Reads the 'settings' document's server-written updatedAt as a proxy
  /// for cloud data freshness overall -- uploadAll() writes it via
  /// FieldValue.serverTimestamp() in the same batch as everything else.
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
