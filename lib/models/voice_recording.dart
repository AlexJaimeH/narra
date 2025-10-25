class VoiceRecording {
  VoiceRecording({
    required this.id,
    required this.audioUrl,
    required this.audioPath,
    required this.transcript,
    required this.createdAt,
    this.userId,
    this.storyId,
    this.storyTitle,
    this.durationSeconds,
    this.storageBucket,
  });

  final String id;
  final String? userId;
  final String? storyId;
  final String? storyTitle;
  final String audioUrl;
  final String audioPath;
  final String transcript;
  final double? durationSeconds;
  final DateTime createdAt;
  final String? storageBucket;

  String get formattedStoryTitle =>
      (storyTitle != null && storyTitle!.trim().isNotEmpty)
          ? storyTitle!.trim()
          : 'Sin título';

  VoiceRecording copyWith({
    String? transcript,
    String? storyId,
    String? storyTitle,
    String? storageBucket,
  }) {
    return VoiceRecording(
      id: id,
      userId: userId,
      storyId: storyId ?? this.storyId,
      storyTitle: storyTitle ?? this.storyTitle,
      audioUrl: audioUrl,
      audioPath: audioPath,
      transcript: transcript ?? this.transcript,
      durationSeconds: durationSeconds,
      createdAt: createdAt,
      storageBucket: storageBucket ?? this.storageBucket,
    );
  }

  factory VoiceRecording.fromMap(Map<String, dynamic> map) {
    return VoiceRecording(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      storyId: map['story_id'] as String?,
      storyTitle: map['story_title'] as String?,
      audioUrl: map['audio_url'] as String,
      audioPath: map['audio_path'] as String,
      transcript: (map['transcript'] ?? '') as String,
      durationSeconds: map['duration_seconds'] == null
          ? null
          : (map['duration_seconds'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      storageBucket: (map['storage_bucket'] as String?) ?? 'voice-recordings',
    );
  }
}
