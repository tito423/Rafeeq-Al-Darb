import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/notification_service.dart';

final alertSettingsProvider = StateNotifierProvider<AlertSettingsNotifier, AlertSettingsState>((ref) {
  return AlertSettingsNotifier(ref);
});

class AlertSettingsState {
  final bool isKahfEnabled;
  final TimeOfDay kahfTime;
  final bool isMulkEnabled;
  final TimeOfDay mulkTime;
  final bool isSajdahEnabled;
  final TimeOfDay sajdahTime;
  final bool isBaqarahEnabled;
  final TimeOfDay baqarahTime;

  // New Azkar/Wird settings
  final bool isMorningAthkarEnabled;
  final TimeOfDay morningAthkarTime;
  final bool isEveningAthkarEnabled;
  final TimeOfDay eveningAthkarTime;
  final bool isMorningWirdEnabled;
  final TimeOfDay morningWirdTime;
  final bool isEveningWirdEnabled;
  final TimeOfDay eveningWirdTime;

  AlertSettingsState({
    this.isKahfEnabled = false,
    this.kahfTime = const TimeOfDay(hour: 9, minute: 0),
    this.isMulkEnabled = false,
    this.mulkTime = const TimeOfDay(hour: 22, minute: 0),
    this.isSajdahEnabled = false,
    this.sajdahTime = const TimeOfDay(hour: 5, minute: 0),
    this.isBaqarahEnabled = false,
    this.baqarahTime = const TimeOfDay(hour: 7, minute: 0),

    this.isMorningAthkarEnabled = false,
    this.morningAthkarTime = const TimeOfDay(hour: 5, minute: 0),
    this.isEveningAthkarEnabled = false,
    this.eveningAthkarTime = const TimeOfDay(hour: 16, minute: 30),
    this.isMorningWirdEnabled = false,
    this.morningWirdTime = const TimeOfDay(hour: 5, minute: 0),
    this.isEveningWirdEnabled = false,
    this.eveningWirdTime = const TimeOfDay(hour: 16, minute: 30),
  });

  AlertSettingsState copyWith({
    bool? isKahfEnabled,
    TimeOfDay? kahfTime,
    bool? isMulkEnabled,
    TimeOfDay? mulkTime,
    bool? isSajdahEnabled,
    TimeOfDay? sajdahTime,
    bool? isBaqarahEnabled,
    TimeOfDay? baqarahTime,
    bool? isMorningAthkarEnabled,
    TimeOfDay? morningAthkarTime,
    bool? isEveningAthkarEnabled,
    TimeOfDay? eveningAthkarTime,
    bool? isMorningWirdEnabled,
    TimeOfDay? morningWirdTime,
    bool? isEveningWirdEnabled,
    TimeOfDay? eveningWirdTime,
  }) {
    return AlertSettingsState(
      isKahfEnabled: isKahfEnabled ?? this.isKahfEnabled,
      kahfTime: kahfTime ?? this.kahfTime,
      isMulkEnabled: isMulkEnabled ?? this.isMulkEnabled,
      mulkTime: mulkTime ?? this.mulkTime,
      isSajdahEnabled: isSajdahEnabled ?? this.isSajdahEnabled,
      sajdahTime: sajdahTime ?? this.sajdahTime,
      isBaqarahEnabled: isBaqarahEnabled ?? this.isBaqarahEnabled,
      baqarahTime: baqarahTime ?? this.baqarahTime,
      isMorningAthkarEnabled: isMorningAthkarEnabled ?? this.isMorningAthkarEnabled,
      morningAthkarTime: morningAthkarTime ?? this.morningAthkarTime,
      isEveningAthkarEnabled: isEveningAthkarEnabled ?? this.isEveningAthkarEnabled,
      eveningAthkarTime: eveningAthkarTime ?? this.eveningAthkarTime,
      isMorningWirdEnabled: isMorningWirdEnabled ?? this.isMorningWirdEnabled,
      morningWirdTime: morningWirdTime ?? this.morningWirdTime,
      isEveningWirdEnabled: isEveningWirdEnabled ?? this.isEveningWirdEnabled,
      eveningWirdTime: eveningWirdTime ?? this.eveningWirdTime,
    );
  }
}

