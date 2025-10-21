import 'package:uuid/uuid.dart';
import 'package:narra/supabase/supabase_config.dart';

class Subscriber {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? relationship;
  final bool isActive;
  final String status;
  final String magicKey;
  final DateTime? magicKeyCreatedAt;
  final DateTime? magicLinkLastSentAt;
  final DateTime? lastAccessAt;
  final String? lastAccessIp;
  final String? lastAccessUserAgent;
  final String? lastAccessSource;
  final DateTime createdAt;

  Subscriber({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.relationship,
    this.isActive = true,
    required this.status,
    required this.magicKey,
    this.magicKeyCreatedAt,
    this.magicLinkLastSentAt,
    this.lastAccessAt,
    this.lastAccessIp,
    this.lastAccessUserAgent,
    this.lastAccessSource,
    required this.createdAt,
  });

  factory Subscriber.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Subscriber(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      relationship: map['relationship'],
      status: (map['status'] as String? ?? 'pending').toLowerCase(),
      isActive: (map['status'] as String? ?? 'pending') != 'unsubscribed',
      magicKey: (map['access_token'] as String? ?? '').trim(),
      magicKeyCreatedAt: parseDate(map['access_token_created_at']),
      magicLinkLastSentAt: parseDate(map['access_token_last_sent_at']),
      lastAccessAt: parseDate(map['last_access_at']),
      lastAccessIp: map['last_access_ip'] as String?,
      lastAccessUserAgent: map['last_access_user_agent'] as String?,
      lastAccessSource: map['last_access_source'] as String?,
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      // 'is_active': isActive, // Column doesn't exist in current schema
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SubscriberEngagement {
  const SubscriberEngagement({
    required this.subscriberId,
    required this.totalReactions,
    required this.totalComments,
    this.lastReactionAt,
    this.lastCommentAt,
  });

  final String subscriberId;
  final int totalReactions;
  final int totalComments;
  final DateTime? lastReactionAt;
  final DateTime? lastCommentAt;

  DateTime? get lastInteractionAt {
    final dates = <DateTime>[
      if (lastReactionAt != null) lastReactionAt!,
      if (lastCommentAt != null) lastCommentAt!,
    ];
    if (dates.isEmpty) return null;
    dates.sort((a, b) => b.compareTo(a));
    return dates.first;
  }

  factory SubscriberEngagement.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return SubscriberEngagement(
      subscriberId: map['subscriber_id'] as String? ?? '',
      totalReactions: (map['total_reactions'] as num?)?.toInt() ?? 0,
      totalComments: (map['total_comments'] as num?)?.toInt() ?? 0,
      lastReactionAt: parseDate(map['last_reaction_at']),
      lastCommentAt: parseDate(map['last_comment_at']),
    );
  }
}

class SubscriberCommentRecord {
  SubscriberCommentRecord({
    required this.id,
    required this.storyId,
    required this.storyTitle,
    required this.content,
    required this.createdAt,
    this.subscriberId,
    this.subscriberName,
    this.source,
  });

  final String id;
  final String storyId;
  final String storyTitle;
  final String content;
  final DateTime createdAt;
  final String? subscriberId;
  final String? subscriberName;
  final String? source;

  factory SubscriberCommentRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final story = map['stories'] as Map<String, dynamic>?;
    final subscriber = map['subscribers'] as Map<String, dynamic>?;

    return SubscriberCommentRecord(
      id: map['id'] as String? ?? '',
      storyId: map['story_id'] as String? ?? story?['id'] as String? ?? '',
      storyTitle: (story?['title'] as String?)?.trim().isNotEmpty == true
          ? (story!['title'] as String).trim()
          : 'Historia compartida',
      content: map['content'] as String? ?? '',
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
      subscriberId:
          map['subscriber_id'] as String? ?? subscriber?['id'] as String?,
      subscriberName: (map['author_name'] as String?)?.trim().isNotEmpty == true
          ? (map['author_name'] as String).trim()
          : (subscriber?['name'] as String?),
      source: map['source'] as String?,
    );
  }
}

class SubscriberReactionRecord {
  SubscriberReactionRecord({
    required this.id,
    required this.storyId,
    required this.storyTitle,
    required this.reactionType,
    required this.createdAt,
    this.subscriberId,
    this.subscriberName,
    this.source,
  });

  final String id;
  final String storyId;
  final String storyTitle;
  final String reactionType;
  final DateTime createdAt;
  final String? subscriberId;
  final String? subscriberName;
  final String? source;

