import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef OnText = void Function(String text);
typedef OnRecorderLog = void Function(String level, String message);

class _RealtimeSessionDetails {
  const _RealtimeSessionDetails({
    required this.clientSecret,
    required this.iceServers,
    required this.model,
    this.sessionId,
    this.expiresAt,
  });

  final String clientSecret;
  final List<Map<String, dynamic>> iceServers;
  final String model;
  final String? sessionId;
  final String? expiresAt;
}

class VoiceRecorder {
  static const _defaultModel = 'gpt-4o-mini-transcribe-realtime';
  html.MediaStream? _inputStream;
  html.MediaStreamTrack? _audioTrack;
  html.MediaRecorder? _mediaRecorder;
  html.RtcPeerConnection? _peerConnection;
  html.RtcDataChannel? _eventsChannel;

  final List<Uint8List> _recordedChunks = [];
  Completer<void>? _recorderStopCompleter;
  Completer<void>? _eventsChannelReadyCompleter;

  OnText? _onText;
  OnRecorderLog? _onLog;

  bool _stopping = false;
  bool _channelOpen = false;
  bool _isPaused = false;
  String? _activeResponseId;
  int _chunkCount = 0;
  String? _sessionId;

  Future<void> start({OnText? onText, OnRecorderLog? onLog}) async {
    _onText = onText;
    _onLog = onLog;

    _stopping = false;
    _channelOpen = false;
    _isPaused = false;
    _activeResponseId = null;
    _recordedChunks.clear();
    _chunkCount = 0;
    _eventsChannelReadyCompleter = Completer<void>();

    _log('Preparando sesión de transcripción...');
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
      }
    });

    _inputStream = stream;
    final tracks = stream.getAudioTracks();
    if (tracks.isEmpty) {
      _log('No se encontró un micrófono activo', level: 'error');
      throw Exception('Micrófono no disponible');
    }
    _audioTrack = tracks.first;
    _log('Micrófono listo: ${_audioTrack?.label ?? 'sin etiqueta'}');

    _initializeMediaRecorder(stream);

    final session = await _createRealtimeSession();
    _sessionId = session.sessionId;
    await _initializePeerConnection(session);

    try {
      await _eventsChannelReadyCompleter!.future
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _log('Timeout esperando canal de eventos', level: 'error');
      throw Exception('Tiempo de espera agotado al iniciar sesión Realtime');
    }

    if (_stopping) {
      _log('Sesión cancelada antes de iniciar', level: 'warning');
      throw Exception('Grabación cancelada');
    }

    _log('Conectado. Comienza a hablar cuando quieras.');
  }

  Future<bool> pause() async {
    _log('Pausando grabación...');
    _isPaused = true;

    try {
      _audioTrack?.enabled = false;
    } catch (error) {
      _log('No se pudo deshabilitar la pista de audio',
          level: 'warning', error: error);
    }

    if (_activeResponseId != null) {
      _safeSend({
        'type': 'response.cancel',
        'response_id': _activeResponseId,
      });
      _log('Respuesta activa cancelada: $_activeResponseId', level: 'debug');
      _activeResponseId = null;
    }

    _safeSend({'type': 'input_audio_buffer.commit'}, level: 'debug');

    try {
      _mediaRecorder?.pause();
    } catch (error) {
      _log('MediaRecorder.pause falló', level: 'warning', error: error);
    }

    return true;
  }

  Future<bool> resume() async {
    _log('Reanudando grabación...');
    _isPaused = false;

    try {
      _audioTrack?.enabled = true;
    } catch (error) {
      _log('No se pudo activar la pista de audio',
          level: 'warning', error: error);
    }

    try {
      _mediaRecorder?.resume();
    } catch (error) {
      _log('MediaRecorder.resume falló', level: 'warning', error: error);
    }

    if (_peerConnection?.connectionState != 'connected') {
      _log(
        'PeerConnection no está conectado (${_peerConnection?.connectionState})',
        level: 'warning',
      );
    }

    _requestTranscription(force: true);
    return true;
  }

  Future<Uint8List?> stop() async {
    if (_mediaRecorder == null && _peerConnection == null) {
      return null;
    }

    _log('Deteniendo grabación...');
    _stopping = true;

    _isPaused = false;

    if (_activeResponseId != null) {
      _safeSend({
        'type': 'response.cancel',
        'response_id': _activeResponseId,
      });
      _activeResponseId = null;
    }

    try {
      _audioTrack?.enabled = false;
    } catch (error) {
      _log('No se pudo deshabilitar la pista de audio',
          level: 'warning', error: error);
    }

    try {
      _mediaRecorder?.stop();
    } catch (error) {
      _log('MediaRecorder.stop falló', level: 'warning', error: error);
    }

    if (_recorderStopCompleter != null) {
      try {
        await _recorderStopCompleter!.future
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }

    try {
      _eventsChannel?.close();
    } catch (_) {}
    try {
      _peerConnection?.close();
    } catch (_) {}

    _channelOpen = false;
    _eventsChannelReadyCompleter = null;

    _inputStream?.getTracks().forEach((track) {
      try {
        track.stop();
      } catch (_) {}
    });

    final recorded = _mergeRecordedChunks();
    _resetState();
    _log('Grabación detenida. Audio capturado: ${recorded?.length ?? 0} bytes',
        level: 'debug');
    return recorded;
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<void> _initializePeerConnection(_RealtimeSessionDetails session) async {
    final iceServers = session.iceServers.isNotEmpty
        ? session.iceServers
        : [
            {'urls': 'stun:stun.l.google.com:19302'},
          ];

    final configuration = {
      'iceServers': iceServers,
    };

    final pc = html.RtcPeerConnection(configuration);
    _peerConnection = pc;

    pc.onConnectionStateChange.listen((_) {
      _log('Estado de conexión WebRTC: ${pc.connectionState}', level: 'debug');
    });

    final dataChannel = pc.createDataChannel('oai-events');
    _eventsChannel = dataChannel;

    dataChannel.onMessage.listen((event) {
      _handleEventMessage(event.data);
    });

    dataChannel.onOpen.listen((_) {
      _channelOpen = true;
      final sessionLabel = _sessionId != null ? ' ($_sessionId)' : '';
      _log('Canal de eventos abierto$sessionLabel');
      _eventsChannelReadyCompleter?.complete();
      _sendSessionConfiguration();
      _requestTranscription(force: true);
    });

    dataChannel.onClose.listen((_) {
      _channelOpen = false;
      _log('Canal de eventos cerrado', level: 'warning');
    });

    if (_audioTrack != null && _inputStream != null) {
      pc.addTrack(_audioTrack!, _inputStream!);
    }

    final offer = await pc.createOffer();
    await pc.setLocalDescription({'type': offer.type, 'sdp': offer.sdp});
    await _waitForIceGatheringComplete(pc);

    final localDescription = pc.localDescription;
    final localSdp = localDescription != null && localDescription.sdp != null
        ? localDescription.sdp!
        : offer.sdp!;

    _log(
      'Intercambiando SDP con OpenAI (model: ${session.model}, offer ${localSdp.length} chars)...',
      level: 'debug',
    );
    final answerSdp = await _exchangeSdp(localSdp, session);

    await pc.setRemoteDescription({
      'type': 'answer',
      'sdp': answerSdp,
    });
  }

  void _initializeMediaRecorder(html.MediaStream stream) {
    final candidates = <String>[
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/ogg;codecs=opus',
      'audio/ogg',
    ];

    String? mimeType;
    for (final candidate in candidates) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        mimeType = candidate;
        break;
      }
    }

    _log('Inicializando MediaRecorder (mimeType: ${mimeType ?? 'default'})',
        level: 'debug');

    _recorderStopCompleter = Completer<void>();
    final options =
        mimeType != null ? <String, dynamic>{'mimeType': mimeType} : null;
    final recorder = html.MediaRecorder(stream, options);
    _mediaRecorder = recorder;

    recorder.addEventListener('dataavailable', (event) async {
      final blobEvent = event as html.BlobEvent;
      final blob = blobEvent.data;
      if (blob == null || blob.size == 0) return;
      final bytes = await _blobToBytes(blob);
      if (bytes != null && bytes.isNotEmpty) {
        _recordedChunks.add(bytes);
        _chunkCount += 1;
        _log('Chunk $_chunkCount recibido (${bytes.length} bytes)',
            level: 'debug');
      }
    });

    recorder.addEventListener('stop', (_) {
      if (!(_recorderStopCompleter?.isCompleted ?? true)) {
        _recorderStopCompleter?.complete();
      }
    });

    try {
      recorder.start(1000);
      _log('MediaRecorder iniciado (cada 1s)', level: 'debug');
    } catch (error) {
      _log('No se pudo iniciar MediaRecorder', level: 'error', error: error);
      rethrow;
    }
  }

  Future<String> _exchangeSdp(
    String offerSdp,
    _RealtimeSessionDetails session,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.openai.com/v1/realtime?model=${Uri.encodeComponent(session.model)}',
      );
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.clientSecret}',
          'Content-Type': 'application/sdp',
          'Accept': 'application/sdp',
          'OpenAI-Beta': 'realtime=v1',
        },
        body: offerSdp,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }

      final errorDetails = _extractRealtimeError(response.body);
      _log(
        'Intercambio SDP falló (${response.statusCode}): $errorDetails',
        level: 'error',
      );
      throw Exception(
        'Intercambio SDP falló (${response.statusCode}): $errorDetails',
      );
    } catch (error) {
      _log('No se pudo intercambiar SDP', level: 'error', error: error);
      rethrow;
    }
  }

  Future<_RealtimeSessionDetails> _createRealtimeSession() async {
    try {
      _log('Solicitando sesión Realtime...', level: 'debug');
      final response = await http.post(
        Uri.parse('/api/realtime-session'),
        headers: const {'Content-Type': 'application/json'},
        body: '{}',
      );

      final body = response.body;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log('Sesión Realtime falló (${response.statusCode}): $body',
            level: 'error');
        throw Exception(
          'No se pudo crear sesión Realtime (${response.statusCode})',
        );
      }

      final data = jsonDecode(body) as Map<String, dynamic>;
      final clientSecret = (data['clientSecret'] ?? data['client_secret']) as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        throw Exception('Respuesta Realtime sin client_secret');
      }

      final rawIceServers = data['iceServers'] ?? data['ice_servers'];
      final iceServers = <Map<String, dynamic>>[];
      if (rawIceServers is List) {
        for (final entry in rawIceServers) {
          if (entry is Map<String, dynamic>) {
            iceServers.add(entry);
          } else if (entry is Map) {
            iceServers.add(Map<String, dynamic>.from(entry as Map));
          }
        }
      }
      if (iceServers.isEmpty) {
        iceServers.add({'urls': 'stun:stun.l.google.com:19302'});
      }

      final model = (data['model'] as String?)?.trim();

      return _RealtimeSessionDetails(
        clientSecret: clientSecret,
        iceServers: iceServers,
        model: model != null && model.isNotEmpty ? model : _defaultModel,
        sessionId: (data['sessionId'] ?? data['session_id']) as String?,
        expiresAt: (data['expiresAt'] ?? data['expires_at']) as String?,
      );
    } catch (error) {
      _log('No se pudo obtener sesión Realtime', level: 'error', error: error);
      rethrow;
    }
  }

  String _extractRealtimeError(String body) {
    try {
      final payload = jsonDecode(body);
      if (payload is Map<String, dynamic>) {
        final error = payload['error'];
        if (error is Map<String, dynamic>) {
          final message = (error['message'] ?? error['code'] ?? error['type'])
              ?.toString()
              .trim();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      }
    } catch (_) {
      // Ignored, fallback below.
    }
    final trimmed = body.trim();
    return trimmed.isEmpty ? 'sin detalles' : trimmed;
  }

  Future<void> _waitForIceGatheringComplete(html.RtcPeerConnection pc) async {
    if (pc.iceGatheringState == 'complete') {
      return;
    }
    final completer = Completer<void>();
    late html.EventListener listener;
    listener = (_) {
      if (pc.iceGatheringState == 'complete') {
        pc.removeEventListener('icegatheringstatechange', listener);
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    };
    pc.addEventListener('icegatheringstatechange', listener);
    await completer.future.timeout(const Duration(seconds: 5), onTimeout: () {
      pc.removeEventListener('icegatheringstatechange', listener);
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
  }

  void _handleEventMessage(dynamic data) {
    if (data is! String) {
      _log('Evento no textual recibido (${data.runtimeType})', level: 'debug');
      return;
    }

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(data) as Map<String, dynamic>;
    } catch (error) {
      _log('No se pudo parsear mensaje JSON', level: 'warning', error: error);
      return;
    }

    final type = payload['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'response.created':
        final response = payload['response'];
        final id = response is Map
            ? response['id'] as String?
            : payload['response_id'] as String?;
        _activeResponseId = id;
        _log('Respuesta creada (${id ?? 'desconocida'})', level: 'debug');
        break;
      case 'response.output_text.delta':
      case 'response.delta':
        _emitDelta(payload['delta']);
        break;
      case 'response.output_text.done':
      case 'response.completed':
        final response = payload['response'];
        final finishedId = response is Map
            ? response['id'] as String?
            : payload['response_id'] as String?;
        if (finishedId == null || finishedId == _activeResponseId) {
          _activeResponseId = null;
        }
        _log('Respuesta completada (${finishedId ?? 'desconocida'})',
            level: 'debug');
        if (!_stopping && !_isPaused) {
          _requestTranscription();
        }
        break;
      case 'response.canceled':
        final canceledId = payload['response_id'] as String?;
        if (canceledId == _activeResponseId) {
          _activeResponseId = null;
        }
        _log('Respuesta cancelada (${canceledId ?? 'desconocida'})',
            level: 'debug');
        break;
      case 'response.error':
      case 'error':
        final errorObj = payload['error'];
        final message = errorObj is Map
            ? errorObj['message']?.toString()
            : payload['message']?.toString();
        _log('Realtime error: ${message ?? payload.toString()}',
            level: 'error');
        break;
      default:
        if (type.startsWith('response.output_text')) {
          _emitDelta(payload['delta']);
        } else {
          _log('Evento recibido: $type', level: 'debug');
        }
    }
  }

  void _emitDelta(dynamic delta) {
    if (delta == null) return;

    if (delta is String) {
      if (delta.isNotEmpty) {
        _onText?.call(delta);
      }
      return;
    }

    if (delta is Map<String, dynamic>) {
      if (delta['text'] is String) {
        _emitDelta(delta['text']);
        return;
      }
      final content = delta['content'];
      if (content is List) {
        for (final element in content) {
          _emitDelta(element);
        }
      }
      return;
    }

    if (delta is List) {
      for (final element in delta) {
        _emitDelta(element);
      }
    }
  }

  void _sendSessionConfiguration() {
    _safeSend({
      'type': 'session.update',
      'session': {
        'modalities': ['text'],
        'instructions':
            'Eres un transcriptor en español. Devuelve exclusivamente, y tal cual, el texto que habla el usuario.',
      },
    }, level: 'debug', logPayload: true);
  }

  void _requestTranscription({bool force = false}) {
    if (!_channelOpen || _stopping) return;
    if (!force && (_isPaused || _activeResponseId != null)) {
      return;
    }
    _safeSend({
      'type': 'response.create',
      'response': {
        'modalities': ['text'],
        'instructions':
            'Transcribe en español únicamente lo que escucha el micrófono. No agregues notas ni etiquetas.',
      },
    }, level: 'debug', logPayload: true);
  }

  void _safeSend(Map<String, dynamic> payload,
      {String level = 'info', bool logPayload = false}) {
    if (!_channelOpen) {
      if (logPayload) {
        _log('Canal no disponible para enviar ${payload['type']}',
            level: 'warning');
      }
      return;
    }

    try {
      final message = jsonEncode(payload);
      _eventsChannel?.send(message);
      if (logPayload) {
        _log('Mensaje enviado: ${payload['type']}', level: level);
      }
    } catch (error) {
      _log('No se pudo enviar ${payload['type']}',
          level: 'error', error: error);
    }
  }

  Uint8List? _mergeRecordedChunks() {
    if (_recordedChunks.isEmpty) return null;
    final totalLength =
        _recordedChunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final merged = Uint8List(totalLength);
    var offset = 0;
    for (final chunk in _recordedChunks) {
      merged.setAll(offset, chunk);
      offset += chunk.length;
    }
    _recordedChunks.clear();
    return merged;
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
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    try {
      reader.readAsArrayBuffer(blob);
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future;
  }

  void _resetState() {
    _recorderStopCompleter = null;
    _eventsChannelReadyCompleter = null;
    _mediaRecorder = null;
    _eventsChannel = null;
    _peerConnection = null;
    _inputStream = null;
    _audioTrack = null;
    _onText = null;

    _onLog = null;

    _stopping = false;
    _channelOpen = false;
    _isPaused = false;
    _activeResponseId = null;
    _chunkCount = 0;
    _sessionId = null;
  }

  void _log(String message, {String level = 'info', Object? error}) {
    final detail = error != null ? '$message ($error)' : message;
    if (kDebugMode) {
      debugPrint('[VoiceRecorder][$level] $detail');
    }
    _onLog?.call(level, detail);
  }
}
