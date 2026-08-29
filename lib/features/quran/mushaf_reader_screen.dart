import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/models/quran_models.dart';
import '../../core/services/arabic_text_utils.dart';
import '../../core/services/audio_download_service.dart';
import '../../core/services/bookmark_service.dart';
import '../../core/services/quran_audio_service.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/tajweed_helper.dart';
import '../../core/theme/app_theme.dart';
import '../../core/data/bismillah.dart';

String _t(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

const Map<String, String> _quranFontFamilies = {
  'default': '',
  'QuranQPCHafs': 'QuranQPCHafs',
  'QuranKFGQPCUthmanic': 'QuranKFGQPCUthmanic',
  'QuranAlQuranNeo': 'QuranAlQuranNeo',
  'QuranIndopakNastaleeq': 'QuranIndopakNastaleeq',
  'QuranMeQuranVolt': 'QuranMeQuranVolt',
};

/// Quran reader built on Wirdi's own QuranRepository (same source as the
/// existing quran_screen.dart) and wired directly into the existing,
/// already-proven QuranAudioService -- so playback, background/notification
/// controls, and offline downloads all reuse tested app-wide code instead of
/// a second, separate audio stack.
class MushafReaderScreen extends StatefulWidget {
  const MushafReaderScreen({super.key});
  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen> {
  List<SurahModel>? _allSurahs;
  String? _error;
  SurahModel? _selectedSurah;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _searchInVerses = false;
  bool _nightMode = false;
  Timer? _sleepTimer;
  int? _sleepMinutesRemaining;

  @override
  void initState() {
    super.initState();
    _load();
    quranAudio.addListener(_onAudioChanged);
  }

  @override
  void dispose() {
    quranAudio.removeListener(_onAudioChanged);
    _sleepTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final surahs = await QuranRepository.load();
      if (!mounted) return;
      setState(() => _allSurahs = surahs);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = _t(context, '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0646\u0635 \u0627\u0644\u0642\u0631\u0622\u0646. \u062a\u062d\u0642\u0642 \u0645\u0646 \u0627\u062a\u0635\u0627\u0644\u0643 \u0648\u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.', 'Could not load the Quran text. Check your connection and try again.'));
    }
  }

  void _startSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutesRemaining = minutes);
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      quranAudio.stop();
      if (mounted) setState(() => _sleepMinutesRemaining = null);
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutesRemaining = null);
  }

  Future<void> _downloadSurah(SurahModel surah) async {
    final allSurahs = _allSurahs;
    if (allSurahs == null) return;

    // Show the estimated file size before starting, using the same
    // per-ayah average (~0.4 MB) so the user can decide before spending data.
    final estimatedMb = (surah.ayahs.length * 0.4).toStringAsFixed(1);
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t(context, '\u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0633\u0648\u0631\u0629', 'Download surah')),
        content: Text(_t(context,
            '\u062d\u062c\u0645 \u0627\u0644\u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0642\u0631\u064a\u0628\u064a: \u0644 $estimatedMb \u0645\u064a\u062c\u0627\u0628\u0627\u064a\u062a. \u0647\u0644 \u062a\u0631\u064a\u062f \u0627\u0644\u0645\u062a\u0627\u0628\u0639\u0629\u061f',
            'Estimated download size: $estimatedMb MB. Continue?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t(context, '\u0625\u0644\u063a\u0627\u0621', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t(context, '\u062a\u062d\u0645\u064a\u0644', 'Download'))),
        ],
      ),
    );
    if (proceed != true) return;
    if (!mounted) return;

    bool cancelled = false;
    final progress = ValueNotifier<double>(0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t(context, '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0645\u064a\u0644...', 'Downloading...')),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, value, __) => LinearProgressIndicator(value: value == 0 ? null : value),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.of(dialogContext).pop();
            },
            child: Text(_t(context, '\u0625\u0644\u063a\u0627\u0621', 'Cancel')),
          ),
        ],
      ),
    );

    await AudioDownloadService.downloadSurah(
      reciterId: appSettings.reciterId,
      surah: surah,
      allSurahs: allSurahs,
      onProgress: (done, total) => progress.value = total == 0 ? 0 : done / total,
      isCancelled: () => cancelled,
    );

    if (!mounted) return;
    if (!cancelled && Navigator.canPop(context)) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t(context, '\u062a\u0645 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0633\u0648\u0631\u0629 \u0644\u0644\u0627\u0633\u062a\u0645\u0627\u0639 \u0628\u062f\u0648\u0646 \u0627\u062a\u0635\u0627\u0644', 'Surah downloaded for offline listening'))),
      );
    }
  }

  Future<void> _showRangeDialog(SurahModel surah) async {
    final allSurahs = _allSurahs;
    if (allSurahs == null) return;
    final maxAyah = surah.ayahs.length;
    int start = 1;
    int end = maxAyah;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_t(context, '\u062a\u0634\u063a\u064a\u0644 \u0646\u0637\u0627\u0642 \u0622\u064a\u0627\u062a', 'Play a verse range')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_t(context, '\u0645\u0646 \u0622\u064a\u0629 $start \u0625\u0644\u0649 \u0622\u064a\u0629 $end', 'From ayah $start to ayah $end')),
            RangeSlider(
              values: RangeValues(start.toDouble(), end.toDouble()),
              min: 1, max: maxAyah.toDouble(),
              divisions: maxAyah > 1 ? maxAyah - 1 : 1,
              onChanged: (values) => setDialogState(() {
                start = values.start.round();
                end = values.end.round();
              }),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(_t(context, '\u0625\u0644\u063a\u0627\u0621', 'Cancel'))),
            TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(_t(context, '\u062a\u0634\u063a\u064a\u0644', 'Play'))),
          ],
        ),
      ),
    );
    if (result == true) {
      quranAudio.playRange(surah, allSurahs, start, end);
    }
  }

  Future<void> _showRepeatDialog({required bool forSurah}) async {
    final options = [1, 2, 3, 5, 10, null];
    final choice = await showDialog<int?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(_t(context, '\u0639\u062f\u062f \u0645\u0631\u0627\u062a \u0627\u0644\u062a\u0643\u0631\u0627\u0631', 'Repeat count')),
        children: [
          for (final n in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, n),
              child: Text(n == null ? _t(context, '\u0644\u0627 \u0646\u0647\u0627\u0626\u064a (\u221e)', 'Infinite (\u221e)') : _t(context, '$n \u0645\u0631\u0627\u062a', '$n times')),
            ),
        ],
      ),
    );
    quranAudio.setRepeatCount(choice);
    if (forSurah) {
      if (!quranAudio.repeatSurah) quranAudio.toggleRepeatSurah();
    } else {
      if (!quranAudio.repeatCurrent) quranAudio.toggleRepeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final surah = _selectedSurah;
    return Scaffold(
      backgroundColor: _nightMode ? const Color(0xFF1A1410) : null,
      appBar: AppBar(
        title: Text(surah == null ? _t(context, '\u0642\u0627\u0631\u0626 \u0627\u0644\u0642\u0631\u0622\u0646', 'Quran Reader') : surah.name),
        centerTitle: true,
        leading: surah != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedSurah = null))
            : null,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.font_download_outlined),
            tooltip: _t(context, '\u0627\u0644\u062e\u0637', 'Font'),
            onSelected: (family) => appSettings.setQuranFontFamily(family),
            itemBuilder: (_) => [
              for (final key in _quranFontFamilies.keys)
                PopupMenuItem(
                  value: key,
                  child: Row(children: [
                    if (appSettings.quranFontFamily == key) const Icon(Icons.check, size: 18) else const SizedBox(width: 18),
                    const SizedBox(width: 8),
                    Text(key == 'default' ? _t(context, '\u0627\u0641\u062a\u0631\u0627\u0636\u064a', 'Default') : key.replaceFirst('Quran', '')),
                  ]),
                ),
            ],
          ),
          IconButton(
            icon: Icon(_nightMode ? Icons.nightlight_round : Icons.nightlight_outlined),
            tooltip: _t(context, '\u0648\u0636\u0639 \u0627\u0644\u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0644\u064a\u0644\u064a\u0629', 'Night reading mode'),
            onPressed: () => setState(() => _nightMode = !_nightMode),
          ),
          if (surah != null) ...[
            PopupMenuButton<double>(
              icon: const Icon(Icons.speed),
              tooltip: _t(context, '\u0633\u0631\u0639\u0629 \u0627\u0644\u062a\u0644\u0627\u0648\u0629', 'Playback speed'),
              onSelected: (rate) => quranAudio.setSpeed(rate),
              itemBuilder: (_) => [
                PopupMenuItem(value: 0.5, child: const Text('0.5x')),
                PopupMenuItem(value: 0.75, child: const Text('0.75x')),
                PopupMenuItem(value: 1.0, child: Text(_t(context, '1.0x (\u0639\u0627\u062f\u064a)', '1.0x (normal)'))),
                PopupMenuItem(value: 1.25, child: const Text('1.25x')),
                PopupMenuItem(value: 1.5, child: const Text('1.5x')),
                PopupMenuItem(value: 2.0, child: const Text('2.0x')),
              ],
            ),
            IconButton(
              icon: Icon(quranAudio.repeatSurah || quranAudio.repeatCurrent ? Icons.repeat_on_rounded : Icons.repeat_rounded,
                  color: (quranAudio.repeatSurah || quranAudio.repeatCurrent) ? AppColors.goldAccent : null),
              tooltip: _t(context, '\u062a\u0643\u0631\u0627\u0631', 'Repeat'),
              onPressed: () => _showRepeatDialog(forSurah: quranAudio.playingWholeSurah),
            ),
            PopupMenuButton<int>(
              icon: Icon(_sleepMinutesRemaining != null ? Icons.bedtime : Icons.bedtime_outlined),
              tooltip: _t(context, '\u0645\u0624\u0642\u062a \u0627\u0644\u0646\u0648\u0645', 'Sleep timer'),
              onSelected: (minutes) => minutes == 0 ? _cancelSleepTimer() : _startSleepTimer(minutes),
              itemBuilder: (_) => [
                if (_sleepMinutesRemaining != null) PopupMenuItem(value: 0, child: Text(_t(context, '\u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u0645\u0624\u0642\u062a', 'Cancel timer'))),
                PopupMenuItem(value: 5, child: Text(_t(context, '5 \u062f\u0642\u0627\u0626\u0642', '5 minutes'))),
                PopupMenuItem(value: 10, child: Text(_t(context, '10 \u062f\u0642\u0627\u0626\u0642', '10 minutes'))),
                PopupMenuItem(value: 15, child: Text(_t(context, '15 \u062f\u0642\u064a\u0642\u0629', '15 minutes'))),
                PopupMenuItem(value: 30, child: Text(_t(context, '30 \u062f\u0642\u064a\u0642\u0629', '30 minutes'))),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: _t(context, '\u062a\u062d\u0645\u064a\u0644 \u0644\u0644\u0627\u0633\u062a\u0645\u0627\u0639 \u0628\u062f\u0648\u0646 \u0627\u062a\u0635\u0627\u0644', 'Download for offline'),
              onPressed: () => _downloadSurah(surah),
            ),
            IconButton(
              icon: const Icon(Icons.linear_scale),
              tooltip: _t(context, '\u062a\u0634\u063a\u064a\u0644 \u0646\u0637\u0627\u0642 \u0622\u064a\u0627\u062a', 'Play a verse range'),
              onPressed: () => _showRangeDialog(surah),
            ),
          ],
        ],
      ),
      body: _buildBody(surah),
    );
  }

  Widget _buildBody(SurahModel? surah) {
    if (_error != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)));
    }
    final allSurahs = _allSurahs;
    if (allSurahs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (surah == null) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _t(context, '\u0627\u0628\u062d\u062b \u0639\u0646 \u0633\u0648\u0631\u0629 \u0623\u0648 \u0622\u064a\u0629...', 'Search for a surah or ayah...'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ChoiceChip(
                  label: Text(_t(context, '\u0627\u0644\u0633\u0648\u0631', 'Surahs')),
                  selected: !_searchInVerses,
                  onSelected: (_) => setState(() => _searchInVerses = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: Text(_t(context, '\u0627\u0644\u0622\u064a\u0627\u062a (\u0646\u0635 \u0643\u0627\u0645\u0644)', 'Verses (full text)')),
                  selected: _searchInVerses,
                  onSelected: (_) => setState(() => _searchInVerses = true),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(
          child: _shouldShowVerseResults(allSurahs)
              ? _buildVerseSearchResults(allSurahs, _query.trim())
              : _buildSurahList(allSurahs),
        ),
      ]);
    }
    return _buildVerseList(surah, allSurahs);
  }

  /// If the user explicitly picked "Verses" mode, always search verse
  /// text. If they're in the default "Surahs" mode but their query matches
  /// no surah name/number at all, fall back to searching verse content too
  /// -- so typing part of an ayah always finds something instead of
  /// silently showing an empty surah list.
  bool _shouldShowVerseResults(List<SurahModel> allSurahs) {
    final q = _query.trim();
    if (q.isEmpty) return false;
    if (_searchInVerses) return true;
    final anySurahMatch = allSurahs.any((s) =>
        ArabicTextUtils.contains(s.name, q) ||
        s.englishName.toLowerCase().contains(q.toLowerCase()) ||
        s.number.toString() == q);
    return !anySurahMatch;
  }

  Widget _buildSurahList(List<SurahModel> allSurahs) {
    final filtered = _query.trim().isEmpty
        ? allSurahs
        : allSurahs.where((s) {
            final q = _query.trim();
            return ArabicTextUtils.contains(s.name, q) ||
                s.englishName.toLowerCase().contains(q.toLowerCase()) ||
                s.number.toString() == q;
          }).toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final s = filtered[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.1),
            child: Text('${s.number}', style: const TextStyle(color: AppColors.primaryEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: Text(s.name, textDirection: TextDirection.rtl),
          subtitle: Text('${s.englishName} \u2014 ${s.ayahs.length} ${_t(context, '\u0622\u064a\u0629', 'verses')}', style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
          onTap: () => setState(() => _selectedSurah = s),
        );
      },
    );
  }

  Widget _buildVerseSearchResults(List<SurahModel> allSurahs, String query) {
    final results = <MapEntry<SurahModel, AyahModel>>[];
    for (final s in allSurahs) {
      for (final a in s.ayahs) {
        if (ArabicTextUtils.contains(a.text, query)) {
          results.add(MapEntry(s, a));
          if (results.length >= 200) break;
        }
      }
      if (results.length >= 200) break;
    }
    if (results.isEmpty) {
      return Center(child: Text(_t(context, '\u0644\u0627 \u062a\u0648\u062c\u062f \u0646\u062a\u0627\u0626\u062c', 'No results')));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return ListTile(
          title: Text(entry.value.text, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18, height: 1.8)),
          subtitle: Text('${entry.key.name} \u2014 ${_t(context, '\u0622\u064a\u0629', 'Ayah')} ${entry.value.number}'),
          onTap: () => setState(() => _selectedSurah = entry.key),
        );
      },
    );
  }

  Widget _buildVerseList(SurahModel surah, List<SurahModel> allSurahs) {
    final isThisSurahPlaying = quranAudio.isSurahActive(surah.number) && quranAudio.playingWholeSurah;
    final showBismillah = Bismillah.shouldShowFor(surah.number);
    final fontKey = _quranFontFamilies[appSettings.quranFontFamily] ?? '';
    // Two independent things affect what background the reader sits on:
    // (1) the in-page night-reading toggle (_nightMode), and (2) the app's
    // GLOBAL theme (Settings > Mode: Light/Dark/System). Previously this
    // only accounted for (1) and assumed "not in reading-night-mode" always
    // meant a light background -- which is false when the global theme is
    // Dark, causing near-black text on a near-black background.
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final baseStyle = TextStyle(
      fontFamily: fontKey.isEmpty ? 'AmiriQuran' : fontKey,
      fontSize: 22,
      height: 2.0,
      color: _nightMode
          ? const Color(0xFFE8D9C5)
          : (isDarkTheme ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A)),
    );

    return Column(children: [
      Container(
        color: _nightMode ? Colors.black : AppColors.primaryEmerald.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Icon(
            isThisSurahPlaying && !quranAudio.isPaused ? Icons.pause_circle_filled : Icons.play_circle_fill,
            color: AppColors.primaryEmerald,
          ),
          IconButton(
            icon: Icon(
              isThisSurahPlaying && !quranAudio.isPaused ? Icons.pause_circle_filled : Icons.play_circle_fill,
              color: AppColors.primaryEmerald,
            ),
            onPressed: () {
              if (isThisSurahPlaying) {
                quranAudio.isPaused ? quranAudio.resume() : quranAudio.pause();
              } else {
                quranAudio.playWholeSurah(surah, allSurahs);
              }
            },
          ),
          Expanded(child: Text(_t(context, '\u062a\u0634\u063a\u064a\u0644 \u0627\u0644\u0633\u0648\u0631\u0629 \u0643\u0627\u0645\u0644\u0629', 'Play whole surah'), style: TextStyle(fontSize: 12, color: _nightMode ? Colors.white70 : AppColors.mutedText))),
          if (quranAudio.isBuffering)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: surah.ayahs.length + (showBismillah ? 1 : 0),
          itemBuilder: (context, index) {
            if (showBismillah && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Center(
                  child: Text(
                    Bismillah.text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: baseStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                ),
              );
            }
            final ayah = surah.ayahs[index - (showBismillah ? 1 : 0)];
            final isPlaying = quranAudio.isPlayingFor(surah.number, ayah.number);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPlaying
                    ? (_nightMode ? Colors.white10 : AppColors.primaryEmerald.withValues(alpha: 0.08))
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                appSettings.showTajweedColoring
                    ? RichText(
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        text: TextSpan(children: TajweedHelper.buildSpans(ayah.text, baseStyle)),
                      )
                    : Text(ayah.text, textAlign: TextAlign.right, textDirection: TextDirection.rtl, style: baseStyle),
                const SizedBox(height: 6),
                Row(children: [
                  Text('\u0622\u064a\u0629 ${ayah.number}', style: TextStyle(fontSize: 11, color: _nightMode ? Colors.white38 : AppColors.mutedText)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(isPlaying && !quranAudio.isPaused ? Icons.pause_circle : Icons.play_circle_outline, color: AppColors.primaryEmerald),
                    onPressed: () async {
                      try {
                        if (isPlaying) {
                          quranAudio.isPaused ? await quranAudio.resume() : await quranAudio.pause();
                        } else {
                          await quranAudio.playAyah(surah, allSurahs, ayah.number);
                        }
                      } catch (e) {
                        // One automatic retry -- covers transient network hiccups
                        // (the same class of issue the radio player hit) without
                        // making the user tap twice.
                        try {
                          await Future.delayed(const Duration(milliseconds: 500));
                          await quranAudio.playAyah(surah, allSurahs, ayah.number);
                        } catch (e2) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Playback error: ' + e2.toString())),
                            );
                          }
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_add_outlined),
                    tooltip: _t(context, '\u0625\u0636\u0627\u0641\u0629 \u0625\u0634\u0627\u0631\u0629 \u0645\u0631\u062c\u0639\u064a\u0629', 'Add bookmark'),
                    onPressed: () async {
                      await BookmarkService.addBookmark(
                        surahNumber: surah.number,
                        surahName: surah.name,
                        ayahNumber: ayah.number,
                        ayahText: ayah.text,
                        note: '',
                        category: 'other',
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_t(context, '\u062a\u0645\u062a \u0625\u0636\u0627\u0641\u0629 \u0627\u0644\u0625\u0634\u0627\u0631\u0629 \u0627\u0644\u0645\u0631\u062c\u0639\u064a\u0629', 'Bookmark added'))),
                        );
                      }
                    },
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}
