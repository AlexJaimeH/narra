import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/services/tag_service.dart';

class UserService {
  // Crear perfil de usuario después del registro
  static Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
    String? birthDate,
    String? phone,
    String? location,
  }) async {
    try {
      await SupabaseService.createUserProfile(userId, {
        'name': name,
        'email': email,
        'birth_date': birthDate,
        'phone': phone,
        'location': location,
      });
    } catch (e) {
      print('Error creating user profile: $e');
      // Continuar con otras operaciones aunque falle el perfil
    }

    try {
      // Crear configuraciones por defecto
      await _createDefaultSettings(userId);
    } catch (e) {
      print('Error creating default settings: $e');
    }

    try {
      // Crear etiquetas por defecto
      await TagService.createDefaultTags();
    } catch (e) {
      print('Error creating default tags: $e');
    }
  }

  // Obtener perfil del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return null;

    return await SupabaseService.getUserProfile(userId);
  }

  // Actualizar perfil de usuario
  static Future<Map<String, dynamic>> updateUserProfile(
    Map<String, dynamic> updates,
  ) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.update('users', userId, updates);
  }

  // Obtener configuraciones del usuario
  static Future<Map<String, dynamic>?> getUserSettings() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return null;

    final settings = await SupabaseService.select(
      'user_settings',
      eq: 'user_id',
      eqValue: userId,
    );

    return settings.isNotEmpty ? settings.first : null;
  }

  // Actualizar configuraciones del usuario
  static Future<Map<String, dynamic>> updateUserSettings(
    Map<String, dynamic> updates,
  ) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Buscar configuraciones existentes
    final existing = await getUserSettings();
    
    if (existing != null) {
      return await SupabaseService.update('user_settings', existing['id'], updates);
    } else {
      // Crear nuevas configuraciones si no existen
      return await SupabaseService.insert('user_settings', {
        'user_id': userId,
        ...updates,
      });
    }
  }

  // Actualizar plan de usuario (simulación de pago)
  static Future<void> upgradeToPremium() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Simular pago exitoso - en producción aquí iría la integración con Stripe
    await SupabaseService.update('users', userId, {
      'plan_type': 'premium',
      'plan_expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });
  }

  // Verificar si el usuario tiene plan premium
  static Future<bool> isPremiumUser() async {
    final profile = await getCurrentUserProfile();
    if (profile == null) return false;

    final planType = profile['plan_type'];
    final expiresAt = profile['plan_expires_at'];

    if (planType != 'premium') return false;
    
    if (expiresAt != null) {
      final expiry = DateTime.parse(expiresAt);
      return expiry.isAfter(DateTime.now());
    }

    return false;
  }

  // Obtener actividad reciente del usuario
  static Future<List<Map<String, dynamic>>> getRecentActivity({
    int limit = 10,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return [];

    final activities = await SupabaseConfig.client
        .from('user_activity')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return activities;
  }

  // Obtener estadísticas generales del usuario
  static Future<Map<String, dynamic>> getUserDashboardStats() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // Estadísticas de historias
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

    // Estadísticas de personas
    final people = await SupabaseService.select(
      'people',
      eq: 'user_id',
      eqValue: userId,
    );

    // Estadísticas de suscriptores
    final subscribers = await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
    );

    final activeSubscribers = subscribers.where((s) => s['status'] == 'confirmed').length;

    // Actividad reciente
    final recentActivity = await getRecentActivity(limit: 5);

    return {
      'total_stories': stories.length,
      'published_stories': published,
      'draft_stories': drafts,
      'total_words': totalWords,
      'progress_to_book': (published / 20 * 100).clamp(0, 100).round(),
      'total_people': people.length,
      'active_subscribers': activeSubscribers,
      'recent_activity': recentActivity,
      'this_week_stories': _getThisWeekCount(stories),
    };
  }

  // Eliminar cuenta de usuario
  static Future<void> deleteUserAccount() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    // En Supabase, las eliminaciones en cascada se encargarán de limpiar los datos relacionados
    await SupabaseService.delete('users', userId);
    
    // Cerrar sesión
    await SupabaseAuth.signOut();
  }

  // Crear configuraciones por defecto
  static Future<void> _createDefaultSettings(String userId) async {
    await SupabaseService.insert('user_settings', {
      'user_id': userId,
      'auto_save': true,
      'notification_stories': true,
      'notification_reminders': true,
      'sharing_enabled': false,
      'language': 'es',
      'font_family': 'Montserrat',
      'text_scale': 1.0,
    });
  }

  // Contar historias de esta semana
  static int _getThisWeekCount(List<Map<String, dynamic>> stories) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    return stories.where((story) {
      final createdAt = DateTime.parse(story['created_at']);
      return createdAt.isAfter(weekStart);
    }).length;
  }
}