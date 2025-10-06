import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);

class _TranscriptionSegment {
  _TranscriptionSegment({
    required this.id,
    required this.text,
    required this.endSeconds,
  });

  final int id;
  String text;
  double endSeconds;
}

class VoiceRecorder {
  static const _primaryModel = 'gpt-4o-mini-transcribe';
  static const _transcriptionDebounce = Duration(milliseconds: 600);

  OnText? _onText;
  OnRecorderLog? _onLog;

  html.MediaStream? _inputStream;
  html.MediaStreamTrack? _audioTrack;
  html.MediaRecorder? _mediaRecorder;

  final List<Uint8List> _audioChunks = <Uint8List>[];
  Uint8List? _cachedCombinedAudio;
  int _cachedCombinedAudioChunkCount = 0;

  bool _isRecording = false;
  bool _isPaused = false;
  bool _stopping = false;

  bool _transcribing = false;
  bool _hasPendingTranscription = false;
  Timer? _transcriptionTimer;
  Future<void>? _ongoingTranscription;

  final SplayTreeMap<int, _TranscriptionSegment> _segments =
      SplayTreeMap<int, _TranscriptionSegment>();
  String? _lastEmittedTranscript;

  Completer<void>? _stopCompleter;

  Future<void> start({OnText? onText, OnRecorderLog? onLog}) async {
    _onText = onText;
    _onLog = onLog;

    _resetState();
    _emitTranscript('');

    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      _log('El navegador no soporta mediaDevices', level: 'error');
      throw Exception('Navegador sin soporte de mediaDevices');
    }

