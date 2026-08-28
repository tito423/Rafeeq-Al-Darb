import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart' as import_permission;
import 'prayer_times_service.dart';
import '../models/prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart' as import_material;
import '../../app/rafeeq_app.dart' as import_app;
import '../../features/quran/presentation/screens/surah_reading_screen.dart' as import_surah;
import '../../features/azkar/presentation/screens/azkar_detail_screen.dart' as import_azkar;
import '../../features/prayer/presentation/screens/full_screen_adhan_screen.dart';
import '../../features/prayer/domain/adhan_player_controller.dart';
import 'package:hijri/hijri.dart';
import 'package:flutter/services.dart';

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

    // The channel will be created automatically when scheduling with the dynamic ID and custom sound.
    // if (Platform.isAndroid) {
    //   ...
    // }

    _initialized = true;
  }

  // ── Request permissions ───────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    bool granted = false;
    if (Platform.isAndroid) {
      final plugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      granted = await plugin?.requestNotificationsPermission() ?? false;
      
      // Request battery exemption and exact alarms for smooth background adhan
      try {
        final batteryStatus = await import_permission.Permission.ignoreBatteryOptimizations.status;
        if (!batteryStatus.isGranted) {
          await import_permission.Permission.ignoreBatteryOptimizations.request();
        }
        
        final alarmStatus = await import_permission.Permission.scheduleExactAlarm.status;
        if (!alarmStatus.isGranted) {
          await import_permission.Permission.scheduleExactAlarm.request();
        }
      } catch (e) {
        debugPrint('Error requesting background permissions: $e');
      }
      
      return granted;
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

    final muezzinId = prefs.getString('selectedMuezzin') ?? 'makkah';
    
    // Check per-prayer adhan mode
    final prayerMode = prefs.getString('prayer_adhan_mode_$prayerName') ?? 'animated';
    final bool playSound = prayerMode != 'silent' && prayerMode != 'vibrate_only';
    final bool enableVibration = prayerMode != 'silent';
    final bool fullScreen = prayerMode == 'animated';
    final bool isSilentMode = prayerMode == 'silent';
    
    final androidDetails = AndroidNotificationDetails(
      '${_adhanChannelId}_$muezzinId',
      _adhanChannelName,
      channelDescription: _adhanChannelDesc,
      importance: isSilentMode ? Importance.low : Importance.max,
      priority: isSilentMode ? Priority.low : Priority.high,
      playSound: playSound,
      sound: playSound ? RawResourceAndroidNotificationSound('adhan_$muezzinId') : null,
      enableVibration: enableVibration,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: fullScreen,
      ongoing: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'dismiss',
          'إيقاف الأذان',
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'mute',
          'صامت',
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
      sound: playSound ? 'adhan.aiff' : null,
      presentAlert: !isSilentMode,
      presentBadge: !isSilentMode,
      presentSound: playSound,
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
        payload: 'adhan_${prayerName}_${muezzinId}_$prayerMode',
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

  // ── Live Persistent Prayer Notification ───────────────────────────────────
  static const _liveChannelId = 'live_prayer_channel';
  static const _liveChannelName = 'الصلاة القادمة';
  static const _liveChannelDesc = 'عرض الصلاة القادمة والوقت المتبقي لها';

  static const _platform = MethodChannel('com.tito.rafeeq_aldarb/salatuk_notification');

  Future<void> updateLivePrayerNotification(PrayerTimes pt) async {
    if (!Platform.isAndroid) return;
    await initialize();

    final now = DateTime.now();
    final prayers = [
      (nameAr: 'الفجر',   time: _parseToDateTime(pt.fajr)),
      (nameAr: 'الشروق', time: _parseToDateTime(pt.sunrise)),
      (nameAr: 'الظهر',   time: _parseToDateTime(pt.dhuhr)),
      (nameAr: 'العصر',   time: _parseToDateTime(pt.asr)),
      (nameAr: 'المغرب',  time: _parseToDateTime(pt.maghrib)),
      (nameAr: 'العشاء',  time: _parseToDateTime(pt.isha)),
    ];

    String nextPrayerName = 'الفجر';
    DateTime? nextPrayerTime;
    int activeIndex = 0;

    for (int i = 0; i < prayers.length; i++) {
      final p = prayers[i];
      if (p.time != null && p.time!.isAfter(now)) {
        nextPrayerName = p.nameAr;
        nextPrayerTime = p.time;
        activeIndex = i;
        break;
      }
    }

    if (nextPrayerTime == null) {
      // It's after Isha, next is Fajr tomorrow.
      final t = _parseToDateTime(pt.fajr);
      if (t != null) {
        nextPrayerTime = t.add(const Duration(days: 1));
        nextPrayerName = 'الفجر';
        activeIndex = 0;
      } else {
        return;
      }
    }

    try {
      await _platform.invokeMethod('updateNotification', {
        'nextPrayerName': nextPrayerName,
        'nextPrayerTimeMs': nextPrayerTime.millisecondsSinceEpoch,
        'times': [
          pt.fajr,
          pt.sunrise,
          pt.dhuhr,
          pt.asr,
          pt.maghrib,
          pt.isha,
        ],
        'activeIndex': activeIndex,
      });
    } catch (e) {
      debugPrint("Failed to update custom native notification: $e");
    }
  }

  Future<void> cancelLivePrayerNotification() async {
    if (Platform.isAndroid) {
      try {
        await _platform.invokeMethod('cancelNotification');
      } catch (e) {
         debugPrint("Failed to cancel custom native notification: $e");
      }
    }
    await _plugin.cancel(100);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static const Map<int, ({String ar, String en, int page})> _surahMetadata = {
    2: (ar: 'البقرة', en: 'Al-Baqarah', page: 2),
    18: (ar: 'الكهف', en: 'Al-Kahf', page: 293),
    32: (ar: 'السجدة', en: 'As-Sajdah', page: 415),
    67: (ar: 'الملك', en: 'Al-Mulk', page: 562),
  };

  void _onNotificationTap(NotificationResponse response) async {
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
      // Mode is at index 3: 'animated', 'audio_only', 'vibrate_only', or 'silent'
      final mode = parts.length > 3 ? parts[3] : 'animated';
      
      if (mode == 'silent') {
        // Silent mode - do nothing, just dismiss
        return;
      } else if (mode == 'vibrate_only') {
        // Vibrate only - no audio, no screen
        return;
      } else if (mode == 'audio_only') {
        // Just play in background
        playAdhanInBackground(pName, mMuezzin);
      } else {
        // 'animated' - Full screen adhan with animation
        import_app.navigatorKey.currentState?.push(
          import_material.MaterialPageRoute(
            builder: (_) => FullScreenAdhanScreen(
              prayerName: pName,
              muezzinName: mMuezzin,
            ),
          ),
        );
      }
      return;
    } else if (response.payload != null && response.payload!.startsWith('azkar_')) {
      final parts = response.payload!.split('_');
      final catKey = parts.length > 1 ? parts[1] : 'صباح';
      final catName = catKey == 'صباح' ? 'أذكار الصباح' : (catKey == 'مساء' ? 'أذكار المساء' : 'الأذكار');
      import_app.navigatorKey.currentState?.push(
        import_material.MaterialPageRoute(
          builder: (_) => import_azkar.AzkarDetailScreen(
            categoryKey: catKey,
            categoryName: catName,
            gradientColors: const [import_material.Color(0xFF1B3328), import_material.Color(0xFF0F1714)],
          ),
        ),
      );
      return;
    } else if (response.payload != null && response.payload!.startsWith('quran_wird_')) {
      import_app.navigatorKey.currentState?.push(
        import_material.MaterialPageRoute(
          builder: (_) => const import_surah.SurahReadingScreen(
            surahId: 1,
            surahNameAr: 'سورة الفاتحة',
            surahNameEn: 'Al-Fatihah',
            startPage: 1,
          ),
        ),
      );
      return;
    }

    // Handle tap / action buttons
    switch (response.actionId) {
      case 'dismiss':
        // Stop audio and cancel notification (already cancelled by cancelNotification: true)
        AdhanPlayerController.stop();
        break;
      case 'mute':
        // Mute audio (toggle mute)
        AdhanPlayerController.mute();
        break;
    }
  }

  // Check if app was launched via notification (e.g. from fullScreenIntent)
  Future<bool> checkInitialNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp && details.notificationResponse != null) {
      // Delay to ensure the navigator is mounted when launching from cold start
      Future.delayed(const Duration(milliseconds: 500), () {
        _onNotificationTap(details.notificationResponse!);
      });
      return true;
    }
    return false;
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

  // ── Athkar & Wird Daily Alarms (Sakanty Style) ───────────────────────────

  static const _athkarChannelId = 'athkar_channel';
  static const _athkarChannelName = 'أذكار الصباح والمساء والورد';
  static const _athkarChannelDesc = 'تنبيهات أذكار الصباح وأذكار المساء والورد القرآني';

  Future<void> scheduleAthkarAndWirdReminders({
    required bool morningAthkar, required import_material.TimeOfDay morningAthkarTime,
    required bool eveningAthkar, required import_material.TimeOfDay eveningAthkarTime,
    required bool morningWird, required import_material.TimeOfDay morningWirdTime,
    required bool eveningWird, required import_material.TimeOfDay eveningWirdTime,
  }) async {
    await initialize();

    // Cancel previous alarms
    await _plugin.cancel(30);
    await _plugin.cancel(31);
    await _plugin.cancel(32);
    await _plugin.cancel(33);

    // 1. Morning Athkar
    if (morningAthkar) {
      await _scheduleDailyReminder(
        id: 30,
        title: 'أذكار الصباح 🌅',
        body: 'أصبحنا وأصبح الملك لله.. ابدأ يومك بذكر الله وطمأنينة القلب',
        hour: morningAthkarTime.hour,
        minute: morningAthkarTime.minute,
        payload: 'azkar_صباح',
      );
    }

    // 2. Evening Athkar
    if (eveningAthkar) {
      await _scheduleDailyReminder(
        id: 31,
        title: 'أذكار المساء 🌙',
        body: 'أمسينا وأمسى الملك لله.. حصّن نفسك وأهلك بأذكار المساء',
        hour: eveningAthkarTime.hour,
        minute: eveningAthkarTime.minute,
        payload: 'azkar_مساء',
      );
    }

    // 3. Morning Quran Wird
    if (morningWird) {
      await _scheduleDailyReminder(
        id: 32,
        title: 'ورد القرآن الصباحي 📖',
        body: 'رتّل آيات من كتاب الله لتستفتح بها يومك بالبركة والهدى',
        hour: morningWirdTime.hour,
        minute: morningWirdTime.minute,
        payload: 'quran_wird_morning',
      );
    }

    // 4. Evening Quran Wird
    if (eveningWird) {
      await _scheduleDailyReminder(
        id: 33,
        title: 'ورد القرآن المسائي 📖',
        body: 'لا تنسَ تلاوة وردك اليومي من القرآن الكريم قبل غروب الشمس',
        hour: eveningWirdTime.hour,
        minute: eveningWirdTime.minute,
        payload: 'quran_wird_evening',
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>(
  (_) => NotificationService(),
);
