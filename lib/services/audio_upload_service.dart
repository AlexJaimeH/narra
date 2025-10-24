import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:narra/supabase/narra_client.dart';

/// Service to upload raw audio recordings to Supabase Storage
class AudioUploadService {
  static const String bucketName = 'narra_stories'; // reuse bucket

  static const String _defaultRecordingFolder = 'recordings';

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
    final user = NarraSupabaseClient.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedFolder =
          (folder == null || folder.isEmpty) ? _defaultRecordingFolder : folder;
      final uniqueFileName =
          '${user.id}/$sanitizedFolder/${timestamp}_$fileName';

      final client = NarraSupabaseClient.client;
      await client.storage.from(bucketName).uploadBinary(
            uniqueFileName,
            audioBytes,
            fileOptions: FileOptions(contentType: contentType),
          );

      return _buildResult(path: uniqueFileName, client: client);
    } catch (e) {
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
