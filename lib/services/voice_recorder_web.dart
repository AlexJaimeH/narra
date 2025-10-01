import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:narra/openai/openai_service.dart';

typedef OnText = void Function(String text);


class VoiceRecorder {
  html.MediaRecorder? _recorder;
  final List<Uint8List> _chunks = [];
  String _mimeType = 'audio/webm';


  Future<void> start({OnText? onText}) async {

    // Request mic
    final stream = await html.window.navigator.mediaDevices!.getUserMedia({'audio': true});

    // Choose supported mime type
    const candidates = [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
    ];
    for (final c in candidates) {
      if (html.MediaRecorder.isTypeSupported(c)) {
        _mimeType = c.split(';').first; // simplify for backend
        break;
      }
    }

    _recorder = html.MediaRecorder(stream, {'mimeType': candidates.firstWhere(
      (c) => html.MediaRecorder.isTypeSupported(c),
      orElse: () => 'audio/webm;codecs=opus',
    )});

    _recorder!.addEventListener('dataavailable', (event) async {
      final e = event as html.BlobEvent;
      final blob = e.data;
      if (blob != null && (blob.size ?? 0) > 0) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        reader.onLoadEnd.listen((_) {
          final buffer = reader.result as ByteBuffer;
          final bytes = Uint8List.view(buffer);
          _chunks.add(bytes);

          // Transcribe chunk via OpenAI Whisper proxy and emit text
          () async {
            try {
              final text = await OpenAIService.transcribeChunk(audioBytes: bytes, mimeType: _mimeType, language: 'es');
              if (text.trim().isNotEmpty) {
                onText?.call(text);
              }
            } catch (_) {}
          }();

          completer.complete(bytes);
        });
        reader.readAsArrayBuffer(blob);
        await completer.future;
      }
    });

    // Emit frequent chunks for near-real-time transcription
    _recorder!.start(750); // timeslice in ms
  }

  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final completer = Completer<void>();
    recorder.addEventListener('stop', (_) => completer.complete());
    recorder.stop();
    await completer.future;

    if (_chunks.isEmpty) return null;
    final totalLength = _chunks.fold<int>(0, (sum, b) => sum + b.length);
    final merged = Uint8List(totalLength);
    var offset = 0;
    for (final c in _chunks) {
      merged.setAll(offset, c);
      offset += c.length;
    }
    _chunks.clear();
    return merged;
  }
}


