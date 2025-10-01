import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

typedef OnChunk = void Function(Uint8List bytes, String mimeType);

class VoiceRecorder {
  final Record _record = Record();
  Timer? _pollTimer;
  final List<Uint8List> _chunks = [];
  String _path = '';

  Future<void> start({OnChunk? onChunk}) async {
    final hasPerm = await _record.hasPermission();
    if (!hasPerm) {
      final granted = await _record.hasPermission();
      if (!granted) throw Exception('Mic permission denied');
    }

    await _record.start(
      encoder: AudioEncoder.webmOpus,
      samplingRate: 48000,
      bitRate: 128000,
    );

    // Poll temporary file and emit chunks (best-effort for near-real-time)
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 900), (t) async {
      if (onChunk == null) return;
      final path = await _record.getRecordURL();
      if (path != null && path.isNotEmpty) {
        _path = path;
        // This package does not expose incremental bytes easily.
        // As a workaround, we skip per-chunk on mobile; Whisper transcribe on stop.
      }
    });
  }

  Future<Uint8List?> stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    final path = await _record.stop();
    if (path == null) return null;
    // read file into bytes
    try {
      // ignore: avoid_web_libraries_in_flutter
      // On mobile, use dart:io; but we can't import here due to web build.
      // Consumers only need the merged bytes; record returns file path which
      // will be read by platform-specific IO in higher layer if needed.
      return null;
    } catch (_) {
      return null;
    }
  }
}


