import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(); // Overridden in main.dart
});

class Muezzin {
  final String id;
  final String name;
  final String url;

  const Muezzin({required this.id, required this.name, required this.url});
}

const kMuezzins = [
  Muezzin(id: 'makkah', name: 'أذان مكة المكرمة', url: 'https://download.quranicaudio.com/adhan/makkah.mp3'),
  Muezzin(id: 'abdulbasit', name: 'عبد الباسط عبد الصمد', url: 'https://download.quranicaudio.com/adhan/abdulbasit.mp3'),
  Muezzin(id: 'minshawi', name: 'محمد صديق المنشاوي', url: 'https://download.quranicaudio.com/adhan/minshawi.mp3'),
  Muezzin(id: 'hussaini', name: 'محمود خليل الحسيني', url: 'https://download.quranicaudio.com/adhan/hussaini.mp3'),
  Muezzin(id: 'hafez', name: 'أذان حافظ', url: 'https://download.quranicaudio.com/adhan/hafez.mp3'),
];

class PrayerSettings {
  final bool globalNotifications;
  final bool locationEnabled;
  final String selectedMuezzin;
  final Map<String, bool> prayerToggles;
  final Map<String, int> prayerOffsets;

  PrayerSettings({
    this.globalNotifications = true,
    this.locationEnabled = true,
    this.selectedMuezzin = 'أذان مكة المكرمة',
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
  });

  PrayerSettings copyWith({
    bool? globalNotifications,
    bool? locationEnabled,
    String? selectedMuezzin,
    Map<String, bool>? prayerToggles,
    Map<String, int>? prayerOffsets,
  }) {
    return PrayerSettings(
      globalNotifications: globalNotifications ?? this.globalNotifications,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      selectedMuezzin: selectedMuezzin ?? this.selectedMuezzin,
      prayerToggles: prayerToggles ?? this.prayerToggles,
      prayerOffsets: prayerOffsets ?? this.prayerOffsets,
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
    final muezzin = _prefs.getString('selectedMuezzin') ?? 'أذان مكة المكرمة';
    
    final toggles = <String, bool>{};
    final offsets = <String, int>{};
    final prayers = ['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    for (final p in prayers) {
      toggles[p] = _prefs.getBool('prayer_$p') ?? (p != 'الشروق'); // Default: true for all except Sunrise
      offsets[p] = _prefs.getInt('prayer_offset_$p') ?? 0;
    }

    state = PrayerSettings(
      globalNotifications: global,
      locationEnabled: loc,
      selectedMuezzin: muezzin,
      prayerToggles: toggles,
      prayerOffsets: offsets,
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
}

final prayerSettingsProvider = StateNotifierProvider<PrayerSettingsNotifier, PrayerSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return PrayerSettingsNotifier(prefs);
});
