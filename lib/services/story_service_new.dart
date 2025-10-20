import 'package:flutter/foundation.dart';
import 'package:narra/api/narra_api.dart';
import 'package:narra/openai/openai_service.dart';
import 'package:narra/repositories/story_repository.dart';

/// Enhanced story service using the new API client
/// This replaces the old story_service.dart with better architecture
class StoryServiceNew {
  
  // ================================
  // STORY OPERATIONS
  // ================================

  /// Get all stories with filtering and pagination
  static Future<List<Story>> getStories({
    StoryFilter? filter,
    int page = 1,
    int pageSize = 20,
  }) async {
    final offset = (page - 1) * pageSize;
    
    return await NarraAPI.getStories(
      status: filter?.status,
      searchQuery: filter?.searchQuery,
      tagIds: filter?.tagIds,
      limit: pageSize,
      offset: offset,
    );
  }

  /// Get recent stories (last 10)
  static Future<List<Story>> getRecentStories({int limit = 10}) async {
    final stories = await NarraAPI.getStories();
    stories.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return stories.take(limit).toList();
  }

  /// Get published stories only
  static Future<List<Story>> getPublishedStories() async {
    return await NarraAPI.getStories(status: StoryStatus.published);
  }

  /// Get draft stories only
  static Future<List<Story>> getDraftStories() async {
    return await NarraAPI.getStories(status: StoryStatus.draft);
  }

  /// Get story by ID with full details
  static Future<Story?> getStoryById(String id) async {
    return await NarraAPI.getStoryById(id);
  }

  /// Create new story
  static Future<Story> createStory({
    required String title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    String? datesPrecision,
    String status = 'draft',
  }) async {
    return await NarraAPI.createStory(
      title: title,
      content: content ?? '',
      tags: tags,
      startDate: startDate,
      endDate: endDate,
      datesPrecision: datesPrecision,
      status: status,
    );
  }

  /// Save draft story
  static Future<Story> saveDraft(String id, {
    String? title,
    String? content,
    DateTime? storyDate,
    String? location,
  }) async {
    final update = StoryUpdate(
      title: title,
      content: content,
      storyDate: storyDate,
      location: location,
    );

    return await NarraAPI.updateStory(id, update);
  }

