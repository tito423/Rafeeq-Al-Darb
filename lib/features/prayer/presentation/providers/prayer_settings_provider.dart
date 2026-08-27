import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Overridden in main.dart
});

class Muezzin {
  final String id;
  final String name;
  final String assetPath;

  const Muezzin({required this.id, required this.name, required this.assetPath});
}

final muezzinsProvider = Provider<List<Muezzin>>((ref) {
  return const [
    Muezzin(
      id: 'abdulbasit',
      name: 'عبدالباسط عبدالصمد',
      assetPath: 'assets/audio/abdulbasit.m4a',
    ),
    Muezzin(
      id: 'minshawi',
      name: 'محمد صديق المنشاوي',
      assetPath: 'assets/audio/minshawi.m4a',
    ),
    Muezzin(
      id: 'mishary',
      name: 'مشاري راشد العفاسي',
      assetPath: 'assets/audio/mishary.m4a',
    ),
    Muezzin(
      id: 'mustafa_ismail',
      name: 'مصطفى إسماعيل',
      assetPath: 'assets/audio/mustafa_ismail.m4a',
    ),
    Muezzin(
      id: 'al_aqsa',
      name: 'أذان المسجد الأقصى',
      assetPath: 'assets/audio/al_aqsa.m4a',
    ),
    Muezzin(
      id: 'custom',
      name: 'أذان مخصص (من الجهاز)',
      assetPath: '', // Handled separately
    ),
  ];
});


class PrayerSettings {
  final bool globalNotifications;
  final bool locationEnabled;
  final String selectedMuezzin;
  final String customAdhanPath; // Path to the custom adhan file chosen by user
  final String adhanDisplayMode; // 'animated' or 'audio_only'
  final String adhanSoundMode; // 'sound', 'vibrate', 'silent'
  final String calculationMethod;
  final Map<String, bool> prayerToggles;
  final Map<String, int> prayerOffsets;
  final Map<String, String> prayerAdhanModes; // 'animated', 'audio_only', 'vibrate_only', 'silent'
  final Map<String, int> preAdhanAlarms; // Minutes before
  final Map<String, int> iqamahAlarms;   // Minutes after

  // Athkar & Quran Wird Reminders (Sakanty-Style)
  final bool morningAthkarEnabled;
  final bool eveningAthkarEnabled;
  final bool morningQuranWirdEnabled;
  final bool eveningQuranWirdEnabled;

  PrayerSettings({
    this.globalNotifications = true,
    this.locationEnabled = true,
    this.selectedMuezzin = 'عبدالباسط عبدالصمد',
    this.customAdhanPath = '',
    this.adhanDisplayMode = 'animated',
    this.adhanSoundMode = 'sound',
    this.calculationMethod = 'Umm Al-Qura Univ., Makkah',
    this.prayerToggles = const {
      'الفجر': true,
      'الشروق': false,
      'الظهر': true,
      'العصر': true,
      'المغرب': true,
      'العشاء': true,
    },
    this.prayerOffsets = const {
      'الفجر': 0,
      'الشروق': 0,
      'الظهر': 0,
      'العصر': 0,
      'المغرب': 0,
      'العشاء': 0,
    },
    this.prayerAdhanModes = const {
      'الفجر': 'animated',
      'الظهر': 'animated',
      'العصر': 'animated',
      'المغرب': 'animated',
      'العشاء': 'animated',
    },
    this.preAdhanAlarms = const {
      'الفجر': 15,
      'الشروق': 0,
      'الظهر': 0,
      'العصر': 0,
      'المغرب': 0,
      'العشاء': 0,
    },
    this.iqamahAlarms = const {
      'الفجر': 20,
      'الشروق': 0,
      'الظهر': 15,
      'العصر': 15,
      'المغرب': 10,
      'العشاء': 15,
    },
    this.morningAthkarEnabled = true,
    this.eveningAthkarEnabled = true,
    this.morningQuranWirdEnabled = true,
    this.eveningQuranWirdEnabled = true,
  });

