import 'package:flutter/widgets.dart';

/// Coordinador simple para permitir que otros widgets dentro del dashboard
/// avancen el walkthrough y reaccionen a los cambios de paso sin depender
/// del estado interno directamente.
class DashboardWalkthroughController {
  DashboardWalkthroughController._();

  static VoidCallback? _startCallback;
  static VoidCallback? _advanceCallback;
  static ValueChanged<GlobalKey>? _stepStartedCallback;
  static VoidCallback? _finishedCallback;
  static ValueChanged<bool>? _blockingChangedCallback;

  /// Registra un callback para iniciar el walkthrough cuando se solicite.
  static void registerStart(VoidCallback callback) {
    _startCallback = callback;
  }

  /// Elimina el callback registrado para iniciar el walkthrough.
  static void unregisterStart(VoidCallback callback) {
    if (identical(_startCallback, callback)) {
      _startCallback = null;
    }
  }

  /// Notifica que se solicitó iniciar el walkthrough.
  static void triggerStart() {
    _startCallback?.call();
  }

  /// Registra el callback que debe ejecutarse cuando se solicite avanzar.
  static void registerAdvance(VoidCallback callback) {
    _advanceCallback = callback;
  }

  /// Elimina el callback registrado para evitar referencias obsoletas.
  static void unregisterAdvance(VoidCallback callback) {
    if (identical(_advanceCallback, callback)) {
      _advanceCallback = null;
    }
  }

  /// Notifica que se solicitó avanzar al siguiente paso del walkthrough.
  static void triggerAdvance() {
    _advanceCallback?.call();
  }

  /// Registra un callback para escuchar cuando ShowCase inicia un paso.
  static void registerStepStarted(ValueChanged<GlobalKey> callback) {
    _stepStartedCallback = callback;
  }

  /// Cancela el callback de inicio de paso si coincide con el registrado.
  static void unregisterStepStarted(ValueChanged<GlobalKey> callback) {
    if (identical(_stepStartedCallback, callback)) {
      _stepStartedCallback = null;
    }
  }

  /// Notifica a los listeners que ShowCase comenzó a mostrar la [key].
  static void notifyStepStarted(GlobalKey key) {
    _stepStartedCallback?.call(key);
  }

  /// Registra un callback que se ejecutará cuando el walkthrough termine.
  static void registerFinished(VoidCallback callback) {
    _finishedCallback = callback;
  }

  /// Cancela el callback de finalización si coincide con el registrado.
  static void unregisterFinished(VoidCallback callback) {
    if (identical(_finishedCallback, callback)) {
      _finishedCallback = null;
    }
  }

  /// Notifica que el walkthrough terminó en el ShowCase principal.
  static void notifyFinished() {
    _finishedCallback?.call();
  }

  /// Registra un callback para escuchar cuando el overlay bloqueador debe
  /// mostrarse u ocultarse.
  static void registerBlockingChanged(ValueChanged<bool> callback) {
    _blockingChangedCallback = callback;
  }

  /// Cancela el callback de cambio de overlay si coincide con el registrado.
  static void unregisterBlockingChanged(ValueChanged<bool> callback) {
    if (identical(_blockingChangedCallback, callback)) {
      _blockingChangedCallback = null;
    }
  }

  /// Notifica que el overlay bloqueador debe mostrarse (true) u ocultarse
  /// (false).
  static void notifyBlockingChanged(bool shouldBlock) {
    _blockingChangedCallback?.call(shouldBlock);
  }
}
