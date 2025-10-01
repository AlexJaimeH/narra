import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:narra/openai/openai_service.dart';

typedef OnText = void Function(String text);


class VoiceRecorder {
  html.MediaRecorder? _recorder;
  final List<Uint8List> _chunks = [];
  String _mimeType = 'application/octet-stream';
  Timer? _flushTimer;

  html.MediaStream? _stream;




  Future<void> start({OnText? onText}) async {
    final isSecure = html.window.isSecureContext ?? false;
    if (!isSecure) {
      throw Exception('El micrófono requiere HTTPS.');
    }

    // Request mic with safe defaults
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      throw Exception('Navegador sin soporte de mediaDevices');
    }
    final stream = await mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      }
    });

    _stream = stream;


    // Choose supported mime type (browsers vary; Safari often prefers mp4/aac)
    final candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
      'audio/mp4;codecs=mp4a.40.2',
      'audio/mp4',
      'audio/aac',
    ];

    String? supported;
    for (final c in candidates) {
      if (html.MediaRecorder.isTypeSupported(c)) {
        supported = c;
        break;
      }
    }

    if (supported != null) {
      _recorder = html.MediaRecorder(stream, {'mimeType': supported});
      _mimeType = supported.split(';').first;
    } else {
      // Let browser pick default container
      _recorder = html.MediaRecorder(stream);
      _mimeType = 'application/octet-stream';
    }

    _recorder!.addEventListener('dataavailable', (event) async {
      final e = event as html.BlobEvent;
      final blob = e.data;
      // Evitar enviar fragmentos diminutos que provocan 400
      if (blob != null && blob.size > 65536) {
        final reader = html.FileReader();
        final completer = Completer<Uint8List>();
        reader.onError.listen((_) {
          try { reader.abort(); } catch (_) {}
          if (!completer.isCompleted) completer.completeError(reader.error ?? 'read error');
        });
        reader.onLoadEnd.listen((_) {
          try {
            final result = reader.result;
            Uint8List? bytes;
            if (result is ByteBuffer) {
              bytes = Uint8List.view(result);
            } else if (result is Uint8List) {
              bytes = result;
            } else if (result is List<int>) {
              bytes = Uint8List.fromList(result);
            }
            if (bytes == null) {
              if (!completer.isCompleted) completer.completeError('empty buffer');
              return;
            }
            _chunks.add(bytes);
            // Transcribe chunk via OpenAI Whisper proxy and emit text
            () async {
              try {
                final text = await OpenAIService.transcribeChunk(audioBytes: bytes!, mimeType: _mimeType, language: 'es');
                if (text.trim().isNotEmpty) {
                  onText?.call(text);
                }
              } catch (_) {}
            }();
            if (!completer.isCompleted) completer.complete(bytes);
          } catch (_) {
            if (!completer.isCompleted) completer.completeError('load error');
          }
        });
        reader.readAsArrayBuffer(blob);
        await completer.future;
      }
    });

    // Solicitar fragmentos más largos (~3s) para contenedores válidos y mejor precisión
    _recorder!.start(3000);
  }

  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    _flushTimer?.cancel();
    _flushTimer = null;
    final completer = Completer<void>();
    recorder.addEventListener('stop', (_) => completer.complete());
    recorder.stop();
    await completer.future;
    try {
      _stream?.getTracks().forEach((t) { try { t.stop(); } catch (_) {} });
    } catch (_) {}
    _stream = null;

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


