import 'package:flutter/material.dart';
import 'package:narra/theme.dart' as app_theme;
import 'package:narra/services/user_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  String _fontFamily = 'Montserrat';
  double _textScale = 1.0;

  ThemeData _light = app_theme.buildLightThemeWithFont('Montserrat');
  ThemeData _dark = app_theme.buildDarkThemeWithFont('Montserrat');

  ThemeData get light => _light;
  ThemeData get dark => _dark;
  String get fontFamily => _fontFamily;
  double get textScale => _textScale;

  Future<void> loadInitialFromSupabase() async {
    try {
      final settings = await UserService.getUserSettings();
      final font = (settings?['font_family'] as String?)?.trim();
      final scale = (settings?['text_scale'] as num?)?.toDouble();
      if (font != null && font.isNotEmpty) {
        _applyFont(font);
      }
      if (scale != null && scale > 0) {
        _textScale = scale;
      }
      notifyListeners();
    } catch (_) {
      // ignore and keep defaults
    }
  }

  Future<void> updateFont(String font) async {
    if (font == _fontFamily) return;
    _applyFont(font);
    notifyListeners();
    await UserService.updateUserSettings({'font_family': font});
  }

  Future<void> updateTextScale(double scale) async {
    if (scale == _textScale) return;
    _textScale = scale;
    notifyListeners();
    await UserService.updateUserSettings({'text_scale': scale});
  }

  void _applyFont(String font) {
    _fontFamily = font;
    _light = app_theme.buildLightThemeWithFont(font);
    _dark = app_theme.buildDarkThemeWithFont(font);
  }
}


