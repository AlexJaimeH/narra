import 'dart:typed_data';

typedef OnChunk = void Function(Uint8List bytes, String mimeType);

class VoiceRecorder {
  Future<void> start({OnChunk? onChunk}) async {
    throw UnsupportedError('Voice recording is only available on web in this build.');
  }

  Future<Uint8List?> stop() async {
    throw UnsupportedError('Voice recording is only available on web in this build.');
  }
}


