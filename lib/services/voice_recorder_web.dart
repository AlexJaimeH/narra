import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);

class _TranscriptSegment {
  const _TranscriptSegment({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
  });

  final String id;
  final String text;
  final double start;
  final double end;
}

class _PendingAudioSlice {
  const _PendingAudioSlice({
    required this.bytes,
    required this.startChunkIndex,
    required this.endChunkIndex,
  });

  final Uint8List bytes;
  final int startChunkIndex;
  final int endChunkIndex;
}

class VoiceRecorder {
  static const _primaryModel = 'gpt-4o-mini-transcribe';
  static const _fallbackModel = 'gpt-4o-transcribe-latest';
  static const _transcriptionDebounce = Duration(milliseconds: 180);
  static const _preferredTimeslices = <int>[320, 480, 640, 1000];
  static const _maxChunksPerUpload = 12;
  static const _contextChunks = 3;

  OnText? _onText;
  OnRecorderLog? _onLog;

  html.MediaStream? _inputStream;
  html.MediaStreamTrack? _audioTrack;
  html.MediaRecorder? _mediaRecorder;

  final List<Uint8List> _audioChunks = <Uint8List>[];
  Uint8List? _cachedCombinedAudio;
  int _cachedCombinedAudioChunkCount = 0;
  Uint8List? _cachedRecentAudio;
  int _cachedRecentStartIndex = 0;
  int _cachedRecentEndIndex = 0;
  bool _cachedRecentIncludesHeader = false;

  bool _isRecording = false;
  bool _isPaused = false;
  bool _stopping = false;

  bool _transcribing = false;
  bool _hasPendingTranscription = false;
  bool _pendingForceFull = false;
  Timer? _transcriptionTimer;
  Future<void>? _ongoingTranscription;

  String _transcriptBuffer = '';
  String? _lastEmittedTranscript;

  final Map<String, String> _segmentTexts = <String, String>{};
  String? _lastFullTranscript;

  int _transcribedChunkCount = 0;

  Completer<void>? _stopCompleter;

