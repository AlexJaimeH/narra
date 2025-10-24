import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:narra/models/voice_recording.dart';
import 'package:narra/services/audio_upload_service.dart';
import 'package:narra/supabase/narra_client.dart';

class VoiceRecordingRepository {
  const VoiceRecordingRepository._();

  static SupabaseClient get _client => NarraSupabaseClient.client;

  static Future<List<VoiceRecording>> fetchAll() async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final response = await _client
        .from('voice_recordings')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => VoiceRecording.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static Future<VoiceRecording> create({
    required Uint8List audioBytes,
    required String transcript,
    double? durationSeconds,
    String? storyId,
    String? storyTitle,
  }) async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final upload = await AudioUploadService.uploadRecording(
      audioBytes: audioBytes,
      fileName: 'voice_recording.webm',
      folder: storyId != null ? 'stories/$storyId' : null,
    );

    final payload = <String, dynamic>{
      'user_id': user.id,
      'story_id': storyId,
      'story_title': storyTitle,
      'audio_url': upload.publicUrl,
      'audio_path': upload.path,
      'transcript': transcript,
      'duration_seconds': durationSeconds,
    };

    final inserted = await _client
        .from('voice_recordings')
        .insert(payload)
        .select()
        .single();

    return VoiceRecording.fromMap(
      Map<String, dynamic>.from(inserted as Map),
    );
  }

  static Future<VoiceRecording> updateTranscript({
    required String recordingId,
    required String transcript,
  }) async {
    final updated = await _client
        .from('voice_recordings')
        .update({'transcript': transcript})
        .eq('id', recordingId)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw Exception('No se encontró la grabación solicitada');
    }

    return VoiceRecording.fromMap(
      Map<String, dynamic>.from(updated as Map),
    );
  }

  static Future<void> delete({
    required String recordingId,
    required String audioPath,
  }) async {
    await _client.from('voice_recordings').delete().eq('id', recordingId);
    await AudioUploadService.deleteRecordingFile(audioPath);
  }
}
