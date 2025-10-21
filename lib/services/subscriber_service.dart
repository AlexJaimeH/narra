import 'package:uuid/uuid.dart';
import 'package:narra/supabase/supabase_config.dart';

class Subscriber {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? relationship;
  final bool isActive;
  final String status;
  final String magicKey;
  final DateTime? magicKeyCreatedAt;
  final DateTime? magicLinkLastSentAt;
  final DateTime? lastAccessAt;
  final String? lastAccessIp;
  final String? lastAccessUserAgent;
  final String? lastAccessSource;
  final DateTime createdAt;

  Subscriber({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.relationship,
    this.isActive = true,
    required this.status,
    required this.magicKey,
    this.magicKeyCreatedAt,
    this.magicLinkLastSentAt,
    this.lastAccessAt,
    this.lastAccessIp,
    this.lastAccessUserAgent,
    this.lastAccessSource,
    required this.createdAt,
  });

  factory Subscriber.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Subscriber(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      relationship: map['relationship'],
      status: (map['status'] as String? ?? 'pending').toLowerCase(),
      isActive: (map['status'] as String? ?? 'pending') != 'unsubscribed',
      magicKey: (map['access_token'] as String? ?? '').trim(),
      magicKeyCreatedAt: parseDate(map['access_token_created_at']),
      magicLinkLastSentAt: parseDate(map['access_token_last_sent_at']),
      lastAccessAt: parseDate(map['last_access_at']),
      lastAccessIp: map['last_access_ip'] as String?,
      lastAccessUserAgent: map['last_access_user_agent'] as String?,
      lastAccessSource: map['last_access_source'] as String?,
      createdAt: parseDate(map['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      // 'is_active': isActive, // Column doesn't exist in current schema
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SubscriberService {
  static const _uuid = Uuid();

  // Obtener todos los suscriptores
  static Future<List<Subscriber>> getSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    final data = await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );

    return data.map((item) => Subscriber.fromMap(item)).toList();
  }

  static Future<List<Subscriber>> getConfirmedSubscribers() async {
    final subscribers = await getSubscribers();
    return subscribers
        .where((subscriber) => subscriber.status == 'confirmed')
        .toList();
  }

  // Obtener todos los suscriptores del usuario (legacy)
  static Future<List<Map<String, dynamic>>> getUserSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
      orderBy: 'name',
    );
  }

  // Crear nuevo suscriptor
  static Future<Map<String, dynamic>> createSubscriber({
    required String name,
    required String email,
    String? phone,
    String? relationship,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.insert('subscribers', {
      'id': _uuid.v4(),
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'status': 'confirmed', // Por simplicidad, confirmamos automáticamente
    });
  }

  // Actualizar suscriptor
  static Future<Map<String, dynamic>> updateSubscriber(
    String subscriberId,
    Map<String, dynamic> updates,
  ) async {
    return await SupabaseService.update('subscribers', subscriberId, updates);
  }

  // Eliminar suscriptor
  static Future<void> deleteSubscriber(String subscriberId) async {
    await SupabaseService.delete('subscribers', subscriberId);
  }

  // Cambiar estado de suscriptor
  static Future<void> updateSubscriberStatus(
    String subscriberId,
    String status,
  ) async {
    await SupabaseService.update('subscribers', subscriberId, {
      'status': status,
    });
  }

  static Future<void> markMagicLinkSent(String subscriberId) async {
    await SupabaseService.update('subscribers', subscriberId, {
      'access_token_last_sent_at': DateTime.now().toIso8601String(),
    });
  }

  // Obtener estadísticas de suscriptores
  static Future<Map<String, int>> getSubscriberStats() async {
    final subscribers = await getUserSubscribers();

    final confirmed =
        subscribers.where((s) => s['status'] == 'confirmed').length;
    final pending = subscribers.where((s) => s['status'] == 'pending').length;
    final unsubscribed =
        subscribers.where((s) => s['status'] == 'unsubscribed').length;

    return {
      'total': subscribers.length,
      'confirmed': confirmed,
      'pending': pending,
      'unsubscribed': unsubscribed,
    };
  }

  // Simular envío de historia a suscriptores
  static Future<void> shareStoryWithSubscribers(
    String storyId,
    List<String> subscriberIds,
  ) async {
    // En una implementación real, aquí se enviarían emails o notificaciones
    // Por ahora solo actualizamos la fecha de último envío

    for (final subscriberId in subscriberIds) {
      await SupabaseService.update('subscribers', subscriberId, {
        'last_sent_at': DateTime.now().toIso8601String(),
      });
    }

    // Registrar actividad
    await _logActivity('story_shared', storyId, metadata: {
      'subscriber_count': subscriberIds.length,
    });
  }

  // Obtener suscriptores activos (confirmados)
  static Future<List<Map<String, dynamic>>> getActiveSubscribers() async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) throw Exception('Usuario no autenticado');

    return await SupabaseService.select(
      'subscribers',
      eq: 'user_id',
      eqValue: userId,
    ).then((subscribers) =>
        subscribers.where((s) => s['status'] == 'confirmed').toList());
  }

  // Registrar actividad privada
  static Future<void> _logActivity(
    String activityType,
    String entityId, {
    Map<String, dynamic>? metadata,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.insert('user_activity', {
      'id': _uuid.v4(),
      'user_id': userId,
      'activity_type': activityType,
      'entity_id': entityId,
      'metadata': metadata,
    });
  }
}
