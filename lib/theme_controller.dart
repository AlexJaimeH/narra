import 'package:flutter/material.dart';
import 'package:narra/theme.dart' as app_theme;
import 'package:narra/services/user_service.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  String _fontFamily = 'Montserrat';
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reduceMotion = false;

  ThemeData _light = app_theme.buildLightThemeWithFont('Montserrat', highContrast: false);
  ThemeData _dark = app_theme.buildDarkThemeWithFont('Montserrat', highContrast: false);

  ThemeData get light => _light;
  ThemeData get dark => _dark;
  String get fontFamily => _fontFamily;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;

  Future<void> loadInitialFromSupabase() async {
    try {
      final settings = await UserService.getUserSettings();
      final font = (settings?['font_family'] as String?)?.trim();
      final scale = (settings?['text_scale'] as num?)?.toDouble();
      final hc = settings?['high_contrast'] as bool?;
      final rm = settings?['reduce_motion'] as bool?;
      if (font != null && font.isNotEmpty) {
        _applyFont(font);
      }
      if (scale != null && scale > 0) {
        _textScale = scale;
      }
      if (hc != null) {
        _highContrast = hc;
      }
      if (rm != null) {
        _reduceMotion = rm;
      }
      _rebuildThemes();
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

  Future<void> updateHighContrast(bool value) async {
    if (value == _highContrast) return;
    _highContrast = value;
    _rebuildThemes();
    notifyListeners();
    await UserService.updateUserSettings({'high_contrast': value});
  }

  Future<void> updateReduceMotion(bool value) async {
    if (value == _reduceMotion) return;
    _reduceMotion = value;
    _rebuildThemes();
    notifyListeners();
    await UserService.updateUserSettings({'reduce_motion': value});
  }

  void _applyFont(String font) {
    _fontFamily = font;
    _rebuildThemes();
  }

  void _rebuildThemes() {
    final lightBase = app_theme.buildLightThemeWithFont(_fontFamily, highContrast: _highContrast);
    final darkBase = app_theme.buildDarkThemeWithFont(_fontFamily, highContrast: _highContrast);
    if (_reduceMotion) {
      final noTransitions = const PageTransitionsTheme(builders: {
        TargetPlatform.android: _NoTransitionsBuilder(),
        TargetPlatform.iOS: _NoTransitionsBuilder(),
        TargetPlatform.macOS: _NoTransitionsBuilder(),
        TargetPlatform.windows: _NoTransitionsBuilder(),
        TargetPlatform.linux: _NoTransitionsBuilder(),
        TargetPlatform.fuchsia: _NoTransitionsBuilder(),
      });
      _light = lightBase.copyWith(pageTransitionsTheme: noTransitions);
      _dark = darkBase.copyWith(pageTransitionsTheme: noTransitions);
    } else {
      _light = lightBase;
      _dark = darkBase;
    }
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child; // No animations
  }
}


