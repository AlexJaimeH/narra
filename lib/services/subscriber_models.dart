class Subscriber {
  const Subscriber({
    required this.id,
    required this.userId,
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

  final String id;
  final String userId;
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
      userId: map['user_id'] ?? '',
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
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Subscriber copyWith({
    String? id,
    String? userId,
    String? name,
    String? email,
    String? phone,
    String? relationship,
    bool? isActive,
    String? status,
    String? magicKey,
    DateTime? magicKeyCreatedAt,
    DateTime? magicLinkLastSentAt,
    DateTime? lastAccessAt,
    String? lastAccessIp,
    String? lastAccessUserAgent,
    String? lastAccessSource,
    DateTime? createdAt,
  }) {
    return Subscriber(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      magicKey: magicKey ?? this.magicKey,
      magicKeyCreatedAt: magicKeyCreatedAt ?? this.magicKeyCreatedAt,
      magicLinkLastSentAt: magicLinkLastSentAt ?? this.magicLinkLastSentAt,
      lastAccessAt: lastAccessAt ?? this.lastAccessAt,
      lastAccessIp: lastAccessIp ?? this.lastAccessIp,
      lastAccessUserAgent: lastAccessUserAgent ?? this.lastAccessUserAgent,
      lastAccessSource: lastAccessSource ?? this.lastAccessSource,
      createdAt: createdAt ?? this.createdAt,
    );
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
  const SubscriberCommentRecord({
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
  const SubscriberReactionRecord({
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
  const SubscriberDashboardData({
    required this.subscribers,
    required this.engagementBySubscriber,
    required this.recentComments,
    required this.recentReactions,
  });

  final List<Subscriber> subscribers;
  final Map<String, SubscriberEngagement> engagementBySubscriber;
  final List<SubscriberCommentRecord> recentComments;
  final List<SubscriberReactionRecord> recentReactions;

  int get totalSubscribers =>
      subscribers.where((s) => s.status != 'unsubscribed').length;
  int get confirmedSubscribers =>
      subscribers.where((s) => s.status == 'confirmed').length;
  int get pendingSubscribers =>
      subscribers.where((s) => s.status == 'pending').length;
  int get unsubscribedSubscribers =>
      subscribers.where((s) => s.status == 'unsubscribed').length;

  int get totalComments {
    // Solo contar comentarios de suscriptores activos (no desuscritos)
    final activeSubscriberIds = subscribers
        .where((s) => s.status != 'unsubscribed')
        .map((s) => s.id)
        .toSet();
    return engagementBySubscriber.entries
        .where((entry) => activeSubscriberIds.contains(entry.key))
        .fold<int>(0, (value, item) => value + item.value.totalComments);
  }

  int get totalReactions {
    // Solo contar reacciones de suscriptores activos (no desuscritos)
    final activeSubscriberIds = subscribers
        .where((s) => s.status != 'unsubscribed')
        .map((s) => s.id)
        .toSet();
    return engagementBySubscriber.entries
        .where((entry) => activeSubscriberIds.contains(entry.key))
        .fold<int>(0, (value, item) => value + item.value.totalReactions);
  }

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
