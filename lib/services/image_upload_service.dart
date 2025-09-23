import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:narra/supabase/narra_client.dart';

/// Service for handling image uploads to Supabase Storage
class ImageUploadService {
  static const String bucketName = 'narra_stories';

  /// Upload image to Supabase Storage and return the public URL
  static Future<String> uploadStoryImage({
    required String storyId,
    required Uint8List imageBytes,
    required String fileName,
    String? mimeType,
  }) async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Generate unique filename with path structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _getFileExtension(fileName);
      final uniqueFileName = '${user.id}/$storyId/${timestamp}_$fileName';

      // Upload to Supabase Storage
      final client = NarraSupabaseClient.client;
      if (mimeType != null) {
        await client.storage.from(bucketName).uploadBinary(
          uniqueFileName,
          imageBytes,
          fileOptions: FileOptions(contentType: mimeType),
        );
      } else {
        await client.storage.from(bucketName).uploadBinary(
          uniqueFileName,
          imageBytes,
        );
      }

      // Get public URL
      final publicUrl = client.storage
          .from(bucketName)
          .getPublicUrl(uniqueFileName);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading image: $e');
    }
  }

  /// Delete image from Supabase Storage
  static Future<void> deleteStoryImage(String imageUrl) async {
    final user = NarraSupabaseClient.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Find the bucket name in the path and get everything after it
      final bucketIndex = pathSegments.indexOf(bucketName);
      if (bucketIndex == -1 || bucketIndex >= pathSegments.length - 1) {
        throw Exception('Invalid image URL format');
      }
      
      final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
      
      // Delete from Supabase Storage
      final client = NarraSupabaseClient.client;
      await client.storage.from(bucketName).remove([filePath]);
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Could not delete image from storage: $e');
      }
      // Don't throw error for deletion failures to avoid breaking the flow
    }
  }

  /// Get file extension from filename
  static String _getFileExtension(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return fileName.substring(dotIndex);
  }

  /// Determine MIME type from file extension
  static String? getMimeType(String fileName) {
    final extension = _getFileExtension(fileName).toLowerCase();
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return null;
    }
  }

  /// Validate if file is a supported image format
  static bool isSupportedImageFormat(String fileName) {
    final extension = _getFileExtension(fileName).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(extension);
  }

  /// Get optimized file name for storage
  static String getOptimizedFileName(String originalFileName) {
    // Remove special characters and spaces
    String cleaned = originalFileName.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_');
    
    // Ensure it's not too long
    if (cleaned.length > 100) {
      final extension = _getFileExtension(cleaned);
      final nameWithoutExt = cleaned.substring(0, cleaned.length - extension.length);
      cleaned = nameWithoutExt.substring(0, 100 - extension.length) + extension;
    }
    
    return cleaned;
  }
}