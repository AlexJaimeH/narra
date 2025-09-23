import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ptlzlaacaiftusslzwhc.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0bHpsYWFjYWlmdHVzc2x6d2hjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc5ODc3NzEsImV4cCI6MjA3MzU2Mzc3MX0.Da1VcxbSjd3sWdks9CzXU4OJaRSv0pW016thze0mAs4';
  
  static late Supabase _instance;
  static SupabaseClient get client => _instance.client;
  
  static Future<void> initialize() async {
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