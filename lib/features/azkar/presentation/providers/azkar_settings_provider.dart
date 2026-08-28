import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final azkarSettingsProvider = StateNotifierProvider<AzkarSettingsNotifier, AzkarSettings>((ref) {
  return AzkarSettingsNotifier();
});

class AzkarSettings {
  final bool hapticFeedbackEnabled;

  const AzkarSettings({this.hapticFeedbackEnabled = true});

  AzkarSettings copyWith({bool? hapticFeedbackEnabled}) {
    return AzkarSettings(
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
    );
  }
}

class AzkarSettingsNotifier extends StateNotifier<AzkarSettings> {
  AzkarSettingsNotifier() : super(const AzkarSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final haptic = prefs.getBool('azkar_haptic_feedback') ?? true;
    state = AzkarSettings(hapticFeedbackEnabled: haptic);
  }

  Future<void> toggleHapticFeedback() async {
    final newValue = !state.hapticFeedbackEnabled;
    state = state.copyWith(hapticFeedbackEnabled: newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('azkar_haptic_feedback', newValue);
  }
}