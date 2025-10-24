import 'dart:async';
import 'dart:typed_data';
// Mobile stub: we will not stream chunks; we'll only capture final file

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
  }) async {
    // TODO: Implement with a cross-platform audio recorder plugin and dart:io for bytes.
    throw UnimplementedError('Recording on mobile pending implementation');
  }

  Future<Uint8List?> stop() async {
    return null;
  }
}
