import 'dart:typed_data';

typedef OnText = void Function(String text);

class VoiceRecorder {
  Future<void> start({OnText? onText}) async {}

  Future<Uint8List?> stop() async { return null; }

}


