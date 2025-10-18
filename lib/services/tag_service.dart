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
    final result = await SupabaseConfig.client.from('story_tags').select('''
          tag_id,
          tags (
            id,
            name,
            color
          )
        ''').eq('story_id', storyId);

    return result
        .map<Map<String, dynamic>>((item) => {
              'id': item['tags']['id'],
              'name': item['tags']['name'],
              'color': item['tags']['color'],
            })
        .toList();
  }

  // Obtener estadísticas de etiquetas
  static Future<List<Map<String, dynamic>>> getTagStats() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final result = await SupabaseConfig.client.from('tags').select('''
          *,
          story_tags (
            story_id
          )
        ''').eq('user_id', userId);

    return result
        .map<Map<String, dynamic>>((tag) => {
              ...tag,
              'story_count': (tag['story_tags'] as List).length,
            })
        .toList();
  }

  // Obtener etiquetas predeterminadas para nuevos usuarios
  static Future<void> createDefaultTags() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final defaultTags = [
      {'name': 'Familia', 'color': '#F97362'},
      {'name': 'Infancia', 'color': '#FABF58'},
      {'name': 'Padres', 'color': '#FF8A80'},
      {'name': 'Hermanos', 'color': '#FFAFCC'},
      {'name': 'Tradiciones familiares', 'color': '#FFD166'},
      {'name': 'Hogar', 'color': '#FFC4A8'},
      {'name': 'Historia de amor', 'color': '#FF8FA2'},
      {'name': 'Pareja', 'color': '#FB6F92'},
      {'name': 'Matrimonio', 'color': '#FFC6A5'},
      {'name': 'Hijos', 'color': '#FFB347'},
      {'name': 'Nietos', 'color': '#FFD6BA'},
      {'name': 'Amistad', 'color': '#74C69D'},
      {'name': 'Escuela', 'color': '#4BA3C3'},
      {'name': 'Universidad', 'color': '#6C63FF'},
      {'name': 'Mentores', 'color': '#89A1EF'},
      {'name': 'Primer día de clases', 'color': '#80C7FF'},
      {'name': 'Graduación', 'color': '#9381FF'},
      {'name': 'Actividades escolares', 'color': '#59C3C3'},
      {'name': 'Primer trabajo', 'color': '#0077B6'},
      {'name': 'Carrera profesional', 'color': '#00B4D8'},
      {'name': 'Emprendimiento', 'color': '#48CAE4'},
      {'name': 'Mentoría laboral', 'color': '#8ECAE6'},
      {'name': 'Jubilación', 'color': '#90E0EF'},
      {'name': 'Servicio comunitario', 'color': '#6BCB77'},
      {'name': 'Viajes', 'color': '#00A6FB'},
      {'name': 'Mudanzas', 'color': '#72EFDD'},
      {'name': 'Naturaleza', 'color': '#2BB673'},
      {'name': 'Cultura', 'color': '#FFC857'},
      {'name': 'Descubrimientos', 'color': '#4D96FF'},
      {'name': 'Aventura en carretera', 'color': '#5E60CE'},
      {'name': 'Logros', 'color': '#FFB703'},
      {'name': 'Sueños cumplidos', 'color': '#FF9E00'},
      {'name': 'Celebraciones familiares', 'color': '#FFD670'},
      {'name': 'Reconocimientos', 'color': '#FFC8DD'},
      {'name': 'Momentos de orgullo', 'color': '#FF8FAB'},
      {'name': 'Cumpleaños memorables', 'color': '#FFC4D6'},
      {'name': 'Enfermedad', 'color': '#9D4EDD'},
      {'name': 'Recuperación', 'color': '#B15EFF'},
      {'name': 'Momentos difíciles', 'color': '#845EC2'},
      {'name': 'Pérdidas', 'color': '#6D597A'},
      {'name': 'Fe y esperanza', 'color': '#80CED7'},
      {'name': 'Lecciones de vida', 'color': '#577590'},
      {'name': 'Hobbies', 'color': '#06D6A0'},
      {'name': 'Mascotas', 'color': '#FFA69E'},
      {'name': 'Recetas favoritas', 'color': '#FFC15E'},
      {'name': 'Música', 'color': '#118AB2'},
      {'name': 'Tecnología', 'color': '#73B0FF'},
      {'name': 'Conversaciones especiales', 'color': '#9EADC8'},
      {'name': 'Otros momentos', 'color': '#B0BEC5'},
      {'name': 'Recuerdos únicos', 'color': '#CDB4DB'},
      {'name': 'Sin categoría', 'color': '#E2E2E2'},
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
