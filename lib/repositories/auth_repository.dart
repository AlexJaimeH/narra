import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:narra/supabase/narra_client.dart';

/// Repository for authentication operations
class AuthRepository {
  /// Sign up with email and password
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? location,
  }) async {
    try {
      final response = await NarraSupabaseClient.signUp(
        email: email,
        password: password,
        metadata: {
          'name': name,
          'phone': phone,
          'location': location,
        },
      );

      if (response.user != null) {
        // Create user profile immediately after successful registration
        try {
          await NarraSupabaseClient.createUserProfile(
            userId: response.user!.id,
            email: email,
            name: name,
            phone: phone,
            location: location,
          );
        } catch (profileError) {
          // If profile creation fails, still return success but log the error
          print('Warning: Could not create user profile: $profileError');
        }
        
        return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
      } else {
        return AuthResult.failure('Error creating account');
      }
    } catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await NarraSupabaseClient.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Ensure user profile exists (for users created before this fix)
        try {
          final userProfile = await NarraSupabaseClient.getUserProfile(response.user!.id);
          if (userProfile == null) {
            // Create profile if it doesn't exist
            await NarraSupabaseClient.createUserProfile(
              userId: response.user!.id,
              email: email,
              name: response.user!.userMetadata?['name'] ?? email.split('@').first,
              phone: response.user!.userMetadata?['phone'],
              location: response.user!.userMetadata?['location'],
            );
          }
        } catch (profileError) {
          print('Warning: Could not verify/create user profile: $profileError');
        }
        
        return AuthResult.success(AuthUser.fromSupabaseUser(response.user!));
      } else {
        return AuthResult.failure('Error signing in');
      }
    } catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await NarraSupabaseClient.signOut();
  }

  /// Get current authenticated user
  static AuthUser? get currentUser {
    final user = NarraSupabaseClient.currentUser;
    return user != null ? AuthUser.fromSupabaseUser(user) : null;
  }

  /// Check if user is authenticated
  static bool get isAuthenticated => NarraSupabaseClient.isAuthenticated;

  /// Listen to authentication state changes
  static Stream<AuthUser?> get authStateChanges {
    return NarraSupabaseClient.authStateChanges.map((state) {
      return state.session?.user != null
          ? AuthUser.fromSupabaseUser(state.session!.user)
          : null;
    });
  }

  /// Reset password
  static Future<AuthResult> resetPassword(String email) async {
    try {
      // Note: Supabase reset password would be implemented here
      // For now, just return success
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    }
  }

  /// Update user password
  static Future<AuthResult> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Note: Supabase update password would be implemented here
      return AuthResult.success(null);
    } catch (e) {
      return AuthResult.failure(_getErrorMessage(e));
    }
  }

  /// Delete user account
  static Future<void> deleteAccount() async {
    await NarraSupabaseClient.deleteUserAccount();
  }

  /// Get user-friendly error message
  static String _getErrorMessage(dynamic error) {
    final message = error.toString().toLowerCase();
    
    if (message.contains('invalid login credentials') || 
        message.contains('invalid email or password')) {
      return 'Credenciales incorrectas. Verifica tu email y contraseña.';
    } else if (message.contains('user already registered') ||
               message.contains('email already registered')) {
      return 'Ya existe una cuenta con este email.';
    } else if (message.contains('signup disabled')) {
      return 'El registro de nuevas cuentas está deshabilitado temporalmente.';
    } else if (message.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    } else if (message.contains('email not confirmed')) {
      return 'Por favor, confirma tu email antes de continuar.';
    } else if (message.contains('network') || message.contains('connection')) {
      return 'Error de conexión. Verifica tu internet e inténtalo de nuevo.';
    } else if (message.contains('rate limit') || message.contains('too many')) {
      return 'Demasiados intentos. Espera unos minutos antes de intentar de nuevo.';
    } else if (message.contains('invalid email')) {
      return 'El formato del email no es válido.';
    }
    
    return 'Error de autenticación. Inténtalo de nuevo.';
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool isSuccess;
  final AuthUser? user;
  final String? error;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.error,
  });

  factory AuthResult.success(AuthUser? user) {
    return AuthResult._(isSuccess: true, user: user);
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}

/// Authenticated user model
class AuthUser {
  final String id;
  final String email;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? emailConfirmedAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.metadata,
    required this.createdAt,
    this.emailConfirmedAt,
  });

  factory AuthUser.fromSupabaseUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      metadata: user.userMetadata,
      createdAt: DateTime.parse(user.createdAt),
      emailConfirmedAt: user.emailConfirmedAt != null ? DateTime.parse(user.emailConfirmedAt!) : null,
    );
  }

  String? get name => metadata?['name'] as String?;
  String? get phone => metadata?['phone'] as String?;
  String? get location => metadata?['location'] as String?;
  
  bool get isEmailConfirmed => emailConfirmedAt != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'email_confirmed_at': emailConfirmedAt?.toIso8601String(),
    };
  }
}

/// Authentication exceptions
class AuthException implements Exception {
  final String message;
  final String code;

  const AuthException({
    required this.message,
    required this.code,
  });

  @override
  String toString() => message;
}

/// Authentication error codes
class AuthErrorCodes {
  static const String invalidCredentials = 'invalid_credentials';
  static const String userAlreadyExists = 'user_already_exists';
  static const String emailNotConfirmed = 'email_not_confirmed';
  static const String weakPassword = 'weak_password';
  static const String networkError = 'network_error';
  static const String rateLimitExceeded = 'rate_limit_exceeded';
  static const String signupDisabled = 'signup_disabled';
  static const String invalidEmail = 'invalid_email';
  static const String unknown = 'unknown';
}