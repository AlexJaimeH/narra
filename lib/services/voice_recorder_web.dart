import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
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

class _TranscriptAccumulator {
  String _value = '';
  String? _lastEmitted;

  String get value => _value;

  void reset() {
    _value = '';
    _lastEmitted = null;
  }

  void emitReset(OnText? callback) {
    _value = '';
    _lastEmitted = '';
    callback?.call('');
    debugPrint('[VoiceRecorder] Emitiendo transcripción (0 chars)');
  }

  bool apply(
    String nextTranscript, {
    required bool forceFull,
    required void Function(String level, String message) log,
  }) {
    if (forceFull) {
      if (_value == nextTranscript) {
        log('debug',
            'Transcripción final sin cambios, se mantiene el texto actual.');
        return false;
      }

      _value = nextTranscript;
      log('debug', 'Transcript reemplazado tras forceFull => "$_value"');
      return true;
    }

    if (_value.isEmpty) {
      return appendAddition(nextTranscript, log: log);
    }

    if (_value == nextTranscript) {
      log('debug', 'Transcripción idéntica a la previa, sin cambios.');
      return false;
    }

    if (nextTranscript.startsWith(_value)) {
      final addition = nextTranscript.substring(_value.length).trimLeft();
      if (addition.isEmpty) {
        log('debug', 'Respuesta solo repite texto previo, se omite.');
        return false;
      }

      return appendAddition(addition, log: log);
    }

    final prefixLength = _longestCommonPrefixLength(_value, nextTranscript);
    if (prefixLength < _value.length) {
      if (nextTranscript.length >= _value.length) {
        log(
          'info',
          'Transcripción corregida por el modelo (prefix=$prefixLength, '
              'previo=${_value.length}, nuevo=${nextTranscript.length}). '
              'Se reemplaza el texto previo para mantener fidelidad.',
        );
        _value = nextTranscript;
        return true;
      }

      log(
        'warning',
        'Transcripción nueva más corta que la previa (prefix=$prefixLength). '
            'Se ignora para no perder texto.',
      );
      return false;
    }

    final addition = nextTranscript.substring(prefixLength).trimLeft();
    if (addition.isEmpty) {
      log('debug', 'Texto restante vacío tras calcular diff, se omite.');
      return false;
    }

    return appendAddition(addition, log: log);
  }

  bool emitIfChanged(OnText? callback) {
    if (_lastEmitted == _value) {
      return false;
    }

    _lastEmitted = _value;
    callback?.call(_value);
    debugPrint(
        '[VoiceRecorder] Emitiendo transcripción (${_value.length} chars)');
    return true;
  }

  bool appendAddition(
    String addition, {
    required void Function(String, String) log,
  }) {
    return _appendInternal(addition, log: log);
  }

  bool _appendInternal(
    String addition, {
    required void Function(String, String) log,
  }) {
    final cleaned = addition.trim();
    if (cleaned.isEmpty) {
      return false;
    }

    if (_value.isEmpty) {
      _value = cleaned;
      log('debug', 'Transcript inicial establecido: "$_value"');
      return true;
    }

    final needsSpace = _needsSpaceBetween(_value, cleaned);
    final appendedText = needsSpace ? ' $cleaned' : cleaned;
    _value += appendedText;
    log('debug', 'Transcript actualizado con "$appendedText" => "$_value"');
    return true;
  }

  static bool _needsSpaceBetween(String existing, String addition) {
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

  static int _longestCommonPrefixLength(String a, String b) {
    final minLength = a.length < b.length ? a.length : b.length;
    var index = 0;

    while (index < minLength && a.codeUnitAt(index) == b.codeUnitAt(index)) {
      index++;
    }

    return index;
  }
}

class VoiceRecorder {
  static const _primaryModel = 'gpt-4o-mini-transcribe';
  static const _fallbackModel = 'gpt-4o-transcribe-latest';
  static const _transcriptionDebounce = Duration(milliseconds: 120);
  static const _preferredTimeslices = <int>[240, 360, 520, 800];

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
  bool _pendingForceFull = false;
  Timer? _transcriptionTimer;
  Future<void>? _ongoingTranscription;

  final _TranscriptAccumulator _transcript = _TranscriptAccumulator();

  int _uploadedChunkTail = 0;

  Completer<void>? _stopCompleter;

  Future<void> start({OnText? onText, OnRecorderLog? onLog}) async {
    _onText = onText;
    _onLog = onLog;

    _resetState();
    _transcript.emitReset(_onText);

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

      final error = await _initializeRecorderFromStream(stream);
      if (error != null) {
        throw Exception(error);
      }

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

    final completer = Completer<void>();
    _stopCompleter = completer;

    try {
      _mediaRecorder?.stop();
    } catch (error) {
      _log('MediaRecorder.stop al pausar falló',
          level: 'warning', error: error);
    }

    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      // ignore timeout: algunos navegadores tardan en cerrar el stream
      // y aún así entregan los últimos datos correctamente.
    }

    _stopCompleter = null;

    _releaseCurrentStream();
    _mediaRecorder = null;
    _isRecording = false;

    _markPendingTranscription();
    return true;
  }

  Future<bool> resume() async {
    if (!_isPaused) {
      return _isRecording;
    }

    _log('Reanudando grabación...');

    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      _log('El navegador no soporta mediaDevices', level: 'error');
      return false;
    }

