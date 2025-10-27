import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:narra/models/voice_recording.dart';
import 'package:narra/services/audio_upload_service.dart';
import 'package:narra/supabase/narra_client.dart';

class VoiceRecordingRepository {
  const VoiceRecordingRepository._();

  static SupabaseClient get _client => NarraSupabaseClient.client;

  static Future<List<VoiceRecording>> fetchAll(
      {required String storyId}) async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final normalizedStoryId = storyId.trim();
    if (normalizedStoryId.isEmpty) {
      return const <VoiceRecording>[];
    }

    final query = _client
        .from('voice_recordings')
        .select()
        .eq('user_id', user.id)
        .eq('story_id', normalizedStoryId);

    final response = await query.order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((item) => VoiceRecording.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  static Future<VoiceRecording> create({
    required Uint8List audioBytes,
    required String transcript,
    double? durationSeconds,
    required String storyId,
    String? storyTitle,
  }) async {
    if (kDebugMode) {
      debugPrint('📦 [VoiceRecordingRepository.create] INICIANDO');
      debugPrint('   - storyId: $storyId');
      debugPrint('   - storyTitle: $storyTitle');
      debugPrint('   - audioBytes: ${audioBytes.lengthInBytes} bytes');
      debugPrint('   - transcript length: ${transcript.length} chars');
      debugPrint('   - duration: $durationSeconds seconds');
    }

    final user = NarraSupabaseClient.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('❌ [VoiceRecordingRepository] Usuario no autenticado');
      }
      throw Exception('Usuario no autenticado');
    }

    if (kDebugMode) {
      debugPrint('   - user.id: ${user.id}');
    }

    final normalizedStoryId = storyId.trim();
    if (normalizedStoryId.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ [VoiceRecordingRepository] Story ID está vacío');
      }
      throw Exception(
          'No se pudo asociar la grabación sin una historia válida');
    }

    final normalizedTitle = (storyTitle ?? '').trim();
    final resolvedTitle =
        normalizedTitle.isEmpty ? 'Historia sin título' : normalizedTitle;

    if (kDebugMode) {
      debugPrint('   - normalizedStoryId: $normalizedStoryId');
      debugPrint('   - resolvedTitle: $resolvedTitle');
    }

    if (kDebugMode) {
      debugPrint('🔐 [VoiceRecordingRepository] Verificando perfil de usuario...');
    }
    await NarraSupabaseClient.ensureUserProfileExists();

    try {
      if (kDebugMode) {
        debugPrint('📤 [VoiceRecordingRepository] Subiendo audio a Supabase Storage...');
      }
      final upload = await AudioUploadService.uploadRecording(
        audioBytes: audioBytes,
        fileName: 'voice_recording.webm',
        folder: 'stories/$normalizedStoryId/voice-recordings',
      );

      if (kDebugMode) {
        debugPrint('✅ [VoiceRecordingRepository] Audio subido exitosamente');
        debugPrint('   - path: ${upload.path}');
        debugPrint('   - publicUrl: ${upload.publicUrl}');
      }

      final payload = <String, dynamic>{
        'user_id': user.id,
        'story_id': normalizedStoryId,
        'story_title': resolvedTitle,
        'audio_url': upload.publicUrl,
        'audio_path': upload.path,
        'storage_bucket': AudioUploadService.bucketName,
        'transcript': transcript,
        'duration_seconds': durationSeconds,
      };

      if (kDebugMode) {
        debugPrint('💾 [VoiceRecordingRepository] Insertando en tabla voice_recordings...');
        debugPrint('   - payload: $payload');
      }

      final inserted = await _client
          .from('voice_recordings')
          .insert(payload)
          .select()
          .single();

      final insertedMap = inserted is Map<String, dynamic>
          ? inserted
          : Map<String, dynamic>.from(inserted as Map);

      if (kDebugMode) {
        debugPrint('✅ [VoiceRecordingRepository] Grabación guardada en DB');
        debugPrint('   - id: ${insertedMap['id']}');
        debugPrint('   - created_at: ${insertedMap['created_at']}');
      }

      return VoiceRecording.fromMap(insertedMap);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [VoiceRecordingRepository.create] ERROR FATAL');
        debugPrint('   - error: $error');
        debugPrint('   - stackTrace: $stackTrace');
      }
      rethrow;
    }
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

  static Future<void> updateStoryAssociation({
    required String recordingId,
    required String storyId,
    String? storyTitle,
  }) async {
    await _client.from('voice_recordings').update({
      'story_id': storyId,
      'story_title': storyTitle,
    }).eq('id', recordingId);
  }

  static Future<void> delete({
    required String recordingId,
    required String audioPath,
  }) async {
    await _client.from('voice_recordings').delete().eq('id', recordingId);
    await AudioUploadService.deleteRecordingFile(audioPath);
  }
}