  PrayerSettings copyWith({
    bool? globalNotifications,
    bool? locationEnabled,
    String? selectedMuezzin,
    String? customAdhanPath,
    String? adhanDisplayMode,
    String? adhanSoundMode,
    String? calculationMethod,
    Map<String, bool>? prayerToggles,
    Map<String, int>? prayerOffsets,
    Map<String, String>? prayerAdhanModes,
    Map<String, int>? preAdhanAlarms,
    Map<String, int>? iqamahAlarms,
    bool? morningAthkarEnabled,
    bool? eveningAthkarEnabled,
    bool? morningQuranWirdEnabled,
    bool? eveningQuranWirdEnabled,
  }) {
    return PrayerSettings(
      globalNotifications: globalNotifications ?? this.globalNotifications,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      selectedMuezzin: selectedMuezzin ?? this.selectedMuezzin,
      customAdhanPath: customAdhanPath ?? this.customAdhanPath,
      adhanDisplayMode: adhanDisplayMode ?? this.adhanDisplayMode,
      adhanSoundMode: adhanSoundMode ?? this.adhanSoundMode,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      prayerToggles: prayerToggles ?? this.prayerToggles,
      prayerOffsets: prayerOffsets ?? this.prayerOffsets,
      prayerAdhanModes: prayerAdhanModes ?? this.prayerAdhanModes,
      preAdhanAlarms: preAdhanAlarms ?? this.preAdhanAlarms,
      iqamahAlarms: iqamahAlarms ?? this.iqamahAlarms,
      morningAthkarEnabled: morningAthkarEnabled ?? this.morningAthkarEnabled,
      eveningAthkarEnabled: eveningAthkarEnabled ?? this.eveningAthkarEnabled,
      morningQuranWirdEnabled: morningQuranWirdEnabled ?? this.morningQuranWirdEnabled,
      eveningQuranWirdEnabled: eveningQuranWirdEnabled ?? this.eveningQuranWirdEnabled,
    );
  }
}

class PrayerSettingsNotifier extends StateNotifier<PrayerSettings> {
  final SharedPreferences _prefs;

  PrayerSettingsNotifier(this._prefs) : super(PrayerSettings()) {
    _loadSettings();
  }

  void _loadSettings() {
    final global = _prefs.getBool('globalNotifications') ?? true;
    final loc = _prefs.getBool('locationEnabled') ?? true;
    final muezzin = _prefs.getString('selectedMuezzin') ?? 'عبدالباسط عبدالصمد';
    final customPath = _prefs.getString('customAdhanPath') ?? '';
    final adhanMode = _prefs.getString('adhanDisplayMode') ?? 'animated';
    final adhanSound = _prefs.getString('adhanSoundMode') ?? 'sound';
    final calcMethod = _prefs.getString('calculationMethod') ?? 'Umm Al-Qura Univ., Makkah';
    
    final toggles = <String, bool>{};
    final offsets = <String, int>{};
    final adhanModes = <String, String>{};
    final preAdhans = <String, int>{};
    final iqamahs = <String, int>{};
    final prayers = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    for (final p in prayers) {
      toggles[p] = _prefs.getBool('prayer_$p') ?? (p != 'الشروق');
      offsets[p] = _prefs.getInt('prayer_offset_$p') ?? 0;
      adhanModes[p] = _prefs.getString('prayer_adhan_mode_$p') ?? 'animated';
      preAdhans[p] = _prefs.getInt('prayer_preadhan_$p') ?? (p == 'الفجر' ? 15 : 0);
      iqamahs[p] = _prefs.getInt('prayer_iqamah_$p') ?? (p == 'المغرب' ? 10 : (p == 'الشروق' ? 0 : 15));
    }

    final mAthkar = _prefs.getBool('morning_athkar_enabled') ?? true;
    final eAthkar = _prefs.getBool('evening_athkar_enabled') ?? true;
    final mWird = _prefs.getBool('morning_quran_wird_enabled') ?? true;
    final eWird = _prefs.getBool('evening_quran_wird_enabled') ?? true;

    state = PrayerSettings(
      globalNotifications: global,
      locationEnabled: loc,
      selectedMuezzin: muezzin,
      customAdhanPath: customPath,
      adhanDisplayMode: adhanMode,
      adhanSoundMode: adhanSound,
      calculationMethod: calcMethod,
      prayerToggles: toggles,
      prayerOffsets: offsets,
      prayerAdhanModes: adhanModes,
      preAdhanAlarms: preAdhans,
      iqamahAlarms: iqamahs,
      morningAthkarEnabled: mAthkar,
      eveningAthkarEnabled: eAthkar,
      morningQuranWirdEnabled: mWird,
      eveningQuranWirdEnabled: eWird,
    );
  }

