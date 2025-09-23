import 'package:flutter/material.dart';
import 'package:narra/api/narra_api.dart';
import 'package:narra/repositories/user_repository.dart';
import 'package:narra/services/story_service_new.dart';
import 'story_editor_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _dashboardStats;
  List<Map<String, dynamic>> _recentStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final profile = await NarraAPI.getCurrentUserProfile();
      final dashboardStats = await NarraAPI.getDashboardStats();
      final recentStories = await StoryServiceNew.getRecentStories(limit: 3);
      
      if (mounted) {
        setState(() {
          _userProfile = profile?.toMap();
          _dashboardStats = {
            'total_stories': dashboardStats.totalStories,
            'published_stories': dashboardStats.publishedStories,
            'draft_stories': dashboardStats.draftStories,
            'total_words': dashboardStats.totalWords,
            'progress_to_book': dashboardStats.progressToBook,
            'total_people': dashboardStats.totalPeople,
            'active_subscribers': dashboardStats.activeSubscribers,
            'this_week_stories': dashboardStats.thisWeekStories,
            'recent_activity': dashboardStats.recentActivity
          };
          _recentStories = recentStories.map((story) => story.toMap()).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Dashboard'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola ${_userProfile?['name']?.split(' ').first ?? 'Usuario'}! 👋',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Es hora de contar una nueva historia',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoryEditorPage(),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Nueva historia'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Progress to Book
            BookProgressCard(stats: _dashboardStats),
            const SizedBox(height: 24),
            
            // Recent Stories
            Text(
              'Historias recientes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            RecentStoriesSection(stories: _recentStories),
            const SizedBox(height: 24),
            
            // Recent Activity
            Text(
              'Actividad reciente',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            RecentActivitySection(activity: _dashboardStats?['recent_activity'] ?? []),
          ],
        ),
      ),
    );
  }
}

class BookProgressCard extends StatelessWidget {
  final Map<String, dynamic>? stats;
  
  const BookProgressCard({super.key, this.stats});

  @override
  Widget build(BuildContext context) {
    final currentStories = stats?['published_stories'] ?? 0;
    const requiredStories = 20;
    final progress = currentStories / requiredStories;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.book,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Progreso hacia tu libro',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$currentStories de $requiredStories historias',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Text(
              'Necesitas ${requiredStories - currentStories} historias más para crear tu libro automáticamente.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            
            if (currentStories >= requiredStories) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StoryEditorPage(),
                    ),
                  ),
                  icon: const Icon(Icons.auto_stories, color: Colors.white),
                  label: const Text('Crear mi libro'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class RecentStoriesSection extends StatelessWidget {
  final List<Map<String, dynamic>> stories;
  
  const RecentStoriesSection({super.key, required this.stories});

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.library_books,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay historias aún',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comienza creando tu primera historia',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const StoryEditorPage(),
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Crear primera historia'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: stories.map((story) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: StoryCard(
          storyId: story['id']?.toString() ?? '',
          title: story['title']?.toString() ?? 'Historia sin título',
          status: story['status'] == 'published' ? 'Publicada' : 'Borrador',
          date: _formatDate(story['created_at']?.toString() ?? DateTime.now().toIso8601String()),
          reactions: story['reactions'] as int? ?? 0,
          isPublished: story['status'] == 'published',
        ),
      )).toList(),
    );
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date).inDays;
      
      if (difference == 0) {
        return 'Hoy';
      } else if (difference == 1) {
        return 'Ayer';
      } else if (difference < 7) {
        return 'Hace $difference días';
      } else {
        final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                       'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
        return '${date.day} ${months[date.month - 1]}';
      }
    } catch (e) {
      return 'Fecha inválida';
    }
  }
}

class StoryCard extends StatelessWidget {
  final String storyId;
  final String title;
  final String status;
  final String date;
  final int reactions;
  final bool isPublished;

  const StoryCard({
    super.key,
    required this.storyId,
    required this.title,
    required this.status,
    required this.date,
    required this.reactions,
    required this.isPublished,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isPublished
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPublished ? Icons.public : Icons.drafts,
            color: isPublished
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Row(
          children: [
            Text(status),
            const Text(' • '),
            Text(date),
            if (isPublished && reactions > 0) ...[
              const Text(' • '),
              Icon(
                Icons.favorite,
                size: 16,
                color: Colors.red,
              ),
              const SizedBox(width: 4),
              Text('$reactions'),
            ],
          ],
        ),
        trailing: IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryEditorPage(storyId: storyId),
            ),
          ),
          icon: const Icon(Icons.edit),
        ),
      ),
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  final List<dynamic> activity;
  
  const RecentActivitySection({super.key, required this.activity});

  String _getActivityMessage(Map<String, dynamic> activity) {
    final type = activity['activity_type'] as String;
    switch (type) {
      case 'story_created':
        return 'Nueva historia creada';
      case 'story_updated':
        return 'Historia actualizada';
      case 'story_published':
        return 'Historia publicada';
      case 'photo_added':
        return 'Foto añadida a historia';
      case 'person_added':
        return 'Nueva persona agregada';
      case 'voice_recorded':
        return 'Audio grabado para historia';
      default:
        return 'Nueva actividad';
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'story_created':
        return Icons.add_circle;
      case 'story_updated':
        return Icons.edit;
      case 'story_published':
        return Icons.publish;
      case 'photo_added':
        return Icons.photo;
      case 'person_added':
        return Icons.person_add;
      case 'voice_recorded':
        return Icons.mic;
      default:
        return Icons.notifications;
    }
  }

  String _getTimeAgo(String dateTime) {
    final date = DateTime.parse(dateTime);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.notifications_none,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No hay actividad reciente',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: activity.take(5).map<Widget>((activityItem) {
          final item = activityItem as Map<String, dynamic>;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                _getActivityIcon(item['activity_type']),
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(
              _getActivityMessage(item),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              _getTimeAgo(item['created_at']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }).toList(),
      ),
    );
  }
}