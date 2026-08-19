import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_service.dart';
import '../models/prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart' as import_material;
import '../../app/rafeeq_app.dart' as import_app;
import '../../features/quran/presentation/screens/surah_reading_screen.dart' as import_surah;
import '../../features/prayer/presentation/screens/full_screen_adhan_screen.dart';

// ── Notification IDs ──────────────────────────────────────────────────────────

class _NotifIds {
  static const int fajr    = 10;
  static const int sunrise = 11;
  static const int dhuhr   = 12;
  static const int asr     = 13;
  static const int maghrib = 14;
  static const int isha    = 15;
}

// ── Service ───────────────────────────────────────────────────────────────────

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Android notification channel for Adhan ────────────────────────────────

  static const _adhanChannelId   = 'adhan_channel';
  static const _adhanChannelName = 'أذان الصلاة';
  static const _adhanChannelDesc = 'إشعارات أذان مواقيت الصلاة';

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings  = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create the high-priority Adhan sound channel (Android only)
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _adhanChannelId,
              _adhanChannelName,
              description: _adhanChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              enableLights: true,
            ),
          );
    }

    _initialized = true;
  }

  // ── Request permissions ───────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final plugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await plugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final plugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await plugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  // ── Schedule prayer notifications ─────────────────────────────────────────

  /// Schedule all 5 prayer notifications for today based on PrayerTimes data.
  Future<void> schedulePrayerNotifications(PrayerTimes pt) async {
    await initialize();

    // Cancel any previously scheduled prayer notifications
    await cancelPrayerNotifications();

    final prefs = await SharedPreferences.getInstance();
    final globalEnabled = prefs.getBool('globalNotifications') ?? true;
    if (!globalEnabled) return;

    final prayers = [
      (nameAr: 'الفجر',   time: pt.fajr,    id: _NotifIds.fajr),
      (nameAr: 'الظهر',   time: pt.dhuhr,   id: _NotifIds.dhuhr),
      (nameAr: 'العصر',   time: pt.asr,     id: _NotifIds.asr),
      (nameAr: 'المغرب',  time: pt.maghrib, id: _NotifIds.maghrib),
      (nameAr: 'العشاء',  time: pt.isha,    id: _NotifIds.isha),
    ];

    final now = DateTime.now();

    for (final p in prayers) {
      final isEnabled = prefs.getBool('prayer_${p.nameAr}') ?? (p.nameAr != 'الشروق');
      if (!isEnabled) continue;

      final scheduledTime = _parseToDateTime(p.time);
      if (scheduledTime == null || scheduledTime.isBefore(now)) continue;

      await _schedulePrayerNotification(
        id: p.id,
        prayerName: p.nameAr,
        prayerTime: scheduledTime,
      );
    }
  }

  Future<void> _schedulePrayerNotification({
    required int id,
    required String prayerName,
    required DateTime prayerTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? '';
    final greeting = userName.isNotEmpty ? 'يا $userName' : '';

    final androidDetails = AndroidNotificationDetails(
      _adhanChannelId,
      _adhanChannelName,
      channelDescription: _adhanChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true, // Wake device and bypass keyguard
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'dismiss',
          'إيقاف الأذان',
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze',
          'تأجيل ١٠ دقائق',
          cancelNotification: false,
        ),
      ],
      styleInformation: BigTextStyleInformation(
        'يمكنك الآن سماع الأذان أو إيقافه مؤقتاً',
        contentTitle: 'حان وقت $prayerName $greeting',
        summaryText: 'رفيق الدرب',
      ),
    );

    final iosDetails = DarwinNotificationDetails(
      sound: 'adhan.aiff',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notifDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        'حان وقت $prayerName $greeting',
        'يمكنك الآن سماع الأذان أو إيقافه مؤقتاً',
        _toTZDateTime(prayerTime),
        notifDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'adhan_${prayerName}_${prefs.getString('selectedMuezzin') ?? 'makkah'}',
      );
    } catch (e) {
      debugPrint('NotificationService: failed to schedule $prayerName — $e');
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> cancelPrayerNotifications() async {
    for (final id in [
      _NotifIds.fajr,
      _NotifIds.dhuhr,
      _NotifIds.asr,
      _NotifIds.maghrib,
      _NotifIds.isha,
    ]) {
      await _plugin.cancel(id);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  // ── Show immediate notification (for testing) ─────────────────────────────

  Future<void> showImmediate({
    required String title,
    required String body,
    int id = 99,
  }) async {
    await initialize();
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _adhanChannelId,
          _adhanChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const Map<int, ({String ar, String en, int page})> _surahMetadata = {
    2: (ar: 'البقرة', en: 'Al-Baqarah', page: 2),
    18: (ar: 'الكهف', en: 'Al-Kahf', page: 293),
    32: (ar: 'السجدة', en: 'As-Sajdah', page: 415),
    67: (ar: 'الملك', en: 'Al-Mulk', page: 562),
  };

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && response.payload!.startsWith('surah_')) {
      final surahNumber = int.tryParse(response.payload!.split('_')[1]);
      if (surahNumber != null) {
        final meta = _surahMetadata[surahNumber] ??
            (ar: 'سورة $surahNumber', en: 'Surah $surahNumber', page: 1);
        import_app.navigatorKey.currentState?.push(
          import_material.MaterialPageRoute(
            builder: (_) => import_surah.SurahReadingScreen(
              surahId: surahNumber,
              surahNameAr: meta.ar,
              surahNameEn: meta.en,
              startPage: meta.page,
            ),
          ),
        );
        return;
      }
    } else if (response.payload != null && response.payload!.startsWith('adhan_')) {
      final parts = response.payload!.split('_');
      final pName = parts.length > 1 ? parts[1] : 'الصلاة';
      final mMuezzin = parts.length > 2 ? parts[2] : 'مكة';
      import_app.navigatorKey.currentState?.push(
        import_material.MaterialPageRoute(
          builder: (_) => FullScreenAdhanScreen(
            prayerName: pName,
            muezzinName: mMuezzin,
          ),
        ),
      );
      return;
    }

    // Handle tap / action buttons
    switch (response.actionId) {
      case 'dismiss':
        // Already cancelled by cancelNotification: true
        break;
      case 'snooze':
        // Re-schedule 10 minutes later
        final snoozeTime = DateTime.now().add(const Duration(minutes: 10));
        _schedulePrayerNotification(
          id: response.id ?? 99,
          prayerName: 'الصلاة',
          prayerTime: snoozeTime,
        );
        break;
    }
  }

  DateTime? _parseToDateTime(String timeStr) {
    if (timeStr == '--:--') return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, h, m);
  }

  // Convert DateTime to TZDateTime using local timezone offset
  tz.TZDateTime _toTZDateTime(DateTime dt) {
    return tz.TZDateTime.from(dt, tz.local);
  }

  // ── Surah Reminders ───────────────────────────────────────────────────────

  static const _surahChannelId = 'surah_reminders_channel';
  static const _surahChannelName = 'تنبيهات السور';
  static const _surahChannelDesc = 'تنبيهات قراءة سورة البقرة، الكهف، الملك، والسجدة';

  Future<void> scheduleSurahReminders({
    required bool isKahfEnabled, required dynamic kahfTime,
    required bool isMulkEnabled, required dynamic mulkTime,
    required bool isSajdahEnabled, required dynamic sajdahTime,
    required bool isBaqarahEnabled, required dynamic baqarahTime,
  }) async {
    await initialize();

    // Cancel old reminders
    await _plugin.cancel(20); // Kahf
    await _plugin.cancel(21); // Mulk
    await _plugin.cancel(22); // Sajdah
    await _plugin.cancel(23); // Baqarah

    if (isBaqarahEnabled) {
      _scheduleDailyReminder(
        id: 23,
        title: 'تذكير بقراءة سورة البقرة',
        body: 'أخذها بركة وتركها حسرة. اضغط هنا للقراءة.',
        hour: baqarahTime.hour,
        minute: baqarahTime.minute,
        payload: 'surah_2',
      );
    }

    if (isKahfEnabled) {
      _scheduleWeeklyReminder(
        id: 20,
        title: 'تذكير بقراءة سورة الكهف',
        body: 'نور ما بين الجمعتين. اضغط هنا للقراءة.',
        day: DateTime.friday,
        hour: kahfTime.hour,
        minute: kahfTime.minute,
        payload: 'surah_18',
      );
    }

    if (isSajdahEnabled) {
      _scheduleWeeklyReminder(
        id: 22,
        title: 'تذكير بقراءة سورة السجدة',
        body: 'كان النبي ﷺ يقرأها يوم الجمعة. اضغط للقراءة.',
        day: DateTime.friday,
        hour: sajdahTime.hour,
        minute: sajdahTime.minute,
        payload: 'surah_32',
      );
    }

    if (isMulkEnabled) {
      _scheduleDailyReminder(
        id: 21,
        title: 'تذكير بقراءة سورة الملك',
        body: 'المنجية من عذاب القبر. اضغط هنا للقراءة.',
        hour: mulkTime.hour,
        minute: mulkTime.minute,
        payload: 'surah_67',
      );
    }
  }

  Future<void> _scheduleWeeklyReminder({
    required int id,
    required String title,
    required String body,
    required int day,
    required int hour,
    required int minute,
    required String payload,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    await _scheduleReminder(id, title, body, scheduledDate, matchComponents: DateTimeComponents.dayOfWeekAndTime, payload: payload);
  }

  Future<void> _scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String payload,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _scheduleReminder(id, title, body, scheduledDate, matchComponents: DateTimeComponents.time, payload: payload);
  }

  Future<void> _scheduleReminder(int id, String title, String body, tz.TZDateTime scheduledDate, {DateTimeComponents? matchComponents, String? payload}) async {
    const androidDetails = AndroidNotificationDetails(
      _surahChannelId,
      _surahChannelName,
      channelDescription: _surahChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const notifDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
      payload: payload,
    );
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);
