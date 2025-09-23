import 'package:uuid/uuid.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/openai/openai_config.dart';

class StoryService {
  static const _uuid = Uuid();

  // Obtener todas las historias del usuario
  static Future<List<Map<String, dynamic>>> getUserStories({
    String? status,
    String? searchQuery,
    List<String>? tagIds,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    dynamic query = SupabaseConfig.client
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
            photo_url,
            caption
          )
        ''')
        .eq('user_id', userId);

    if (status != null) {
      query = query.eq('status', status);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or('title.ilike.%$searchQuery%,content.ilike.%$searchQuery%');
    }

    query = query.order('updated_at', ascending: false);

    final result = await query;
    return result;
  }

  // Crear nueva historia
  static Future<Map<String, dynamic>> createStory({
    required String title,
    String content = '',
    String? storyDate,
    String? location,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final storyData = {
      'id': _uuid.v4(),
      'user_id': userId,
      'title': title,
      'content': content,
      'story_date': storyDate,
      'location': location,
      'word_count': _countWords(content),
      'reading_time': _calculateReadingTime(content),
    };

    final story = await SupabaseService.insert('stories', storyData);

    // Registrar actividad
    await _logActivity('story_created', story['id']);

    return story;
  }

  // Actualizar historia
  static Future<Map<String, dynamic>> updateStory(
    String storyId,
    Map<String, dynamic> updates,
  ) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Actualizar word_count y reading_time si se actualiza el contenido
    if (updates.containsKey('content')) {
      final content = updates['content'] as String;
      updates['word_count'] = _countWords(content);
      updates['reading_time'] = _calculateReadingTime(content);
    }

    final story = await SupabaseService.update('stories', storyId, updates);

    // Registrar actividad
    await _logActivity('story_updated', storyId);

    return story;
  }

  // Evaluar completitud con IA
  static Future<void> evaluateStoryCompleteness(String storyId) async {
    final stories = await SupabaseService.select(
      'stories',
      eq: 'id',
      eqValue: storyId,
    );

    if (stories.isEmpty) return;

    final story = stories.first;
    final evaluation = await OpenAIService.evaluateStoryCompleteness(
      storyText: story['content'],
      title: story['title'],
    );

    await SupabaseService.update('stories', storyId, {
      'completeness_score': evaluation['completeness_score'],
      'ai_suggestions': evaluation['suggestions'],
    });
  }

  // Mejorar texto con IA
  static Future<String> improveStoryText(
    String storyId,
    String originalText,
  ) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Obtener el tono de escritura del usuario
    final user = await SupabaseService.getUserProfile(userId);
    final writingTone = user?['writing_tone'] ?? 'warm';

    final result = await OpenAIService.improveStoryText(
      originalText: originalText,
      tone: writingTone,
    );
    return result['polished_text'] ?? originalText;
  }

  // Generar pistas/preguntas para la historia
  static Future<List<String>> generateStoryPrompts({
    required String context,
    required String theme,
  }) async {
    return await OpenAIService.generateStoryPrompts(
      context: context,
      theme: theme,
    );
  }

  // Añadir foto a historia
  static Future<void> addPhotoToStory(
    String storyId,
    String photoUrl, {
    String? caption,
  }) async {
    await SupabaseService.insert('story_photos', {
      'id': _uuid.v4(),
      'story_id': storyId,
      'photo_url': photoUrl,
      'caption': caption,
      'position': await _getNextPhotoPosition(storyId),
    });

    await _logActivity('photo_added', storyId);
  }

  // Publicar historia
  static Future<void> publishStory(String storyId) async {
    await SupabaseService.update('stories', storyId, {
      'status': 'published',
    });

    await _logActivity('story_published', storyId);
  }

  // Eliminar historia
  static Future<void> deleteStory(String storyId) async {
    await SupabaseService.delete('stories', storyId);
  }

  // Obtener estadísticas del usuario
  static Future<Map<String, dynamic>> getUserStats() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final stories = await SupabaseService.select(
      'stories',
      eq: 'user_id',
      eqValue: userId,
    );

    final published = stories.where((s) => s['status'] == 'published').length;
    final drafts = stories.where((s) => s['status'] == 'draft').length;
    final totalWords = stories.fold<int>(
      0,
      (sum, story) => sum + (story['word_count'] as int? ?? 0),
    );

    return {
      'total_stories': stories.length,
      'published_stories': published,
      'draft_stories': drafts,
      'total_words': totalWords,
      'progress_to_book': (published / 20 * 100).clamp(0, 100).round(),
    };
  }

  // Métodos privados auxiliares
  static int _countWords(String text) {
    return text.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  }

  static int _calculateReadingTime(String text) {
    const wordsPerMinute = 200;
    final wordCount = _countWords(text);
    return (wordCount / wordsPerMinute).ceil();
  }

  static Future<int> _getNextPhotoPosition(String storyId) async {
    final photos = await SupabaseService.select(
      'story_photos',
      eq: 'story_id',
      eqValue: storyId,
      orderBy: 'position',
      ascending: false,
    );

    if (photos.isEmpty) return 0;
    return (photos.first['position'] as int) + 1;
  }

  static Future<void> _logActivity(String activityType, String entityId) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.insert('user_activity', {
      'id': _uuid.v4(),
      'user_id': userId,
      'activity_type': activityType,
      'entity_id': entityId,
    });
  }
}