  /// Publish story
  static Future<Story> publishStory(String id) async {
    // Evaluate completeness before publishing
    final story = await NarraAPI.getStoryById(id);
    if (story != null && story.content?.isNotEmpty == true) {
      try {
        final evaluation = await NarraAPI.evaluateStoryCompleteness(
          storyText: story.content!,
          title: story.title,
        );

        final rawScore = evaluation['completeness_score'];
        int? completenessScore;

        if (rawScore is int) {
          completenessScore = rawScore;
        } else if (rawScore is double) {
          completenessScore = rawScore.round();
        } else if (rawScore is String) {
          completenessScore = int.tryParse(rawScore) ??
              double.tryParse(rawScore)?.round();
        }

        if (completenessScore != null) {
          await NarraAPI.updateStory(id, StoryUpdate(
            completenessScore: completenessScore,
          ));
        }
      } on OpenAIProxyException catch (error, stackTrace) {
        debugPrint(
          'Skipping completeness evaluation during publish due to OpenAI proxy error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      } catch (error, stackTrace) {
        debugPrint(
          'Skipping completeness evaluation during publish due to unexpected error: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return await NarraAPI.publishStory(id);
  }

  /// Delete story
  static Future<void> deleteStory(String id) async {
    await NarraAPI.deleteStory(id);
  }

  // ================================
  // AI ASSISTANCE
  // ================================

  /// Get story hints/prompts from AI
  static Future<List<String>> getStoryHints({
    required String context,
    required String theme,
  }) async {
    return await NarraAPI.generateStoryPrompts(
      context: context,
      theme: theme,
      count: 5,
    );
  }

  /// Improve story text with AI
  static Future<String> improveStoryWithAI(String storyId) async {
    final story = await NarraAPI.getStoryById(storyId);
    if (story == null || story.content?.isEmpty != false) {
      throw Exception('Historia no encontrada o vacía');
    }

    final userProfile = await NarraAPI.getUserProfile();
    final writingTone = userProfile?.writingTone.name ?? 'warm';

    final improvedText = await NarraAPI.improveStoryText(
      originalText: story.content!,
      writingTone: writingTone,
    );

    // Update the story with improved text
    await NarraAPI.updateStory(storyId, StoryUpdate(
      content: improvedText,
    ));

    return improvedText;
  }

  /// Get story completeness evaluation
  static Future<StoryEvaluation> evaluateStory(String storyId) async {
    final story = await NarraAPI.getStoryById(storyId);
    if (story == null) {
      throw Exception('Historia no encontrada');
    }

    final evaluation = await NarraAPI.evaluateStoryCompleteness(
      storyText: story.content!,
      title: story.title,
    );

    return StoryEvaluation.fromMap(evaluation);
  }

  /// Generate title suggestions
  static Future<List<String>> suggestTitles(String storyId) async {
    final story = await NarraAPI.getStoryById(storyId);
    if (story == null || story.content?.isEmpty != false) {
      throw Exception('Historia no encontrada o vacía');
    }

    return await NarraAPI.generateTitleSuggestions(
      storyContent: story.content!,
      count: 5,
    );
  }

  // ================================
  // MEDIA MANAGEMENT
  // ================================

  /// Add photo to story
  static Future<StoryPhoto> addPhoto(
    String storyId,
    String photoUrl, {
    String? caption,
  }) async {
    return await NarraAPI.addPhotoToStory(
      storyId,
      photoUrl,
      caption: caption,
    );
  }

  /// Remove photo from story
  static Future<void> removePhoto(String photoId) async {
    await NarraAPI.removePhotoFromStory(photoId);
  }

  /// Update photo caption
  static Future<void> updatePhotoCaption(String photoId, String caption) async {
    // This would require an additional API method
    // For now, we'll leave it as a TODO
    throw UnimplementedError('Photo caption update not implemented');
  }

  // ================================
  // TAGGING & ORGANIZATION
  // ================================

  /// Add tag to story
  static Future<void> addTagToStory(String storyId, String tagId) async {
    await NarraAPI.addTagToStory(storyId, tagId);
  }

  /// Remove tag from story
  static Future<void> removeTagFromStory(String storyId, String tagId) async {
    await NarraAPI.removeTagFromStory(storyId, tagId);
  }

  /// Get stories by tag
  static Future<List<Story>> getStoriesByTag(String tagId) async {
    return await NarraAPI.getStories(tagIds: [tagId]);
  }

  /// Add person to story
  static Future<void> addPersonToStory(String storyId, String personId) async {
    await NarraAPI.addPersonToStory(storyId, personId);
  }

  /// Remove person from story
  static Future<void> removePersonFromStory(String storyId, String personId) async {
    await NarraAPI.removePersonFromStory(storyId, personId);
  }

  /// Get stories by person
  static Future<List<Story>> getStoriesByPerson(String personId) async {
    // This would require a custom query - for now return empty
    return [];
  }

  // ================================
  // STATISTICS & ANALYTICS
  // ================================

  /// Get story statistics
  static Future<StoryStats> getStoryStats() async {
    final stories = await NarraAPI.getStories();
    
    final published = stories.where((s) => s.status == StoryStatus.published);
    final drafts = stories.where((s) => s.status == StoryStatus.draft);
    
    final totalWords = stories.fold<int>(
      0,
      (sum, story) => sum + story.wordCount,
    );
    
    final totalReadingTime = stories.fold<int>(
      0,
      (sum, story) => sum + story.readingTime,
    );
    
    // Calculate this month's stories
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final thisMonthStories = stories.where((story) {
      return story.createdAt.isAfter(monthStart);
    }).length;

    return StoryStats(
      totalStories: stories.length,
      publishedStories: published.length,
      draftStories: drafts.length,
      totalWords: totalWords,
      totalReadingTime: totalReadingTime,
      thisMonthStories: thisMonthStories,
      averageWordsPerStory: stories.isNotEmpty ? (totalWords / stories.length).round() : 0,
      completenessAverage: stories.isNotEmpty 
          ? stories.fold<int>(0, (sum, s) => sum + s.completenessScore) / stories.length
          : 0,
    );
  }

  /// Get book progress (based on published stories)
  static Future<BookProgress> getBookProgress() async {
    const requiredStories = 20;
    final published = await getPublishedStories();
    
    return BookProgress(
      currentStories: published.length,
      requiredStories: requiredStories,
      progress: (published.length / requiredStories * 100).clamp(0, 100),
      canCreateBook: published.length >= requiredStories,
    );
  }
  
  /// Update an existing story
  static Future<Story> updateStory(
    String storyId, {
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    String? datesPrecision,
  }) async {
    return await NarraAPI.updateStory(storyId, StoryUpdate(
      title: title,
      content: content,
      tags: tags,
      startDate: startDate,
      endDate: endDate,
      datesPrecision: datesPrecision,
    ));
  }

  /// Unpublish a story (convert back to draft)
  static Future<Story> unpublishStory(String storyId) async {
    return await NarraAPI.updateStory(storyId, StoryUpdate(
      status: StoryStatus.draft,
    ));
  }

  /// Delete a story permanently
  static Future<void> deleteStoryPermanently(String storyId) async {
    await NarraAPI.deleteStory(storyId);
  }

  // ================================
  // BULK OPERATIONS
  // ================================

  /// Bulk update stories status
  static Future<void> bulkUpdateStatus(
    List<String> storyIds,
    StoryStatus status,
  ) async {
    final futures = storyIds.map((id) => 
      NarraAPI.updateStory(id, StoryUpdate(status: status))
    );
    
    await Future.wait(futures);
  }

  /// Bulk delete stories
  static Future<void> bulkDeleteStories(List<String> storyIds) async {
    final futures = storyIds.map((id) => NarraAPI.deleteStory(id));
    await Future.wait(futures);
  }

  /// Export all stories data
  static Future<Map<String, dynamic>> exportAllStories() async {
    final stories = await NarraAPI.getStories();
    final tags = await NarraAPI.getTags();
    final people = await NarraAPI.getPeople();
    
    return {
      'export_date': DateTime.now().toIso8601String(),
      'total_stories': stories.length,
      'stories': stories.map((s) => s.toMap()).toList(),
      'tags': tags.map((t) => t.toMap()).toList(),
      'people': people.map((p) => p.toMap()).toList(),
    };
  }
}

// ================================
// HELPER MODELS
// ================================

/// Story filter for querying
class StoryFilter {
  final StoryStatus? status;
  final String? searchQuery;
  final List<String>? tagIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool? hasPhotos;
  final bool? hasVoice;

  const StoryFilter({
    this.status,
    this.searchQuery,
    this.tagIds,
    this.dateFrom,
    this.dateTo,
    this.hasPhotos,
    this.hasVoice,
  });

  bool get isEmpty =>
      status == null &&
      searchQuery == null &&
      tagIds == null &&
      dateFrom == null &&
      dateTo == null &&
      hasPhotos == null &&
      hasVoice == null;
}

/// Story evaluation result
class StoryEvaluation {
  final int completenessScore;
  final List<String> missingElements;
  final List<String> suggestions;
  final List<String> strengths;

  const StoryEvaluation({
    required this.completenessScore,
    required this.missingElements,
    required this.suggestions,
    required this.strengths,
  });

  factory StoryEvaluation.fromMap(Map<String, dynamic> map) {
    return StoryEvaluation(
      completenessScore: map['completeness_score'] as int? ?? 0,
      missingElements: List<String>.from(map['missing_elements'] ?? []),
      suggestions: List<String>.from(map['suggestions'] ?? []),
      strengths: List<String>.from(map['strengths'] ?? []),
    );
  }

  bool get isComplete => completenessScore >= 80;
  bool get needsWork => completenessScore < 50;
}

/// Story statistics
class StoryStats {
  final int totalStories;
  final int publishedStories;
  final int draftStories;
  final int totalWords;
  final int totalReadingTime;
  final int thisMonthStories;
  final int averageWordsPerStory;
  final double completenessAverage;

  const StoryStats({
    required this.totalStories,
    required this.publishedStories,
    required this.draftStories,
    required this.totalWords,
    required this.totalReadingTime,
    required this.thisMonthStories,
    required this.averageWordsPerStory,
    required this.completenessAverage,
  });
}

/// Book creation progress
class BookProgress {
  final int currentStories;
  final int requiredStories;
  final double progress;
  final bool canCreateBook;

  const BookProgress({
    required this.currentStories,
    required this.requiredStories,
    required this.progress,
    required this.canCreateBook,
  });

  int get remainingStories => (requiredStories - currentStories).clamp(0, requiredStories);
  
  String get progressMessage {
    if (canCreateBook) {
      return '¡Tu libro está listo para crear!';
    } else if (currentStories > 0) {
      return 'Te faltan $remainingStories historias más';
    } else {
      return 'Empieza escribiendo tu primera historia';
    }
  }
}