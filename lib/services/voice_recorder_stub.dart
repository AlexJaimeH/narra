import 'dart:typed_data';

typedef OnChunk = void Function(Uint8List bytes, String mimeType);

class VoiceRecorder {
  Future<void> start({OnChunk? onChunk}) async {}

  Future<Uint8List?> stop() async { return null; }
}


