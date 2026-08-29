

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../auth/account_screen.dart';
import '../../core/services/auth_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/data/adhan_option.dart';
import '../../core/services/audio_download_service.dart';
import '../../core/services/azkar_repository.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/daily_reminder_scheduler.dart';
import '../../core/services/quran_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/prayer_service.dart';
import '../../core/services/prayer_notification_scheduler.dart';
import '../../core/data/app_sources.dart';
import '../../core/services/user_progress_service.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _wirdTarget = 5;
  final AudioPlayer _previewPlayer = AudioPlayer();
  String? _previewingAdhanId;
  DateTime? _quranCachedAt;
  DateTime? _azkarCachedAt;
  int _downloadedAudioBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadWirdTarget();
    _loadCacheInfo();
    _loadDownloadedAudioSize();
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _previewingAdhanId = null);
    });
  }

  Future<void> _loadDownloadedAudioSize() async {
    final bytes = await AudioDownloadService.totalStorageUsedBytes();
    if (mounted) setState(() => _downloadedAudioBytes = bytes);
  }

  String _downloadedAudioSize(AppLocalizations l10n) {
    if (_downloadedAudioBytes == 0) return l10n.settingsNoDownloadedAudio;
    final mb = _downloadedAudioBytes / (1024 * 1024);
    return l10n.settingsMbDownloaded(mb.toStringAsFixed(1));
  }

  Future<void> _confirmDeleteAllDownloads() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteAllDownloadsTitle),
        content: Text(l10n.settingsDeleteAllDownloadsBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await AudioDownloadService.deleteAllDownloads();
      _loadDownloadedAudioSize();
    }
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePreviewAdhan(AdhanOption option) async {
    if (_previewingAdhanId == option.id) {
      try {
        await _previewPlayer.stop();
      } catch (_) {
        // Nothing loaded — fine.
      }
      setState(() => _previewingAdhanId = null);
      return;
    }

    setState(() => _previewingAdhanId = option.id);
    try {
      try {
        await _previewPlayer.stop();
      } catch (_) {
        // Nothing loaded yet — expected on first preview, safe to ignore.
      }
      await _previewPlayer.play(UrlSource(option.url));
    } catch (e) {
      if (mounted) {
        setState(() => _previewingAdhanId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).settingsPreviewFailed)),
        );
      }
    }
  }

  Future<void> _loadCacheInfo() async {
    final quranAt = await QuranRepository.cachedAt();
    final azkarAt = await AzkarRepository.cachedAt();
    if (mounted) {
      setState(() {
        _quranCachedAt = quranAt;
        _azkarCachedAt = azkarAt;
      });
    }
  }

  String _formatCacheDate(DateTime? date, String languageCode, AppLocalizations l10n) {
    if (date == null) return l10n.settingsNotDownloadedYet;
    // Falls back to 'en' formatting for locales without an intl date
    // pattern registered (all four we ship are registered in main.dart).
    return DateFormat('d MMMM y, h:mm a', languageCode).format(date);
  }

  Future<void> _rescheduleAllPrayerReminders() async {
    try {
      final result = await PrayerService.fetchUsingSavedPreference();
      if (mounted) {
        await PrayerNotificationScheduler.rescheduleFromResult(context, result);
      }
    } catch (_) {
      // No saved location / offline yet -- reminders will reschedule next
      // time the Prayer Times screen successfully fetches.
    }
  }

  Future<void> _loadWirdTarget() async {
    final target = await UserProgressService.dailyWirdTarget();
    if (mounted) setState(() => _wirdTarget = target);
  }

  Future<void> _setWirdTarget(int value) async {
    if (value < 1) return;
    await UserProgressService.setDailyWirdTarget(value);
    setState(() => _wirdTarget = value);
  }

  Future<void> _confirmClearData() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsDeleteLocalData),
        content: Text(l10n.settingsDeleteLocalDataBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonDelete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserProgressService.clearAllLocalData();
      await appSettings.load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsLocalDataDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle), centerTitle: true),
      body: ListenableBuilder(
        listenable: appSettings,
        builder: (context, _) {
          return ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.goldAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                // Internal build-diagnostic text -- only ever useful to us
                // during development, confusing/unprofessional for a real
                // end user to see in Settings. Debug builds only now.
                child: kDebugMode
                    ? const Text(
                        'Merge build: v93-2026-08-29-fix-keystore-path-depth',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      )
                    : const SizedBox.shrink(),
              ),
                        _SectionLabel(l10n.settingsAppearance),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [

            // ── Account / Cloud Sync ──────────────────────────────────────
            ListenableBuilder(
              listenable: AuthService.instance,
              builder: (context, _) {
                final user = AuthService.instance.currentUser;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryEmerald,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!) : null,
                      child: user?.photoURL == null
                          ? Text(
                              user != null
                                  ? (user.displayName ?? user.email ?? 'U')[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                    title: Text(
                      user != null
                          ? (user.displayName ?? user.email ?? 'Account')
                          : 'Sign in to sync progress',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      user != null ? 'Cloud sync enabled ✓' : 'Data stays on this device',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Icon(Icons.chevron_left, color: Colors.grey.shade400, size: 20),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AccountScreen())),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
                        Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.settingsMode, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.light,
                              label: Text(l10n.settingsModeLight, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              label: Text(l10n.settingsModeDark, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              label: Text(l10n.settingsModeAuto, overflow: TextOverflow.ellipsis, maxLines: 1),
                            ),
                          ],
                          // Icons removed -- with 3 segments + icon + label side by side, longer
                          // translated labels (e.g. Arabic "تلقائي") didn't fit the available
                          // width and wrapped to a 2nd line, growing the button's height beyond
                          // what the parent Column expected -- causing a real RenderFlex
                          // "bottom overflowed by 109 pixels" render error. Text-only segments
                          // fit reliably across all supported languages.
                          selected: {appSettings.themeMode},
                          onSelectionChanged: (set) => appSettings.setThemeMode(set.first),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(l10n.settingsFontSize, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Slider(
                        value: appSettings.fontScale,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        label: '${(appSettings.fontScale * 100).round()}%',
                        onChanged: (value) => appSettings.setFontScale(value),
                      ),
                      Text(
                        l10n.settingsFontPreview,
                        style: TextStyle(fontSize: 16 * appSettings.fontScale),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsShowTransliteration),
                        subtitle: Text(l10n.settingsShowTransliterationSubtitle),
                        value: appSettings.showTransliteration,
                        activeTrackColor: AppColors.primaryEmerald,
                        onChanged: (value) => appSettings.setShowTransliteration(value),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsTajweedColoring),
                        subtitle: Text(l10n.settingsTajweedColoringSubtitle),
                        value: appSettings.showTajweedColoring,
                        activeTrackColor: AppColors.primaryEmerald,
                        onChanged: (value) => appSettings.setShowTajweedColoring(value),
                      ),
                      const Divider(height: 24),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.language_outlined, color: AppColors.mutedText),
                        title: Text(l10n.settingsLanguage),
                        subtitle: Text(l10n.settingsLanguageSubtitle),
                        trailing: Text(
                          appSettings.explicitLocale == null
                              ? l10n.settingsLanguageSystem
                              : {
                                  'ar': l10n.languageName_ar,
                                  'en': l10n.languageName_en,
                                  'de': l10n.languageName_de,
                                  'tr': l10n.languageName_tr,
                                }[appSettings.explicitLocale!.languageCode] ?? '',
                          style: const TextStyle(color: AppColors.mutedText),
                        ),
                        onTap: () => _showLanguageSheet(context, l10n),
                    ),
                  ],
                ),
            ]))),
              const SizedBox(height: 20),
              _SectionLabel(l10n.settingsPrayerReminder),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsPrayerReminderEnable),
                      subtitle: Text(l10n.settingsPrayerReminderSubtitle),
                      value: appSettings.prayerReminderEnabled,
                      activeTrackColor: AppColors.primaryEmerald,
                      onChanged: (value) async {
                        for (final key in AppSettings.remindablePrayerKeys) {
                          await appSettings.setPrayerReminderEnabledFor(key, value);
                        }
                        unawaited(NotificationService.requestPermission());
                        unawaited(_rescheduleAllPrayerReminders());
                      },
                    ),
                    if (appSettings.prayerReminderEnabled) ...[
                      const SizedBox(height: 8),
                      Text(l10n.settingsRemindMeFor, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 4, children: [
                        for (final key in AppSettings.remindablePrayerKeys)
                          FilterChip(
                            label: Text(_prayerKeyLabel(l10n, key)),
                            selected: appSettings.isPrayerReminderEnabledFor(key),
                            onSelected: (sel) async {
                              await appSettings.setPrayerReminderEnabledFor(key, sel);
                              unawaited(_rescheduleAllPrayerReminders());
                            },
                          ),
                      ]),
                      const SizedBox(height: 16),
                      Text(l10n.settingsPrayerReminderMinutesBefore, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Slider(
                        value: appSettings.prayerReminderMinutesBefore.toDouble(),
                        min: 0, max: 30, divisions: 30,
                        label: l10n.settingsPrayerReminderMinutesLabel(appSettings.prayerReminderMinutesBefore),
                        onChanged: (v) => setState(() {}),
                        onChangeEnd: (v) async {
                          await appSettings.setPrayerReminderMinutesBefore(v.round());
                          unawaited(_rescheduleAllPrayerReminders());
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.settingsPrayerReminderMethod, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'adhan', label: Text(l10n.settingsReminderAdhan)),
                          ButtonSegment(value: 'beep', label: Text(l10n.settingsReminderBeep)),
                          ButtonSegment(value: 'banner', label: Text(l10n.settingsReminderBanner)),
                        ],
                        selected: {appSettings.prayerReminderMode == 'off' ? 'banner' : appSettings.prayerReminderMode},
                        onSelectionChanged: (set) async {
                          await appSettings.setPrayerReminderMode(set.first);
                          unawaited(_rescheduleAllPrayerReminders());
                        },
                      ),
                      if (appSettings.prayerReminderMode == 'adhan') ...[
                        const SizedBox(height: 16),
                        Text(l10n.settingsAdhanSound, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        for (final option in AppSources.adhanOptions)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.displayNameFor(languageCode)),
                            leading: Radio<String>(
                              value: option.id,
                              groupValue: appSettings.adhanId,
                              onChanged: (id) async {
                                if (id == null) return;
                                await appSettings.setAdhanId(id);
                                unawaited(_rescheduleAllPrayerReminders());
                              },
                            ),
                            trailing: IconButton(
                              icon: Icon(_previewingAdhanId == option.id ? Icons.stop_circle_outlined : Icons.play_circle_outline),
                              tooltip: _previewingAdhanId == option.id ? l10n.settingsStopPreview : l10n.settingsListen,
                              onPressed: () => _togglePreviewAdhan(option),
                            ),
                            onTap: () async {
                              await appSettings.setAdhanId(option.id);
                              unawaited(_rescheduleAllPrayerReminders());
                            },
                          ),
                      ],
                      const Divider(height: 24),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsNotifyAtPrayerTime),
                        subtitle: Text(l10n.settingsNotifyAtPrayerTimeSubtitle),
                        value: appSettings.notifyAtPrayerTime,
                        activeTrackColor: AppColors.primaryEmerald,
                        onChanged: (value) async {
                          await appSettings.setNotifyAtPrayerTime(value);
                          unawaited(_rescheduleAllPrayerReminders());
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.settingsPostPrayerReminder),
                        subtitle: Text(appSettings.postPrayerReminderEnabled
                            ? l10n.settingsPostPrayerReminderMinutesLabel(appSettings.postPrayerReminderMinutesAfter)
                            : l10n.settingsPostPrayerReminderSubtitle),
                        value: appSettings.postPrayerReminderEnabled,
                        activeTrackColor: AppColors.primaryEmerald,
                        onChanged: (value) async {
                          await appSettings.setPostPrayerReminderEnabled(value);
                          unawaited(_rescheduleAllPrayerReminders());
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(l10n.settingsReminderNote, style: const TextStyle(fontSize: 11, color: AppColors.mutedText)),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primaryEmerald),
                  title: const Text('Send test notification now'),
                  subtitle: const Text('Diagnostic: checks if notifications can show on this device at all'),
                  onTap: () async {
                    await NotificationService.requestPermission();
                    final error = await NotificationService.showTestNotification();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error == null
                          ? 'Test notification sent -- check your notification shade now.'
                          : 'Failed: ' + error)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.volume_up_rounded, color: AppColors.primaryEmerald),
                  title: const Text('Test Adhan notification now'),
                  subtitle: const Text('Fires the REAL Adhan sound through the REAL notification channel immediately -- no need to wait for an actual prayer time'),
                  onTap: () async {
                    await NotificationService.requestPermission();
                    final error = await NotificationService.showTestAdhanNotification();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(error == null
                          ? 'Test Adhan sent -- you should hear the Adhan sound now.'
                          : 'Failed: ' + error)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              _SectionLabel(l10n.settingsMoreReminders),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(children: [
                    _DailyReminderTile(reminderKey: 'friday', title: l10n.settingsFridayReminder, subtitle: l10n.settingsFridayReminderSubtitle),
                    const Divider(height: 1),
                    _DailyReminderTile(reminderKey: 'morningAzkar', title: l10n.settingsMorningAzkarReminder, subtitle: l10n.settingsMorningAzkarReminderSubtitle),
                    const Divider(height: 1),
                    _DailyReminderTile(reminderKey: 'eveningAzkar', title: l10n.settingsEveningAzkarReminder, subtitle: l10n.settingsEveningAzkarReminderSubtitle),
                    const Divider(height: 1),
                    _DailyReminderTile(reminderKey: 'sleepAzkar', title: l10n.settingsSleepAzkarReminder, subtitle: l10n.settingsSleepAzkarReminderSubtitle),
                    const Divider(height: 1),
                    _DailyReminderTile(reminderKey: 'dailyWird', title: l10n.settingsDailyWirdReminder, subtitle: l10n.settingsDailyWirdReminderSubtitle),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsDailyWirdTarget),
                      subtitle: Text(l10n.settingsDailyWirdPerDay(_wirdTarget)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => _setWirdTarget(_wirdTarget - 1)),
                        Text('$_wirdTarget', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _setWirdTarget(_wirdTarget + 1)),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(l10n.settingsDataManagement),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.menu_book_outlined, color: AppColors.mutedText),
                      title: Text(l10n.settingsQuranLastUpdate),
                      subtitle: Text(_formatCacheDate(_quranCachedAt, languageCode, l10n)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.favorite_outline, color: AppColors.mutedText),
                      title: Text(l10n.settingsAzkarLastUpdate),
                      subtitle: Text(_formatCacheDate(_azkarCachedAt, languageCode, l10n)),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.refresh, color: AppColors.primaryEmerald),
                      title: Text(l10n.settingsUpdateNow),
                      subtitle: Text(l10n.settingsRequiresInternet),
                      onTap: () async {
                        await QuranRepository.load(forceRefresh: true);
                        await AzkarRepository.load(forceRefresh: true);
                        await _loadCacheInfo();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.settingsDataUpdated)),
                          );
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.download_outlined, color: AppColors.mutedText),
                      title: Text(l10n.settingsDownloadedAudio),
                      subtitle: Text(_downloadedAudioSize(l10n)),
                      trailing: _downloadedAudioBytes > 0
                          ? TextButton(
                              onPressed: _confirmDeleteAllDownloads,
                              child: Text(l10n.settingsDeleteAll, style: const TextStyle(color: Colors.red)),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.restart_alt, color: Colors.orange),
                      title: Text(l10n.settingsResetKhatma),
                      subtitle: Text(l10n.settingsResetKhatmaSubtitle),
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.settingsResetKhatma),
                            content: Text(l10n.settingsResetKhatmaBody),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.settingsResetKhatmaConfirm)),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await UserProgressService.resetKhatmaProgress();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.settingsKhatmaResetDone)),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: Text(l10n.settingsDeleteLocalData, style: const TextStyle(color: Colors.red)),
                      onTap: _confirmClearData,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Shows the language picker sheet and applies the choice. Uses a
  /// dedicated "was it dismissed or was System default tapped" signal
  /// (a sentinel Locale) since both map to `null` from Navigator.pop
  /// otherwise.
  Future<void> _showLanguageSheet(BuildContext context, AppLocalizations l10n) async {
    // kLanguageNames already carries the correct native display name for
    // ALL 7 supported locales (it's a plain data map, not tied to l10n
    // getters). The previous version used a switch over l10n.languageName_*
    // getters that only existed for ar/de/tr and silently fell back to
    // "English" for fr/es/id -- which is exactly why "English" showed up
    // multiple times in the sheet for languages that aren't English at all.
    String nameFor(Locale locale) => kLanguageNames[locale.languageCode] ?? locale.languageCode;

    final choice = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.8),
            child: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.settingsLanguage, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
              RadioListTile<bool>(
                value: true,
                groupValue: appSettings.explicitLocale == null,
                activeColor: AppColors.primaryEmerald,
                title: Text(l10n.settingsLanguageSystem),
                onChanged: (_) => Navigator.pop(sheetContext, const Locale('system')),
              ),
              for (final locale in AppSettings.supportedLocales)
                RadioListTile<bool>(
                  value: true,
                  groupValue: appSettings.explicitLocale?.languageCode == locale.languageCode,
                  activeColor: AppColors.primaryEmerald,
                  title: Text(nameFor(locale)),
                  onChanged: (_) => Navigator.pop(sheetContext, locale),
                ),
              const SizedBox(height: 8),
            ],
              ),
            ),
          ),
        );
      },
    );

    if (choice == null) return; // sheet dismissed without a tap
    if (choice.languageCode == 'system') {
      await appSettings.setLocale(null); // "System default"
    } else {
      await appSettings.setLocale(choice);
    }
  }
}

