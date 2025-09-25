import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // Values are provided via --dart-define or environment at build time.
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static late Supabase _instance;
  static SupabaseClient get client => _instance.client;

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('Supabase env not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define.');
    }
    _instance = await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }
}

class SupabaseAuth {
  static SupabaseClient get _client => SupabaseConfig.client;
  
  static User? get currentUser => _client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }
  
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  static Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}

class SupabaseService {
  static SupabaseClient get _client => SupabaseConfig.client;
  
  // Generic CRUD operations
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    String? eq,
    dynamic eqValue,
    String? orderBy,
    bool ascending = true,
  }) async {
    dynamic query = _client.from(table).select(select ?? '*');
    
    if (eq != null && eqValue != null) {
      query = query.eq(eq, eqValue);
    }
    
    if (orderBy != null) {
      query = query.order(orderBy, ascending: ascending);
    }
    
    return await query;
  }
  
  static Future<Map<String, dynamic>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final result = await _client.from(table).insert(data).select();
    return result.first;
  }
  
  static Future<Map<String, dynamic>> update(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await _client.from(table).update(data).eq('id', id).select();
    return result.first;
  }
  
  static Future<void> delete(String table, String id) async {
    await _client.from(table).delete().eq('id', id);
  }
  
  // User operations
  static Future<void> createUserProfile(String userId, Map<String, dynamic> profile) async {
    await _client.from('users').insert({
      'id': userId,
      ...profile,
      'created_at': DateTime.now().toIso8601String(),
    });
  }
  
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final result = await _client.from('users').select().eq('id', userId);
    return result.isNotEmpty ? result.first : null;
  }
}