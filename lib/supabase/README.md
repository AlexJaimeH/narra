# Narra Supabase Client Documentation

This directory contains the complete Supabase client implementation for the Narra storytelling application. The architecture follows clean code principles with separation of concerns and type-safe operations.

## Architecture Overview

```
lib/
├── api/
│   └── narra_api.dart          # Main API client (unified interface)
├── repositories/
│   ├── auth_repository.dart    # Authentication operations
│   ├── user_repository.dart    # User profile and settings
│   └── story_repository.dart   # Story management
├── services/
│   └── story_service_new.dart  # Enhanced story service layer
├── supabase/
│   ├── supabase_config.dart    # Basic Supabase configuration
│   ├── narra_client.dart       # Enhanced Supabase client
│   ├── supabase_tables.sql     # Database schema
│   └── supabase_policies.sql   # Row Level Security policies
└── openai/
    └── openai_config.dart      # AI integration
```

## Key Components

### 1. NarraAPI (`lib/api/narra_api.dart`)
**Main entry point for all backend operations**

```dart
// Authentication
final result = await NarraAPI.signUp(
  email: 'user@example.com',
  password: 'password123',
  name: 'John Doe',
);

// Stories
final stories = await NarraAPI.getStories(
  status: StoryStatus.published,
  limit: 10,
);

// AI Features
final prompts = await NarraAPI.generateStoryPrompts(
  context: 'childhood memories',
  theme: 'family',
);
```

### 2. NarraSupabaseClient (`lib/supabase/narra_client.dart`)
**Enhanced Supabase client with Narra-specific methods**

Features:
- ✅ Type-safe database operations
- ✅ Automatic error handling
- ✅ Built-in security checks
- ✅ Activity logging
- ✅ Relationship management

```dart
// Create story with automatic word counting and activity logging
final story = await NarraSupabaseClient.createStory(
  title: 'My First Day at School',
  content: 'It was a sunny September morning...',
  location: 'Madrid, Spain',
);

// Get stories with related data (tags, photos, people)
final stories = await NarraSupabaseClient.getUserStories();
```

### 3. Repository Layer
**Clean abstraction over database operations**

#### AuthRepository
- User registration and login
- Password management
- Session handling
- Error translation to user-friendly messages

#### UserRepository  
- Profile management
- Settings persistence
- Dashboard statistics
- Premium upgrade handling

#### StoryRepository
- CRUD operations for stories
- Media management (photos)
- Tagging system
- People association

### 4. Enhanced Story Service
**Business logic layer with advanced features**

```dart
// AI-powered story improvement
final improvedText = await StoryServiceNew.improveStoryWithAI(storyId);

// Get story completeness evaluation
final evaluation = await StoryServiceNew.evaluateStory(storyId);
if (evaluation.isComplete) {
  print('Story is ready to publish!');
}

// Bulk operations
await StoryServiceNew.bulkUpdateStatus(
  ['story1', 'story2'], 
  StoryStatus.published,
);
```

## Database Schema

The application uses 10 main tables with proper relationships:

### Core Tables
- **users** - User profiles and settings
- **stories** - Main content with metadata
- **story_photos** - Photo attachments
- **tags** - User-defined categories
- **people** - Character management
- **subscribers** - Sharing recipients

### Relationship Tables
- **story_tags** - Many-to-many story-tag relationships
- **story_people** - Many-to-many story-people relationships
- **user_settings** - User preferences
- **user_activity** - Activity tracking

### Key Features
- ✅ **Row Level Security (RLS)** - Users can only access their own data
- ✅ **Cascading Deletes** - Proper cleanup when records are deleted
- ✅ **Automatic Timestamps** - Created/updated tracking
- ✅ **UUID Primary Keys** - Secure, non-sequential IDs
- ✅ **Proper Indexing** - Optimized for common queries

## Usage Examples

### Complete User Flow

```dart
// 1. User Registration
final authResult = await NarraAPI.signUp(
  email: 'maria@example.com',
  password: 'securePassword',
  name: 'María García',
);

if (authResult.isSuccess) {
  // 2. Create First Story
  final story = await NarraAPI.createStory(
    title: 'Mi infancia en el pueblo',
    content: 'Recuerdo cuando tenía 8 años...',
    storyDate: DateTime(1975, 6, 15),
    location: 'Salamanca, España',
  );

  // 3. Add Photos
  final photo = await NarraAPI.addPhotoToStory(
    story.id,
    'https://example.com/photo.jpg',
    caption: 'Casa familiar en 1975',
  );

  // 4. Create Tags
  final familyTag = await NarraAPI.createTag(
    name: 'Familia',
    color: '#e74c3c',
  );

  // 5. Associate Tag
  await NarraAPI.addTagToStory(story.id, familyTag.id);

  // 6. Get AI Suggestions
  final prompts = await NarraAPI.generateStoryPrompts(
    context: story.content,
    theme: 'childhood',
  );

  // 7. Improve with AI
  final improvedText = await NarraAPI.improveStoryText(
    originalText: story.content,
    writingTone: 'warm',
  );

  // 8. Publish Story
  final publishedStory = await NarraAPI.publishStory(story.id);
}
```

