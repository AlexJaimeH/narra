import 'package:narra/supabase/narra_client.dart';

/// Repository for user-related operations
class UserRepository {
  /// Get current user profile
  static Future<UserProfile?> getCurrentProfile() async {
    final data = await NarraSupabaseClient.getUserProfile();
    return data != null ? UserProfile.fromMap(data) : null;
  }

  /// Update user profile
  static Future<UserProfile> updateProfile(UserProfileUpdate update) async {
    final data = await NarraSupabaseClient.updateUserProfile(update.toMap());
    return UserProfile.fromMap(data);
  }

  /// Delete user account
  static Future<void> deleteAccount() async {
    await NarraSupabaseClient.deleteUserAccount();
  }

  /// Get dashboard statistics
  static Future<DashboardStats> getDashboardStats() async {
    final data = await NarraSupabaseClient.getDashboardStats();
    return DashboardStats.fromMap(data);
  }

  /// Get user settings
  static Future<UserSettings?> getSettings() async {
    final data = await NarraSupabaseClient.getUserSettings();
    return data != null ? UserSettings.fromMap(data) : null;
  }

  /// Update user settings
  static Future<UserSettings> updateSettings(UserSettingsUpdate update) async {
    final data = await NarraSupabaseClient.updateUserSettings(update.toMap());
    return UserSettings.fromMap(data);
  }

  /// Upgrade to premium
  static Future<void> upgradeToPremium() async {
    await NarraSupabaseClient.updateUserProfile({
      'plan_type': 'premium',
      'plan_expires_at': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
    });
  }

  /// Check if user has premium
  static Future<bool> isPremium() async {
    final profile = await getCurrentProfile();
    if (profile == null) return false;
    
    if (profile.planType != PlanType.premium) return false;
    
    if (profile.planExpiresAt != null) {
      return profile.planExpiresAt!.isAfter(DateTime.now());
    }
    
    return false;
  }
}

