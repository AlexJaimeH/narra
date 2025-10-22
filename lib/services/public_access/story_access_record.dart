class StoryAccessRecord {
  const StoryAccessRecord({
    required this.authorId,
    required this.subscriberId,
    required this.grantedAt,
    this.subscriberName,
    this.accessToken,
    this.source,
    this.status = 'confirmed',
  });

  final String authorId;
  final String subscriberId;
  final DateTime grantedAt;
  final String? subscriberName;
  final String? accessToken;
  final String? source;
  final String status;

  StoryAccessRecord copyWith({
    String? subscriberName,
    String? accessToken,
    String? source,
    DateTime? grantedAt,
    String? status,
  }) {
    return StoryAccessRecord(
      authorId: authorId,
      subscriberId: subscriberId,
      grantedAt: grantedAt ?? this.grantedAt,
      subscriberName: subscriberName ?? this.subscriberName,
      accessToken: accessToken ?? this.accessToken,
      source: source ?? this.source,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'authorId': authorId,
      'subscriberId': subscriberId,
      'subscriberName': subscriberName,
      'accessToken': accessToken,
      'grantedAt': grantedAt.toIso8601String(),
      'source': source,
      'status': status,
    };
  }

  factory StoryAccessRecord.fromJson(Map<String, dynamic> json) {
    return StoryAccessRecord(
      authorId: json['authorId'] as String,
      subscriberId: json['subscriberId'] as String,
      subscriberName: json['subscriberName'] as String?,
      accessToken: json['accessToken'] as String?,
      source: json['source'] as String?,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      status: (json['status'] as String?)?.trim().isNotEmpty == true
          ? (json['status'] as String).trim()
          : 'confirmed',
    );
  }
}
