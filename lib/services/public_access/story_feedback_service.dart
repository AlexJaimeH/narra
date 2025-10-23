import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:narra/supabase/supabase_config.dart';

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
    this.parentId,
    List<StoryFeedbackComment>? replies,
  }) : replies = replies ?? <StoryFeedbackComment>[];

  final String id;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final String? subscriberId;
  final String? source;
  final String? parentId;
  final List<StoryFeedbackComment> replies;

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
      parentId: json['parentId'] as String? ?? json['parent_id'] as String?,
      replies: (json['replies'] is List)
          ? (json['replies'] as List)
              .whereType<Map<String, dynamic>>()
              .map(StoryFeedbackComment.fromJson)
              .toList()
          : <StoryFeedbackComment>[],
    );
  }
}

class StoryFeedbackState {
  const StoryFeedbackState({
    required this.comments,
    required this.hasReacted,
    required this.commentCount,
  });

  final List<StoryFeedbackComment> comments;
  final bool hasReacted;
  final int commentCount;

  factory StoryFeedbackState.fromJson(Map<String, dynamic> json) {
    final commentsRaw = json['comments'];
    final ordered = <StoryFeedbackComment>[];
    if (commentsRaw is List) {
      for (final item in commentsRaw) {
        if (item is Map<String, dynamic>) {
          ordered.add(StoryFeedbackComment.fromJson(item));
        }
      }
    }

    final map = <String, StoryFeedbackComment>{
      for (final comment in ordered) comment.id: comment,
    };

    final roots = <StoryFeedbackComment>[];
    for (final comment in ordered) {
      final parentId = comment.parentId;
      if (parentId != null && parentId != comment.id) {
        final parent = map[parentId];
        if (parent != null) {
          parent.replies.add(comment);
          continue;
        }
      }
      roots.add(comment);
    }

    void sortThread(List<StoryFeedbackComment> entries) {
      entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final node in entries) {
        if (node.replies.isNotEmpty) {
          sortThread(node.replies);
        }
      }
    }

    sortThread(roots);
    roots.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final reaction = json['reaction'];
    final hasReacted =
        reaction is Map<String, dynamic> ? reaction['active'] == true : false;

    final countFromJson = json['commentCount'];
    final fallbackCount = _flattenCount(roots);
    final parsedCount = countFromJson is num ? countFromJson.toInt() : null;

    return StoryFeedbackState(
      comments: roots,
      hasReacted: hasReacted,
      commentCount: parsedCount ?? fallbackCount,
    );
  }

  static int _flattenCount(List<StoryFeedbackComment> nodes) {
    var total = 0;
    for (final node in nodes) {
      total += 1;
      if (node.replies.isNotEmpty) {
        total += _flattenCount(node.replies);
      }
    }
    return total;
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
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    final rpcResponse = await _callSupabaseRpc({
      'p_action': 'fetch',
      'p_author_id': authorId,
      'p_story_id': storyId,
      'p_subscriber_id': subscriberId,
      'p_token': token,
      if (source != null && source.isNotEmpty) 'p_source': source,
    }, overrideUrl: supabaseUrl, overrideAnonKey: supabaseAnonKey);
    if (rpcResponse != null) {
      if (rpcResponse['error'] != null) {
        final code = rpcResponse['error'].toString();
        throw StoryFeedbackException(
          statusCode: _statusCodeForError(code),
          message: _messageForError(code),
          body: rpcResponse,
        );
      }
      return StoryFeedbackState.fromJson(rpcResponse);
    }

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
    String? parentCommentId,
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    final rpcResponse = await _callSupabaseRpc({
      'p_action': 'comment',
      'p_author_id': authorId,
      'p_story_id': storyId,
      'p_subscriber_id': subscriberId,
      'p_token': token,
      'p_content': content,
      if (source != null && source.isNotEmpty) 'p_source': source,
      if (parentCommentId != null && parentCommentId.isNotEmpty)
        'p_parent_comment_id': parentCommentId,
    }, overrideUrl: supabaseUrl, overrideAnonKey: supabaseAnonKey);
    if (rpcResponse != null) {
      if (rpcResponse['error'] != null) {
        final code = rpcResponse['error'].toString();
        throw StoryFeedbackException(
          statusCode: _statusCodeForError(code),
          message: _messageForError(code),
          body: rpcResponse,
        );
      }
      final comment = rpcResponse['comment'];
      if (comment is Map<String, dynamic>) {
        return StoryFeedbackComment.fromJson(comment);
      }
    }

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
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parentCommentId': parentCommentId,
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
    String? supabaseUrl,
    String? supabaseAnonKey,
  }) async {
    final rpcResponse = await _callSupabaseRpc({
      'p_action': 'reaction',
      'p_author_id': authorId,
      'p_story_id': storyId,
      'p_subscriber_id': subscriberId,
      'p_token': token,
      'p_reaction_type': 'heart',
      'p_active': isActive,
      if (source != null && source.isNotEmpty) 'p_source': source,
    }, overrideUrl: supabaseUrl, overrideAnonKey: supabaseAnonKey);
    if (rpcResponse != null) {
      if (rpcResponse['error'] != null) {
        final code = rpcResponse['error'].toString();
        throw StoryFeedbackException(
          statusCode: _statusCodeForError(code),
          message: _messageForError(code),
          body: rpcResponse,
        );
      }
      final reaction = rpcResponse['reaction'];
      if (reaction is Map<String, dynamic>) {
        return reaction['active'] == true;
      }
      return isActive;
    }

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

  static Future<Map<String, dynamic>?> _callSupabaseRpc(
    Map<String, dynamic> payload, {
    String? overrideUrl,
    String? overrideAnonKey,
  }) async {
    final url = (overrideUrl ?? SupabaseConfig.supabaseUrl).trim();
    final anonKey = (overrideAnonKey ?? SupabaseConfig.supabaseAnonKey).trim();
    if (url.isEmpty || anonKey.isEmpty) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$url/rest/v1/rpc/process_story_feedback'),
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return const {};
        }
        final decoded = jsonDecode(response.body);
        if (decoded == null) {
          return const {};
        }
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return {'result': decoded};
      }

      if (response.statusCode == 404) {
        return null;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static int _statusCodeForError(String code) {
    switch (code) {
      case 'subscriber_not_found':
        return 404;
      case 'invalid_token':
      case 'subscriber_inactive':
        return 403;
      case 'content_required':
      case 'unsupported_action':
      case 'parent_not_found':
        return 400;
      default:
        return 400;
    }
  }

  static String _messageForError(String code) {
    switch (code) {
      case 'subscriber_not_found':
        return 'No encontramos este suscriptor.';
      case 'invalid_token':
        return 'El enlace ya no es válido.';
      case 'subscriber_inactive':
        return 'Este suscriptor canceló su acceso.';
      case 'content_required':
        return 'El comentario necesita contenido.';
      case 'unsupported_action':
        return 'No podemos procesar esta acción.';
      case 'parent_not_found':
        return 'No pudimos encontrar el comentario original.';
      default:
        return 'No se pudo procesar esta solicitud.';
    }
  }

  static Map<String, dynamic>? _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final dynamic parsed = jsonDecode(response.body);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {
      return {'raw': response.body};
    }
    return null;
  }
}
