import 'dart:convert';

import 'package:http/http.dart' as http;

class StoryFeedbackException implements Exception {
  StoryFeedbackException({
    required this.statusCode,
    required this.message,
    this.body,
  });

  final int statusCode;
  final String message;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'StoryFeedbackException($statusCode): $message';
}

class StoryFeedbackComment {
  StoryFeedbackComment({
    required this.id,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.subscriberId,
    this.source,
  });

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final String? subscriberId;
  final String? source;

  factory StoryFeedbackComment.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'] ?? json['created_at'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    }

    return StoryFeedbackComment(
      id: json['id'] as String? ?? '',
      authorName: (json['authorName'] as String?)?.trim().isNotEmpty == true
          ? (json['authorName'] as String).trim()
          : 'Suscriptor',
      content: json['content'] as String? ?? '',
      createdAt: createdAt ?? DateTime.now(),
      subscriberId: json['subscriberId'] as String?,
      source: json['source'] as String?,
    );
  }
}

class StoryFeedbackState {
  const StoryFeedbackState({
    required this.comments,
    required this.hasReacted,
  });

  final List<StoryFeedbackComment> comments;
  final bool hasReacted;

  factory StoryFeedbackState.fromJson(Map<String, dynamic> json) {
    final commentsRaw = json['comments'];
    final comments = <StoryFeedbackComment>[];
    if (commentsRaw is List) {
      for (final item in commentsRaw) {
        if (item is Map<String, dynamic>) {
          comments.add(StoryFeedbackComment.fromJson(item));
        }
      }
    }
    final reaction = json['reaction'];
    final hasReacted =
        reaction is Map<String, dynamic> ? reaction['active'] == true : false;

    return StoryFeedbackState(comments: comments, hasReacted: hasReacted);
  }
}

class StoryFeedbackService {
  const StoryFeedbackService._();

  static const String _endpoint = '/api/story-feedback';

  static Future<StoryFeedbackState> fetchState({
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
        'action': 'fetch',
        'authorId': authorId,
        'storyId': storyId,
        'subscriberId': subscriberId,
        'token': token,
        if (source != null && source.isNotEmpty) 'source': source,
      }),
    );

    final decoded = _decodeBody(response);
    if (response.statusCode == 200) {
      return StoryFeedbackState.fromJson(decoded ?? const {});
    }

    throw StoryFeedbackException(
      statusCode: response.statusCode,
      message: decoded?['error']?.toString() ??
          'No se pudo recuperar la actividad de los suscriptores.',
      body: decoded,
    );
  }

  static Future<StoryFeedbackComment> submitComment({
    required String authorId,
    required String storyId,
    required String subscriberId,
    required String token,
    required String content,
    String? source,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'comment',
        'authorId': authorId,
        'storyId': storyId,
        'subscriberId': subscriberId,
        'token': token,
        'content': content,
        if (source != null && source.isNotEmpty) 'source': source,
      }),
    );

    final decoded = _decodeBody(response);
    if (response.statusCode == 200) {
      final comment = decoded?['comment'];
      if (comment is Map<String, dynamic>) {
        return StoryFeedbackComment.fromJson(comment);
      }
      throw StoryFeedbackException(
        statusCode: 500,
        message: 'Comentario guardado en formato inesperado.',
      );
    }

    throw StoryFeedbackException(
      statusCode: response.statusCode,
      message: decoded?['error']?.toString() ??
          'No se pudo registrar el comentario.',
      body: decoded,
    );
  }

  static Future<bool> setReaction({
    required String authorId,
    required String storyId,
    required String subscriberId,
    required String token,
    required bool isActive,
    String? source,
  }) async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'reaction',
        'authorId': authorId,
        'storyId': storyId,
        'subscriberId': subscriberId,
        'token': token,
        'reactionType': 'heart',
        'active': isActive,
        if (source != null && source.isNotEmpty) 'source': source,
      }),
    );

    final decoded = _decodeBody(response);
    if (response.statusCode == 200) {
      final reaction = decoded?['reaction'];
      if (reaction is Map<String, dynamic>) {
        return reaction['active'] == true;
      }
      return isActive;
    }

    throw StoryFeedbackException(
      statusCode: response.statusCode,
      message:
          decoded?['error']?.toString() ?? 'No se pudo actualizar la reacción.',
      body: decoded,
    );
  }

  static Map<String, dynamic>? _decodeBody(http.Response response) {
    final bodyText = utf8.decode(response.bodyBytes);
    if (bodyText.isEmpty) return null;
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'data': decoded};
    } catch (_) {
      return {'raw': bodyText};
    }
  }
}
