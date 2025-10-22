import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/public_access/public_author_profile.dart';
import 'package:narra/supabase/narra_client.dart';

/// Service dedicated to loading stories for the public blog experience.
///
/// The goal is to abstract the source of the data so we can swap the
/// implementation (Supabase, Edge Function, mock data) without touching the UI.
class PublicStoryService {
  const PublicStoryService._();

  /// Load a single published story.
  static Future<Story?> getPublishedStory(String storyId) async {
    try {
      return await StoryRepository.getPublishedStoryForPublic(storyId);
    } catch (error) {
      // Log and swallow the exception so the UI can decide how to react.
      // ignore: avoid_print
      print('Error fetching public story: $error');
      return null;
    }
  }

  /// Load additional stories from the same author to display as recommendations.
  static Future<List<Story>> getRecommendedStories({
    required String authorId,
    required String excludeStoryId,
    int limit = 3,
  }) async {
    try {
      final stories = await StoryRepository.getPublishedStoriesByAuthor(
        authorId,
        limit: limit + 1, // Fetch one more to account for the current story.
        excludeStoryId: excludeStoryId,
      );

      return stories
          .where((story) => story.id != excludeStoryId)
          .take(limit)
          .toList();
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching recommended stories: $error');
      return const [];
    }
  }

  /// Load the latest published stories for an author without excluding any.
  static Future<List<Story>> getLatestStories({
    required String authorId,
    int limit = 6,
  }) async {
    try {
      final stories = await StoryRepository.getPublishedStoriesByAuthor(
        authorId,
        limit: limit,
      );
      return stories;
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching latest stories: $error');
      return const [];
    }
  }

  /// Resolve the display name that should be shown to subscribers.
  static Future<PublicAuthorProfile?> getAuthorProfile(String authorId) async {
    try {
      final data = await NarraSupabaseClient.getAuthorPublicProfile(authorId);
      if (data == null) return null;
      return PublicAuthorProfile.fromSupabase(data);
    } catch (error) {
      // ignore: avoid_print
      print('Error fetching author profile: $error');
      return null;
    }
  }

  static Future<String?> getAuthorDisplayName(String authorId) async {
    final profile = await getAuthorProfile(authorId);
    return profile?.resolvedDisplayName;
  }
}
