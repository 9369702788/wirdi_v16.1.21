import '../../core/services/tajweed_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/data/bismillah.dart';
import '../../core/models/mushaf_models.dart';
import '../../core/models/quran_models.dart';
import '../../core/services/mushaf_repository.dart';
import '../../core/services/quran_audio_service.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class MushafViewScreen extends StatefulWidget {
  final int? initialPage;
  const MushafViewScreen({super.key, this.initialPage});

  @override
  State<MushafViewScreen> createState() => _MushafViewScreenState();
}

class _MushafViewScreenState extends State<MushafViewScreen> {
  late Future<(List<MushafPage>, List<SurahModel>)> _future;
  late PageController _pageController;

  /// Cached once [_loadAll] resolves, so [_onAudioChanged] (which fires
  /// on every ayah transition, independent of the FutureBuilder) can
  /// look up which page a given ayah belongs to without re-awaiting
  /// the future.
  List<MushafPage>? _pages;

  @override
  void initState() {
    super.initState();
    _future = _loadAll();
    _pageController = PageController(initialPage: (widget.initialPage ?? 1) - 1);
    quranAudio.addListener(_onAudioChanged);
    // FIX: keep the screen awake while reading the Mushaf, same as a
    // real physical copy never "locks itself" while you're reading it.
    // WakelockPlus only suppresses the device's AUTOMATIC screen
    // timeout -- it does NOT block the user's own power button or any
    // manual lock action, so "the user locking the screen themselves"
    // still works exactly as normal. Disabled again in dispose() so
    // leaving this screen doesn't keep the whole app awake elsewhere.
    WakelockPlus.enable();
  }

  Future<(List<MushafPage>, List<SurahModel>)> _loadAll() async {
    final results = await Future.wait([MushafRepository.load(), QuranRepository.load()]);
    final pages = results[0] as List<MushafPage>;
    _pages = pages;
    return (pages, results[1] as List<SurahModel>);
  }