    _log('Solicitando acceso al micrófono...');
    final stream = await devices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
      },
    });

    _inputStream = stream;
    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) {
      _log('No se encontró un micrófono activo', level: 'error');
      await _disposeInternal();
      throw Exception('Micrófono no disponible');
    }

    _audioTrack = tracks.first;
    debugPrint('[VoiceRecorder] Micrófono: ${_audioTrack?.label}');

    _mediaRecorder = _createMediaRecorder(stream);
    if (_mediaRecorder == null) {
      await _disposeInternal();
      throw Exception('MediaRecorder no soportado en este navegador');
    }

    _attachRecorderListeners(_mediaRecorder!);

    try {
      _mediaRecorder!.start(1500);
      _isRecording = true;
      _isPaused = false;
      _log('Grabación iniciada');
    } catch (error) {
      _log('No se pudo iniciar la grabación', level: 'error', error: error);
      await _disposeInternal();
      throw Exception('No se pudo iniciar la grabación: $error');
    }
  }

  Future<bool> pause() async {
    if (!_isRecording || _isPaused) {
      return true;
    }

    _log('Pausando grabación...');
    _isPaused = true;

    try {
      _audioTrack?.enabled = false;
    } catch (error) {
      _log('No se pudo deshabilitar la pista de audio',
          level: 'warning', error: error);
    }

    try {
      _mediaRecorder?.pause();
    } catch (error) {
      _log('MediaRecorder.pause falló', level: 'warning', error: error);
    }

    return true;
  }

  Future<bool> resume() async {
    if (!_isRecording || !_isPaused) {
      return _isRecording;
    }

    _log('Reanudando grabación...');
    _isPaused = false;

    try {
      _audioTrack?.enabled = true;
    } catch (error) {
      _log('No se pudo habilitar la pista de audio',
          level: 'warning', error: error);
    }

    try {
      _mediaRecorder?.resume();
    } catch (error) {
      _log('MediaRecorder.resume falló', level: 'warning', error: error);
      return false;
    }

    _markPendingTranscription();
    return true;
  }

  Future<Uint8List?> stop() async {
    if (!_isRecording && _mediaRecorder == null && _inputStream == null) {
      return null;
    }

    _log('Deteniendo grabación...');
    _stopping = true;
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _hasPendingTranscription = true;

    final completer = Completer<void>();
    _stopCompleter = completer;

    try {
      _mediaRecorder?.stop();
    } catch (error) {
      _log('MediaRecorder.stop falló', level: 'warning', error: error);
    }

    try {
      await completer.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      // ignore timeout: recorder might already be stopped.
    }

    await _runTranscription(immediate: true);
    if (_ongoingTranscription != null) {
      await _ongoingTranscription;
    }

    final audioBytes = _combinedAudioBytes();
    await _disposeInternal();

    if (audioBytes.isEmpty) {
      return null;
    }
    return audioBytes;
  }

  Future<void> dispose() async {
    await _disposeInternal();
  }

  void _resetState() {
    _audioChunks.clear();
    _cachedCombinedAudio = null;
    _cachedCombinedAudioChunkCount = 0;
    _segments.clear();
    _lastEmittedTranscript = null;
    _hasPendingTranscription = false;
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _ongoingTranscription = null;
    _transcribing = false;
    _stopping = false;
    _stopCompleter = null;
  }

  html.MediaRecorder? _createMediaRecorder(html.MediaStream stream) {
    final candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
    ];

    for (final mime in candidates) {
      try {
        if (html.MediaRecorder.isTypeSupported(mime)) {
          return html.MediaRecorder(stream, {'mimeType': mime});
        }
      } catch (_) {
        // Continue testing other mime types.
      }
    }

    try {
      return html.MediaRecorder(stream);
    } catch (_) {
      return null;
    }
  }

  void _attachRecorderListeners(html.MediaRecorder recorder) {
    recorder.addEventListener('dataavailable', (html.Event event) async {
      final dynamic blob = js_util.getProperty(event, 'data');
      if (blob is! html.Blob || blob.size == 0) {
        return;
      }

      final bytes = await _blobToBytes(blob);
      if (bytes == null || bytes.isEmpty) {
        return;
      }

      _audioChunks.add(bytes);
      _cachedCombinedAudio = null;
      _cachedCombinedAudioChunkCount = 0;

      _log('Chunk de audio capturado (${bytes.length} bytes)', level: 'debug');
      _markPendingTranscription();
    });

    recorder.addEventListener('error', (html.Event event) {
      final name = js_util.hasProperty(event, 'name')
          ? js_util.getProperty(event, 'name')
          : null;
      final message = js_util.hasProperty(event, 'message')
          ? js_util.getProperty(event, 'message')
          : null;
      final detailParts = <String>[];
      if (name is String && name.isNotEmpty) {
        detailParts.add(name);
      }
      if (message is String && message.isNotEmpty) {
        detailParts.add(message);
      }
      final detail = detailParts.isEmpty ? event.type : detailParts.join(': ');
      _log('Error en MediaRecorder: $detail', level: 'error');
    });

    recorder.addEventListener('stop', (_) {
      _stopCompleter?.complete();
      _stopCompleter = null;
    });
  }

  void _markPendingTranscription() {
    if (_stopping) {
      return;
    }
    _hasPendingTranscription = true;
    _transcriptionTimer?.cancel();
    _transcriptionTimer =
        Timer(_transcriptionDebounce, () => _runTranscription());
  }

  Future<void> _runTranscription({bool immediate = false}) {
    if (_transcribing) {
      return _ongoingTranscription ?? Future.value();
    }

    if (!_hasPendingTranscription && !immediate) {
      return Future.value();
    }

    _hasPendingTranscription = false;
    _transcribing = true;

    final future = _transcribeLatest();
    _ongoingTranscription = future;
    return future.whenComplete(() {
      _transcribing = false;
      _ongoingTranscription = null;

      if (_hasPendingTranscription && !_stopping) {
        _transcriptionTimer?.cancel();
        _transcriptionTimer =
            Timer(_transcriptionDebounce, () => _runTranscription());
      }
    });
  }

  Future<void> _transcribeLatest() async {
    final audioBytes = _combinedAudioBytes();
    if (audioBytes.isEmpty) {
      return;
    }

    final prompt = _buildPrompt();
    final uri = Uri.parse('/api/whisper').replace(queryParameters: {
      'model': _primaryModel,
      if (prompt.isNotEmpty) 'prompt': prompt,
    });

    final request = http.MultipartRequest('POST', uri)
      ..fields['response_format'] = 'verbose_json'
      ..fields['temperature'] = '0';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioBytes,
      filename: 'audio.webm',
      contentType: MediaType('audio', 'webm'),
    ));

    _log(
      'Enviando audio para transcribir (${audioBytes.length} bytes)...',
      level: 'debug',
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send();
    } catch (error) {
      _log('No se pudo enviar el audio a transcripción',
          level: 'error', error: error);
      return;
    }

    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log(
        'Transcripción falló (${response.statusCode}): ${response.body}',
        level: 'error',
      );
      return;
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (error) {
      _log('Respuesta de transcripción inválida', level: 'error', error: error);
      return;
    }

    final updated = _applyTranscriptionPayload(payload);
    if (updated) {
      _emitTranscript(_normalizedTranscript());
    }
  }

  bool _applyTranscriptionPayload(Map<String, dynamic> payload) {
    var updated = false;
    final segments = payload['segments'];
    if (segments is List) {
      for (final entry in segments) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }

        final idValue = entry['id'];
        final textValue = entry['text'];
        if (idValue is! num || textValue is! String) {
          continue;
        }

        final id = idValue.toInt();
        final text = textValue;
        final endSeconds =
            (entry['end'] is num) ? (entry['end'] as num).toDouble() : null;

        final existing = _segments[id];
        if (existing == null) {
          _segments[id] = _TranscriptionSegment(
            id: id,
            text: text,
            endSeconds: endSeconds ?? 0,
          );
          updated = true;
        } else if (existing.text != text) {
          existing.text = text;
          if (endSeconds != null) {
            existing.endSeconds = endSeconds;
          }
          updated = true;
        } else if (endSeconds != null && existing.endSeconds != endSeconds) {
          existing.endSeconds = endSeconds;
        }
      }

      return updated;
    }

    final text = payload['text'];
    if (text is String) {
      final normalized = text.trim();
      final previous = _normalizedTranscript();
      if (normalized != previous) {
        _segments
          ..clear()
          ..[0] = _TranscriptionSegment(
            id: 0,
            text: normalized,
            endSeconds: double.nan,
          );
        updated = true;
      }
    }

    return updated;
  }

  String _normalizedTranscript() {
    if (_segments.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final segment in _segments.values) {
      buffer.write(segment.text);
    }

    final raw = buffer.toString();
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed;
  }

  void _emitTranscript(String transcript) {
    if (_lastEmittedTranscript == transcript) {
      return;
    }

    _lastEmittedTranscript = transcript;
    _onText?.call(transcript);
    debugPrint(
        '[VoiceRecorder] Emitiendo transcripción (${transcript.length} chars)');
  }

  String _buildPrompt() {
    final current = _normalizedTranscript();
    if (current.isEmpty) {
      return '';
    }

    const maxPromptLength = 200;
    if (current.length <= maxPromptLength) {
      return current;
    }
    return current.substring(current.length - maxPromptLength);
  }

  Uint8List _combinedAudioBytes() {
    if (_audioChunks.isEmpty) {
      return Uint8List(0);
    }

    if (_cachedCombinedAudio != null &&
        _cachedCombinedAudioChunkCount == _audioChunks.length) {
      return _cachedCombinedAudio!;
    }

    final builder = BytesBuilder(copy: false);
    for (final chunk in _audioChunks) {
      builder.add(chunk);
    }

    _cachedCombinedAudio = builder.toBytes();
    _cachedCombinedAudioChunkCount = _audioChunks.length;
    return _cachedCombinedAudio!;
  }

  Future<void> _disposeInternal() async {
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _ongoingTranscription = null;
    _hasPendingTranscription = false;
    _transcribing = false;
    _isRecording = false;
    _isPaused = false;

    try {
      _mediaRecorder?.stop();
    } catch (_) {
      // Ignore if already stopped.
    }
    _mediaRecorder = null;

    try {
      final tracks = _inputStream?.getTracks() ?? <html.MediaStreamTrack>[];
      for (final track in tracks) {
        track.stop();
      }
    } catch (_) {
      // ignore
    }

    _audioTrack = null;
    _inputStream = null;
    _audioChunks.clear();
    _cachedCombinedAudio = null;
    _cachedCombinedAudioChunkCount = 0;
    _segments.clear();
    _lastEmittedTranscript = null;
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();

    reader.onError.listen((_) {
      try {
        reader.abort();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) {
        return;
      }
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
    });

    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  void _log(String message, {String level = 'info', Object? error}) {
    final detail = error == null ? message : '$message: $error';
    _onLog?.call(level, detail);
    debugPrint('[VoiceRecorder][$level] $detail');
  }
}
