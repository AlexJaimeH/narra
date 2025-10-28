import 'dart:convert';

import 'package:narra/supabase/narra_client.dart';

DateTime? _parseFlexibleTimestamp(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    String normalizeTimestamp(String input) {
      var normalized = input.trim();

      if (normalized.isEmpty) {
        return normalized;
      }

      if (!normalized.contains('T') &&
          RegExp(r'^\d{4}-\d{2}-\d{2} ').hasMatch(normalized)) {
        normalized = normalized.replaceFirst(' ', 'T');
      }

      if (normalized.endsWith(' UTC')) {
        normalized = '${normalized.substring(0, normalized.length - 4)}Z';
      }

      final offsetWithoutColon =
          RegExp(r'([+\-]\d{2})(\d{2})(?!:)').firstMatch(normalized);
      if (offsetWithoutColon != null) {
        normalized = normalized.replaceRange(
          offsetWithoutColon.start,
          offsetWithoutColon.end,
          '${offsetWithoutColon.group(1)}:${offsetWithoutColon.group(2)}',
        );
      }

      final shortOffset =
          RegExp(r'([+\-]\d{2})(?!:)(?!\d)').firstMatch(normalized);
      if (shortOffset != null) {
        normalized = normalized.replaceRange(
          shortOffset.start,
          shortOffset.end,
          '${shortOffset.group(1)}:00',
        );
      }

      if (normalized.endsWith('+00:00') ||
          normalized.endsWith('-00:00') ||
          normalized.endsWith('+00')) {
        final plusIndex = normalized.lastIndexOf('+');
        final minusIndex = normalized.lastIndexOf('-');
        final tzIndex = plusIndex > minusIndex ? plusIndex : minusIndex;
        if (tzIndex != -1) {
          normalized = '${normalized.substring(0, tzIndex)}Z';
        }
      }

      return normalized;
    }

    final normalizedInitial = normalizeTimestamp(trimmed);

    final candidates = <String>{
      trimmed,
      normalizedInitial,
    };

    candidates.removeWhere((candidate) => candidate.isEmpty);

    for (final candidate in candidates.toList()) {
      if (!candidate.endsWith('Z') &&
          !RegExp(r'[+\-]\d{2}:\d{2}$').hasMatch(candidate)) {
        candidates.add('${candidate}Z');
      }
    }

    for (final candidate in candidates) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    return null;
  }

  if (value is int) {
    if (value > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    if (value > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
          .toLocal();
    }
  }

  if (value is double) {
    final intValue = value.round();
    if (intValue > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(intValue, isUtc: true)
          .toLocal();
    }
    if (intValue > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch((value * 1000).round(),
              isUtc: true)
          .toLocal();
    }
  }

  if (value is Map && value.isNotEmpty) {
    for (final entry in value.entries) {
      final parsed = _parseFlexibleTimestamp(entry.value);
      if (parsed != null) return parsed;
    }
  }

  return null;
}

