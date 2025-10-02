import 'dart:typed_data';

typedef OnText = void Function(String text);

class VoiceRecorder {
  Future<void> start({OnText? onText}) async {}

  Future<bool> pause() async => false;

  Future<bool> resume() async => false;

  Future<Uint8List?> stop() async => null;

  Future<void> dispose() async {}
}
