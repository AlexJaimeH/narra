import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:narra/openai/openai_service.dart';

typedef OnText = void Function(String text);

class VoiceRecorder {
  static const _minFlushBytes = 12 * 1024; // ~0.2s of opus audio
  static const _maxFlushInterval = Duration(milliseconds: 2500);

  html.MediaRecorder? _recorder;
  final List<Uint8List> _chunks = [];
  html.MediaStream? _stream;

  String _mimeType = 'application/octet-stream';
  OnText? _onText;

  BytesBuilder? _pendingBuilder;
  Timer? _flushTimer;
  Future<void> _transcriptionQueue = Future<void>.value();
  bool _stopping = false;

  bool get isRecording => _recorder?.state == 'recording';
  bool get isPaused => _recorder?.state == 'paused';

  Future<void> start({OnText? onText}) async {
    final isSecure = html.window.isSecureContext ?? false;
    if (!isSecure) {
      throw Exception('El micrófono requiere HTTPS.');
    }

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
    _onText = onText;
    _pendingBuilder = BytesBuilder(copy: false);

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
    for (final candidate in candidates) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        supported = candidate;
        break;
      }
    }

    if (supported != null) {
      _recorder = html.MediaRecorder(stream, {'mimeType': supported});
      _mimeType = supported.split(';').first;
    } else {
      _recorder = html.MediaRecorder(stream);
      _mimeType = 'audio/webm';
    }

    _recorder!.addEventListener('dataavailable', (event) async {
      if (_stopping) return;

      final e = event as html.BlobEvent;
      final blob = e.data;

      if (blob == null || blob.size == 0) return;

      try {
        final bytes = await _readBlob(blob);
        if (bytes == null || bytes.isEmpty) return;

        _chunks.add(bytes);
        _pendingBuilder ??= BytesBuilder(copy: false);
        _pendingBuilder!.add(bytes);

        if (_pendingBuilder!.length >= _minFlushBytes) {
          _enqueueTranscription();
        } else {
          _scheduleFlush();
        }
      } catch (_) {
        // Ignore read issues and keep recording
      }
    });

    // Frequent chunks to keep UX reactive even with long silences
    _recorder!.start(1000);
  }

  Future<bool> pause() async {
    final recorder = _recorder;
    if (recorder == null || recorder.state != 'recording') return false;

    await _flushPending();
    var paused = false;
    try {
      recorder.pause();
      paused = recorder.state == 'paused';
    } catch (_) {
      // Some browsers may not support pause
    }
    return paused;
  }

  Future<bool> resume() async {
    final recorder = _recorder;
    if (recorder == null) return false;

    if (recorder.state == 'paused') {
      try {
        recorder.resume();
        return recorder.state == 'recording';
      } catch (_) {
        // If resume is unsupported the caller will handle restarting
      }
    }
    return recorder.state == 'recording';

  }

  Future<Uint8List?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;

    _stopping = true;
    await _flushPending();
    _cancelFlushTimer();

    final completer = Completer<void>();
    late html.EventListener listener;
    listener = (_) {
      recorder.removeEventListener('stop', listener);
      if (!completer.isCompleted) {
        completer.complete();
      }
    };
    recorder.addEventListener('stop', listener);

    try {
      recorder.stop();
    } catch (_) {
      listener(html.Event('stop'));
    }

    await completer.future;

    try {
      _stream?.getTracks().forEach((track) {
        try {
          track.stop();
        } catch (_) {}
      });
    } catch (_) {}
    _stream = null;

    await _transcriptionQueue;

    final bytes = _mergeChunks();
    _resetState();
    return bytes;
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<Uint8List?> _readBlob(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();

    reader.onError.listen((_) {
      try {
        reader.abort();
      } catch (_) {}
      completer.complete(null);
    });

    reader.onLoadEnd.listen((_) {
      try {
        final result = reader.result;
        if (result is ByteBuffer) {
          completer.complete(Uint8List.view(result));
        } else if (result is Uint8List) {
          completer.complete(result);
        } else if (result is List<int>) {
          completer.complete(Uint8List.fromList(result));
        } else {
          completer.complete(null);
        }
      } catch (_) {
        completer.complete(null);
      }
    });

    try {
      reader.readAsArrayBuffer(blob);
    } catch (_) {
      completer.complete(null);
    }

    return completer.future;
  }

  void _enqueueTranscription() {
    final payload = _takePendingBytes();
    if (payload == null || payload.isEmpty) return;

    _transcriptionQueue = _transcriptionQueue.then((_) async {
      await _transcribe(payload);
    });
  }

  Future<void> _flushPending() async {
    _cancelFlushTimer();
    final payload = _takePendingBytes();
    if (payload == null || payload.isEmpty) return;

    _transcriptionQueue = _transcriptionQueue.then((_) async {
      await _transcribe(payload);
    });

    await _transcriptionQueue;
  }

  void _scheduleFlush() {
    if (_flushTimer?.isActive ?? false) return;
    _flushTimer = Timer(_maxFlushInterval, () {
      _flushTimer = null;
      _enqueueTranscription();
    });
  }

  void _cancelFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  Uint8List? _takePendingBytes() {
    final builder = _pendingBuilder;
    if (builder == null || builder.length == 0) {
      return null;
    }
    final bytes = builder.takeBytes();
    _pendingBuilder = BytesBuilder(copy: false);
    return bytes;
  }

  Future<void> _transcribe(Uint8List audioBytes) async {
    final handler = _onText;
    if (handler == null) return;

    try {
      final text = await OpenAIService.transcribeChunk(
        audioBytes: audioBytes,
        mimeType: _mimeType,
        language: 'es',
      );
      if (text.trim().isNotEmpty) {
        handler(text);
      }
    } catch (_) {
      // Ignore transcription failures; subsequent chunks may succeed
    }
  }

  Uint8List? _mergeChunks() {
    if (_chunks.isEmpty) return null;

    final totalLength =
        _chunks.fold<int>(0, (sum, bytes) => sum + bytes.length);
    final merged = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in _chunks) {
      merged.setAll(offset, chunk);
      offset += chunk.length;
    }
    _chunks.clear();
    return merged;
  }

  void _resetState() {
    _recorder = null;
    _onText = null;
    _pendingBuilder = null;
    _cancelFlushTimer();
    _transcriptionQueue = Future<void>.value();
    _stopping = false;
  }
}