Map<String, dynamic>? _asStringMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

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
    final storyData = await NarraSupabaseClient.getStoryById(id);
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
    this.authorName,
    this.authorDisplayName,
    this.authorAvatarUrl,
  });

  bool get isDraft => status == StoryStatus.draft && !isPublished;
  bool get isPublished =>
      status == StoryStatus.published ||
      (publishedAt != null && status != StoryStatus.archived);
  bool get isArchived => status == StoryStatus.archived;

  factory Story.fromMap(Map<String, dynamic> map) {
    try {
      final rawPublishedAt =
          map['published_at'] ?? map['publishedAt'] ?? map['publish_date'];
      final publishedAt = _parseFlexibleTimestamp(rawPublishedAt);

      StoryStatus resolveStatus(String rawStatus, DateTime? publishedAt) {
        final normalized = rawStatus.trim().toLowerCase();
        if (normalized.isEmpty) {
          return publishedAt != null
              ? StoryStatus.published
              : StoryStatus.draft;
        }

        if (normalized == StoryStatus.archived.name) {
          return StoryStatus.archived;
        }

        if (normalized == StoryStatus.published.name) {
          return StoryStatus.published;
        }

        if (normalized == StoryStatus.draft.name) {
          return publishedAt != null
              ? StoryStatus.published
              : StoryStatus.draft;
        }

        try {
          final status = StoryStatus.values.firstWhere(
            (value) => value.name == normalized,
          );
          if (status == StoryStatus.draft && publishedAt != null) {
            return StoryStatus.published;
          }
          return status;
        } catch (_) {
          return publishedAt != null
              ? StoryStatus.published
              : StoryStatus.draft;
        }
      }

      final rawStatus = (map['status'] as String? ?? '');
      final status = resolveStatus(rawStatus, publishedAt);

      final authorProfile = map['author_profile'] as Map<String, dynamic>? ??
          map['author'] as Map<String, dynamic>? ??
          map['users'] as Map<String, dynamic>?;
      final authorSettings =
          authorProfile?['user_settings'] as Map<String, dynamic>? ??
              map['author_settings'] as Map<String, dynamic>?;

      DateTime? parseDate(dynamic value) => _parseFlexibleTimestamp(value);

      String? normalizePrecision(String? value) {
        final raw = value?.trim().toLowerCase();
        if (raw == null || raw.isEmpty) return null;
        if (raw == 'day' || raw == 'month' || raw == 'year') {
          return raw;
        }
        switch (raw) {
          case 'exact':
            return 'day';
          case 'month_year':
            return 'month';
          default:
            return null;
        }
      }

      final tagNames = <String>[];
      void addTag(dynamic raw) {
        if (raw == null) return;
        final display = raw.toString().trim();
        if (display.isEmpty) return;
        final normalized = display.toLowerCase();
        final alreadyExists =
            tagNames.any((existing) => existing.toLowerCase() == normalized);
        if (!alreadyExists) {
          tagNames.add(display);
        }
      }

      void addTags(dynamic raw) {
        if (raw == null) return;
        if (raw is List) {
          for (final item in raw) {
            addTag(item);
          }
          return;
        }
        if (raw is String && raw.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) {
              addTags(decoded);
              return;
            }
          } catch (_) {
            // Not JSON - fall through to treat as plain string
          }
          addTag(raw);
        }
      }

      final storyTagObjects = <StoryTag>[];
      final rawStoryTags = map['story_tags'];
      if (rawStoryTags is List) {
        for (final entry in rawStoryTags) {
          if (entry is! Map) continue;
          final Map entryMap = entry;
          final baseMap = entryMap is Map<String, dynamic>
              ? entryMap
              : Map<String, dynamic>.from(entryMap);
          final nested = baseMap['tags'];
          Map<String, dynamic>? tagMap;
          if (nested is Map<String, dynamic>) {
            tagMap = nested;
          } else if (nested is Map) {
            final Map nestedMap = nested;
            tagMap = Map<String, dynamic>.from(nestedMap);
          } else {
            tagMap = baseMap;
          }

          if (tagMap != null) {
            try {
              final tag = StoryTag.fromMap(tagMap);
              storyTagObjects.add(tag);
              addTag(tag.name);
            } catch (_) {
              addTag(tagMap['name']);
            }
          }
        }
      }

      addTags(map['tags']);

      final storyDate = parseDate(map['story_date']);
      final startDate = parseDate(map['start_date']) ?? storyDate;
      final endDate = parseDate(map['end_date']);
      final normalizedPrecision =
          normalizePrecision(map['dates_precision'] as String?) ??
              (storyDate != null ? 'day' : null);

      final photos = <StoryPhoto>[];
      final rawPhotos = map['story_photos'];
      if (rawPhotos is List) {
        for (final entry in rawPhotos) {
          final photoMap = _asStringMap(entry);
          if (photoMap == null) continue;
          try {
            photos.add(
              StoryPhoto.fromMap(
                photoMap,
                parentStoryId: map['id']?.toString(),
              ),
            );
          } catch (_) {
            // Skip malformed photo entries without aborting the whole story.
          }
        }
      }

      return Story(
        id: map['id'] as String? ?? '',
        userId: map['user_id'] as String? ?? '',
        title: map['title'] as String? ?? 'Historia sin título',
        content: map['content'] as String?,
        excerpt: map['excerpt'] as String? ??
            _generateExcerpt(map['content'] as String? ?? ''),
        status: status,
        storyDate: storyDate,
        startDate: startDate,
        endDate: endDate,
        datesPrecision: normalizedPrecision,
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
        createdAt: _parseFlexibleTimestamp(map['created_at']) ?? DateTime.now(),
        updatedAt: _parseFlexibleTimestamp(map['updated_at']) ?? DateTime.now(),
        publishedAt: publishedAt,
        tags: tagNames.isEmpty ? null : tagNames,
        storyTags: storyTagObjects,
        photos: photos,
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
      'published_at': publishedAt?.toIso8601String(),
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
    DateTime? publishedAt,
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
      publishedAt: publishedAt ?? this.publishedAt,
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

  factory StoryPhoto.fromMap(
    Map<String, dynamic> map, {
    String? parentStoryId,
  }) {
    final rawId = map['id'] ?? map['photo_id'];
    final rawStoryId =
        map['story_id'] ?? map['storyId'] ?? map['story'] ?? parentStoryId;
    final rawPhotoUrl = map['photo_url'] ?? map['photoUrl'];

    if (rawId == null || rawStoryId == null || rawPhotoUrl == null) {
      throw const FormatException('Missing required photo fields');
    }

    int resolvePosition(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0;
    }

    return StoryPhoto(
      id: rawId.toString(),
      storyId: rawStoryId.toString(),
      photoUrl: rawPhotoUrl.toString(),
      caption: map['caption'] as String?,
      position: resolvePosition(map['position']),
      createdAt:
          _parseFlexibleTimestamp(map['created_at'] ?? map['createdAt']) ??
              DateTime.now(),
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
