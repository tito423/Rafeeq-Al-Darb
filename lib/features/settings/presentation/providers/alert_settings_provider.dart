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

  AlertSettingsState({
    this.isKahfEnabled = false,
    this.kahfTime = const TimeOfDay(hour: 9, minute: 0),
    this.isMulkEnabled = false,
    this.mulkTime = const TimeOfDay(hour: 22, minute: 0),
    this.isSajdahEnabled = false,
    this.sajdahTime = const TimeOfDay(hour: 5, minute: 0),
    this.isBaqarahEnabled = false,
    this.baqarahTime = const TimeOfDay(hour: 7, minute: 0),
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

    state = state.copyWith(
      isKahfEnabled: kahfEnabled,
      kahfTime: TimeOfDay(hour: kahfHour, minute: kahfMinute),
      isMulkEnabled: mulkEnabled,
      mulkTime: TimeOfDay(hour: mulkHour, minute: mulkMinute),
      isSajdahEnabled: sajdahEnabled,
      sajdahTime: TimeOfDay(hour: sajdahHour, minute: sajdahMinute),
      isBaqarahEnabled: baqarahEnabled,
      baqarahTime: TimeOfDay(hour: baqarahHour, minute: baqarahMinute),
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

  void _rescheduleAlerts() {
    ref.read(notificationServiceProvider).scheduleSurahReminders(
      isKahfEnabled: state.isKahfEnabled, kahfTime: state.kahfTime,
      isMulkEnabled: state.isMulkEnabled, mulkTime: state.mulkTime,
      isSajdahEnabled: state.isSajdahEnabled, sajdahTime: state.sajdahTime,
      isBaqarahEnabled: state.isBaqarahEnabled, baqarahTime: state.baqarahTime,
    );
  }
}
