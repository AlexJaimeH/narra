import 'dart:typed_data';

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);
typedef OnLevel = void Function(double level);
typedef OnTranscriptionState = void Function(bool active);

class VoiceRecorder {
  Future<void> start({
    OnText? onText,
    OnRecorderLog? onLog,
    OnLevel? onLevel,
    OnTranscriptionState? onTranscriptionState,
  }) async {}

  Future<bool> pause() async => false;

  Future<bool> resume() async => false;

  Future<Uint8List?> stop() async => null;

  Future<void> dispose() async {}
}