  factory SubscriberReactionRecord.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final story = map['stories'] as Map<String, dynamic>?;
    final subscriber = map['subscribers'] as Map<String, dynamic>?;

    return SubscriberReactionRecord(
      id: map['id'] as String? ?? '',
      storyId: map['story_id'] as String? ?? story?['id'] as String? ?? '',
      storyTitle: (story?['title'] as String?)?.trim().isNotEmpty == true
          ? (story!['title'] as String).trim()
          : 'Historia compartida',
      reactionType: (map['reaction_type'] as String?)?.trim() ?? 'heart',
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
      subscriberId:
          map['subscriber_id'] as String? ?? subscriber?['id'] as String?,
      subscriberName:
          (subscriber?['name'] as String?)?.trim().isNotEmpty == true
              ? (subscriber!['name'] as String).trim()
              : null,
      source: map['source'] as String?,
    );
  }
}

class SubscriberDashboardData {
  SubscriberDashboardData({
    required this.subscribers,
    required this.engagementBySubscriber,
    required this.recentComments,
    required this.recentReactions,
  });

  final List<Subscriber> subscribers;
  final Map<String, SubscriberEngagement> engagementBySubscriber;
  final List<SubscriberCommentRecord> recentComments;
  final List<SubscriberReactionRecord> recentReactions;

  int get totalSubscribers => subscribers.length;
  int get confirmedSubscribers =>
      subscribers.where((s) => s.status == 'confirmed').length;
  int get pendingSubscribers =>
      subscribers.where((s) => s.status == 'pending').length;
  int get unsubscribedSubscribers =>
      subscribers.where((s) => s.status == 'unsubscribed').length;

  int get totalComments => engagementBySubscriber.values
      .fold<int>(0, (value, item) => value + item.totalComments);

  int get totalReactions => engagementBySubscriber.values
      .fold<int>(0, (value, item) => value + item.totalReactions);

  int subscribersEngagedWithin(Duration duration) {
    final threshold = DateTime.now().subtract(duration);
    return engagementBySubscriber.values.where((engagement) {
      final date = engagement.lastInteractionAt;
      return date != null && date.isAfter(threshold);
    }).length;
  }

  SubscriberEngagement? engagementFor(String subscriberId) =>
      engagementBySubscriber[subscriberId];
}

class SubscriberService {
  static const _uuid = Uuid();