  Future<void> start({OnText? onText, OnRecorderLog? onLog}) async {
    _onText = onText;
    _onLog = onLog;

    _resetState();
    _emitTranscript('');

    try {
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

      var started = false;
      for (final slice in _preferredTimeslices) {
        try {
          _mediaRecorder!.start(slice);
          started = true;
          break;
        } catch (error) {
          _log(
            'MediaRecorder.start($slice) falló, probando siguiente valor',
            level: 'warning',
            error: error,
          );
        }
      }

      if (!started) {
        try {
          _mediaRecorder!.start();
          started = true;
        } catch (error) {
          _log('MediaRecorder.start sin timeslice falló',
              level: 'error', error: error);
        }
      }

      if (!started) {
        await _disposeInternal();
        throw Exception('No se pudo iniciar la grabación: MediaRecorder falló');
      }

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

    await _runTranscription(immediate: true, forceFull: true);
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
    _cachedRecentAudio = null;
    _cachedRecentStartIndex = 0;
    _cachedRecentEndIndex = 0;
    _cachedRecentIncludesHeader = false;
    _transcriptBuffer = '';
    _lastEmittedTranscript = null;
    _segmentTexts.clear();
    _lastFullTranscript = null;
    _transcribedChunkCount = 0;
    _hasPendingTranscription = false;
    _pendingForceFull = false;
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
      _cachedRecentAudio = null;
      _cachedRecentStartIndex = 0;
      _cachedRecentEndIndex = 0;

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

  Future<void> _runTranscription({
    bool immediate = false,
    bool forceFull = false,
  }) {
    if (forceFull) {
      _pendingForceFull = true;
    }

    if (_transcribing) {
      if (!immediate) {
        _hasPendingTranscription = true;
      }
      return _ongoingTranscription ?? Future.value();
    }

    if (!_hasPendingTranscription && !immediate && !_pendingForceFull) {
      return Future.value();
    }

    final shouldForceFull = _pendingForceFull;
    _pendingForceFull = false;
    _hasPendingTranscription = false;
    _transcribing = true;

    final future = _transcribeLatest(forceFull: shouldForceFull);
    _ongoingTranscription = future;
    return future.whenComplete(() {
      _transcribing = false;
      _ongoingTranscription = null;

      final shouldForceRunAgain = _pendingForceFull ||
          (_hasPendingTranscription && (!_stopping || _pendingForceFull));

      if (!shouldForceRunAgain) {
        return;
      }

      _transcriptionTimer?.cancel();

      if (_pendingForceFull) {
        scheduleMicrotask(() {
          _runTranscription(immediate: true);
        });
      } else {
        _transcriptionTimer =
            Timer(_transcriptionDebounce, () => _runTranscription());
      }
    });
  }

  Future<void> _transcribeLatest({bool forceFull = false}) async {
    final slice = _audioSliceForTranscription(forceFull: forceFull);
    if (slice == null || slice.bytes.isEmpty) {
      return;
    }

    final uri = Uri.parse('/api/whisper').replace(queryParameters: {
      'model': _primaryModel,
      'fallback': '$_fallbackModel,whisper-1',
    });

    final request = http.MultipartRequest('POST', uri)
      ..fields['response_format'] = 'verbose_json'
      ..fields['temperature'] = '0';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      slice.bytes,
      filename: 'audio.webm',
      contentType: MediaType('audio', 'webm', {'codecs': 'opus'}),
    ));

    _log(
      'Enviando audio (${slice.bytes.length} bytes) para transcribir...',
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

    final updated = _applyTranscriptionPayload(payload, forceFull: forceFull);
    if (updated) {
      _emitTranscript(_transcriptBuffer);
    }

    _transcribedChunkCount = slice.endChunkIndex;
    if (_audioChunks.length > _transcribedChunkCount) {
      _hasPendingTranscription = true;
    }
  }

  bool _applyTranscriptionPayload(
    Map<String, dynamic> payload, {
    required bool forceFull,
  }) {
    if (forceFull) {
      _segmentTexts.clear();
      _lastFullTranscript = null;
    }

    final incomingSegments = _segmentsFromPayload(payload)
      ..sort((a, b) {
        final startComparison = a.start.compareTo(b.start);
        if (startComparison != 0) {
          return startComparison;
        }
        final endComparison = a.end.compareTo(b.end);
        if (endComparison != 0) {
          return endComparison;
        }
        return a.id.compareTo(b.id);
      });

    var appended = false;

    if (incomingSegments.isNotEmpty) {
      for (final segment in incomingSegments) {
        final previous = _segmentTexts[segment.id] ?? '';
        final addition = _diffAppend(previous, segment.text);
        if (addition.isEmpty) {
          _segmentTexts[segment.id] = segment.text;
          continue;
        }

        _appendToTranscript(addition);
        _segmentTexts[segment.id] = segment.text;
        appended = true;
      }

      if (appended) {
        _lastFullTranscript = null;
      }
      return appended;
    }

    final fallbackText = _sanitizeTranscript(
      (payload['text'] as String?) ?? '',
    );

    if (fallbackText.isEmpty) {
      return false;
    }

    if (_lastFullTranscript == fallbackText) {
      return false;
    }

    final addition = _diffAppend(_transcriptBuffer, fallbackText);
    if (addition.isEmpty) {
      _lastFullTranscript = fallbackText;
      return false;
    }

    _appendToTranscript(addition);
    _lastFullTranscript = fallbackText;
    return true;
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

  _PendingAudioSlice? _audioSliceForTranscription({bool forceFull = false}) {
    if (_audioChunks.isEmpty) {
      return null;
    }

    final currentEndIndex = _audioChunks.length;
    if (!forceFull && currentEndIndex <= _transcribedChunkCount) {
      return null;
    }

    if (forceFull || _transcribedChunkCount == 0) {
      final bytes = _combinedAudioBytes();
      return _PendingAudioSlice(
        bytes: bytes,
        startChunkIndex: 0,
        endChunkIndex: currentEndIndex,
      );
    }

    final context = math.min(_contextChunks, _transcribedChunkCount);
    var startChunkIndex = math.max(0, _transcribedChunkCount - context);

    if (currentEndIndex - startChunkIndex > _maxChunksPerUpload) {
      startChunkIndex = math.max(0, currentEndIndex - _maxChunksPerUpload);
    }

    final bytes = _combinedAudioRange(startChunkIndex, currentEndIndex);
    return _PendingAudioSlice(
      bytes: bytes,
      startChunkIndex: startChunkIndex,
      endChunkIndex: currentEndIndex,
    );
  }

  List<_TranscriptSegment> _segmentsFromPayload(Map<String, dynamic> payload) {
    final segmentsField = payload['segments'];
    if (segmentsField is! List) {
      return const <_TranscriptSegment>[];
    }

    final parsed = <_TranscriptSegment>[];
    for (var index = 0; index < segmentsField.length; index++) {
      final entry = segmentsField[index];
      if (entry is! Map<String, dynamic>) {
        continue;
      }

      final rawText = entry['text'];
      if (rawText is! String) {
        continue;
      }

      final sanitized = _sanitizeTranscript(rawText);
      if (sanitized.isEmpty) {
        continue;
      }

      final rawId = entry['id'];
      final id = rawId == null ? 'segment-$index' : rawId.toString();
      final start = _parseTimestamp(entry['start'], index.toDouble());
      final end = _parseTimestamp(entry['end'], start);

      parsed.add(
        _TranscriptSegment(
          id: id,
          text: sanitized,
          start: start,
          end: end,
        ),
      );
    }

    return parsed;
  }

  String _sanitizeTranscript(String value) {
    final normalized = value.replaceAll('\n', ' ');
    final collapsed = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed;
  }

  void _appendToTranscript(String addition) {
    final cleaned = addition.trim();
    if (cleaned.isEmpty) {
      return;
    }

    if (_transcriptBuffer.isEmpty) {
      _transcriptBuffer = cleaned;
      return;
    }

    final needsSpace = _needsSpaceBetween(_transcriptBuffer, cleaned);
    _transcriptBuffer += needsSpace ? ' $cleaned' : cleaned;
  }

  String _diffAppend(String existing, String incoming) {
    if (incoming.isEmpty || incoming == existing) {
      return '';
    }

    if (existing.isEmpty) {
      return incoming;
    }

    if (incoming.startsWith(existing)) {
      return incoming.substring(existing.length).trimLeft();
    }

    final maxOverlap =
        existing.length < incoming.length ? existing.length : incoming.length;

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final suffix = existing.substring(existing.length - overlap);
      final prefix = incoming.substring(0, overlap);
      if (suffix == prefix) {
        return incoming.substring(overlap).trimLeft();
      }
    }

    return '';
  }

  bool _needsSpaceBetween(String existing, String addition) {
    if (existing.isEmpty) {
      return false;
    }

    final lastChar = existing.codeUnitAt(existing.length - 1);
    final firstChar = addition.codeUnitAt(0);

    const whitespace = <int>[32, 9, 10, 13];
    if (whitespace.contains(lastChar)) {
      return false;
    }

    const punctuation = <int>[44, 46, 33, 63, 58, 59];
    if (punctuation.contains(firstChar)) {
      return false;
    }

    return true;
  }

  double _parseTimestamp(dynamic value, double fallback) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback;
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
    _cachedRecentAudio = _cachedCombinedAudio;
    _cachedRecentStartIndex = 0;
    _cachedRecentEndIndex = _audioChunks.length;
    _cachedRecentIncludesHeader = true;
    return _cachedCombinedAudio!;
  }

