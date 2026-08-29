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
  static const _dailyChannelId = 'wirdi_daily_reminder';
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
  /// with `uiLocalNotificationDateInterpretation: absoluteTime` below,
  /// the plugin fires at the right absolute moment regardless of what
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
        await _plugin.zonedSchedule(
          r.id,
          r.title,
          r.body,
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
