import 'package:narra/repositories/auth_repository.dart';
import 'package:narra/repositories/user_repository.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/supabase/narra_client.dart';
import 'package:narra/openai/openai_service.dart';

/// Main API client for the Narra application
/// Provides a unified interface for all backend operations
class NarraAPI {
  // ================================
  // AUTHENTICATION
  // ================================

  /// Sign up new user
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? location,
  }) async {
    return AuthRepository.signUp(
      email: email,
      password: password,
      name: name,
      phone: phone,
      location: location,
    );
  }

  /// Sign in user
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    return AuthRepository.signIn(email: email, password: password);
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await AuthRepository.signOut();
  }

  /// Get current authenticated user
  static AuthUser? get currentUser => AuthRepository.currentUser;

  /// Check if user is authenticated
  static bool get isAuthenticated => AuthRepository.isAuthenticated;

  /// Listen to auth state changes
  static Stream<AuthUser?> get authStateChanges => AuthRepository.authStateChanges;

  // ================================
  // USER PROFILE & SETTINGS
  // ================================

  /// Get current user profile
  static Future<UserProfile?> getUserProfile() async {
    return UserRepository.getCurrentProfile();
  }

  /// Update user profile
  static Future<UserProfile> updateUserProfile(UserProfileUpdate update) async {
    return UserRepository.updateProfile(update);
  }

  /// Get user settings
  static Future<UserSettings?> getUserSettings() async {
    return UserRepository.getSettings();
  }

  /// Update user settings
  static Future<UserSettings> updateUserSettings(UserSettingsUpdate update) async {
    return UserRepository.updateSettings(update);
  }

  /// Get current user profile
  static Future<UserProfile?> getCurrentUserProfile() async {
    return UserRepository.getCurrentProfile();
  }

  /// Get dashboard statistics
  static Future<DashboardStats> getDashboardStats() async {
    return UserRepository.getDashboardStats();
  }

  /// Upgrade to premium
  static Future<void> upgradeToPremium() async {
    await UserRepository.upgradeToPremium();
  }

  /// Check if user has premium
  static Future<bool> isPremiumUser() async {
    return UserRepository.isPremium();
  }

  /// Delete user account
  static Future<void> deleteUserAccount() async {
    await UserRepository.deleteAccount();
  }

  // ================================
  // STORIES
  // ================================

  /// Get all user stories
  static Future<List<Story>> getStories({
    StoryStatus? status,
    String? searchQuery,
    List<String>? tagIds,
    int? limit,
    int? offset,
  }) async {
    return StoryRepository.getStories(
      status: status,
      searchQuery: searchQuery,
      tagIds: tagIds,
      limit: limit,
      offset: offset,
    );
  }

  /// Get story by ID
  static Future<Story?> getStoryById(String id) async {
    return StoryRepository.getStoryById(id);
  }

  /// Create new story
  static Future<Story> createStory({
    required String title,
    String content = '',
    String status = 'draft',
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
    String? datesPrecision,
    DateTime? storyDate,
    String? storyDateText,
    String? location,
    bool isVoiceGenerated = false,
    String? voiceTranscript,
  }) async {
    final storyStatus = status == 'published' ? StoryStatus.published : StoryStatus.draft;
    
    return StoryRepository.createStory(
      title: title,
      content: content,
      status: storyStatus,
      storyDate: storyDate,
      storyDateText: storyDateText,
      location: location,
      isVoiceGenerated: isVoiceGenerated,
      voiceTranscript: voiceTranscript,
    );
  }

  /// Update story
  static Future<Story> updateStory(String id, StoryUpdate update) async {
    return StoryRepository.updateStory(id, update);
  }

  /// Delete story
  static Future<void> deleteStory(String id) async {
    await StoryRepository.deleteStory(id);
  }

  /// Publish story
  static Future<Story> publishStory(String id) async {
    return StoryRepository.publishStory(id);
  }

  /// Unpublish story (convert back to draft)
  static Future<Story> unpublishStory(String id) async {
    return StoryRepository.unpublishStory(id);
  }

  /// Add photo to story
  static Future<StoryPhoto> addPhotoToStory(
    String storyId,
    String photoUrl, {
    String? caption,
    int? position,
  }) async {
    return StoryRepository.addPhoto(
      storyId,
      photoUrl,
      caption: caption,
      position: position,
    );
  }

  /// Remove photo from story
  static Future<void> removePhotoFromStory(String photoId) async {
    await StoryRepository.removePhoto(photoId);
  }

  // ================================
  // TAGS
  // ================================

  /// Get all user tags
  static Future<List<StoryTag>> getTags() async {
    final data = await NarraSupabaseClient.getUserTags();
    return data.map((item) => StoryTag.fromMap(item)).toList();
  }

  /// Create new tag
  static Future<StoryTag> createTag({
    required String name,
    String color = '#3498db',
  }) async {
    final data = await NarraSupabaseClient.createTag(name: name, color: color);
    return StoryTag.fromMap(data);
  }

  /// Update tag
  static Future<StoryTag> updateTag(String tagId, Map<String, dynamic> updates) async {
    final data = await NarraSupabaseClient.updateTag(tagId, updates);
    return StoryTag.fromMap(data);
  }

  /// Delete tag
  static Future<void> deleteTag(String tagId) async {
    await NarraSupabaseClient.deleteTag(tagId);
  }

  /// Add tag to story
  static Future<void> addTagToStory(String storyId, String tagId) async {
    await StoryRepository.addTag(storyId, tagId);
  }

  /// Remove tag from story
  static Future<void> removeTagFromStory(String storyId, String tagId) async {
    await StoryRepository.removeTag(storyId, tagId);
  }

  // ================================
  // SUBSCRIBERS
  // ================================

  /// Get all user subscribers
  static Future<List<Subscriber>> getSubscribers() async {
    final data = await NarraSupabaseClient.getUserSubscribers();
    return data.map((item) => Subscriber.fromMap(item)).toList();
  }

  /// Add subscriber
  static Future<Subscriber> addSubscriber({
    required String name,
    required String email,
    String? phone,
    String? relationship,
  }) async {
    final data = await NarraSupabaseClient.addSubscriber(
      name: name,
      email: email,
      phone: phone,
      relationship: relationship,
    );
    return Subscriber.fromMap(data);
  }

  /// Update subscriber
  static Future<Subscriber> updateSubscriber(
    String subscriberId,
    Map<String, dynamic> updates,
  ) async {
    final data = await NarraSupabaseClient.updateSubscriber(subscriberId, updates);
    return Subscriber.fromMap(data);
  }

  /// Delete subscriber
  static Future<void> deleteSubscriber(String subscriberId) async {
    await NarraSupabaseClient.deleteSubscriber(subscriberId);
  }

  // ================================
  // AI FEATURES
  // ================================

  /// Generate story prompts/hints
  static Future<List<String>> generateStoryPrompts({
    required String context,
    required String theme,
    int count = 5,
  }) async {
    return OpenAIService.generateStoryPrompts(
      context: context,
      theme: theme,
      count: count,
    );
  }

  /// Improve story text with AI (simple version for backward compatibility)
  static Future<String> improveStoryText({
    required String originalText,
    required String writingTone,
  }) async {
    return OpenAIService.improveStoryTextSimple(
      originalText: originalText,
      writingTone: writingTone,
    );
  }

  /// Improve story text with AI (advanced version with full configuration)
  static Future<Map<String, dynamic>> improveStoryTextAdvanced({
    required String originalText,
    String? sttText,
    String? currentDraft,
    String language = 'es',
    String tone = 'warm',
    String person = 'first',
    String fidelity = 'balanced',
    String profanity = 'soften',
    String readingLevel = 'plain',
    String lengthTarget = 'keep',
    String formatting = 'clean paragraphs',
    bool keepMarkers = true,
    bool anonymizePrivate = false,
    List<String> forbiddenPhrases = const [],
    List<String> privatePeople = const [],
    List<String> tags = const [],
    String? dateRange,
    String? authorProfile,
    String? styleHints,
    String outputFormat = 'json',
    int? targetWords,
  }) async {
    return OpenAIService.improveStoryTextAdvanced(
      originalText: originalText,
      sttText: sttText,
      currentDraft: currentDraft,
      language: language,
      tone: tone,
      person: person,
      fidelity: fidelity,
      profanity: profanity,
      readingLevel: readingLevel,
      lengthTarget: lengthTarget,
      formatting: formatting,
      keepMarkers: keepMarkers,
      anonymizePrivate: anonymizePrivate,
      forbiddenPhrases: forbiddenPhrases,
      privatePeople: privatePeople,
      tags: tags,
      dateRange: dateRange,
      authorProfile: authorProfile,
      styleHints: styleHints,
      outputFormat: outputFormat,
      targetWords: targetWords,
    );
  }

  /// Evaluate story completeness
  static Future<Map<String, dynamic>> evaluateStoryCompleteness({
    required String storyText,
    required String title,
  }) async {
    return OpenAIService.evaluateStoryCompleteness(
      storyText: storyText,
      title: title,
    );
  }

  /// Generate title suggestions
  static Future<List<String>> generateTitleSuggestions({
    required String storyContent,
    int count = 5,
  }) async {
    return OpenAIService.generateTitleSuggestions(
      storyContent: storyContent,
      count: count,
    );
  }

  // ================================
  // UTILITY METHODS
  // ================================

  /// Get app version and status
  static Map<String, dynamic> getAppInfo() {
    return {
      'version': '1.0.0',
      'build': '1',
      'status': 'active',
      'features': {
        'ai_assistance': true,
        'voice_recording': true,
        'photo_upload': true,
        'pdf_export': true,
        'subscriber_sharing': true,
      },
      'limits': {
        'free': {
          'stories_per_month': 10,
          'photos_per_story': 3,
          'subscribers': 5,
        },
        'premium': {
          'stories_per_month': -1, // unlimited
          'photos_per_story': 8,
          'subscribers': -1, // unlimited
        },
      },
    };
  }

  /// Check feature availability for current user
  static Future<bool> isFeatureAvailable(String feature) async {
    final isPremium = await isPremiumUser();
    
    switch (feature) {
      case 'unlimited_stories':
      case 'voice_transcription':
      case 'advanced_ai':
      case 'pdf_export':
      case 'unlimited_subscribers':
        return isPremium;
      case 'basic_stories':
      case 'photo_upload':
      case 'basic_ai':
      case 'basic_sharing':
        return true;
      default:
        return false;
    }
  }

  /// Get feature limits for current user
  static Future<Map<String, int>> getFeatureLimits() async {
    final isPremium = await isPremiumUser();
    
    if (isPremium) {
      return {
        'stories_per_month': -1, // unlimited
        'photos_per_story': 8,
        'subscribers': -1, // unlimited
        'ai_requests_per_day': 100,
      };
    } else {
      return {
        'stories_per_month': 10,
        'photos_per_story': 3,
        'subscribers': 5,
        'ai_requests_per_day': 10,
      };
    }
  }

  /// Initialize the API (should be called once at app startup)
  static Future<void> initialize() async {
    // Any initialization logic here
    // For example, setting up analytics, crash reporting, etc.
  }

  /// Cleanup resources
  static Future<void> dispose() async {
    // Cleanup logic here
  }
}

/// Subscriber data model
class Subscriber {
  final String id;
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final String? relationship;
  final SubscriberStatus status;
  final DateTime? lastSentAt;
  final DateTime createdAt;

  const Subscriber({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.relationship,
    required this.status,
    this.lastSentAt,
    required this.createdAt,
  });

  factory Subscriber.fromMap(Map<String, dynamic> map) {
    return Subscriber(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String?,
      relationship: map['relationship'] as String?,
      status: SubscriberStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => SubscriberStatus.pending,
      ),
      lastSentAt: map['last_sent_at'] != null 
          ? DateTime.parse(map['last_sent_at'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'relationship': relationship,
      'status': status.name,
      'last_sent_at': lastSentAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Subscriber status enumeration
enum SubscriberStatus {
  pending,
  confirmed,
  unsubscribed;

  String get displayName {
    switch (this) {
      case SubscriberStatus.pending:
        return 'Pendiente';
      case SubscriberStatus.confirmed:
        return 'Confirmado';
      case SubscriberStatus.unsubscribed:
        return 'Desuscrito';
    }
  }
}