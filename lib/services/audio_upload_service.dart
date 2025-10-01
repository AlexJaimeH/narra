import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:narra/supabase/narra_client.dart';

/// Service to upload raw audio recordings to Supabase Storage
class AudioUploadService {
  static const String bucketName = 'narra_stories'; // reuse bucket

  static Future<String> uploadStoryAudio({
    required String storyId,
    required Uint8List audioBytes,
    String fileName = 'recording.webm',
    String contentType = 'audio/webm',
  }) async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${user.id}/$storyId/${timestamp}_$fileName';

      final client = NarraSupabaseClient.client;
      await client.storage.from(bucketName).uploadBinary(
        uniqueFileName,
        audioBytes,
        fileOptions: FileOptions(contentType: contentType),
      );

      final publicUrl = client.storage
          .from(bucketName)
          .getPublicUrl(uniqueFileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading audio: $e');
    }
  }
}


