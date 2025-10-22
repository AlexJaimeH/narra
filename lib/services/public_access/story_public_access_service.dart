import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:narra/supabase/supabase_config.dart';

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
    String? storyId,
    required String subscriberId,
    required String token,
    String? source,
    String? eventType,
  }) async {
    final supabaseUrl = SupabaseConfig.supabaseUrl.trim();
    final supabaseAnonKey = SupabaseConfig.supabaseAnonKey.trim();

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      return _registerAccessViaSupabase(
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: supabaseAnonKey,
        authorId: authorId,
        storyId: storyId,
        subscriberId: subscriberId,
        token: token,
        source: source,
        eventType: eventType,
      );
    }

    return _registerAccessViaLegacyFunction(
      authorId: authorId,
      subscriberId: subscriberId,
      token: token,
      storyId: storyId,
      source: source,
      eventType: eventType,
    );
  }

  static Future<StoryAccessRecord?> _registerAccessViaSupabase({
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String authorId,
    String? storyId,
    required String subscriberId,
    required String token,
    String? source,
    String? eventType,
  }) async {
    final payload = <String, dynamic>{
      'author_id': authorId,
      'subscriber_id': subscriberId,
      'token': token,
    };

    if (storyId != null && storyId.isNotEmpty) {
      payload['story_id'] = storyId;
    }
    if (source != null && source.isNotEmpty) {
      payload['source'] = source;
    }
    if (eventType != null && eventType.isNotEmpty) {
      payload['event_type'] = eventType;
    }

    final response = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/rpc/register_subscriber_access'),
      headers: {
        'Content-Type': 'application/json',
        'apikey': supabaseAnonKey,
        'Authorization': 'Bearer $supabaseAnonKey',
        'Prefer': 'return=representation',
      },
      body: jsonEncode(payload),
    );

    final decoded = _tryDecodeJson(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded == null) {
        throw StoryPublicAccessException(
          statusCode: response.statusCode,
          message: 'La respuesta del servidor no tiene el formato esperado.',
        );
      }

      final status = decoded['status']?.toString();
      switch (status) {
        case 'ok':
          final data = decoded['data'] as Map<String, dynamic>? ?? const {};
          return _buildAccessRecord(
            authorId: authorId,
            subscriberIdFallback: subscriberId,
            tokenFallback: token,
            sourceFallback: source,
            payload: data,
          );
        case 'not_found':
          return null;
        case 'forbidden':
          throw StoryPublicAccessException(
            statusCode: 403,
            message: decoded['message']?.toString() ??
                'No pudimos validar tu enlace en este momento.',
            body: decoded,
          );
        default:
          throw StoryPublicAccessException(
            statusCode: response.statusCode,
            message: decoded['message']?.toString() ??
                'No se pudo validar el enlace de acceso.',
            body: decoded,
          );
      }
    }

    throw StoryPublicAccessException(
      statusCode: response.statusCode,
      message: decoded?['message']?.toString() ??
          'No se pudo validar el enlace de acceso.',
      body: decoded,
    );
  }

  static Future<StoryAccessRecord?> _registerAccessViaLegacyFunction({
    required String authorId,
    required String subscriberId,
    required String token,
    String? storyId,
    String? source,
    String? eventType,
  }) async {
    final payload = <String, dynamic>{
      'authorId': authorId,
      'subscriberId': subscriberId,
      'token': token,
    };

    if (storyId != null && storyId.isNotEmpty) {
      payload['storyId'] = storyId;
    }
    if (source != null && source.isNotEmpty) {
      payload['source'] = source;
    }
    if (eventType != null && eventType.isNotEmpty) {
      payload['eventType'] = eventType;
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decoded = _tryDecodeJson(utf8.decode(response.bodyBytes));

    if (response.statusCode == 200) {
      return _buildAccessRecord(
        authorId: authorId,
        subscriberIdFallback: subscriberId,
        tokenFallback: token,
        sourceFallback: source,
        payload: decoded ?? const {},
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

  static Map<String, dynamic>? _tryDecodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      final dynamic parsed = jsonDecode(body);
      return parsed is Map<String, dynamic> ? parsed : null;
    } catch (_) {
      return null;
    }
  }

  static StoryAccessRecord _buildAccessRecord({
    required String authorId,
    required String subscriberIdFallback,
    required String tokenFallback,
    required String? sourceFallback,
    required Map<String, dynamic> payload,
  }) {
    final subscriber =
        payload['subscriber'] as Map<String, dynamic>? ?? const {};
    final resolvedToken =
        (payload['token'] as String?)?.trim().isNotEmpty == true
            ? payload['token'] as String
            : tokenFallback;
    final resolvedSource =
        (payload['source'] as String?)?.trim().isNotEmpty == true
            ? payload['source'] as String
            : sourceFallback;
    final grantedAtRaw = payload['grantedAt'] as String?;
    final grantedAt =
        grantedAtRaw != null ? DateTime.tryParse(grantedAtRaw) : null;

    return StoryAccessRecord(
      authorId: authorId,
      subscriberId: (subscriber['id'] as String?)?.isNotEmpty == true
          ? subscriber['id'] as String
          : subscriberIdFallback,
      subscriberName: subscriber['name'] as String?,
      accessToken: resolvedToken,
      source: resolvedSource,
      grantedAt: grantedAt ?? DateTime.now(),
    );
  }
}