  Uint8List _combinedAudioRange(int startChunkIndex, int endChunkIndex) {
    if (_audioChunks.isEmpty) {
      return Uint8List(0);
    }

    final normalizedStart = startChunkIndex <= 0 ? 0 : startChunkIndex;
    final normalizedEnd = math.max(normalizedStart, math.min(endChunkIndex, _audioChunks.length));
    final includeHeader = normalizedStart > 0;

    if (!includeHeader && normalizedStart == 0 && normalizedEnd == _audioChunks.length) {
      return _combinedAudioBytes();
    }

    if (_cachedRecentAudio != null &&
        _cachedRecentStartIndex == normalizedStart &&
        _cachedRecentEndIndex == normalizedEnd &&
        _cachedRecentIncludesHeader == includeHeader) {
      return _cachedRecentAudio!;
    }

    final builder = BytesBuilder(copy: false);
    if (includeHeader) {
      builder.add(_audioChunks.first);
    }

    for (var index = normalizedStart; index < normalizedEnd; index++) {
      builder.add(_audioChunks[index]);
    }

    final bytes = builder.takeBytes();
    _cachedRecentAudio = bytes;
    _cachedRecentStartIndex = normalizedStart;
    _cachedRecentEndIndex = normalizedEnd;
    _cachedRecentIncludesHeader = includeHeader;
    return bytes;
  }

  Future<void> _disposeInternal() async {
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _ongoingTranscription = null;
    _hasPendingTranscription = false;
    _pendingForceFull = false;
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
    _cachedRecentAudio = null;
    _cachedRecentStartIndex = 0;
    _cachedRecentEndIndex = 0;
    _cachedRecentIncludesHeader = false;
    _segmentTexts.clear();
    _lastFullTranscript = null;
    _transcriptBuffer = '';
    _lastEmittedTranscript = null;
    _transcribedChunkCount = 0;
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
