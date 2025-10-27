import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);
typedef OnLevel = void Function(double level);
typedef OnTranscriptionState = void Function(bool active);

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
  }

  bool apply(
    String nextTranscript, {
    required bool forceFull,
    required void Function(String level, String message) log,
  }) {
    final cleaned = nextTranscript.trim();
    if (_value == cleaned) {
      final message = forceFull
          ? 'Transcripción final sin cambios, se mantiene el texto actual.'
          : 'Transcripción idéntica a la previa, sin cambios.';
      log('debug', message);
      return false;
    }

    _value = cleaned;
    if (_value.isEmpty) {
      log('debug', 'Transcript limpiado tras recibir texto vacío.');
    } else if (forceFull) {
      log('debug', 'Transcript reemplazado tras forceFull => "$cleaned"');
    } else {
      log('debug', 'Transcript reemplazado con "$cleaned"');
    }
    return true;
  }

  bool emitIfChanged(OnText? callback) {
    if (_lastEmitted == _value) {
      return false;
    }

    _lastEmitted = _value;
    callback?.call(_value);
    return true;
  }

  bool appendAddition(
    String additionText, {
    required void Function(String, String) log,
  }) {
    return _appendInternal(additionText, log: log);
  }

  bool _appendInternal(
    String additionText, {
    required void Function(String, String) log,
  }) {
    final cleaned = additionText.trim();
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

  static bool _needsSpaceBetween(String existing, String additionText) {
    if (existing.isEmpty) {
      return false;
    }

    final lastChar = existing.codeUnitAt(existing.length - 1);
    final firstChar = additionText.codeUnitAt(0);

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
}

class VoiceRecorder {
  static const _primaryModel = 'gpt-4o-mini-transcribe';
  static const _fallbackModel = 'gpt-4o-transcribe-latest';
  static const _transcriptionDebounce = Duration(milliseconds: 2);
  static const _preferredTimeslices = <int>[24, 40, 60, 90, 140];
  static const int _introSuppressionCount = 2;
  static const String _introPlaceholderMessage =
      'Transcripción en progreso… sigue narrando';
  static const Set<String> _supportedLanguages = {
    'es',
    'en',
    'pt',
    'fr',
    'it',
    'de',
  };

  OnText? _onText;
  OnRecorderLog? _onLog;
  OnLevel? _onLevel;
  OnTranscriptionState? _onTranscriptionState;

  html.MediaStream? _inputStream;
  html.MediaRecorder? _mediaRecorder;

  final List<Uint8List> _audioChunks = <Uint8List>[];
  Uint8List? _cachedCombinedAudio;
  int _cachedCombinedAudioChunkCount = 0;
  Uint8List? _cachedRecentAudio;
  int _cachedRecentStartIndex = 0;
  int _cachedRecentEndIndex = 0;
  bool _cachedRecentIncludesHeader = false;
  List<String> _languageHints = const <String>[];

  bool _isRecording = false;
  bool _isPaused = false;
  bool _stopping = false;

  bool _transcribing = false;
  bool _hasPendingTranscription = false;
  bool _pendingForceFull = false;
  Timer? _transcriptionTimer;
  Future<void>? _ongoingTranscription;
  bool _shouldShowTranscribing = false;

  final _TranscriptAccumulator _transcript = _TranscriptAccumulator();
  int _introPlaceholdersRemaining = 0;
  bool _lastReportedTranscribing = false;

  int _uploadedChunkTail = 0;

  Completer<void>? _stopCompleter;

  Object? _audioContext;
  Object? _audioAnalyser;
  Object? _audioSourceNode;
  Timer? _levelTimer;
  Uint8List? _levelDataBuffer;
  double _lastEmittedLevel = 0;
  bool _hasDetectedSpeech = false;

  Future<void> start(
      {OnText? onText,
      OnRecorderLog? onLog,
      OnLevel? onLevel,
      OnTranscriptionState? onTranscriptionState}) async {
    _onText = onText;
    _onLog = onLog;
    _onTranscriptionState = onTranscriptionState;

    _resetState();
    _introPlaceholdersRemaining = _introSuppressionCount;
    _onLevel = onLevel;
    _transcript.emitReset(_onText);
    _onLevel?.call(0);
    _reportTranscriptionState(false);
    _languageHints = _detectPreferredLanguages();
    if (_languageHints.isNotEmpty) {
      _log(
        'Idiomas preferidos detectados: ${_languageHints.join(', ')}',
        level: 'debug',
      );
    }

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
    _teardownLevelMonitoring();
    _onLevel?.call(0);
    _setTranscribing(false);

    // Limpiar placeholders antes de forzar transcripción final
    _introPlaceholdersRemaining = 0;

    await _ensureTranscription(forceFull: true);
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
      _setTranscribing(true);
      return true;
    } catch (error) {
      _log('No se pudo reanudar la grabación', level: 'error', error: error);
      return false;
    }
  }

  Future<Uint8List?> stop() async {
    _log('Deteniendo grabación...');
    _stopping = true;
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    _hasPendingTranscription = true;

    // Si el MediaRecorder existe (no pausado), detenerlo
    if (_mediaRecorder != null) {
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
    }

    // Limpiar placeholders antes de forzar transcripción final
    _introPlaceholdersRemaining = 0;

    await _ensureTranscription(forceFull: true);

    _onLevel?.call(0);

    // Obtener bytes de audio capturados (incluso si está pausado)
    final audioBytes = _combinedAudioBytes();
    await _disposeInternal();

    if (audioBytes.isEmpty) {
      _log('No se capturaron bytes de audio', level: 'warning');
      return null;
    }

    _log('Audio capturado exitosamente: ${audioBytes.length} bytes', level: 'debug');
    return audioBytes;
  }

  Future<void> dispose() async {
    await _disposeInternal();
  }

  void _resetState() {
    _teardownLevelMonitoring();
    _onLevel = null;
    _levelDataBuffer = null;
    _lastEmittedLevel = 0;
    _hasDetectedSpeech = false;
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
    _languageHints = const <String>[];
    _introPlaceholdersRemaining = 0;
    _shouldShowTranscribing = false;
    _reportTranscriptionState(false);
  }

  String? get _languageHint =>
      _languageHints.isNotEmpty ? _languageHints.first : null;

  List<String> _detectPreferredLanguages() {
    final navigator = html.window.navigator;
    final unique = <String>{};
    final resolved = <String>[];

    void addLanguage(String? raw) {
      final normalized = _normalizeLanguageCode(raw);
      if (normalized != null && unique.add(normalized)) {
        resolved.add(normalized);
      }
    }

    final languages = navigator.languages;
    if (languages != null) {
      for (final dynamic entry in languages) {
        addLanguage(entry?.toString());
      }
    }

    addLanguage(navigator.language);
    return resolved;
  }

  String? _detectPreferredLanguage() {
    final detected = _detectPreferredLanguages();
    if (detected.isNotEmpty) {
      return detected.first;
    }

    return _normalizeLanguageCode(html.window.navigator.language);
  }

  List<String> _resolveLanguageHints({String? fallbackHint}) {
    var cached = _languageHints;
    if (cached.isNotEmpty) {
      return cached;
    }

    final detected = _detectPreferredLanguages();
    if (detected.isNotEmpty) {
      _languageHints = detected;
      return detected;
    }

    final fallback = fallbackHint ?? _detectPreferredLanguage();
    if (fallback != null) {
      cached = <String>[fallback];
    } else {
      cached = const <String>[];
    }

    _languageHints = cached;
    return cached;
  }

  String? _normalizeLanguageCode(String? raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    for (final code in _supportedLanguages) {
      if (normalized == code || normalized.startsWith('$code-')) {
        return code;
      }
    }

    return null;
  }

  String _buildTranscriptionPrompt([List<String>? languages]) {
    final hints = languages ?? _languageHints;
    final buffer = StringBuffer(
      'You are a transcription tool. Your ONLY task is to transcribe the exact words spoken by the user. '
      'Rules: '
      '1. Transcribe exactly what is said, word for word '
      '2. Keep the original language - do not translate '
      '3. If multiple languages are mixed, preserve them exactly as spoken '
      '4. Add proper punctuation '
      '5. If there is silence or noise only, return empty '
      '6. NEVER respond to the user, NEVER answer questions, ONLY transcribe the audio',
    );

    if (hints.isNotEmpty) {
      buffer
        ..write(' Languages: ')
        ..write(hints.join(', '))
        ..write('.');
    }

    return buffer.toString();
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

    final recorder = _createMediaRecorder(stream);
    if (recorder == null) {
      _log('MediaRecorder no soportado en este navegador', level: 'error');
      _releaseStream(stream);
      _inputStream = null;
      return 'MediaRecorder no soportado en este navegador';
    }

    _mediaRecorder = recorder;
    _attachRecorderListeners(recorder);
    _setupLevelMonitoring(stream);

    final started = _startRecorder(recorder);
    if (!started) {
      _mediaRecorder = null;
      _releaseStream(stream);
      _inputStream = null;
      return 'No se pudo iniciar la grabación: MediaRecorder falló';
    }

    _isRecording = true;
    _isPaused = false;
    _setTranscribing(true);
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

  void _setupLevelMonitoring(html.MediaStream stream) {
    _teardownLevelMonitoring();
    if (_onLevel == null) {
      return;
    }

    try {
      Object? ctor;
      if (js_util.hasProperty(html.window, 'AudioContext')) {
        ctor = js_util.getProperty(html.window, 'AudioContext');
      }
      if (ctor == null &&
          js_util.hasProperty(html.window, 'webkitAudioContext')) {
        ctor = js_util.getProperty(html.window, 'webkitAudioContext');
      }

      if (ctor == null) {
        throw UnsupportedError('AudioContext no disponible');
      }

      final context = js_util.callConstructor(ctor, const []);
      final source =
          js_util.callMethod(context, 'createMediaStreamSource', [stream]);
      final analyser = js_util.callMethod(context, 'createAnalyser', const []);
      js_util.setProperty(analyser, 'fftSize', 512);
      js_util.setProperty(analyser, 'smoothingTimeConstant', 0.22);
      js_util.callMethod(source, 'connect', [analyser]);

      final binCount = js_util.getProperty(analyser, 'frequencyBinCount');
      final count = binCount is int ? binCount : int.tryParse('$binCount') ?? 0;

      _audioContext = context;
      _audioSourceNode = source;
      _audioAnalyser = analyser;
      _levelDataBuffer = Uint8List(count > 0 ? count : 512);
      _levelTimer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) => _emitAudioLevel(),
      );
    } catch (error) {
      _teardownLevelMonitoring();
      _log(
        'No se pudo iniciar el visualizador de audio',
        level: 'warning',
        error: error,
      );
    }
  }

  void _emitAudioLevel() {
    final analyser = _audioAnalyser;
    final buffer = _levelDataBuffer;
    final onLevel = _onLevel;
    if (analyser == null || buffer == null || onLevel == null) {
      return;
    }

    try {
      js_util.callMethod(analyser, 'getByteTimeDomainData', [buffer]);
    } catch (_) {
      return;
    }
    var sum = 0.0;
    for (var i = 0; i < buffer.length; i++) {
      final normalized = (buffer[i] - 128) / 128.0;
      sum += normalized * normalized;
    }

    final rms = math.sqrt(sum / buffer.length);
    final level = (rms * 1.35).clamp(0.0, 1.0);
    final previous = _lastEmittedLevel;
    final eased = (previous * 0.28) + (level * 0.72);

    _lastEmittedLevel = eased;
    if (!_hasDetectedSpeech && eased > 0.048) {
      _hasDetectedSpeech = true;
    }
    onLevel(eased);
  }

  void _teardownLevelMonitoring() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _levelDataBuffer = null;
    _lastEmittedLevel = 0;

    final source = _audioSourceNode;
    if (source != null) {
      try {
        js_util.callMethod(source, 'disconnect', const []);
      } catch (_) {}
    }
    _audioSourceNode = null;
    _audioAnalyser = null;

    final context = _audioContext;
    _audioContext = null;
    if (context != null) {
      try {
        final closeResult = js_util.callMethod(context, 'close', const []);
        if (closeResult is Future) {
          closeResult.catchError((_) {});
        } else if (closeResult != null) {
          try {
            js_util.promiseToFuture(closeResult).catchError((_) {});
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  void _markPendingTranscription() {
    if (_stopping) {
      return;
    }
    _hasPendingTranscription = true;
    _setTranscribing(true);
    _transcriptionTimer?.cancel();

    if (_transcribing) {
      _transcriptionTimer = Timer(
          _transcriptionDebounce, () => _runTranscription(immediate: true));
    } else {
      _runTranscription(immediate: true);
    }
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
        if (_stopping) {
          _setTranscribing(false);
        }
        return;
      }

      _transcriptionTimer?.cancel();

      if (_pendingForceFull) {
        scheduleMicrotask(() {
          _runTranscription(immediate: true);
        });
      } else {
        _transcriptionTimer = Timer(
          _transcriptionDebounce,
          () => _runTranscription(immediate: true),
        );
      }
    });
  }

  Future<void> _ensureTranscription({bool forceFull = false}) async {
    final active = _ongoingTranscription;
    if (active != null) {
      try {
        await active;
      } catch (_) {
        // ignore previous transcription failures before forcing a refresh
      }
    }

    _hasPendingTranscription = true;
    await _runTranscription(immediate: true, forceFull: forceFull);

    final followUp = _ongoingTranscription;
    if (followUp != null) {
      try {
        await followUp;
      } catch (_) {
        // ignore failures bubbling from the forced transcription
      }
    }
  }

  Future<void> _transcribeLatest({bool forceFull = false}) async {
    final slice = _audioSliceForTranscription(forceFull: forceFull);
    if (slice == null || slice.bytes.isEmpty) {
      return;
    }

    if (!forceFull && _transcript.value.isEmpty && !_hasDetectedSpeech) {
      _log(
        'Transcripción pospuesta: esperando detección de voz.',
        level: 'debug',
      );
      _hasPendingTranscription = true;
      return;
    }

    final hasTranscript = _transcript.value.isNotEmpty;
    final minBytes =
        forceFull ? 0 : (_hasDetectedSpeech || hasTranscript ? 1800 : 2400);
    if (!forceFull && slice.bytes.length < minBytes) {
      _log(
        'Transcripción pospuesta: acumulando más audio (${slice.bytes.length} bytes < $minBytes bytes mínimos)',
        level: 'debug',
      );
      _hasPendingTranscription = true;
      return;
    }

    final uri = Uri.parse('/api/whisper').replace(queryParameters: {
      'model': _primaryModel,
      'fallback': '$_fallbackModel,whisper-1',
    });

    final request = http.MultipartRequest('POST', uri)
      ..fields['response_format'] = 'verbose_json'
      ..fields['temperature'] = '0';

    final languageHint = _languageHint ?? _detectPreferredLanguage();

    final languages = _resolveLanguageHints(
      fallbackHint: languageHint,
    );
    request.fields['prompt'] = _buildTranscriptionPrompt(languages);

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
      if (response.statusCode == 401) {
        _log(
          'OpenAI rechazó la solicitud (401). Verifica la API key y variables OPENAI_TRANSCRIBE_* en Cloudflare.',
          level: 'error',
        );
      }
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

    if (forceFull) {
      _introPlaceholdersRemaining = 0;
    }

    final updated = _applyTranscriptionPayload(payload, forceFull: forceFull);
    if (updated) {
      // Si es forceFull, siempre emitir la transcripción real, nunca el placeholder
      if (!forceFull && _introPlaceholdersRemaining > 0) {
        _introPlaceholdersRemaining--;
        _onText?.call(_introPlaceholderMessage);
        return;
      }

      // Si el transcript es el placeholder, no emitir (esperar transcripción real)
      if (_transcript.value == _introPlaceholderMessage) {
        return;
      }

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
    final segmentsField = payload['segments'];
    final hasSegments = segmentsField is List && segmentsField.isNotEmpty;
    var hasConfidentSegment = false;
    if (segmentsField is List) {
      for (final entry in segmentsField) {
        if (entry is! Map<String, dynamic>) {
          hasConfidentSegment = true;
          break;
        }

        final noSpeechProb = _asNullableDouble(entry['no_speech_prob']);
        if (noSpeechProb == null || noSpeechProb < 0.8) {
          hasConfidentSegment = true;
          break;
        }
      }
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
    } else if (!hasConfidentSegment && hasSegments) {
      _log(
        'Todos los segmentos fueron marcados como silencio (no_speech_prob>=0.8). Se descarta la actualización.',
        level: 'debug',
      );
      return false;
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
    final normalizedEnd =
        math.max(normalizedStart, math.min(endChunkIndex, _audioChunks.length));
    final includeHeader = normalizedStart > 0;

    if (!includeHeader &&
        normalizedStart == 0 &&
        normalizedEnd == _audioChunks.length) {
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
    _teardownLevelMonitoring();
    _onLevel = null;
    _levelDataBuffer = null;
    _lastEmittedLevel = 0;
    _hasDetectedSpeech = false;
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
  }

  // ignore: unused_element
  void _appendToTranscript(String additionText) {
    final sanitized = _sanitizeTranscript(additionText);
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

  bool get isActivelyTranscribing => _shouldShowTranscribing;

  void _setTranscribing(bool active) {
    if (_shouldShowTranscribing == active) {
      return;
    }
    _shouldShowTranscribing = active;
    _reportTranscriptionState(active);
  }

  void _reportTranscriptionState(bool active) {
    if (_lastReportedTranscribing == active) {
      return;
    }
    _lastReportedTranscribing = active;
    _onTranscriptionState?.call(active);
  }
}
