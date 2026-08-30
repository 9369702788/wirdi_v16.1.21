
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/radio_station.dart';
import '../data/radio_stations.dart';
import 'playback_coordinator.dart';

enum RadioState { stopped, loading, playing, error }

/// Which source is currently serving the station list.
enum RadioSource { embedded, mp3quran, radioBrowser, dataRosy, uthumany, fallback }

class RadioService extends ChangeNotifier {
  RadioService._();
  static final RadioService instance = RadioService._();

  final AudioPlayer _player = AudioPlayer();
  RadioState _state = RadioState.stopped;
  RadioStation? _currentStation;
  String? _errorMessage;
  Timer? _sleepTimer;
  Timer? _sleepCountdown;
  int? _sleepMinutesRemaining;
  Set<String> _favoriteIds = {};
  bool _initialized = false;

  // Start with embedded list immediately — no waiting
  List<RadioStation> _liveStations = kFallbackStations;
  bool _loadingLive = false;
  RadioSource _activeSource = RadioSource.embedded;
  String _sourceLabel = '18 curated Islamic stations';

  static const _favsKey = 'radio_favorites';

  // ── Getters ───────────────────────────────────────────────────────────────
  RadioState get state             => _state;
  RadioStation? get currentStation => _currentStation;
  String? get errorMessage         => _errorMessage;
  bool get isPlaying               => _state == RadioState.playing;
  bool get isLoading               => _state == RadioState.loading;
  int? get sleepMinutesRemaining   => _sleepMinutesRemaining;
  bool get hasSleepTimer           => _sleepTimer != null;
  bool get loadingLive             => _loadingLive;
  bool get loadingStations         => _loadingLive;
  RadioSource get activeSource     => _activeSource;
  String get sourceLabel           => _sourceLabel;
  bool isFavorite(String id)       => _favoriteIds.contains(id);

  List<RadioStation> get stations  => _liveStations;
  List<RadioStation> get allStations => _liveStations;

  List<RadioStation> get favoriteStations =>
      _liveStations.where((s) => _favoriteIds.contains(s.id)).toList();

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadFavorites();

    _player.onPlayerStateChanged.listen((ps) {
      if (ps == PlayerState.playing) {
        _state = RadioState.playing;
      } else if (ps == PlayerState.stopped || ps == PlayerState.completed ||
                 ps == PlayerState.paused) {
        if (_state != RadioState.error) _state = RadioState.stopped;
      }
      notifyListeners();
    });