  static List<Map<String, dynamic>> _castMapList(dynamic data) {
    if (data is List) {
      final result = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          result.add(Map<String, dynamic>.from(item));
        } else if (item is Map) {
          result.add(Map<String, dynamic>.from(item.cast<dynamic, dynamic>()));
        }
      }
      return result;
    }
    return const [];
  }

  // Obtener todos los suscriptores
  static Future<List<Subscriber>> getSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );

    return data.map((item) => Subscriber.fromMap(item)).toList();
  }

  static Future<List<Subscriber>> getConfirmedSubscribers() async {
    final subscribers = await getSubscribers();
    return subscribers
        .where((subscriber) => subscriber.status == 'confirmed')
        .toList();
  }

  // Obtener todos los suscriptores del usuario (legacy)
  static Future<List<Map<String, dynamic>>> getUserSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
  }

  static Future<SubscriberDashboardData> getDashboardData({
    int recentCommentLimit = 20,
    int recentReactionLimit = 20,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final client = SupabaseConfig.client;

    final results = await Future.wait<dynamic>([
      getSubscribers(),
      client
          .from('subscriber_engagement_summary')
          .select()
          .eq('user_id', userId),
      client
          .from('story_comments')
          .select('''
            id,
            story_id,
            subscriber_id,
            content,
            created_at,
            source,
            author_name,
            stories ( id, title ),
            subscribers ( id, name )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(recentCommentLimit),
      client
          .from('story_reactions')
          .select('''
            id,
            story_id,
            subscriber_id,
            reaction_type,
            created_at,
            source,
            stories ( id, title ),
            subscribers ( id, name )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(recentReactionLimit),
    ]);

    final subscribers = results[0] as List<Subscriber>;
    final engagementMaps = _castMapList(results[1]);
    final commentMaps = _castMapList(results[2]);
    final reactionMaps = _castMapList(results[3]);

    final engagement = <String, SubscriberEngagement>{};
    for (final map in engagementMaps) {
      final data = SubscriberEngagement.fromMap(map);
      if (data.subscriberId.isNotEmpty) {
        engagement[data.subscriberId] = data;
      }
    }

    final comments = commentMaps
        .map(SubscriberCommentRecord.fromMap)
        .toList(growable: false);
    final reactions = reactionMaps
        .map(SubscriberReactionRecord.fromMap)
        .toList(growable: false);

    return SubscriberDashboardData(
      subscribers: subscribers,
      engagementBySubscriber: engagement,
      recentComments: comments,
      recentReactions: reactions,
    );
  }

  // Crear nuevo suscriptor
  static Future<Map<String, dynamic>> createSubscriber({
    required String name,
    required String email,
    String? phone,
    String? relationship,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.insert('subscribers', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'status': 'pending',
    });
  }

  // Actualizar suscriptor
  static Future<Map<String, dynamic>> updateSubscriber(
    String subscriberId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update('subscribers', subscriberId, updates);
  }

  // Eliminar suscriptor
  static Future<void> deleteSubscriber(String subscriberId) async {
    await SupabaseService.delete('subscribers', subscriberId);
  }

  // Cambiar estado de suscriptor
  static Future<void> updateSubscriberStatus(
    String subscriberId,
    String status,
  ) async {
    await SupabaseService.update('subscribers', subscriberId, {
      'status': status,
    });
  }

  static Future<void> markMagicLinkSent(String subscriberId) async {
    await SupabaseService.update('subscribers', subscriberId, {
      'access_token_last_sent_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<SubscriberCommentRecord>> getCommentsForSubscriber(
    String subscriberId, {
    int limit = 50,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseConfig.client
        .from('story_comments')
        .select('''
          id,
          story_id,
          subscriber_id,
          content,
          created_at,
          source,
          author_name,
          stories ( id, title ),
          subscribers ( id, name )
        ''')
        .eq('user_id', userId)
        .eq('subscriber_id', subscriberId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _castMapList(data)
        .map(SubscriberCommentRecord.fromMap)
        .toList(growable: false);
  }

  static Future<List<SubscriberReactionRecord>> getReactionsForSubscriber(
    String subscriberId, {
    int limit = 50,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseConfig.client
        .from('story_reactions')
        .select('''
          id,
          story_id,
          subscriber_id,
          reaction_type,
          created_at,
          source,
          stories ( id, title ),
          subscribers ( id, name )
        ''')
        .eq('user_id', userId)
        .eq('subscriber_id', subscriberId)
        .order('created_at', ascending: false)
        .limit(limit);

    return _castMapList(data)
        .map(SubscriberReactionRecord.fromMap)
        .toList(growable: false);
  }

  // Obtener estadísticas de suscriptores
  static Future<Map<String, int>> getSubscriberStats() async {
    final subscribers = await getUserSubscribers();

    final confirmed =
        subscribers.where((s) => s['status'] == 'confirmed').length;
    final pending = subscribers.where((s) => s['status'] == 'pending').length;
    final unsubscribed =
        subscribers.where((s) => s['status'] == 'unsubscribed').length;

    return {
      'total': subscribers.length,
      'confirmed': confirmed,
      'pending': pending,
      'unsubscribed': unsubscribed,
    };
  }

  // Simular envío de historia a suscriptores
  static Future<void> shareStoryWithSubscribers(
    String storyId,
    List<String> subscriberIds,
  ) async {
    // En una implementación real, aquí se enviarían emails o notificaciones
    // Por ahora solo actualizamos la fecha de último envío

    for (final subscriberId in subscriberIds) {
      await SupabaseService.update('subscribers', subscriberId, {
        'last_sent_at': DateTime.now().toIso8601String(),
      });
    }

    // Registrar actividad
    await _logActivity('story_shared', storyId, metadata: {
      'subscriber_count': subscriberIds.length,
    });
  }

  // Obtener suscriptores activos (confirmados)
  static Future<List<Map<String, dynamic>>> getActiveSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
    ).then((subscribers) =>
        subscribers.where((s) => s['status'] == 'confirmed').toList());
  }

  // Registrar actividad privada
  static Future<void> _logActivity(
    String activityType,
    String entityId, {
    Map<String, dynamic>? metadata,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.insert('user_activity', {
      'id': _uuid.v4(),
      'user_id': userId,
      'activity_type': activityType,
      'entity_id': entityId,
      'metadata': metadata,
    });
  }
}