class AlertSettingsNotifier extends StateNotifier<AlertSettingsState> {
  final Ref ref;

  AlertSettingsNotifier(this.ref) : super(AlertSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final kahfEnabled = prefs.getBool('alert_kahf_enabled') ?? false;
    final kahfHour = prefs.getInt('alert_kahf_hour') ?? 9;
    final kahfMinute = prefs.getInt('alert_kahf_minute') ?? 0;
    
    final mulkEnabled = prefs.getBool('alert_mulk_enabled') ?? false;
    final mulkHour = prefs.getInt('alert_mulk_hour') ?? 22;
    final mulkMinute = prefs.getInt('alert_mulk_minute') ?? 0;
    
    final sajdahEnabled = prefs.getBool('alert_sajdah_enabled') ?? false;
    final sajdahHour = prefs.getInt('alert_sajdah_hour') ?? 5;
    final sajdahMinute = prefs.getInt('alert_sajdah_minute') ?? 0;

    final baqarahEnabled = prefs.getBool('alert_baqarah_enabled') ?? false;
    final baqarahHour = prefs.getInt('alert_baqarah_hour') ?? 7;
    final baqarahMinute = prefs.getInt('alert_baqarah_minute') ?? 0;

    // Load Azkar / Wird settings
    final mAthkarEnabled = prefs.getBool('alert_morning_athkar_enabled') ?? false;
    final mAthkarHour = prefs.getInt('alert_morning_athkar_hour') ?? 5;
    final mAthkarMinute = prefs.getInt('alert_morning_athkar_minute') ?? 0;

    final eAthkarEnabled = prefs.getBool('alert_evening_athkar_enabled') ?? false;
    final eAthkarHour = prefs.getInt('alert_evening_athkar_hour') ?? 16;
    final eAthkarMinute = prefs.getInt('alert_evening_athkar_minute') ?? 30;

    final mWirdEnabled = prefs.getBool('alert_morning_wird_enabled') ?? false;
    final mWirdHour = prefs.getInt('alert_morning_wird_hour') ?? 5;
    final mWirdMinute = prefs.getInt('alert_morning_wird_minute') ?? 0;

    final eWirdEnabled = prefs.getBool('alert_evening_wird_enabled') ?? false;
    final eWirdHour = prefs.getInt('alert_evening_wird_hour') ?? 16;
    final eWirdMinute = prefs.getInt('alert_evening_wird_minute') ?? 30;

    state = state.copyWith(
      isKahfEnabled: kahfEnabled,
      kahfTime: TimeOfDay(hour: kahfHour, minute: kahfMinute),
      isMulkEnabled: mulkEnabled,
      mulkTime: TimeOfDay(hour: mulkHour, minute: mulkMinute),
      isSajdahEnabled: sajdahEnabled,
      sajdahTime: TimeOfDay(hour: sajdahHour, minute: sajdahMinute),
      isBaqarahEnabled: baqarahEnabled,
      baqarahTime: TimeOfDay(hour: baqarahHour, minute: baqarahMinute),
      isMorningAthkarEnabled: mAthkarEnabled,
      morningAthkarTime: TimeOfDay(hour: mAthkarHour, minute: mAthkarMinute),
      isEveningAthkarEnabled: eAthkarEnabled,
      eveningAthkarTime: TimeOfDay(hour: eAthkarHour, minute: eAthkarMinute),
      isMorningWirdEnabled: mWirdEnabled,
      morningWirdTime: TimeOfDay(hour: mWirdHour, minute: mWirdMinute),
      isEveningWirdEnabled: eWirdEnabled,
      eveningWirdTime: TimeOfDay(hour: eWirdHour, minute: eWirdMinute),
    );
  }

