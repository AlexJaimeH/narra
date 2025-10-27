import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:narra/supabase/supabase_config.dart';

/// Narra-specific Supabase client with all required methods
class NarraSupabaseClient {
  static final _client = Supabase.instance.client;

  /// Get the Supabase client instance
  static SupabaseClient get client => _client;

  // ================================
  // AUTHENTICATION METHODS
  // ================================

  /// Sign up with email and password
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Get current user
  static User? get currentUser => _client.auth.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ================================
  // USER PROFILE METHODS
  // ================================

  /// Get user profile by ID
  static Future<Map<String, dynamic>?> getUserProfile([String? userId]) async {
    final id = userId ?? currentUser?.id;
    if (id == null) return null;

    final result =
        await _client.from('users').select().eq('id', id).maybeSingle();

    return result;
  }

  /// Create user profile
  static Future<Map<String, dynamic>> createUserProfile({
    required String userId,
    required String email,
    required String name,
    String? phone,
    String? location,
  }) async {
    final now = DateTime.now().toIso8601String();

    final profileData = {
      'id': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'location': location,
      'subscription_tier': 'free',
      'stories_written': 0,
      'words_written': 0,
      'ai_queries_used': 0,
      'ai_queries_limit': 50, // Free tier limit
      'created_at': now,
      'updated_at': now,
    };

    try {
      final result =
          await _client.from('users').upsert(profileData).select().single();

      return result;
    } catch (e) {
      // Si falla el upsert, intentar con insert simple
      try {
        final result =
            await _client.from('users').insert(profileData).select().single();
        return result;
      } catch (insertError) {
        // Si ya existe el usuario, obtener el perfil existente
        if (insertError.toString().contains('duplicate') ||
            insertError.toString().contains('unique')) {
          final existingProfile = await getUserProfile(userId);
          if (existingProfile != null) {
            return existingProfile;
          }
        }
        rethrow;
      }
    }
  }

