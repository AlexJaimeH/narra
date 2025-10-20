import 'package:narra/supabase/narra_client.dart';

/// Repository for story-related operations
/// Provides a clean interface for story data management
class StoryRepository {
  /// Get all stories for current user with optional filters
  static Future<List<Story>> getStories({
    StoryStatus? status,
    String? searchQuery,
    List<String>? tagIds,
    int? limit,
    int? offset,
  }) async {
    final data = await NarraSupabaseClient.getUserStories(
      status: status?.name,
      searchQuery: searchQuery,
      tagIds: tagIds,
      limit: limit,
      offset: offset,
    );

    return data.map((item) => Story.fromMap(item)).toList();
  }

  /// Get story by ID
  static Future<Story?> getStoryById(String id) async {
    final stories = await NarraSupabaseClient.getUserStories();
    final storyData = stories.where((s) => s['id'] == id).firstOrNull;
    return storyData != null ? Story.fromMap(storyData) : null;
  }

  /// Get a published story that can be shared publicly
  static Future<Story?> getPublishedStoryForPublic(String id) async {
    final data = await NarraSupabaseClient.getPublishedStoryById(id);
    return data != null ? Story.fromMap(data) : null;
  }

  /// Get other published stories from the same author for recommendations
  static Future<List<Story>> getPublishedStoriesByAuthor(
    String authorId, {
    int limit = 4,
    String? excludeStoryId,
  }) async {
    final stories = await NarraSupabaseClient.getPublishedStoriesByAuthor(
      authorId,
      limit: limit,
      excludeStoryId: excludeStoryId,
    );

    return stories.map((item) => Story.fromMap(item)).toList();
  }

  /// Create new story
  static Future<Story> createStory({
    required String title,
    String? content,
    StoryStatus status = StoryStatus.draft,
    DateTime? storyDate,
    String? storyDateText,
    String? location,
    bool isVoiceGenerated = false,
    String? voiceTranscript,
  }) async {
    final data = await NarraSupabaseClient.createStory(
      title: title,
      content: content,
      status: status.name,
      startDate: storyDate,
      datesPrecision: storyDateText,
    );

    return Story.fromMap(data);
  }

  /// Update story
  static Future<Story> updateStory(String id, StoryUpdate update) async {
    // Convert StoryUpdate to the format expected by NarraSupabaseClient
    final updateMap = <String, dynamic>{};
    if (update.title != null) updateMap['title'] = update.title;
    if (update.content != null) updateMap['content'] = update.content;
    if (update.storyDate != null)
      updateMap['story_date'] = update.storyDate!.toIso8601String();
    if (update.location != null) updateMap['location'] = update.location;
    if (update.completenessScore != null)
      updateMap['completeness_score'] = update.completenessScore;

    final data = await NarraSupabaseClient.updateStory(id, updateMap);
    return Story.fromMap(data);
  }

  /// Delete story
  static Future<void> deleteStory(String id) async {
    await NarraSupabaseClient.deleteStory(id);
  }

  /// Publish story
  static Future<Story> publishStory(String id) async {
    final data = await NarraSupabaseClient.publishStory(id);
    return Story.fromMap(data);
  }

  /// Add photo to story
  static Future<StoryPhoto> addPhoto(
    String storyId,
    String photoUrl, {
    String? caption,
    int? position,
  }) async {
    final data = await NarraSupabaseClient.addPhotoToStory(
      storyId: storyId,
      photoUrl: photoUrl,
      caption: caption,
      position: position ?? 0,
    );

    return StoryPhoto.fromMap(data);
  }

  /// Remove photo from story
  static Future<void> removePhoto(String photoId) async {
    await NarraSupabaseClient.removePhotoFromStory(photoId);
  }

  /// Add tag to story
  static Future<void> addTag(String storyId, String tagId) async {
    await NarraSupabaseClient.addTagToStory(storyId, tagId);
  }

  /// Remove tag from story
  static Future<void> removeTag(String storyId, String tagId) async {
    await NarraSupabaseClient.removeTagFromStory(storyId, tagId);
  }

  /// Add person to story
  static Future<void> addPerson(String storyId, String personId) async {
    await NarraSupabaseClient.addPersonToStory(storyId, personId);
  }

  /// Remove person from story
  static Future<void> removePerson(String storyId, String personId) async {
    await NarraSupabaseClient.removePersonFromStory(storyId, personId);
  }
}

/// Story status enumeration
enum StoryStatus {
  draft,
  published,
  archived;

  String get displayName {
    switch (this) {
      case StoryStatus.draft:
        return 'Borrador';
      case StoryStatus.published:
        return 'Publicado';
      case StoryStatus.archived:
        return 'Archivado';
    }
  }
}

/// Story data model
class Story {
  final String id;
  final String userId;
  final String title;
  final String? content;
  final String? excerpt;
  final StoryStatus status;
  final DateTime? storyDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? datesPrecision;
  final String? storyDateText;
  final String? location;
  final bool isVoiceGenerated;
  final String? voiceTranscript;
  final List<String>? aiSuggestions;
  final int completenessScore;
  final int wordCount;
  final int readingTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  // Author metadata for public sharing
  final String? authorName;
  final String? authorDisplayName;
  final String? authorAvatarUrl;

