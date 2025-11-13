import 'package:flutter/foundation.dart';

/// Coordinador simple para permitir que otros widgets dentro del dashboard
/// avancen el walkthrough sin depender del estado interno directamente.
class DashboardWalkthroughController {
  DashboardWalkthroughController._();

  static VoidCallback? _advanceCallback;

  /// Registra el callback que debe ejecutarse cuando se solicite avanzar.
  static void register(VoidCallback callback) {
    _advanceCallback = callback;
  }

  /// Elimina el callback registrado para evitar referencias obsoletas.
  static void unregister(VoidCallback callback) {
    if (identical(_advanceCallback, callback)) {
      _advanceCallback = null;
    }
  }

  /// Ejecuta el callback actual si existe.
  static void triggerAdvance() {
    _advanceCallback?.call();
  }
}