    // Stations already loaded from embedded list above.
    // Try to refresh from API in background (non-blocking).
    _refreshFromApiInBackground();
  }

  // ── Background API refresh ────────────────────────────────────────────────
  void _refreshFromApiInBackground() {
    // Fire and forget — does NOT block init or the UI
    Future.microtask(_doRefresh);
  }

  Future<void> refreshStations() => _doRefresh();

  /// ROOT CAUSE FIX (v104): the previous priority order tried two
  /// unofficial personal mirrors first (a Vercel-hosted personal
  /// project and a raw-GitHub personal fork), with mp3quran.net -- a
  /// real, documented, verified public API -- only ever used to MERGE
  /// a few extra stations on top of whichever mirror happened to
  /// respond. Personal mirrors can disappear or go stale with no
  /// warning. New priority: try the two independently-run, documented
  /// public APIs (mp3quran.net, then Radio-Browser) FIRST as full
  /// primary station lists, merging the other one's results in on
  /// success for variety; only fall back to the older personal mirrors
  /// if BOTH real APIs fail entirely. This was NOT verified against
  /// live network responses (no internet access in the environment
  /// that authored this fix) -- please confirm real playback still
  /// works end-to-end on a real device/build.
  Future<void> _doRefresh() async {
    _loadingLive = true;
    notifyListeners();

    if (await _tryMp3Quran()) {
      await _mergeRadioBrowser();
      _loadingLive = false;
      notifyListeners();
      return;
    }
    if (await _tryRadioBrowser()) {
      await _mergeMp3Quran();
      _loadingLive = false;
      notifyListeners();
      return;
    }
    // Both documented public APIs failed -- fall back to the older
    // personal mirrors, same as before this fix.
    if (await _tryDataRosy()) {
      await _mergeMp3Quran();
      _loadingLive = false;
      notifyListeners();
      return;
    }
    if (await _tryUthumany()) {
      await _mergeMp3Quran();
      _loadingLive = false;
      notifyListeners();
      return;
    }
    await _mergeMp3Quran();
    _loadingLive = false;
    notifyListeners();
  }

  /// Full-list variant of mp3quran.net (was previously only used via
  /// [_mergeMp3Quran] to add a few extra stations on top of another
  /// source). https://mp3quran.net/api/v3/radios is a real, documented,
  /// verified public API for Quran radio stations.
  Future<bool> _tryMp3Quran() async {
    try {
      final resp = await http
          .get(Uri.parse('https://mp3quran.net/api/v3/radios?language=ar'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final radios = decoded['radios'] as List<dynamic>? ?? const [];
      final stations = radios
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromMp3Quran)
          .where((s) => s.streamUrl.isNotEmpty)
          .toList();
      if (stations.isEmpty) return false;
      _liveStations = stations;
      _activeSource = RadioSource.mp3quran;
      _sourceLabel = stations.length.toString() + ' stations from mp3quran.net';
      debugPrint('[Radio] Refreshed ' + stations.length.toString() + ' stations from mp3quran.net (primary)');
      return true;
    } catch (e) {
      debugPrint('[Radio] mp3quran.net (primary) error: ' + e.toString());
      return false;
    }
  }

  /// Radio-Browser (https://www.radio-browser.info) -- a large,
  /// community-maintained, genuinely open radio station directory with
  /// a documented public API. Their usage policy asks for a
  /// descriptive User-Agent identifying the app, which is set below.
  /// Searches by tag=quran; NOT verified against a live response in
  /// this environment (no network access here) -- please confirm real
  /// playback works on a real device/build.
  Future<bool> _tryRadioBrowser() async {
    try {
      final resp = await http.get(
        Uri.parse('https://de1.api.radio-browser.info/json/stations/bytag/quran?limit=100&hidebroken=true'),
        headers: {'User-Agent': 'WirdiApp/1.52 (Islamic companion app)'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;
      final List<dynamic> data = jsonDecode(resp.body);
      final stations = data
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromRadioBrowser)
          .where((s) => s.streamUrl.isNotEmpty)
          .toList();
      if (stations.isEmpty) return false;
      _liveStations = stations;
      _activeSource = RadioSource.radioBrowser;
      _sourceLabel = stations.length.toString() + ' stations from Radio-Browser';
      debugPrint('[Radio] Refreshed ' + stations.length.toString() + ' stations from Radio-Browser (primary)');
      return true;
    } catch (e) {
      debugPrint('[Radio] Radio-Browser (primary) error: ' + e.toString());
      return false;
    }
  }

  /// Merge-only variant of [_tryRadioBrowser] -- adds any NEW stations
  /// (deduplicated by stream URL) on top of whichever source is
  /// currently the primary list, same pattern as [_mergeMp3Quran].
  Future<void> _mergeRadioBrowser() async {
    try {
      final resp = await http.get(
        Uri.parse('https://de1.api.radio-browser.info/json/stations/bytag/quran?limit=100&hidebroken=true'),
        headers: {'User-Agent': 'WirdiApp/1.52 (Islamic companion app)'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final List<dynamic> data = jsonDecode(resp.body);
      final existingUrls = _liveStations.map((s) => s.streamUrl).toSet();
      final newStations = data
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromRadioBrowser)
          .where((s) => s.streamUrl.isNotEmpty && !existingUrls.contains(s.streamUrl))
          .toList();
      if (newStations.isEmpty) return;
      _liveStations = [..._liveStations, ...newStations];
      _sourceLabel = _sourceLabel + ' + ' + newStations.length.toString() + ' from Radio-Browser';
      debugPrint('[Radio] Merged ' + newStations.length.toString() + ' extra stations from Radio-Browser');
    } catch (e) {
      debugPrint('[Radio] Radio-Browser merge error: ' + e.toString());
    }
  }

  /// Fetches Quran radio stations from mp3quran.net (a real, verified
  /// public API: https://mp3quran.net/api/v3/radios) and merges any NEW
  /// stations (deduplicated by stream URL) into the active list.
  Future<void> _mergeMp3Quran() async {
    try {
      final resp = await http
          .get(Uri.parse('https://mp3quran.net/api/v3/radios?language=ar'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return;
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final radios = decoded['radios'] as List<dynamic>? ?? const [];
      final existingUrls = _liveStations.map((s) => s.streamUrl).toSet();
      final newStations = radios
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromMp3Quran)
          .where((s) => s.streamUrl.isNotEmpty && !existingUrls.contains(s.streamUrl))
          .toList();
      if (newStations.isEmpty) return;
      _liveStations = [..._liveStations, ...newStations];
      _sourceLabel = _sourceLabel + ' + ' + newStations.length.toString() + ' from mp3quran.net';
      debugPrint('[Radio] Merged ' + newStations.length.toString() + ' extra stations from mp3quran.net');
    } catch (e) {
      debugPrint('[Radio] mp3quran.net merge error: ' + e.toString());
    }
  }

  Future<bool> _tryDataRosy() async {
    try {
      final resp = await http.get(
        Uri.parse('https://data-rosy.vercel.app/radio.json'),
        headers: {'User-Agent': 'WirdiApp/1.51'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;
      final List<dynamic> data = jsonDecode(resp.body);
      final stations = data
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromDataRosy)
          .where((s) => s.streamUrl.isNotEmpty)
          .toList();
      if (stations.isEmpty) return false;
      _liveStations = stations;
      _activeSource = RadioSource.dataRosy;
      _sourceLabel = stations.length.toString() + ' stations from data-rosy';
      debugPrint('[Radio] Refreshed ' + stations.length.toString() + ' stations from data-rosy');
      return true;
    } catch (e) {
      debugPrint('[Radio] data-rosy error: ' + e.toString());
      return false;
    }
  }

  Future<bool> _tryUthumany() async {
    try {
      final resp = await http.get(
        Uri.parse('https://raw.githubusercontent.com/uthumany/radio-api/main/client/public/api/stations.json'),
        headers: {'User-Agent': 'WirdiApp/1.51'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return false;
      final List<dynamic> data = jsonDecode(resp.body);
      final stations = data
          .whereType<Map<String, dynamic>>()
          .map(RadioStation.fromUthumany)
          .where((s) => s.streamUrl.isNotEmpty)
          .toList();
      if (stations.isEmpty) return false;
      _liveStations = stations;
      _activeSource = RadioSource.uthumany;
      _sourceLabel = stations.length.toString() + ' stations from Islamic Radio API';
      debugPrint('[Radio] Refreshed ' + stations.length.toString() + ' stations from uthumany');
      return true;
    } catch (e) {
      debugPrint('[Radio] uthumany error: ' + e.toString());
      return false;
    }
  }

  // ── Playback ──────────────────────────────────────────────────────────────
  Future<void> play(RadioStation station) async {
    try {
      if (_currentStation?.id == station.id && isPlaying) return;
      await PlaybackCoordinator.stopQuranForRadio();
      _state = RadioState.loading;
      _currentStation = station;
      _errorMessage = null;
      notifyListeners();
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(UrlSource(station.streamUrl));
    } catch (e) {
      debugPrint('[Radio] play error: ' + e.toString());
      _state = RadioState.error;
      _errorMessage = 'Could not connect to this station. Please try another station or check your connection.';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    try { await _player.stop(); } catch (e) {
      debugPrint('[Radio] play error: ' + e.toString());
    }
    _state = RadioState.stopped;
    _currentStation = null;
    cancelSleepTimer();
    notifyListeners();
  }

  /// Pauses the current station without forgetting it -- unlike [stop],
  /// [_currentStation] stays set so the system media notification (and
  /// any UI reflecting "now playing") can still show which station is
  /// paused and offer a Play button that reconnects to it. Live streams
  /// don't have a meaningful buffered position to truly resume from, so
  /// resuming re-fetches the stream fresh via [play].
  Future<void> pause() async {
    try { await _player.stop(); } catch (e) {
      debugPrint('[Radio] pause error: ' + e.toString());
    }
    if (_state != RadioState.error) _state = RadioState.stopped;
    notifyListeners();
  }

  Future<void> togglePlay(RadioStation station) async {
    if (_currentStation?.id == station.id && isPlaying) {
      await stop();
    } else {
      await play(station);
    }
  }

  // ── Sleep Timer ───────────────────────────────────────────────────────────
  void setSleepTimer(int minutes) {
    cancelSleepTimer();
    _sleepMinutesRemaining = minutes;
    _sleepTimer = Timer(Duration(minutes: minutes), () async {
      await stop();
      _sleepMinutesRemaining = null;
      notifyListeners();
    });
    _sleepCountdown = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_sleepMinutesRemaining != null && _sleepMinutesRemaining! > 0) {
        _sleepMinutesRemaining = _sleepMinutesRemaining! - 1;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepCountdown?.cancel();
    _sleepTimer = null;
    _sleepCountdown = null;
    _sleepMinutesRemaining = null;
  }

  // ── Favorites ─────────────────────────────────────────────────────────────
  Future<void> toggleFavorite(String stationId) async {
    if (_favoriteIds.contains(stationId)) {
      _favoriteIds.remove(stationId);
    } else {
      _favoriteIds.add(stationId);
    }
    await _saveFavorites();
    notifyListeners();
  }

  Future<void> _loadFavorites() async {
    final p = await SharedPreferences.getInstance();
    _favoriteIds = (p.getStringList(_favsKey) ?? []).toSet();
  }

  Future<void> _saveFavorites() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_favsKey, _favoriteIds.toList());
  }
}
