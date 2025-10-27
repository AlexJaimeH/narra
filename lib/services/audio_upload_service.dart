import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:narra/supabase/narra_client.dart';

/// Service to upload raw audio recordings to Supabase Storage
class AudioUploadService {
  static const String bucketName = 'voice-recordings';

  static const String _defaultRecordingFolder = 'recordings';
  static const String _logTag = '[AudioUploadService]';
  static final Uuid _uuid = const Uuid();

  const AudioUploadService._();

  /// Wrapper containing both storage path and public URL.
  static AudioUploadResult _buildResult({
    required String path,
    required SupabaseClient client,
  }) {
    final publicUrl = client.storage.from(bucketName).getPublicUrl(path);
    return AudioUploadResult(path: path, publicUrl: publicUrl);
  }

  static Future<AudioUploadResult> uploadRecording({
    required Uint8List audioBytes,
    String fileName = 'recording.webm',
    String? folder,
    String contentType = 'audio/webm',
  }) async {
    if (kDebugMode) {
      debugPrint('🎵 [AudioUploadService.uploadRecording] INICIANDO');
      debugPrint('   - fileName: $fileName');
      debugPrint('   - folder: $folder');
      debugPrint('   - audioBytes: ${audioBytes.lengthInBytes} bytes');
      debugPrint('   - contentType: $contentType');
    }

    final user = NarraSupabaseClient.currentUser;
    if (user == null) {
      if (kDebugMode) {
        debugPrint('❌ [AudioUploadService] Usuario no autenticado');
      }
      throw Exception('User not authenticated');
    }

    if (kDebugMode) {
      debugPrint('   - user.id: ${user.id}');
    }

    try {
      final sanitizedFolder = (folder == null || folder.isEmpty)
          ? _defaultRecordingFolder
          : folder
              .replaceAll('\\', '/')
              .split('/')
              .where(
                (segment) =>
                    segment.trim().isNotEmpty && segment.trim() != '..',
              )
              .join('/');

      if (kDebugMode) {
        debugPrint('   - sanitizedFolder: $sanitizedFolder');
      }

      final uniqueSuffix = _uuid.v4();
      final uniqueFileName = [
        user.id,
        if (sanitizedFolder.isNotEmpty) sanitizedFolder,
        '${uniqueSuffix}_$fileName',
      ].join('/');

      if (kDebugMode) {
        debugPrint('   - uniqueFileName: $uniqueFileName');
        debugPrint('   - bucketName: $bucketName');
      }

      final client = NarraSupabaseClient.client;

      if (kDebugMode) {
        debugPrint('📤 [AudioUploadService] Subiendo a Supabase Storage...');
      }

      await client.storage.from(bucketName).uploadBinary(
            uniqueFileName,
            audioBytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      if (kDebugMode) {
        debugPrint('✅ [AudioUploadService] Audio subido exitosamente');
      }

      final result = _buildResult(path: uniqueFileName, client: client);

      if (kDebugMode) {
        debugPrint('   - path: ${result.path}');
        debugPrint('   - publicUrl: ${result.publicUrl}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AudioUploadService] Upload failed: $e');
      }
      throw Exception('Error uploading audio: $e');
    }
  }

  static Future<String> uploadStoryAudio({
    required String storyId,
    required Uint8List audioBytes,
    String fileName = 'recording.webm',
    String contentType = 'audio/webm',
  }) async {
    try {
      final result = await uploadRecording(
        audioBytes: audioBytes,
        fileName: fileName,
        folder: 'stories/$storyId',
        contentType: contentType,
      );
      return result.publicUrl;
    } catch (e) {
      throw Exception('Error uploading audio: $e');
    }
  }

  static Future<void> deleteRecordingFile(String path) async {
    try {
      final client = NarraSupabaseClient.client;
      await client.storage.from(bucketName).remove([path]);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting audio file $path: $e');
      }
    }
  }
}

class AudioUploadResult {
  final String path;
  final String publicUrl;

  const AudioUploadResult({
    required this.path,
    required this.publicUrl,
  });
}