### Dashboard Data Loading

```dart
class DashboardController {
  Future<void> loadDashboardData() async {
    // Get user profile
    final profile = await NarraAPI.getUserProfile();
    
    // Get dashboard statistics
    final stats = await NarraAPI.getDashboardStats();
    
    // Get recent stories
    final recentStories = await NarraAPI.getStories(limit: 5);
    
    // Check premium status
    final isPremium = await NarraAPI.isPremiumUser();
    
    // Update UI with loaded data
    updateUI(profile, stats, recentStories, isPremium);
  }
}
```

## Error Handling

All API methods include comprehensive error handling:

```dart
try {
  final stories = await NarraAPI.getStories();
  // Handle success
} catch (e) {
  // Handle specific errors
  if (e.toString().contains('network')) {
    showMessage('Error de conexión');
  } else if (e.toString().contains('unauthorized')) {
    showMessage('Sesión expirada');
    navigateToLogin();
  } else {
    showMessage('Error inesperado: $e');
  }
}
```

## Type Safety

All data models include:
- ✅ **Immutable classes** with const constructors
- ✅ **Factory constructors** for JSON parsing
- ✅ **toMap() methods** for serialization
- ✅ **Null safety** throughout
- ✅ **Enums for status fields**

```dart
// Type-safe story creation
const story = Story(
  id: 'uuid-here',
  title: 'My Story',
  status: StoryStatus.published, // Enum, not string
  tags: <StoryTag>[], // Strongly typed lists
  photos: <StoryPhoto>[],
  // ...
);
```

## Performance Optimizations

### Efficient Queries
- Uses `select()` with specific fields to minimize data transfer
- Implements pagination for large datasets
- Leverages database indexes for fast filtering

### Caching Strategy
```dart
// Future enhancement: Add caching layer
class CachedNarraAPI {
  static final _cache = <String, dynamic>{};
  
  static Future<List<Story>> getStories() async {
    const cacheKey = 'user_stories';
    
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }
    
    final stories = await NarraAPI.getStories();
    _cache[cacheKey] = stories;
    return stories;
  }
}
```

## Security Features

### Row Level Security
```sql
-- Users can only access their own data
CREATE POLICY "Users can view own stories" ON stories
  FOR SELECT USING (auth.uid() = user_id);
```

### Input Validation
```dart
// Validate input before database operations
static Future<Story> createStory({required String title}) async {
  if (title.trim().isEmpty) {
    throw ArgumentError('Title cannot be empty');
  }
  
  if (title.length > 200) {
    throw ArgumentError('Title too long');
  }
  
  // Proceed with creation...
}
```

## Testing Support

The architecture supports easy unit and integration testing:

```dart
// Mock the API for testing
class MockNarraAPI implements NarraAPI {
  @override
  Future<List<Story>> getStories() async {
    return [
      const Story(/* test data */),
    ];
  }
}

// Use in tests
void main() {
  testWidgets('Dashboard loads stories', (tester) async {
    // Inject mock API
    await tester.pumpWidget(MyApp(api: MockNarraAPI()));
    
    // Test UI behavior
    expect(find.text('My Test Story'), findsOneWidget);
  });
}
```

## Migration Support

For future schema changes, the client supports versioning:

```dart
class NarraSupabaseClient {
  static const int CLIENT_VERSION = 1;
  
  static Future<void> migrateIfNeeded() async {
    final currentVersion = await _getCurrentVersion();
    
    if (currentVersion < CLIENT_VERSION) {
      await _runMigrations(currentVersion, CLIENT_VERSION);
    }
  }
}
```

## Conclusion

This Supabase client implementation provides:

1. **Type Safety** - Full Dart type checking
2. **Error Resilience** - Comprehensive error handling  
3. **Performance** - Optimized queries and caching
4. **Security** - RLS and input validation
5. **Maintainability** - Clean architecture and separation of concerns
6. **Testability** - Easy mocking and testing
7. **Scalability** - Prepared for future features

The architecture allows for easy extension and modification while maintaining code quality and developer experience.