/// User profile data model
class UserProfile {
  final String id;
  final String name;
  final String email;
  final DateTime? birthDate;
  final String? phone;
  final String? location;
  final String? bio;
  final String? avatarUrl;
  final PlanType planType;
  final DateTime? planExpiresAt;
  final WritingTone writingTone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.birthDate,
    this.phone,
    this.location,
    this.bio,
    this.avatarUrl,
    required this.planType,
    this.planExpiresAt,
    required this.writingTone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      birthDate: map['birth_date'] != null 
          ? DateTime.parse(map['birth_date']) 
          : null,
      phone: map['phone'] as String?,
      location: map['location'] as String?,
      bio: map['bio'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      planType: PlanType.values.firstWhere(
        (p) => p.name == map['plan_type'],
        orElse: () => PlanType.free,
      ),
      planExpiresAt: map['plan_expires_at'] != null
          ? DateTime.parse(map['plan_expires_at'])
          : null,
      writingTone: WritingTone.values.firstWhere(
        (t) => t.name == map['writing_tone'],
        orElse: () => WritingTone.warm,
      ),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'birth_date': birthDate?.toIso8601String(),
      'phone': phone,
      'location': location,
      'bio': bio,
      'avatar_url': avatarUrl,
      'plan_type': planType.name,
      'plan_expires_at': planExpiresAt?.toIso8601String(),
      'writing_tone': writingTone.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// User profile update model
class UserProfileUpdate {
  final String? name;
  final DateTime? birthDate;
  final String? phone;
  final String? location;
  final String? bio;
  final String? avatarUrl;
  final WritingTone? writingTone;

  const UserProfileUpdate({
    this.name,
    this.birthDate,
    this.phone,
    this.location,
    this.bio,
    this.avatarUrl,
    this.writingTone,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (name != null) map['name'] = name;
    if (birthDate != null) map['birth_date'] = birthDate!.toIso8601String();
    if (phone != null) map['phone'] = phone;
    if (location != null) map['location'] = location;
    if (bio != null) map['bio'] = bio;
    if (avatarUrl != null) map['avatar_url'] = avatarUrl;
    if (writingTone != null) map['writing_tone'] = writingTone!.name;
    
    return map;
  }
}

/// User settings data model
class UserSettings {
  final String id;
  final String userId;
  final bool autoSave;
  final bool notificationStories;
  final bool notificationReminders;
  final bool sharingEnabled;
  final String language;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserSettings({
    required this.id,
    required this.userId,
    required this.autoSave,
    required this.notificationStories,
    required this.notificationReminders,
    required this.sharingEnabled,
    required this.language,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      autoSave: map['auto_save'] as bool? ?? true,
      notificationStories: map['notification_stories'] as bool? ?? true,
      notificationReminders: map['notification_reminders'] as bool? ?? true,
      sharingEnabled: map['sharing_enabled'] as bool? ?? false,
      language: map['language'] as String? ?? 'es',
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'auto_save': autoSave,
      'notification_stories': notificationStories,
      'notification_reminders': notificationReminders,
      'sharing_enabled': sharingEnabled,
      'language': language,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// User settings update model
class UserSettingsUpdate {
  final bool? autoSave;
  final bool? notificationStories;
  final bool? notificationReminders;
  final bool? sharingEnabled;
  final String? language;

  const UserSettingsUpdate({
    this.autoSave,
    this.notificationStories,
    this.notificationReminders,
    this.sharingEnabled,
    this.language,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (autoSave != null) map['auto_save'] = autoSave;
    if (notificationStories != null) map['notification_stories'] = notificationStories;
    if (notificationReminders != null) map['notification_reminders'] = notificationReminders;
    if (sharingEnabled != null) map['sharing_enabled'] = sharingEnabled;
    if (language != null) map['language'] = language;
    
    return map;
  }
}

/// Dashboard statistics model
class DashboardStats {
  final int totalStories;
  final int publishedStories;
  final int draftStories;
  final int totalWords;
  final int progressToBook;
  final int totalPeople;
  final int activeSubscribers;
  final int thisWeekStories;
  final List<UserActivity> recentActivity;

  const DashboardStats({
    required this.totalStories,
    required this.publishedStories,
    required this.draftStories,
    required this.totalWords,
    required this.progressToBook,
    required this.totalPeople,
    required this.activeSubscribers,
    required this.thisWeekStories,
    required this.recentActivity,
  });

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    return DashboardStats(
      totalStories: map['total_stories'] as int? ?? 0,
      publishedStories: map['published_stories'] as int? ?? 0,
      draftStories: map['draft_stories'] as int? ?? 0,
      totalWords: map['total_words'] as int? ?? 0,
      progressToBook: map['progress_to_book'] as int? ?? 0,
      totalPeople: map['total_people'] as int? ?? 0,
      activeSubscribers: map['active_subscribers'] as int? ?? 0,
      thisWeekStories: map['this_week_stories'] as int? ?? 0,
      recentActivity: map['recent_activity'] != null
          ? (map['recent_activity'] as List)
              .map((item) => UserActivity.fromMap(item))
              .toList()
          : [],
    );
  }
}

/// User activity model
class UserActivity {
  final String id;
  final String userId;
  final ActivityType activityType;
  final String? entityId;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const UserActivity({
    required this.id,
    required this.userId,
    required this.activityType,
    this.entityId,
    this.metadata,
    required this.createdAt,
  });

  factory UserActivity.fromMap(Map<String, dynamic> map) {
    return UserActivity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      activityType: ActivityType.values.firstWhere(
        (a) => a.name == map['activity_type'],
        orElse: () => ActivityType.storyCreated,
      ),
      entityId: map['entity_id'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  String get displayMessage {
    switch (activityType) {
      case ActivityType.storyCreated:
        return 'Nueva historia creada';
      case ActivityType.storyUpdated:
        return 'Historia actualizada';
      case ActivityType.storyPublished:
        return 'Historia publicada';
      case ActivityType.photoAdded:
        return 'Foto añadida a historia';
      case ActivityType.personAdded:
        return 'Nueva persona agregada';
      case ActivityType.voiceRecorded:
        return 'Audio grabado para historia';
      case ActivityType.storyShared:
        return 'Historia compartida';
    }
  }
}

/// Plan type enumeration
enum PlanType {
  free,
  premium;

  String get displayName {
    switch (this) {
      case PlanType.free:
        return 'Gratuito';
      case PlanType.premium:
        return 'Premium';
    }
  }
}

/// Writing tone enumeration
enum WritingTone {
  formal,
  warm,
  nostalgic,
  humorous;

  String get displayName {
    switch (this) {
      case WritingTone.formal:
        return 'Formal';
      case WritingTone.warm:
        return 'Cálido';
      case WritingTone.nostalgic:
        return 'Nostálgico';
      case WritingTone.humorous:
        return 'Divertido';
    }
  }
}

/// Activity type enumeration
enum ActivityType {
  storyCreated,
  storyUpdated,
  storyPublished,
  photoAdded,
  personAdded,
  voiceRecorded,
  storyShared;
}