String _prayerKeyLabel(AppLocalizations l10n, String key) => switch (key) {
  'Fajr' => l10n.prayerFajr,
  'Dhuhr' => l10n.prayerDhuhr,
  'Asr' => l10n.prayerAsr,
  'Maghrib' => l10n.prayerMaghrib,
  'Isha' => l10n.prayerIsha,
  _ => key,
};

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.mutedText, fontSize: 13),
      ),
    );
  }
}


class _DailyReminderTile extends StatelessWidget {
  final String reminderKey;
  final String title;
  final String subtitle;
  const _DailyReminderTile({required this.reminderKey, required this.title, required this.subtitle});

  String _formatTime(BuildContext context, int hour, int minute) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final setting = appSettings.dailyReminder(reminderKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle),
          value: setting.enabled,
          activeTrackColor: AppColors.primaryEmerald,
          onChanged: (value) async {
            final l10n = AppLocalizations.of(context);
            await appSettings.setDailyReminder(reminderKey, setting.copyWith(enabled: value));
            if (value) {
              await NotificationService.requestPermission();
            }
            final result = await DailyReminderScheduler.rescheduleAll(l10n);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(result), duration: const Duration(seconds: 6)),
              );
            }
          },
        ),
        if (setting.enabled)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(hour: setting.hour, minute: setting.minute),
                );
                if (picked == null) return;
                if (!context.mounted) return;
                final l10n = AppLocalizations.of(context);
                await appSettings.setDailyReminder(
                  reminderKey,
                  setting.copyWith(hour: picked.hour, minute: picked.minute),
                );
                unawaited(DailyReminderScheduler.rescheduleAll(l10n));
              },
              icon: const Icon(Icons.access_time_outlined),
              label: Text(_formatTime(context, setting.hour, setting.minute)),
            ),
          ),
      ],
    );
  }
}
