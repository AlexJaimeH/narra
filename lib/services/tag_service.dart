import 'package:uuid/uuid.dart';
import 'package:narra/supabase/supabase_config.dart';

class Tag {
  final String id;
  final String name;
  final String color;
  
  Tag({
    required this.id,
    required this.name,
    required this.color,
  });
  
  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      color: map['color'] ?? '#3498db',
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

class TagService {
  static const _uuid = Uuid();

  // Obtener todas las etiquetas
  static Future<List<Tag>> getAllTags() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseService.select(
      'tags',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
    
    return data.map((item) => Tag.fromMap(item)).toList();
  }

  // Obtener todas las etiquetas del usuario (legacy)
  static Future<List<Map<String, dynamic>>> getUserTags() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'tags',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
  }

  // Crear nueva etiqueta
  static Future<Map<String, dynamic>> createTag({
    required String name,
    String color = '#3498db',
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.insert('tags', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'color': color,
    });
  }

  // Actualizar etiqueta
  static Future<Map<String, dynamic>> updateTag(
    String tagId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update('tags', tagId, updates);
  }

  // Eliminar etiqueta
  static Future<void> deleteTag(String tagId) async {
    await SupabaseService.delete('tags', tagId);
  }

  // Añadir etiqueta a historia
  static Future<void> addTagToStory(String storyId, String tagId) async {
    try {
      await SupabaseService.insert('story_tags', {
        'id': _uuid.v4(),
        'story_id': storyId,
        'tag_id': tagId,
      });
    } catch (e) {
      // Ignora si ya existe la relación
      if (!e.toString().contains('unique')) rethrow;
    }
  }

  // Remover etiqueta de historia
  static Future<void> removeTagFromStory(String storyId, String tagId) async {
    final relations = await SupabaseConfig.client
        .from('story_tags')
        .select()
        .eq('story_id', storyId)
        .eq('tag_id', tagId);

    for (final relation in relations) {
      await SupabaseService.delete('story_tags', relation['id']);
    }
  }

  // Obtener etiquetas de una historia
  static Future<List<Map<String, dynamic>>> getStoryTags(String storyId) async {
    final result = await SupabaseConfig.client
        .from('story_tags')
        .select('''
          tag_id,
          tags (
            id,
            name,
            color
          )
        ''')
        .eq('story_id', storyId);

    return result.map<Map<String, dynamic>>((item) => {
          'id': item['tags']['id'],
          'name': item['tags']['name'],
          'color': item['tags']['color'],
        }).toList();
  }

  // Obtener estadísticas de etiquetas
  static Future<List<Map<String, dynamic>>> getTagStats() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final result = await SupabaseConfig.client
        .from('tags')
        .select('''
          *,
          story_tags (
            story_id
          )
        ''')
        .eq('user_id', userId);

    return result.map<Map<String, dynamic>>((tag) => {
          ...tag,
          'story_count': (tag['story_tags'] as List).length,
        }).toList();
  }

  // Obtener etiquetas predeterminadas para nuevos usuarios
  static Future<void> createDefaultTags() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final defaultTags = [
      {'name': 'Familia', 'color': '#e74c3c'},
      {'name': 'Infancia', 'color': '#f39c12'},
      {'name': 'Trabajo', 'color': '#3498db'},
      {'name': 'Amigos', 'color': '#2ecc71'},
      {'name': 'Viajes', 'color': '#9b59b6'},
      {'name': 'Amor', 'color': '#e91e63'},
      {'name': 'Logros', 'color': '#ff9800'},
      {'name': 'Desafíos', 'color': '#607d8b'},
    ];

    for (final tag in defaultTags) {
      try {
        await createTag(
          name: tag['name']!,
          color: tag['color']!,
        );
      } catch (e) {
        // Ignora si ya existe
        continue;
      }
    }
  }
}