  /// FIX: during continuous "play whole surah" playback, the currently
  /// playing ayah advances automatically and this screen already
  /// highlights whichever ayah is playing -- but nothing previously
  /// moved the VISIBLE page forward when playback crossed a Mushaf
  /// page boundary, so once a page's last ayah finished, the next
  /// ayah's highlight kept advancing on a page the user could no
  /// longer see, with no indication to swipe forward. This finds which
  /// page the currently-playing ayah belongs to and animates there
  /// automatically whenever it's not the page already on screen.
  void _onAudioChanged() {
    final pages = _pages;
    final surah = quranAudio.currentSurahNumber;
    final ayah = quranAudio.playingAyah;
    if (pages == null || surah == null || ayah == null) return;
    if (!_pageController.hasClients) return;

    final targetIndex = pages.indexWhere(
      (p) => p.ayahs.any((a) => a.surahNumber == surah && a.ayahNumber == ayah),
    );
    if (targetIndex == -1) return;

    final currentIndex = _pageController.page?.round() ?? _pageController.initialPage;
    if (targetIndex == currentIndex) return;

    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    quranAudio.removeListener(_onAudioChanged);
    _pageController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.mushafTitle),
        centerTitle: true,
        actions: [
          ListenableBuilder(
            listenable: quranAudio,
            builder: (context, _) {
              if (quranAudio.playingAyah == null) return const SizedBox.shrink();
              return IconButton(
                tooltip: l10n.mushafStopAudioTooltip,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: () => quranAudio.stop(),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<(List<MushafPage>, List<SurahModel>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.mutedText),
                    const SizedBox(height: 12),
                    Text(l10n.mushafLoadError, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _future = _loadAll()),
                      child: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            );
          }

          final (pages, allSurahs) = snapshot.data!;

          // FIX: Quran pages are ALWAYS read right-to-left, regardless of
          // the app's current UI language. `reverse: true` on its own
          // reverses page order RELATIVE to the ambient Directionality --
          // that gave the right feel when the app locale was LTR
          // (English/German/etc.), but DOUBLE-flipped it back to
          // LTR-feeling navigation when the app locale is Arabic (RTL),
          // since the ambient Directionality is already RTL there.
          // Wrapping in an explicit, locale-independent RTL
          // Directionality and dropping `reverse` makes page-flip
          // direction consistent no matter what language the rest of
          // the app's UI is in.
          return Directionality(
            textDirection: TextDirection.rtl,
            child: PageView.builder(
              controller: _pageController,
              itemCount: pages.length,
              onPageChanged: (index) {
                UserProgressService.saveLastReading(
                  surahNumber: pages[index].ayahs.isNotEmpty ? pages[index].ayahs.first.surahNumber : 1,
                  surahName: '',
                  ayahNumber: pages[index].ayahs.isNotEmpty ? pages[index].ayahs.first.ayahNumber : 1,
                );
              },
              itemBuilder: (context, index) {
                final page = pages[index];
                return _MushafPageView(page: page, allSurahs: allSurahs);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MushafPageView extends StatefulWidget {
  final MushafPage page;
  final List<SurahModel> allSurahs;
  const _MushafPageView({required this.page, required this.allSurahs});

  @override
  State<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<_MushafPageView> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    quranAudio.addListener(_onAudioChanged);
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    quranAudio.removeListener(_onAudioChanged);
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  SurahModel? _surahFor(int number) {
    for (final s in widget.allSurahs) {
      if (s.number == number) return s;
    }
    return null;
  }

  void _playAyah(MushafAyahRef ayah) {
    // Temporary loud diagnostics -- a tap that silently does nothing is
    // indistinguishable, from the user's side, between "the gesture never
    // registered" and "the gesture fired but playback failed silently".
    // A visible SnackBar on every path removes that ambiguity completely.
    debugPrint('[MushafTap] tapped surah=${ayah.surahNumber} ayah=${ayah.ayahNumber}');
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text('Tapped surah ${ayah.surahNumber}, ayah ${ayah.ayahNumber}'),
        ),
      );
    }
    final surah = _surahFor(ayah.surahNumber);
    if (surah == null) {
      debugPrint('[MushafTap] ABORT: no SurahModel found for surahNumber=${ayah.surahNumber} in allSurahs (length=${widget.allSurahs.length})');
      return;
    }
    if (quranAudio.isPlayingFor(ayah.surahNumber, ayah.ayahNumber)) {
      debugPrint('[MushafTap] already playing this ayah -> stopping');
      quranAudio.stop();
    } else {
      debugPrint('[MushafTap] calling quranAudio.playAyah(surah=${surah.number}, ayahNumber=${ayah.ayahNumber})');
      quranAudio.playAyah(surah, widget.allSurahs, ayah.ayahNumber).catchError((e, st) {
        debugPrint('[MushafTap] playAyah threw: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playback error: $e')),
          );
        }
      });
    }
  }

  TapGestureRecognizer _makeRecognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _disposeRecognizers();

    final groups = <int, List<MushafAyahRef>>{};
    for (final ayah in widget.page.ayahs) {
      groups.putIfAbsent(ayah.surahNumber, () => []).add(ayah);
    }