    try {
      final stream = await devices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
      });

      final error = await _initializeRecorderFromStream(stream);
      if (error != null) {
        _log('No se pudo reanudar la grabación: $error', level: 'error');
        return false;
      }

      _log('Grabación reanudada');
      return true;
    } catch (error) {
      _log('No se pudo reanudar la grabación', level: 'error', error: error);
      return false;
    }
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
    _transcript.reset();
    _uploadedChunkTail = 0;
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

  Future<String?> _initializeRecorderFromStream(html.MediaStream stream) async {
    _inputStream = stream;

    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) {
      _log('No se encontró un micrófono activo', level: 'error');
      _releaseStream(stream);
      _inputStream = null;
      return 'Micrófono no disponible';
    }

    _audioTrack = tracks.first;
    debugPrint('[VoiceRecorder] Micrófono: ${_audioTrack?.label}');

    final recorder = _createMediaRecorder(stream);
    if (recorder == null) {
      _log('MediaRecorder no soportado en este navegador', level: 'error');
      _releaseStream(stream);
      _audioTrack = null;
      _inputStream = null;
      return 'MediaRecorder no soportado en este navegador';
    }

    _mediaRecorder = recorder;
    _attachRecorderListeners(recorder);

    final started = _startRecorder(recorder);
    if (!started) {
      _mediaRecorder = null;
      _releaseStream(stream);
      _audioTrack = null;
      _inputStream = null;
      return 'No se pudo iniciar la grabación: MediaRecorder falló';
    }

    _isRecording = true;
    _isPaused = false;
    return null;
  }

  bool _startRecorder(html.MediaRecorder recorder) {
    var started = false;
    for (final slice in _preferredTimeslices) {
      try {
        recorder.start(slice);
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
        recorder.start();
        started = true;
      } catch (error) {
        _log('MediaRecorder.start sin timeslice falló',
            level: 'error', error: error);
      }
    }

    return started;
  }

  void _releaseStream(html.MediaStream stream) {
    try {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    } catch (_) {
      // ignore
    }
  }

  void _releaseCurrentStream() {
    final stream = _inputStream;
    if (stream != null) {
      _releaseStream(stream);
    }
    _inputStream = null;
    _audioTrack = null;
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

    final rawText = payload['text'];
    final normalizedText =
        rawText is String ? rawText.replaceAll('\n', ' ') : null;
    final segmentsField = payload['segments'];
    final segmentCount = segmentsField is List ? segmentsField.length : 0;
    _log(
      'Respuesta OpenAI recibida (text: ${normalizedText == null ? 'null' : '"$normalizedText"'}, segments: $segmentCount)',
      level: 'debug',
    );

    final updated = _applyTranscriptionPayload(payload, forceFull: forceFull);
    if (updated) {
      _transcript.emitIfChanged(_onText);
    }

    _uploadedChunkTail = slice.endChunkIndex;
    if (_audioChunks.length > _uploadedChunkTail) {
      _hasPendingTranscription = true;
    }
  }

  bool _applyTranscriptionPayload(
    Map<String, dynamic> payload, {
    required bool forceFull,
  }) {
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

    if (incomingSegments.isNotEmpty) {
      final segmentSummaries = incomingSegments
          .map(
            (segment) =>
                '${segment.id}[${segment.start.toStringAsFixed(2)}-${segment.end.toStringAsFixed(2)}]: "${segment.text}"',
          )
          .join(' | ');
      _log(
        'Segmentos recibidos (${incomingSegments.length}): $segmentSummaries',
        level: 'debug',
      );
    }

    var transcriptCandidate = _sanitizeTranscript(
      (payload['text'] as String?) ?? '',
    );

    if (transcriptCandidate.isEmpty && incomingSegments.isNotEmpty) {
      transcriptCandidate = _sanitizeTranscript(
        incomingSegments.map((segment) => segment.text).join(' '),
      );
      if (transcriptCandidate.isNotEmpty) {
        _log(
          'Transcript derivado de segmentos: "$transcriptCandidate"',
          level: 'debug',
        );
      }
    }

    if (transcriptCandidate.isEmpty) {
      _log('Respuesta sin texto utilizable, se omite.', level: 'debug');
      return false;
    }

    return _transcript.apply(
      transcriptCandidate,
      forceFull: forceFull,
      log: (level, message) => _log(message, level: level),
    );
  }

  _PendingAudioSlice? _audioSliceForTranscription({bool forceFull = false}) {
    if (_audioChunks.isEmpty) {
      return null;
    }

    final currentEndIndex = _audioChunks.length;
    if (!forceFull && currentEndIndex <= _uploadedChunkTail) {
      return null;
    }

    final bytes = _combinedAudioBytes();
    return _PendingAudioSlice(
      bytes: bytes,
      startChunkIndex: 0,
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
      final noSpeechProb = _asNullableDouble(entry['no_speech_prob']);
      if (noSpeechProb != null && noSpeechProb >= 0.8) {
        _log(
          'Segmento $id descartado por no_speech_prob=$noSpeechProb',
          level: 'debug',
        );
        continue;
      }

      final avgLogProb = _asNullableDouble(entry['avg_logprob']);
      if (avgLogProb != null && avgLogProb < -1.2) {
        _log(
          'Segmento $id descartado por avg_logprob=$avgLogProb',
          level: 'debug',
        );
        continue;
      }

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

  double? _asNullableDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
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
    _transcript.reset();
    _uploadedChunkTail = 0;
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

  // ignore: unused_element
  void _appendToTranscript(String addition) {
    final sanitized = _sanitizeTranscript(addition);
    if (sanitized.isEmpty) {
      return;
    }

    final updated = _transcript.appendAddition(
      sanitized,
      log: (level, message) => _log(message, level: level),
    );

    if (updated) {
      _transcript.emitIfChanged(_onText);
    }
  }
}
