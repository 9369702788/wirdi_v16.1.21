import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

/// A single reminder to schedule, already fully localized by the caller
/// (this service has no BuildContext / AppLocalizations access, by
/// design — same separation as prayer_display.dart: stable IDs and
/// scheduling logic live here, localized text is the UI layer's job).
enum RecurrenceType { daily, weeklyFriday }

class RecurringReminder {
  final int id;
  final int hour;
  final int minute;
  final String title;
  final String body;
  final RecurrenceType recurrence;
  const RecurringReminder({
    required this.id,
    required this.hour,
    required this.minute,
    required this.title,
    required this.body,
    required this.recurrence,
  });
}

class ScheduledPrayerNotification {
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
  final bool silent;
  /// When true, this notification plays the real bundled Adhan audio
  /// (as the Android notification sound) instead of the default tone.
  final bool useAdhanSound;
  const ScheduledPrayerNotification({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    this.silent = false,
    this.useAdhanSound = false,
  });
}

/// Schedules real OS-level notifications for upcoming prayers, so
/// reminders fire even if the app isn't open — unlike the previous
/// behavior, which only worked while the Prayer Times screen's in-app
/// countdown timer was actively running.
///
/// Honest limitation: Android alarms scheduled this way don't
/// automatically survive a device reboot unless something reschedules
/// them afterward. This app reschedules on every successful prayer-times
/// fetch (app open, pull-to-refresh, background refresh on Home/Prayer
/// screens) for today + tomorrow, which covers the overwhelmingly common
/// case of opening the app at least once a day. It is not a guarantee
/// for someone who reboots their phone and doesn't open the app for
/// several days.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _timezoneReady = false;

  // Rotated from 'prayer_reminders' -- see WirdiAudioHandler's channel
  // rotation earlier in this project for why: Android permanently
  // remembers a disabled channel across reinstalls.
  static const _testChannelId = 'wirdi_test';
  static const _testChannelName = 'Test notifications';
  static const _reminderChannelId = 'wirdi_prayer_reminder_v2';
  static const _reminderChannelName = 'Prayer reminders';
  static const _reminderChannelDescription = 'Reminders shortly before/after each prayer time';
  static const _adhanChannelId = 'wirdi_prayer_adhan_v2';
  static const _adhanChannelName = 'Adhan';
  static const _adhanChannelDescription = 'Full Adhan audio at prayer time';
  /// FIX: this channel ID was the ONE channel in this file that never
  /// got the same "_v2" rotation the prayer-reminder and Adhan channels
  /// already received (see their own comments above). Android
  /// PERMANENTLY remembers a channel's enabled/disabled state across
  /// app updates AND reinstalls, keyed by this exact string ID -- if
  /// this channel was ever muted/disabled at any point during this
  /// app's testing history (a long-press "turn off notifications for
  /// this category" from the notification shade, a system settings
  /// reset, etc.), every single Friday/morning-azkar/evening-azkar/
  /// daily-wird/sleep-azkar notification would silently stop showing
  /// forever, with the app itself having no way to detect or recover
  /// from that -- exactly the reported symptom. Rotating the ID forces
  /// Android to treat it as a brand-new channel, which always starts
  /// enabled by default, regardless of any prior disabled state tied
  /// to the old ID.
  static const _dailyChannelId = 'wirdi_daily_reminder_v2';
  static const _dailyChannelName = 'Daily reminders';
  static const _dailyChannelDescription = 'Friday, Azkar, and daily Wird reminders';
  static const _scheduledIdsKey = 'notif_scheduled_prayer_ids_v1';
  static const _recurringIdsKey = 'notif_scheduled_recurring_ids_v1';

  static Future<void> initialize() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit, macOS: iosInit);

    try {
      await _plugin.initialize(initSettings);
    } catch (e, st) {
      AppLogger.error('Notification plugin initialization failed', error: e, stackTrace: st);
    }
    _initialized = true;
  }

  /// No need to resolve the device's IANA timezone name (that required
  /// the flutter_timezone plugin, which pulled in a native Kotlin Gradle
  /// Plugin dependency that broke Android builds on some toolchains).
  /// TZDateTime.from() converts by absolute instant
  /// (millisecondsSinceEpoch), not by the Location it's tagged with, so
  /// tagging every scheduled time as UTC is exactly as correct as
  /// resolving the real local zone would have been — [n.fireAt] is
  /// already a correct local DateTime (built from device-local
  /// year/month/day/hour/minute in prayer_service.dart), and combined
  /// (this plugin version schedules using absolute-instant semantics
  /// by default, no extra parameter needed any more), the plugin fires
  /// at the right absolute moment regardless of what
  /// Location label is attached.
  static Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tz_data.initializeTimeZones();
    _timezoneReady = true;
  }

  /// Requests notification permission (Android 13+ / iOS) and, on
  /// Android 12+, the separate exact-alarm permission. Exact-alarm denial
  /// isn't fatal — [scheduleAll] falls back to inexact scheduling, which
  /// still delivers the reminder, just with looser timing (usually still
  /// within a minute or two).
  static Future<bool> requestPermission() async {
    await initialize();

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      bool granted = true;
      try {
        granted = await androidImpl.requestNotificationsPermission() ?? true;
      } catch (e, st) {
        AppLogger.error('Notification permission request failed', error: e, stackTrace: st);
      }
      try {
        await androidImpl.requestExactAlarmsPermission();
      } catch (e, st) {
        AppLogger.error('Exact alarm permission request failed', error: e, stackTrace: st);
      }
      return granted;
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      try {
        return await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ?? true;
      } catch (e, st) {
        AppLogger.error('iOS notification permission request failed', error: e, stackTrace: st);
        return false;
      }
    }

    return true;
  }

  /// Cancels only the reminders this service previously scheduled
  /// (tracked by ID in SharedPreferences), not a blind fixed ID range —
  /// keeps this cheap even though it runs on every prayer-times refresh.
  static Future<void> cancelAllScheduled() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_scheduledIdsKey) ?? const [];
    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id != null) {
        try {
          await _plugin.cancel(id);
        } catch (e, st) {
          AppLogger.error('Failed to cancel notification $id', error: e, stackTrace: st);
        }
      }
    }
    await prefs.setStringList(_scheduledIdsKey, const []);
  }

  static Future<void> cancelAllRecurring() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_recurringIdsKey) ?? const [];
    for (final idStr in ids) {
      final id = int.tryParse(idStr);
      if (id != null) {
        try {
          await _plugin.cancel(id);
        } catch (e, st) {
          AppLogger.error('Failed to cancel recurring notification $id', error: e, stackTrace: st);
        }
      }
    }
    await prefs.setStringList(_recurringIdsKey, const []);
  }

  /// Fires an OS notification immediately (no scheduling/timezone/exact-
  /// alarm logic involved) so we can tell, in one tap, whether
  /// notifications can display on this device AT ALL -- independent of
  /// whether a specific scheduled reminder's timing/permission logic
  /// is the problem.
  static Future<String?> showTestNotification() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      _testChannelId,
      _testChannelName,
      channelDescription: 'Manual diagnostic test notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails(presentSound: true));
    try {
      await _plugin.show(999999, 'Wirdi test notification', 'If you can see this, notifications work on this device.', details);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// ROOT CAUSE FIX (v128): AndroidScheduleMode.exactAllowWhileIdle
  /// (SCHEDULE_EXACT_ALARM's AlarmManager.setExactAndAllowWhileIdle)
  /// was confirmed, via this exact diagnostic tool, to be silently
  /// non-delivering on at least one real device even with every
  /// relevant Android permission granted (POST_NOTIFICATIONS,
  /// SCHEDULE_EXACT_ALARM) AND with battery optimization/"sleeping
  /// apps" restrictions fully disabled for this app. This is a known
  /// class of issue on some OEM ROMs (notably Samsung One UI), where
  /// the OS's own power-management daemon can still deprioritize or
  /// silently drop a "while idle" exact alarm despite the app-level
  /// permission being granted.
  ///
  /// AndroidScheduleMode.alarmClock uses
  /// AlarmManager.setAlarmClock() instead -- the SAME underlying API
  /// real alarm-clock apps use. Android's power management treats
  /// this category of alarm as a hard commitment to the user (a
  /// visible alarm-clock icon appears in the status bar) and is
  /// documented to be exempt from Doze/App Standby restrictions far
  /// more reliably than any "while idle" exact-alarm variant. This is
  /// the appropriate mechanism for a genuinely time-critical wake-up
  /// event like a prayer Adhan, and is now used here, in
  /// scheduleAll() (prayer notifications), and in scheduleRecurring()
  /// (daily azkar/wird/Friday reminders) -- previously all three used
  /// exactAllowWhileIdle as their primary attempt.
  ///
  /// Schedules (does NOT show immediately) a diagnostic notification
  /// ~1 minute in the future, self-contained so it proves or
  /// disproves "does scheduled delivery even work on this device"
  /// within one minute, instead of needing to wait for a real prayer
  /// time or daily reminder to (maybe) fire.
  static Future<String?> scheduleTestNotificationSoon() async {
    await initialize();
    await _ensureTimezone();
    const androidDetails = AndroidNotificationDetails(
      _testChannelId,
      _testChannelName,
      channelDescription: 'Manual diagnostic test notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails(presentSound: true));
    final fireAt = DateTime.now().add(const Duration(minutes: 1));
    final tzTime = tz.TZDateTime.from(fireAt, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        999998,
        'Wirdi scheduled test',
        'If you see this about 1 minute after tapping the button, scheduled notifications DO work on this device.',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Fires an immediate notification through the SAME channel and the
  /// SAME real bundled Adhan audio resource used for actual prayer-time
  /// notifications -- lets the Adhan sound specifically be verified
  /// right now, without waiting for a real prayer time to arrive.
  static Future<String?> showTestAdhanNotification() async {
    await initialize();
    const androidDetails = AndroidNotificationDetails(
      _adhanChannelId,
      _adhanChannelName,
      channelDescription: _adhanChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('adhan_sound'),
      audioAttributesUsage: AudioAttributesUsage.notification,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails(presentSound: true));
    try {
      await _plugin.show(999998, 'Wirdi -- test Adhan', 'This is the real Adhan sound/channel used at prayer time.', details);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Returns a human-readable summary of what actually got scheduled
  /// (or why it failed) -- e.g. "Scheduled: Morning Azkar at 06:00" or
  /// "Failed: Morning Azkar -- <real exception text>". Lets the UI show
  /// the caller exactly what happened instead of silently trusting it.
  static Future<String> scheduleRecurring(List<RecurringReminder> reminders) async {
    await initialize();
    await _ensureTimezone();
    await cancelAllRecurring();
    final summary = <String>[];

    const androidDetails = AndroidNotificationDetails(
      _dailyChannelId,
      _dailyChannelName,
      channelDescription: _dailyChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());

    final scheduledIds = <String>[];
    final nowLocal = DateTime.now();

    for (final r in reminders) {
      var scheduledLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day, r.hour, r.minute);
      if (scheduledLocal.isBefore(nowLocal)) {
        scheduledLocal = scheduledLocal.add(const Duration(days: 1));
      }
      if (r.recurrence == RecurrenceType.weeklyFriday) {
        while (scheduledLocal.weekday != DateTime.friday) {
          scheduledLocal = scheduledLocal.add(const Duration(days: 1));
        }
      }
      final scheduled = tz.TZDateTime.from(scheduledLocal, tz.UTC);

      final matchComponents = r.recurrence == RecurrenceType.daily
          ? DateTimeComponents.time
          : DateTimeComponents.dayOfWeekAndTime;
      try {
        // ROOT CAUSE FIX (v132): AndroidScheduleMode.alarmClock is a
        // one-shot exact-alarm API (AlarmManager.setAlarmClock()) with
        // no native support for "and repeat this on a schedule" --
        // pairing it with matchDateTimeComponents (which is what makes
        // this a TRUE recurring daily/weekly reminder rather than a
        // single one-off notification) either silently drops the
        // recurrence or fails outright depending on the OS/plugin
        // version. v128 mistakenly switched this call to alarmClock
        // along with the (correctly one-shot) prayer-notification and
        // test-button calls, which is exactly why every recurring
        // reminder (Friday, morning/evening Azkar, daily wird, sleep
        // Azkar) stopped firing at that point. exactAllowWhileIdle
        // DOES support matchDateTimeComponents correctly and is the
        // right primary choice for a genuinely recurring reminder.
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: matchComponents,
        );
        scheduledIds.add('${r.id}');
        summary.add('OK: ' + r.body + ' at ' + r.hour.toString().padLeft(2, '0') + ':' + r.minute.toString().padLeft(2, '0'));
      } catch (e, st) {
        AppLogger.error('Exact recurring scheduling failed for reminder ${r.id}, retrying inexact', error: e, stackTrace: st);
        try {
          await _plugin.zonedSchedule(
            r.id,
            r.title,
            r.body,
            scheduled,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            matchDateTimeComponents: matchComponents,
          );
          scheduledIds.add('${r.id}');
        } catch (e2, st2) {
          AppLogger.error('Inexact recurring scheduling also failed for reminder ${r.id}', error: e2, stackTrace: st2);
          summary.add('FAILED: ' + r.body + ' -- ' + e2.toString());
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recurringIdsKey, scheduledIds);
    return summary.isEmpty ? 'No reminders enabled' : summary.join('\n');
  }

  /// Replaces all currently-scheduled prayer reminders with
  /// [notifications]. Called after every successful prayer-times fetch
  /// so the schedule always reflects the latest times/location and never
  /// silently goes stale.
  static Future<void> scheduleAll(List<ScheduledPrayerNotification> notifications) async {
    await initialize();
    await _ensureTimezone();
    await cancelAllScheduled();

    final now = DateTime.now();
    final scheduledIds = <String>[];

    for (final n in notifications) {
      if (n.fireAt.isBefore(now)) continue; // never schedule something already in the past

      final androidDetails = AndroidNotificationDetails(
        n.useAdhanSound ? _adhanChannelId : _reminderChannelId,
        n.useAdhanSound ? _adhanChannelName : _reminderChannelName,
        channelDescription: n.useAdhanSound ? _adhanChannelDescription : _reminderChannelDescription,
        importance: n.silent ? Importance.low : Importance.high,
        priority: n.silent ? Priority.low : Priority.high,
        playSound: !n.silent,
        enableVibration: !n.silent,
        sound: (!n.silent && n.useAdhanSound)
            ? const RawResourceAndroidNotificationSound('adhan_sound')
            : null,
        audioAttributesUsage: AudioAttributesUsage.notification,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(presentSound: !n.silent),
      );

      final tzTime = tz.TZDateTime.from(n.fireAt, tz.UTC);
      try {
        await _plugin.zonedSchedule(
          n.id,
          n.title,
          n.body,
          tzTime,
          details,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
        );
        scheduledIds.add('${n.id}');
      } catch (e, st) {
        AppLogger.error('Exact scheduling failed for notification ${n.id}, retrying inexact', error: e, stackTrace: st);
        try {
          await _plugin.zonedSchedule(
            n.id,
            n.title,
            n.body,
            tzTime,
            details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
          scheduledIds.add('${n.id}');
        } catch (e2, st2) {
          AppLogger.error('Inexact scheduling also failed for notification ${n.id}', error: e2, stackTrace: st2);
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_scheduledIdsKey, scheduledIds);
  }
}