    // FIX: on a tablet, this card previously only grew as tall as its
    // text content needed, leaving a large empty gap below it instead
    // of filling the screen like a real Mushaf page. LayoutBuilder
    // gives us the actual available height so the card can be told to
    // fill AT LEAST that much -- while still allowed to grow taller and
    // scroll internally (via the existing SingleChildScrollView) for
    // any page whose content is genuinely longer than the viewport.
    return LayoutBuilder(
      builder: (context, constraints) {
        final verticalMargin = 12.0 + 20.0 + MediaQuery.of(context).padding.bottom;
        final minCardHeight = constraints.maxHeight - verticalMargin;
        return Container(
          margin: EdgeInsets.fromLTRB(14, 12, 14, 20 + MediaQuery.of(context).padding.bottom),
          padding: const EdgeInsets.all(22),
          constraints: BoxConstraints(minHeight: minCardHeight > 0 ? minCardHeight : 0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.goldAccent.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in groups.entries) ...[
              if (entry.value.isNotEmpty && entry.value.first.ayahNumber == 1) ...[
                _SurahHeaderBanner(surah: _surahFor(entry.key)),
                if (Bismillah.shouldShowFor(entry.key)) ...[
                  const SizedBox(height: 14),
                  Text(
                    Bismillah.text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 24, fontWeight: FontWeight.normal),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              Text.rich(
                TextSpan(
                  children: [
                    for (final ayah in entry.value) ...(() {
                      // NOTE: a TapGestureRecognizer set on a TextSpan only
                      // fires for that span's OWN `text`, never for its
                      // `children` -- this is a well-known Flutter gotcha.
                      // The previous version set `recognizer` on the wrapping
                      // parent span (which had no `text` of its own, only
                      // `children`), so the tap target was effectively an
                      // empty, zero-length span that could never actually be
                      // tapped. Fixed by attaching the SAME recognizer to
                      // every leaf span that actually renders visible glyphs
                      // (each Tajweed-colored segment, or the plain-text
                      // span, plus the ayah-number marker) so the whole
                      // rendered ayah -- including its number -- is tappable.
                      final isPlaying = quranAudio.isPlayingFor(ayah.surahNumber, ayah.ayahNumber);
                      final playingStyle = isPlaying
                          ? TextStyle(backgroundColor: AppColors.goldAccent.withValues(alpha: 0.35))
                          : null;
                      final leafSpans = <TextSpan>[
                        if (appSettings.showTajweedColoring)
                          ...TajweedService.analyze(ayah.text).map((segment) {
                            final color = TajweedService.colorFor(segment.rule);
                            return TextSpan(
                              text: segment.text,
                              style: (color != null ? TextStyle(color: color) : const TextStyle()).merge(playingStyle),
                              recognizer: _makeRecognizer(() => _playAyah(ayah)),
                            );
                          })
                        else
                          TextSpan(
                            text: ayah.text,
                            style: playingStyle,
                            recognizer: _makeRecognizer(() => _playAyah(ayah)),
                          ),
                        TextSpan(
                          text: ' \uFD3F${ayah.ayahNumber}\uFD3E ',
                          style: playingStyle,
                          recognizer: _makeRecognizer(() => _playAyah(ayah)),
                        ),
                      ];
                      return leafSpans;
                    })(),
                  ],
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 22, height: 2.4, fontWeight: FontWeight.normal),
              ),
              const SizedBox(height: 16),
            ],
            const Divider(height: 32),
            // FIX: confirmed via screenshot -- "RIGHT OVERFLOWED BY 68
            // PIXELS" in German. None of these 3 Text widgets had any
            // flexible sizing, so each took its full intrinsic (natural)
            // width -- fine for short Arabic/English strings, but
            // German's much longer translated hint text pushed the
            // Row's total width past the screen. Wrapping each in
            // Flexible/Expanded with ellipsis overflow makes this safe
            // for a string of ANY length in any current or future
            // language, not just a fix for German specifically.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    l10n.quranJuzNumber(widget.page.juzNumber),
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Text(
                    l10n.mushafTapAyahHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Flexible(
                  child: Text(
                    l10n.mushafPageNumber(widget.page.pageNumber),
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: AppColors.mutedText, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SurahHeaderBanner extends StatelessWidget {
  final SurahModel? surah;
  const _SurahHeaderBanner({required this.surah});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentSurah = surah;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.goldAccent, width: 1.5),
        borderRadius: BorderRadius.circular(10),
        color: AppColors.primaryEmerald.withValues(alpha: 0.07),
      ),
      alignment: Alignment.center,
      child: Text(
        currentSurah != null ? l10n.quranSurahAppBarTitle(currentSurah.name) : '',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.primaryEmerald),
      ),
    );
  }
}
