import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../core/models/quran_models.dart';
import '../../core/services/quran_repository.dart';
import '../../core/theme/app_theme.dart';

String _ht(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

enum HifzVisibility { visible, blurred, hidden }

/// Memorization practice mode: pick a surah, then hide/blur its verses one
/// at a time (or all at once) to test recall. Built on Wirdi's existing
/// QuranRepository -- no new data source, no persistence needed for a
/// first version (state resets when leaving the screen, by design).
class HifzScreen extends StatefulWidget {
  const HifzScreen({super.key});
  @override
  State<HifzScreen> createState() => _HifzScreenState();
}

class _HifzScreenState extends State<HifzScreen> {
  List<SurahModel>? _allSurahs;
  SurahModel? _selectedSurah;
  HifzVisibility _globalMode = HifzVisibility.visible;
  final Map<int, HifzVisibility> _perAyahOverride = {};

  @override
  void initState() {
    super.initState();
    QuranRepository.load().then((s) {
      if (mounted) setState(() => _allSurahs = s);
    });
  }

  HifzVisibility _modeFor(int ayahNumber) => _perAyahOverride[ayahNumber] ?? _globalMode;

  void _cycleAyah(int ayahNumber) {
    setState(() {
      final current = _modeFor(ayahNumber);
      _perAyahOverride[ayahNumber] = switch (current) {
        HifzVisibility.visible => HifzVisibility.blurred,
        HifzVisibility.blurred => HifzVisibility.hidden,
        HifzVisibility.hidden => HifzVisibility.visible,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final surah = _selectedSurah;
    return Scaffold(
      appBar: AppBar(
        title: Text(surah == null ? _ht(context, '\u0648\u0636\u0639 \u0627\u0644\u062d\u0641\u0638', 'Hifz Mode') : surah.name),
        centerTitle: true,
        leading: surah != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() {
                _selectedSurah = null;
                _perAyahOverride.clear();
              }))
            : null,
        actions: surah == null
            ? null
            : [
                PopupMenuButton<HifzVisibility>(
                  icon: const Icon(Icons.visibility_outlined),
                  tooltip: _ht(context, '\u0648\u0636\u0639 \u0627\u0644\u0625\u062e\u0641\u0627\u0621', 'Hide mode'),
                  onSelected: (mode) => setState(() {
                    _globalMode = mode;
                    _perAyahOverride.clear();
                  }),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: HifzVisibility.visible, child: Text(_ht(context, '\u0645\u0631\u0626\u064a', 'Visible'))),
                    PopupMenuItem(value: HifzVisibility.blurred, child: Text(_ht(context, '\u0645\u0636\u0628\u0651\u0628', 'Blurred'))),
                    PopupMenuItem(value: HifzVisibility.hidden, child: Text(_ht(context, '\u0645\u062e\u0641\u064a', 'Hidden'))),
                  ],
                ),
              ],
      ),
      body: surah == null ? _buildSurahList() : _buildAyahList(surah),
    );
  }

  Widget _buildSurahList() {
    final surahs = _allSurahs;
    if (surahs == null) return const Center(child: CircularProgressIndicator());
    return ListView.builder(
      itemCount: surahs.length,
      itemBuilder: (context, index) {
        final s = surahs[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryEmerald.withValues(alpha: 0.1),
            child: Text('${s.number}', style: const TextStyle(color: AppColors.primaryEmerald, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: Text(s.name, textDirection: TextDirection.rtl),
          subtitle: Text('${s.ayahs.length} ${_ht(context, '\u0622\u064a\u0629', 'verses')}', style: const TextStyle(fontSize: 12, color: AppColors.mutedText)),
          onTap: () => setState(() => _selectedSurah = s),
        );
      },
    );
  }

  Widget _buildAyahList(SurahModel surah) {
    return Column(children: [
      Container(
        width: double.infinity,
        color: AppColors.primaryEmerald.withValues(alpha: 0.06),
        padding: const EdgeInsets.all(10),
        child: Text(
          _ht(context, '\u0627\u0636\u063a\u0637 \u0639\u0644\u0649 \u0623\u064a \u0622\u064a\u0629 \u0644\u062a\u063a\u064a\u064a\u0631 \u0648\u0636\u0639\u0647\u0627 (\u0645\u0631\u0626\u064a \u2190 \u0645\u0636\u0628\u0651\u0628 \u2190 \u0645\u062e\u0641\u064a)',
              'Tap any verse to cycle its state (visible \u2192 blurred \u2192 hidden)'),
          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
          textAlign: TextAlign.center,
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: surah.ayahs.length,
          itemBuilder: (context, index) {
            final ayah = surah.ayahs[index];
            final mode = _modeFor(ayah.number);
            return GestureDetector(
              onTap: () => _cycleAyah(ayah.number),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (mode == HifzVisibility.hidden)
                    Center(
                      child: Icon(Icons.remove_red_eye_outlined, color: Colors.grey.shade400),
                    )
                  else if (mode == HifzVisibility.blurred)
                    ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Text(
                        ayah.text,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 1.9),
                      ),
                    )
                  else
                    Text(
                      ayah.text,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 20, height: 1.9),
                    ),
                  const SizedBox(height: 4),
                  Text('\u0622\u064a\u0629 ${ayah.number}', style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}