  // Related data
  final List<String>? tags; // Simplified tags as strings
  final List<StoryTag> storyTags; // Full tag objects
  final List<StoryPhoto> photos;
  final List<StoryPerson> people;

  const Story({
    required this.id,
    required this.userId,
    required this.title,
    this.content,
    this.excerpt,
    required this.status,
    this.storyDate,
    this.startDate,
    this.endDate,
    this.datesPrecision,
    this.storyDateText,
    this.location,
    required this.isVoiceGenerated,
    this.voiceTranscript,
    this.aiSuggestions,
    required this.completenessScore,
    required this.wordCount,
    required this.readingTime,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.tags,
    required this.storyTags,
    required this.photos,
    required this.people,
    this.authorName,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  factory Story.fromMap(Map<String, dynamic> map) {
    try {
      final rawStatus = (map['status'] as String? ?? '').toLowerCase();
      final status = StoryStatus.values.firstWhere(
        (s) => s.name == rawStatus,
        orElse: () => StoryStatus.draft,
      );

      final authorProfile = map['author_profile'] as Map<String, dynamic>? ??
          map['author'] as Map<String, dynamic>? ??
          map['users'] as Map<String, dynamic>?;
      final authorSettings =
          authorProfile?['user_settings'] as Map<String, dynamic>? ??
              map['author_settings'] as Map<String, dynamic>?;

      return Story(
        id: map['id'] as String? ?? '',
        userId: map['user_id'] as String? ?? '',
        title: map['title'] as String? ?? 'Historia sin título',
        content: map['content'] as String?,
        excerpt: map['excerpt'] as String? ??
            _generateExcerpt(map['content'] as String? ?? ''),
        status: status,
        storyDate: map['story_date'] != null
            ? DateTime.parse(map['story_date'] as String)
            : null,
        startDate: map['story_date'] != null
            ? DateTime.parse(map['story_date'] as String)
            : null,
        endDate: null,
        datesPrecision: map.containsKey('dates_precision')
            ? map['dates_precision'] as String?
            : null,
        storyDateText: map['story_date_text'] as String?,
        location: map['location'] as String?,
        isVoiceGenerated: map['is_voice_generated'] as bool? ?? false,
        voiceTranscript: map['voice_transcript'] as String?,
        aiSuggestions: map['ai_suggestions'] != null
            ? List<String>.from(map['ai_suggestions'])
            : null,
        completenessScore: map['completeness_score'] as int? ?? 0,
        wordCount: map['word_count'] as int? ?? 0,
        readingTime: map['reading_time'] as int? ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        updatedAt: map['updated_at'] != null
            ? DateTime.parse(map['updated_at'] as String)
            : DateTime.now(),
        publishedAt: map['published_at'] != null
            ? DateTime.parse(map['published_at'] as String)
            : null,
        tags: map['tags'] != null ? List<String>.from(map['tags']) : null,
        storyTags: map['story_tags'] != null
            ? (map['story_tags'] as List)
                .map((tag) => StoryTag.fromMap(tag['tags']))
                .toList()
            : [],
        photos: map['story_photos'] != null
            ? (map['story_photos'] as List)
                .map((photo) => StoryPhoto.fromMap(photo))
                .toList()
            : [],
        people: map['story_people'] != null
            ? (map['story_people'] as List)
                .map((person) => StoryPerson.fromMap(person['people']))
                .toList()
            : [],
        authorName:
            authorProfile?['name'] as String? ?? map['author_name'] as String?,
        authorDisplayName: authorSettings?['public_author_name'] as String? ??
            map['author_display_name'] as String?,
        authorAvatarUrl: authorProfile?['avatar_url'] as String? ??
            map['author_avatar_url'] as String?,
      );
    } catch (e) {
      // Fallback for corrupted data - create a minimal story object
      print('Error parsing story: $e');
      print('Story data: $map');
      return Story(
        id: map['id']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: map['user_id']?.toString() ?? '',
        title: map['title']?.toString() ?? 'Historia corrupta',
        content: map['content']?.toString(),
        status: StoryStatus.draft,
        isVoiceGenerated: false,
        completenessScore: 0,
        wordCount: 0,
        readingTime: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        publishedAt: null,
        storyTags: [],
        photos: [],
        people: [],
        authorName: null,
        authorDisplayName: null,
        authorAvatarUrl: null,
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'status': status.name,
      'story_date': storyDate?.toIso8601String(),
      'story_date': startDate?.toIso8601String(),

      'story_date_text': storyDateText,
      'location': location,
      'is_voice_generated': isVoiceGenerated,
      'voice_transcript': voiceTranscript,
      'ai_suggestions': aiSuggestions ?? [],
      'completeness_score': completenessScore,
      'word_count': wordCount,
      'reading_time': readingTime,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // UI-specific fields (not stored in DB)
      'excerpt': excerpt ?? _generateExcerpt(content ?? ''),
      'tags': tags ?? [],
      'photos': photos.length,
      'reactions': 0, // TODO: get actual reactions when implemented
      'comments': 0, // TODO: get actual comments when implemented
      'coverImage': photos.isNotEmpty ? photos.first.photoUrl : null,
      'date': createdAt.toIso8601String(), // Fallback for date field
      'author_display_name':
          authorDisplayName ?? authorName ?? 'Autor/a de Narra',
      'author_name': authorName,
      'author_avatar_url': authorAvatarUrl,
    };
  }

  static String _generateExcerpt(String content) {
    if (content.isEmpty) return '';

    // Remove extra whitespace and get first 150 characters
    final cleanContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleanContent.length <= 150) return cleanContent;

    // Find last complete word within 150 chars
    final truncated = cleanContent.substring(0, 150);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 100) {
      // Only truncate at word boundary if it's not too short
      return truncated.substring(0, lastSpace) + '...';
    }
    return truncated + '...';
  }

  Story copyWith({
    String? title,
    String? content,
    StoryStatus? status,
    DateTime? storyDate,
    String? storyDateText,
    String? location,
    bool? isVoiceGenerated,
    String? voiceTranscript,
    List<String>? aiSuggestions,
    int? completenessScore,
    int? wordCount,
    int? readingTime,
  }) {
    return Story(
      id: id,
      userId: userId,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
      storyDate: storyDate ?? this.storyDate,
      storyDateText: storyDateText ?? this.storyDateText,
      location: location ?? this.location,
      isVoiceGenerated: isVoiceGenerated ?? this.isVoiceGenerated,
      voiceTranscript: voiceTranscript ?? this.voiceTranscript,
      aiSuggestions: aiSuggestions ?? this.aiSuggestions,
      completenessScore: completenessScore ?? this.completenessScore,
      wordCount: wordCount ?? this.wordCount,
      readingTime: readingTime ?? this.readingTime,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      tags: tags,
      photos: photos,
      people: people,
      storyTags: storyTags,
    );
  }
}

/// Story update model for partial updates
class StoryUpdate {
  final String? title;
  final String? content;
  final StoryStatus? status;
  final List<String>? tags;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? datesPrecision;
  final DateTime? storyDate;
  final String? storyDateText;
  final String? location;
  final bool? isVoiceGenerated;
  final String? voiceTranscript;
  final List<String>? aiSuggestions;
  final int? completenessScore;

