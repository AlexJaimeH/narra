import 'dart:convert';

import 'package:http/http.dart' as http;

import 'story_access_record.dart';

class StoryPublicAccessException implements Exception {
  StoryPublicAccessException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'StoryPublicAccessException($statusCode): $message';
}

/// Bridge between the public story experience and the backend validator.
///
/// This service calls a Cloudflare Pages Function that verifies the subscriber
/// token, registers the access in Supabase and returns the resolved metadata
/// so we can persist it locally.
class StoryPublicAccessService {
  const StoryPublicAccessService._();

  static const String _endpoint = '/api/story-access';

  static Future<StoryAccessRecord?> registerAccess({
    required String authorId,
    required String storyId,
    required String subscriberId,
    required String token,
    String? source,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'authorId': authorId,
        'storyId': storyId,
        'subscriberId': subscriberId,
        'token': token,
        if (source != null && source.isNotEmpty) 'source': source,
      }),
    );

    final bodyText = utf8.decode(response.bodyBytes);
    Map<String, dynamic>? decoded;
    if (bodyText.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(bodyText);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        }
      } catch (_) {
        // Ignore invalid JSON responses, handled below.
      }
    }

    if (response.statusCode == 200) {
      final subscriber =
          decoded?['subscriber'] as Map<String, dynamic>? ?? const {};
      final resolvedToken =
          (decoded?['token'] as String?)?.trim().isNotEmpty == true
              ? decoded!['token'] as String
              : token;
      final resolvedSource =
          (decoded?['source'] as String?)?.trim().isNotEmpty == true
              ? decoded!['source'] as String
              : source;
      final grantedAtRaw = decoded?['grantedAt'] as String?;
      final grantedAt =
          grantedAtRaw != null ? DateTime.tryParse(grantedAtRaw) : null;

      return StoryAccessRecord(
        authorId: authorId,
        subscriberId: (subscriber['id'] as String?)?.isNotEmpty == true
            ? subscriber['id'] as String
            : subscriberId,
        subscriberName: subscriber['name'] as String?,
        accessToken: resolvedToken,
        source: resolvedSource,
        grantedAt: grantedAt ?? DateTime.now(),
      );
    }

    if (response.statusCode == 403 || response.statusCode == 404) {
      return null;
    }

    throw StoryPublicAccessException(
      statusCode: response.statusCode,
      message: decoded?['error']?.toString() ??
          'No se pudo validar el enlace de acceso.',
      body: decoded,
    );
  }
}
