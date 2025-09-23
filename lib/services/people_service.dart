import 'package:uuid/uuid.dart';
import 'package:narra/supabase/supabase_config.dart';

class Person {
  final String id;
  final String name;
  final String relation;
  final bool isPrivate;
  final bool isFamily;
  final String? bio;
  final String? avatar;
  
  Person({
    required this.id,
    required this.name,
    required this.relation,
    this.isPrivate = false,
    this.isFamily = false,
    this.bio,
    this.avatar,
  });
  
  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      relation: map['relation'] ?? '',
      isPrivate: map['is_private'] ?? false,
      isFamily: map['is_family'] ?? false,
      bio: map['bio'],
      avatar: map['avatar'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relation': relation,
      'is_private': isPrivate,
      'is_family': isFamily,
      'bio': bio,
      'avatar': avatar,
    };
  }
}

class PeopleService {
  static const _uuid = Uuid();

  // Obtener todas las personas
  static Future<List<Person>> getAllPeople() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseService.select(
      'people',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
    
    return data.map((item) => Person.fromMap(item)).toList();
  }

  // Obtener todas las personas del usuario (legacy)
  static Future<List<Map<String, dynamic>>> getUserPeople() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'people',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
  }

  // Crear nueva persona
  static Future<Map<String, dynamic>> createPerson({
    required String name,
    String? relationship,
    String? birthDate,
    String? notes,
    String? avatarUrl,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final person = await SupabaseService.insert('people', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'relationship': relationship,
      'birth_date': birthDate,
      'notes': notes,
      'avatar_url': avatarUrl,
    });

    // Registrar actividad
    await _logActivity('person_added', person['id']);

    return person;
  }

  // Actualizar persona
  static Future<Map<String, dynamic>> updatePerson(
    String personId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update('people', personId, updates);
  }

  // Eliminar persona
  static Future<void> deletePerson(String personId) async {
    await SupabaseService.delete('people', personId);
  }

  // Añadir persona a historia
  static Future<void> addPersonToStory(String storyId, String personId) async {
    try {
      await SupabaseService.insert('story_people', {
        'id': _uuid.v4(),
        'story_id': storyId,
        'person_id': personId,
      });
    } catch (e) {
      // Ignora si ya existe la relación
      if (!e.toString().contains('unique')) rethrow;
    }
  }

  // Remover persona de historia
  static Future<void> removePersonFromStory(String storyId, String personId) async {
    final relations = await SupabaseConfig.client
        .from('story_people')
        .select()
        .eq('story_id', storyId)
        .eq('person_id', personId);

    for (final relation in relations) {
      await SupabaseService.delete('story_people', relation['id']);
    }
  }

  // Obtener personas de una historia
  static Future<List<Map<String, dynamic>>> getStoryPeople(String storyId) async {
    final result = await SupabaseConfig.client
        .from('story_people')
        .select('''
          person_id,
          people (
            id,
            name,
            relationship,
            avatar_url
          )
        ''')
        .eq('story_id', storyId);

    return result.map<Map<String, dynamic>>((item) => {
          'id': item['people']['id'],
          'name': item['people']['name'],
          'relationship': item['people']['relationship'],
          'avatar_url': item['people']['avatar_url'],
        }).toList();
  }

  // Obtener estadísticas de personas
  static Future<List<Map<String, dynamic>>> getPeopleStats() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final result = await SupabaseConfig.client
        .from('people')
        .select('''
          *,
          story_people (
            story_id
          )
        ''')
        .eq('user_id', userId);

    return result.map<Map<String, dynamic>>((person) => {
          ...person,
          'story_count': (person['story_people'] as List).length,
        }).toList();
  }

  // Buscar personas por nombre
  static Future<List<Map<String, dynamic>>> searchPeople(String query) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final result = await SupabaseConfig.client
        .from('people')
        .select()
        .eq('user_id', userId)
        .ilike('name', '%$query%')
        .order('name');

    return result;
  }

  // Obtener relaciones más frecuentes para sugerencias
  static Future<List<String>> getCommonRelationships() async {
    return [
      'Padre',
      'Madre',
      'Hermano/a',
      'Esposo/a',
      'Hijo/a',
      'Nieto/a',
      'Abuelo/a',
      'Tío/a',
      'Primo/a',
      'Amigo/a',
      'Compañero/a de trabajo',
      'Vecino/a',
      'Maestro/a',
      'Jefe',
      'Colega',
    ];
  }

  // Registrar actividad privada
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