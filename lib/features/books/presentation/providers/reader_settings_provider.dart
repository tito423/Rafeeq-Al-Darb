import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderSettingsProvider extends ChangeNotifier {
  double _fontSize = 20.0;
  bool _isNightMode = false;
  String _fontFamily = 'Amiri';

  double get fontSize => _fontSize;
  bool get isNightMode => _isNightMode;
  String get fontFamily => _fontFamily;

  ReaderSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('reader_font_size') ?? 20.0;
    _isNightMode = prefs.getBool('reader_night_mode') ?? false;
    _fontFamily = prefs.getString('reader_font_family') ?? 'Amiri';
    notifyListeners();
  }

  Future<void> increaseFontSize() async {
    if (_fontSize < 40.0) {
      _fontSize += 2.0;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('reader_font_size', _fontSize);
    }
  }

  Future<void> decreaseFontSize() async {
    if (_fontSize > 12.0) {
      _fontSize -= 2.0;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('reader_font_size', _fontSize);
    }
  }

  Future<void> toggleNightMode() async {
    _isNightMode = !_isNightMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reader_night_mode', _isNightMode);
  }

  Future<void> setFontFamily(String family) async {
    _fontFamily = family;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_font_family', _fontFamily);
  }
}