  const StoryUpdate({
    this.title,
    this.content,
    this.status,
    this.tags,
    this.startDate,
    this.endDate,
    this.datesPrecision,
    this.storyDate,
    this.storyDateText,
    this.location,
    this.isVoiceGenerated,
    this.voiceTranscript,
    this.aiSuggestions,
    this.completenessScore,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};

    if (title != null) map['title'] = title;
    if (content != null) map['content'] = content;
    if (status != null) map['status'] = status!.name;
    if (tags != null) map['tags'] = tags;
    if (startDate != null) map['story_date'] = startDate!.toIso8601String();

    // dates_precision field is optional and may not exist in database
    // if (datesPrecision != null) map['dates_precision'] = datesPrecision;
    if (storyDate != null) map['story_date'] = storyDate!.toIso8601String();
    if (storyDateText != null) map['story_date_text'] = storyDateText;
    if (location != null) map['location'] = location;
    if (isVoiceGenerated != null) map['is_voice_generated'] = isVoiceGenerated;
    if (voiceTranscript != null) map['voice_transcript'] = voiceTranscript;
    if (aiSuggestions != null) map['ai_suggestions'] = aiSuggestions;
    if (completenessScore != null)
      map['completeness_score'] = completenessScore;

    return map;
  }
}

/// Story tag model
class StoryTag {
  final String id;
  final String name;
  final String color;

  const StoryTag({
    required this.id,
    required this.name,
    required this.color,
  });

  factory StoryTag.fromMap(Map<String, dynamic> map) {
    return StoryTag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
    };
  }
}

/// Story photo model
class StoryPhoto {
  final String id;
  final String storyId;
  final String photoUrl;
  final String? caption;
  final int position;
  final DateTime createdAt;

  const StoryPhoto({
    required this.id,
    required this.storyId,
    required this.photoUrl,
    this.caption,
    required this.position,
    required this.createdAt,
  });

  factory StoryPhoto.fromMap(Map<String, dynamic> map) {
    return StoryPhoto(
      id: map['id'] as String,
      storyId: map['story_id'] as String,
      photoUrl: map['photo_url'] as String,
      caption: map['caption'] as String?,
      position: map['position'] as int,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'story_id': storyId,
      'photo_url': photoUrl,
      'caption': caption,
      'position': position,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Story person model
class StoryPerson {
  final String id;
  final String name;
  final String? relationship;

  const StoryPerson({
    required this.id,
    required this.name,
    this.relationship,
  });

  factory StoryPerson.fromMap(Map<String, dynamic> map) {
    return StoryPerson(
      id: map['id'] as String,
      name: map['name'] as String,
      relationship: map['relationship'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
    };
  }
}