  Future<void> setKahfAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_kahf_enabled', enabled);
    await prefs.setInt('alert_kahf_hour', time.hour);
    await prefs.setInt('alert_kahf_minute', time.minute);
    
    state = state.copyWith(isKahfEnabled: enabled, kahfTime: time);
    _rescheduleAlerts();
  }

  Future<void> setMulkAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_mulk_enabled', enabled);
    await prefs.setInt('alert_mulk_hour', time.hour);
    await prefs.setInt('alert_mulk_minute', time.minute);
    
    state = state.copyWith(isMulkEnabled: enabled, mulkTime: time);
    _rescheduleAlerts();
  }

  Future<void> setSajdahAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_sajdah_enabled', enabled);
    await prefs.setInt('alert_sajdah_hour', time.hour);
    await prefs.setInt('alert_sajdah_minute', time.minute);
    
    state = state.copyWith(isSajdahEnabled: enabled, sajdahTime: time);
    _rescheduleAlerts();
  }

  Future<void> setBaqarahAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_baqarah_enabled', enabled);
    await prefs.setInt('alert_baqarah_hour', time.hour);
    await prefs.setInt('alert_baqarah_minute', time.minute);
    
    state = state.copyWith(isBaqarahEnabled: enabled, baqarahTime: time);
    _rescheduleAlerts();
  }

  // Azkar/Wird Mutators
  Future<void> setMorningAthkarAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_morning_athkar_enabled', enabled);
    await prefs.setInt('alert_morning_athkar_hour', time.hour);
    await prefs.setInt('alert_morning_athkar_minute', time.minute);
    
    state = state.copyWith(isMorningAthkarEnabled: enabled, morningAthkarTime: time);
    _rescheduleAlerts();
  }

  Future<void> setEveningAthkarAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_evening_athkar_enabled', enabled);
    await prefs.setInt('alert_evening_athkar_hour', time.hour);
    await prefs.setInt('alert_evening_athkar_minute', time.minute);
    
    state = state.copyWith(isEveningAthkarEnabled: enabled, eveningAthkarTime: time);
    _rescheduleAlerts();
  }

  Future<void> setMorningWirdAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_morning_wird_enabled', enabled);
    await prefs.setInt('alert_morning_wird_hour', time.hour);
    await prefs.setInt('alert_morning_wird_minute', time.minute);
    
    state = state.copyWith(isMorningWirdEnabled: enabled, morningWirdTime: time);
    _rescheduleAlerts();
  }

  Future<void> setEveningWirdAlert(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('alert_evening_wird_enabled', enabled);
    await prefs.setInt('alert_evening_wird_hour', time.hour);
    await prefs.setInt('alert_evening_wird_minute', time.minute);
    
    state = state.copyWith(isEveningWirdEnabled: enabled, eveningWirdTime: time);
    _rescheduleAlerts();
  }


  void _rescheduleAlerts() {
    final notifService = ref.read(notificationServiceProvider);
    
    notifService.scheduleSurahReminders(
      isKahfEnabled: state.isKahfEnabled, kahfTime: state.kahfTime,
      isMulkEnabled: state.isMulkEnabled, mulkTime: state.mulkTime,
      isSajdahEnabled: state.isSajdahEnabled, sajdahTime: state.sajdahTime,
      isBaqarahEnabled: state.isBaqarahEnabled, baqarahTime: state.baqarahTime,
    );

    notifService.scheduleAthkarAndWirdReminders(
      morningAthkar: state.isMorningAthkarEnabled, morningAthkarTime: state.morningAthkarTime,
      eveningAthkar: state.isEveningAthkarEnabled, eveningAthkarTime: state.eveningAthkarTime,
      morningWird: state.isMorningWirdEnabled, morningWirdTime: state.morningWirdTime,
      eveningWird: state.isEveningWirdEnabled, eveningWirdTime: state.eveningWirdTime,
    );
  }
}
