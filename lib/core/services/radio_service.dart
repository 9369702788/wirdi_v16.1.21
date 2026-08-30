
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

  /// ROOT CAUSE FIX (v105): v104 made mp3quran.net / Radio-Browser each
  /// a full-list "primary" source that REPLACED whatever list was
  /// already active. That silently dropped any station that only
  /// existed in the sources that got demoted (e.g. a specific "Egypt
  /// Quran Radio" station some users relied on). Switching which
  /// source is primary should never make a previously-available
  /// station disappear. Fix: fetch from ALL four sources independently
  /// and MERGE every station from every source that responded into one
  /// combined list, deduplicated by stream URL.
  Future<void> _doRefresh() async {
    _loadingLive = true;
    notifyListeners();

    final combined = <String, RadioStation>{};
    final succeededSources = <String>[];

    Future<void> mergeFrom(Future<List<RadioStation>> Function() fetch, String label) async {
      try {
        final list = await fetch();
        if (list.isEmpty) return;
        succeededSources.add(label);
        for (final s in list) {
          if (s.streamUrl.isNotEmpty) combined[s.streamUrl] = s;
        }
      } catch (e) {
        debugPrint('[Radio] $label error: $e');
      }
    }

    await mergeFrom(_fetchMp3Quran, 'mp3quran.net');
    await mergeFrom(_fetchRadioBrowser, 'Radio-Browser');
    await mergeFrom(_fetchDataRosy, 'data-rosy');
    await mergeFrom(_fetchUthumany, 'Islamic Radio API');

    if (combined.isNotEmpty) {
      _liveStations = combined.values.toList();
      _activeSource = RadioSource.fallback;
      _sourceLabel = _liveStations.length.toString() + ' stations from ' + succeededSources.join(' + ');
      debugPrint('[Radio] Combined ' + _liveStations.length.toString() + ' stations from: ' + succeededSources.join(', '));
    } else {
      debugPrint('[Radio] All station sources failed -- keeping the embedded fallback list.');
    }

    _loadingLive = false;
    notifyListeners();
  }

  Future<List<RadioStation>> _fetchMp3Quran() async {
    final resp = await http
        .get(Uri.parse('https://mp3quran.net/api/v3/radios?language=ar'))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final radios = decoded['radios'] as List<dynamic>? ?? const [];
    return radios
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromMp3Quran)
        .where((s) => s.streamUrl.isNotEmpty)
        .toList();
  }

  Future<List<RadioStation>> _fetchRadioBrowser() async {
    final resp = await http.get(
      Uri.parse('https://de1.api.radio-browser.info/json/stations/bytag/quran?limit=100&hidebroken=true'),
      headers: {'User-Agent': 'WirdiApp/1.52 (Islamic companion app)'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final List<dynamic> data = jsonDecode(resp.body);
    return data
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromRadioBrowser)
        .where((s) => s.streamUrl.isNotEmpty)
        .toList();
  }

  Future<List<RadioStation>> _fetchDataRosy() async {
    final resp = await http.get(
      Uri.parse('https://data-rosy.vercel.app/radio.json'),
      headers: {'User-Agent': 'WirdiApp/1.51'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final List<dynamic> data = jsonDecode(resp.body);
    return data
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromDataRosy)
        .where((s) => s.streamUrl.isNotEmpty)
        .toList();
  }

  Future<List<RadioStation>> _fetchUthumany() async {
    final resp = await http.get(
      Uri.parse('https://raw.githubusercontent.com/uthumany/radio-api/main/client/public/api/stations.json'),
      headers: {'User-Agent': 'WirdiApp/1.51'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return const [];
    final List<dynamic> data = jsonDecode(resp.body);
    return data
        .whereType<Map<String, dynamic>>()
        .map(RadioStation.fromUthumany)
        .where((s) => s.streamUrl.isNotEmpty)
        .toList();
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