  /// Ensure user profile exists, create if missing
  static Future<void> ensureUserProfileExists() async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final existingProfile = await getUserProfile(user.id);
      if (existingProfile == null) {
        // Profile doesn't exist, create it
        await createUserProfile(
          userId: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ??
              user.email?.split('@').first ??
              'Usuario',
          phone: user.userMetadata?['phone'],
          location: user.userMetadata?['location'],
        );
      }
    } catch (e) {
      // If profile creation fails, we still want to allow story operations
      // This is a fallback for edge cases
      print('Warning: Could not ensure user profile exists: \$e');
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure user profile exists
    await ensureUserProfileExists();

    updates['updated_at'] = DateTime.now().toIso8601String();

    final result = await _client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return result;
  }

  /// Delete user account and all related data
  static Future<void> deleteUserAccount() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Delete user profile (cascade will handle related data)
    await _client.from('users').delete().eq('id', userId);

    // Sign out
    await signOut();
  }

  // ================================
  // STORY METHODS
  // ================================

  /// Get all stories for current user
  static Future<List<Map<String, dynamic>>> getUserStories({
    String? status,
    String? searchQuery,
    List<String>? tagIds,
    int? limit,
    int? offset,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure user profile exists
    await ensureUserProfileExists();

    dynamic query = _client.from('stories').select('''
          *,
          story_tags (
            tag_id,
            tags (
              id,
              name,
              color
            )
          ),
          story_photos (
            id,
            story_id,
            photo_url,
            caption,
            position,
            created_at
          ),
          story_people (
            person_id,
            people (
              id,
              name,
              relationship
            )
          )
        ''').eq('user_id', userId).order('updated_at', ascending: false);

    if (status != null) {
      if (status == 'published') {
        query = query.or('status.eq.published,published_at.not.is.null');
      } else {
        query = query.eq('status', status);
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query =
          query.or('title.ilike.%$searchQuery%,content.ilike.%$searchQuery%');
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    if (offset != null) {
      query = query.range(offset, offset + (limit ?? 20) - 1);
    }

    final List<dynamic> results = await query;
    return results.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Get story by ID with full details
  static Future<Map<String, dynamic>?> getStoryById(String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client.from('stories').select('''
          *,
          story_tags (
            tag_id,
            tags (
              id,
              name,
              color
            )
          ),
          story_photos (
            id,
            story_id,
            photo_url,
            caption,
            position,
            created_at
          ),
          story_people (
            person_id,
            people (
              id,
              name,
              relationship
            )
          )
        ''').eq('id', storyId).eq('user_id', userId).maybeSingle();

    return result;
  }

  /// Fetch a published story for public sharing without requiring authentication
  static Future<Map<String, dynamic>?> getPublishedStoryById(
      String storyId) async {
    final result = await _client.from('stories').select('''
          *,
          story_tags (
            tag_id,
            tags (
              id,
              name,
              color
            )
          ),
          story_photos (
            id,
            story_id,
            photo_url,
            caption,
            position,
            created_at
          ),
          story_people (
            person_id,
            people (
              id,
              name,
              relationship
            )
          )
        ''').eq('id', storyId).eq('status', 'published').maybeSingle();

    if (result == null) return null;

    final authorId = result['user_id'] as String?;
    if (authorId != null) {
      final profile = await getAuthorPublicProfile(authorId);
      if (profile != null) {
        result['author_profile'] = profile;
      }
    }

    return result;
  }

  /// Get other published stories from the same author to recommend
  static Future<List<Map<String, dynamic>>> getPublishedStoriesByAuthor(
    String authorId, {
    int limit = 4,
    String? excludeStoryId,
  }) async {
    final List<dynamic> results = await _client
        .from('stories')
        .select('''
          *,
          story_tags (
            tag_id,
            tags (
              id,
              name,
              color
            )
          ),
          story_photos (
            id,
            story_id,
            photo_url,
            caption,
            position,
            created_at
          )
        ''')
        .eq('user_id', authorId)
        .eq('status', 'published')
        .order('published_at', ascending: false)
        .limit(limit);

    final profile = await getAuthorPublicProfile(authorId);

    return results
        .map((row) {
          final data = row as Map<String, dynamic>;
          if (excludeStoryId != null && data['id'] == excludeStoryId) {
            return null;
          }
          if (profile != null) {
            data['author_profile'] = profile;
          }
          return data;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Minimal public profile for authors displayed in public story pages
  static Future<Map<String, dynamic>?> getAuthorPublicProfile(
      String authorId) async {
    final result = await _client.from('users').select('''
          id,
          name,
          avatar_url,
          user_settings (
            public_author_name,
            public_author_tagline,
            public_author_summary,
            public_blog_cover_url
          )
        ''').eq('id', authorId).maybeSingle();

    return result;
  }

  /// Get story versions ordered from newest to oldest
  static Future<List<Map<String, dynamic>>> getStoryVersions(
      String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final List<dynamic> result = await _client
        .from('story_versions')
        .select()
        .eq('story_id', storyId)
        .eq('user_id', userId)
        .order('saved_at', ascending: false);

    return result.map((row) => row as Map<String, dynamic>).toList();
  }

  /// Create a story version entry for version history
  static Future<Map<String, dynamic>> createStoryVersion({
    required String storyId,
    required String title,
    required String content,
    required String reason,
    required DateTime savedAt,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    String? datesPrecision,
    List<Map<String, dynamic>>? photos,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final payload = <String, dynamic>{
      'story_id': storyId,
      'user_id': userId,
      'title': title,
      'content': content,
      'reason': reason,
      'saved_at': savedAt.toUtc().toIso8601String(),
      'tags': tags ?? <String>[],
      'photos': photos ?? <Map<String, dynamic>>[],
    };

    if (startDate != null) {
      payload['start_date'] = startDate.toUtc().toIso8601String();
    }
    if (endDate != null) {
      payload['end_date'] = endDate.toUtc().toIso8601String();
    }
    if (datesPrecision != null && datesPrecision.trim().isNotEmpty) {
      payload['dates_precision'] = datesPrecision.trim();
    }

    final result =
        await _client.from('story_versions').insert(payload).select().single();

    return result;
  }

  /// Create story
  static Future<Map<String, dynamic>> createStory({
    required String title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    String? datesPrecision,
    String status = 'draft',
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure user profile exists before creating story
    await ensureUserProfileExists();

    final now = DateTime.now().toIso8601String();

    final storyData = {
      'title': title,
      'content': content ?? '',
      'user_id': userId,
      'status': status,
      'story_date': startDate?.toIso8601String(),

      // dates_precision field removed - not in schema
      'created_at': now,
      'updated_at': now,
    };

    final result =
        await _client.from('stories').insert(storyData).select().single();

    // Add tags if provided
    if (tags != null && tags.isNotEmpty) {
      for (final tagName in tags) {
        try {
          // Get or create tag
          final tag = await getOrCreateTag(tagName);
          // Link tag to story
          await _client.from('story_tags').insert({
            'story_id': result['id'],
            'tag_id': tag['id'],
          });
        } catch (e) {
          print('Error adding tag $tagName: $e');
        }
      }
    }

    return result;
  }

  /// Update story
  static Future<Map<String, dynamic>> updateStory(
    String storyId,
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    updates['updated_at'] = DateTime.now().toIso8601String();

    final result = await _client
        .from('stories')
        .update(updates)
        .eq('id', storyId)
        .eq('user_id', userId)
        .select()
        .single();

    return result;
  }

  /// Delete story and all related data
  static Future<void> deleteStory(String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('stories')
        .delete()
        .eq('id', storyId)
        .eq('user_id', userId);
  }

  /// Publish story
  static Future<Map<String, dynamic>> publishStory(String storyId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now().toIso8601String();
    final baseUpdate = {
      'status': 'published',
      'updated_at': now,
    };

    try {
      final result = await _client
          .from('stories')
          .update({
            ...baseUpdate,
            'published_at': now,
          })
          .eq('id', storyId)
          .eq('user_id', userId)
          .select()
          .single();

      return result;
    } on PostgrestException catch (error) {
      final message = error.message ?? '';
      if (message.contains('published_at') ||
          message.contains('column') && message.contains('published')) {
        // Fallback for databases that don't yet have the published_at column.
        print(
          'publishStory: published_at column missing, proceeding without storing publish timestamp. Error: ${error.message}',
        );

        final fallbackResult = await _client
            .from('stories')
            .update(baseUpdate)
            .eq('id', storyId)
            .eq('user_id', userId)
            .select()
            .single();

        return fallbackResult;
      }

      rethrow;
    }
  }

  // ================================
  // TAG METHODS
  // ================================

  /// Get all tags for current user
  static Future<List<Map<String, dynamic>>> getUserTags() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final results =
        await _client.from('tags').select().eq('user_id', userId).order('name');

    return results.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Create tag
  static Future<Map<String, dynamic>> createTag({
    required String name,
    String? color,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final tagData = {
      'name': name,
      'color': color ?? '#2196F3',
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final result = await _client.from('tags').insert(tagData).select().single();

    return result;
  }

  /// Get or create tag by name
  static Future<Map<String, dynamic>> getOrCreateTag(String name) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Try to find existing tag
    final existing = await _client
        .from('tags')
        .select()
        .eq('user_id', userId)
        .eq('name', name)
        .maybeSingle();

    if (existing != null) {
      return existing;
    }

    // Create new tag
    return await createTag(name: name);
  }

  /// Update tag
  static Future<Map<String, dynamic>> updateTag(
    String tagId,
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client
        .from('tags')
        .update(updates)
        .eq('id', tagId)
        .eq('user_id', userId)
        .select()
        .single();

    return result;
  }

  /// Delete tag
  static Future<void> deleteTag(String tagId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('tags').delete().eq('id', tagId).eq('user_id', userId);
  }

  // ================================
  // PEOPLE METHODS
  // ================================

  /// Get all people for current user
  static Future<List<Map<String, dynamic>>> getUserPeople() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final results = await _client
        .from('people')
        .select()
        .eq('user_id', userId)
        .order('name');

    return results.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Create person
  static Future<Map<String, dynamic>> createPerson({
    required String name,
    String? relationship,
    String? birthDate,
    String? notes,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final personData = {
      'name': name,
      'relationship': relationship,
      'birth_date': birthDate,
      'notes': notes,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final result =
        await _client.from('people').insert(personData).select().single();

    return result;
  }

  /// Update person
  static Future<Map<String, dynamic>> updatePerson(
    String personId,
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client
        .from('people')
        .update(updates)
        .eq('id', personId)
        .eq('user_id', userId)
        .select()
        .single();

    return result;
  }

  /// Delete person
  static Future<void> deletePerson(String personId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('people')
        .delete()
        .eq('id', personId)
        .eq('user_id', userId);
  }

  // ================================
  // SUBSCRIBERS METHODS
  // ================================

  /// Get all subscribers for current user
  static Future<List<Map<String, dynamic>>> getUserSubscribers() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final results = await _client
        .from('subscribers')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return results.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Add subscriber
  static Future<Map<String, dynamic>> addSubscriber({
    required String name,
    required String email,
    String? phone,
    String? relationship,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final subscriberData = {
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'user_id': userId,
      // 'is_active': true, // Column doesn't exist in current schema
      'created_at': DateTime.now().toIso8601String(),
    };

    final result = await _client
        .from('subscribers')
        .insert(subscriberData)
        .select()
        .single();

    return result;
  }

  /// Update subscriber
  static Future<Map<String, dynamic>> updateSubscriber(
    String subscriberId,
    Map<String, dynamic> updates,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client
        .from('subscribers')
        .update(updates)
        .eq('id', subscriberId)
        .eq('user_id', userId)
        .select()
        .single();

    return result;
  }

  /// Delete subscriber
  static Future<void> deleteSubscriber(String subscriberId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('subscribers')
        .delete()
        .eq('id', subscriberId)
        .eq('user_id', userId);
  }

  // ================================
  // STORY RELATIONSHIPS METHODS
  // ================================

  /// Add photo to story
  static Future<Map<String, dynamic>> addPhotoToStory({
    required String storyId,
    required String photoUrl,
    String? caption,
    int position = 0,
  }) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final photoData = {
      'story_id': storyId,
      'photo_url': photoUrl,
      'caption': caption,
      'position': position,
      'created_at': DateTime.now().toIso8601String(),
    };

    final result =
        await _client.from('story_photos').insert(photoData).select().single();

    return result;
  }

  /// Remove photo from story
  static Future<void> removePhotoFromStory(String photoId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('story_photos').delete().eq('id', photoId);
  }

  /// Add tag to story
  static Future<void> addTagToStory(String storyId, String tagId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('story_tags').insert({
      'story_id': storyId,
      'tag_id': tagId,
    });
  }

  /// Remove tag from story
  static Future<void> removeTagFromStory(String storyId, String tagId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('story_tags')
        .delete()
        .eq('story_id', storyId)
        .eq('tag_id', tagId);
  }

  /// Add person to story
  static Future<void> addPersonToStory(String storyId, String personId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('story_people').insert({
      'story_id': storyId,
      'person_id': personId,
    });
  }

  /// Remove person from story
  static Future<void> removePersonFromStory(
      String storyId, String personId) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client
        .from('story_people')
        .delete()
        .eq('story_id', storyId)
        .eq('person_id', personId);
  }

  // ================================
  // DASHBOARD & STATS METHODS
  // ================================

  /// Get dashboard statistics
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Get user profile with stats
    final userProfile = await getUserProfile(userId);

    // Get stories count by status
    final totalStories =
        await _client.from('stories').select('id').eq('user_id', userId);

    final publishedStories = await _client
        .from('stories')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'published');

    final draftStories = await _client
        .from('stories')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'draft');

    // Get subscribers count
    final subscribersCount = await _client.from('subscribers').select('id').eq(
        'user_id',
        userId); // .eq('is_active', true); // Column doesn't exist in current schema

    return {
      'user_profile': userProfile,
      'total_stories': totalStories.length,
      'published_stories': publishedStories.length,
      'draft_stories': draftStories.length,
      'subscribers_count': subscribersCount.length,
    };
  }

  /// Get user settings
  static Future<Map<String, dynamic>?> getUserSettings() async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final result = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return result;
  }

  /// Update user settings
  static Future<Map<String, dynamic>> updateUserSettings(
    Map<String, dynamic> settings,
  ) async {
    final userId = currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Try to update first
    final existing = await _client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // Update existing settings
      final result = await _client
          .from('user_settings')
          .update({
            ...settings,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .select()
          .single();
      return result;
    } else {
      // Create new settings
      final result = await _client
          .from('user_settings')
          .insert({
            'user_id': userId,
            ...settings,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return result;
    }
  }
}