  void setGlobalNotifications(bool value) {
    _prefs.setBool('globalNotifications', value);
    state = state.copyWith(globalNotifications: value);
  }

  void setLocationEnabled(bool value) {
    _prefs.setBool('locationEnabled', value);
    state = state.copyWith(locationEnabled: value);
  }

  void setSelectedMuezzin(String value) {
    _prefs.setString('selectedMuezzin', value);
    state = state.copyWith(selectedMuezzin: value);
  }

  void setCustomAdhanPath(String path) {
    _prefs.setString('customAdhanPath', path);
    state = state.copyWith(customAdhanPath: path);
  }
  
  Future<void> setAdhanDisplayMode(String mode) async {
    await _prefs.setString('adhanDisplayMode', mode);
    state = state.copyWith(adhanDisplayMode: mode);
  }

  Future<void> setAdhanSoundMode(String mode) async {
    await _prefs.setString('adhanSoundMode', mode);
    state = state.copyWith(adhanSoundMode: mode);
  }

  Future<void> setCalculationMethod(String method) async {
    _prefs.setString('calculationMethod', method);
    state = state.copyWith(calculationMethod: method);
  }

  void setPrayerToggle(String prayer, bool value) {
    _prefs.setBool('prayer_$prayer', value);
    final newToggles = Map<String, bool>.from(state.prayerToggles);
    newToggles[prayer] = value;
    state = state.copyWith(prayerToggles: newToggles);
  }

  void setPrayerOffset(String prayer, int offset) {
    _prefs.setInt('prayer_offset_$prayer', offset);
    final newOffsets = Map<String, int>.from(state.prayerOffsets);
    newOffsets[prayer] = offset;
    state = state.copyWith(prayerOffsets: newOffsets);
  }

  void setPrayerAdhanMode(String prayer, String mode) {
    _prefs.setString('prayer_adhan_mode_$prayer', mode);
    final newModes = Map<String, String>.from(state.prayerAdhanModes);
    newModes[prayer] = mode;
    state = state.copyWith(prayerAdhanModes: newModes);
  }

  void setPreAdhanAlarm(String prayer, int minutes) {
    _prefs.setInt('prayer_preadhan_$prayer', minutes);
    final newAlarms = Map<String, int>.from(state.preAdhanAlarms);
    newAlarms[prayer] = minutes;
    state = state.copyWith(preAdhanAlarms: newAlarms);
  }

  void setIqamahAlarm(String prayer, int minutes) {
    _prefs.setInt('prayer_iqamah_$prayer', minutes);
    final newAlarms = Map<String, int>.from(state.iqamahAlarms);
    newAlarms[prayer] = minutes;
    state = state.copyWith(iqamahAlarms: newAlarms);
  }

  void setMorningAthkarEnabled(bool value) {
    _prefs.setBool('morning_athkar_enabled', value);
    state = state.copyWith(morningAthkarEnabled: value);
  }

  void setEveningAthkarEnabled(bool value) {
    _prefs.setBool('evening_athkar_enabled', value);
    state = state.copyWith(eveningAthkarEnabled: value);
  }

  void setMorningQuranWirdEnabled(bool value) {
    _prefs.setBool('morning_quran_wird_enabled', value);
    state = state.copyWith(morningQuranWirdEnabled: value);
  }

  void setEveningQuranWirdEnabled(bool value) {
    _prefs.setBool('evening_quran_wird_enabled', value);
    state = state.copyWith(eveningQuranWirdEnabled: value);
  }
}

final prayerSettingsProvider = StateNotifierProvider<PrayerSettingsNotifier, PrayerSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrayerSettingsNotifier(prefs);
});
