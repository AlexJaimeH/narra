import 'dart:typed_data';

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);
typedef OnLevel = void Function(double level);

class VoiceRecorder {
  Future<void> start(
      {OnText? onText, OnRecorderLog? onLog, OnLevel? onLevel}) async {}

  Future<bool> pause() async => false;

  Future<bool> resume() async => false;

  Future<Uint8List?> stop() async => null;

  Future<void> dispose() async {}
}
