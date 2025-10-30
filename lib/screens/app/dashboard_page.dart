import 'package:flutter/material.dart';
import 'package:narra/api/narra_api.dart';
import 'package:narra/repositories/user_repository.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/services/subscriber_service.dart';
import 'dart:math' as math;
import 'story_editor_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _dashboardStats;
  List<Story> _draftStories = [];
  List<StoryTag> _allTags = [];
  SubscriberDashboardData? _subscriberDashboard;
  Story? _lastPublishedStory;
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
      final allStories = await StoryServiceNew.getStories();
      final draftStories = allStories.where((s) => s.isDraft).toList();
      final allTags = await NarraAPI.getTags();
      final subscriberDashboard = await SubscriberService.getDashboardData(
        recentCommentLimit: 10,
        recentReactionLimit: 10,
      );

      // Get last published story
      final publishedStories = allStories
          .where((s) => s.isPublished)
          .toList()
        ..sort((a, b) => (b.publishedAt ?? b.updatedAt)
            .compareTo(a.publishedAt ?? a.updatedAt));
      final lastPublished = publishedStories.isNotEmpty ? publishedStories.first : null;

      if (mounted) {
        setState(() {
          _userProfile = profile?.toMap();
          _dashboardStats = {
            'total_stories': dashboardStats.totalStories,
            'published_stories': dashboardStats.publishedStories,
            'draft_stories': dashboardStats.draftStories,
            'total_words': dashboardStats.totalWords,
            'progress_to_book': dashboardStats.progressToBook,
            'active_subscribers': dashboardStats.activeSubscribers,
            'this_week_stories': dashboardStats.thisWeekStories,
            'recent_activity': dashboardStats.recentActivity
          };
          _draftStories = draftStories;
          _allTags = allTags;
          _subscriberDashboard = subscriberDashboard;
          _lastPublishedStory = lastPublished;
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header consistente con otras páginas
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Inicio',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tu centro de control para crear historias memorables.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _loadDashboardData,
                          tooltip: 'Actualizar',
                          icon: const Icon(Icons.refresh_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.08),
                            foregroundColor: colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sección de bienvenida mejorada
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WelcomeSection(
                  userProfile: _userProfile,
                  allTags: _allTags,
                  draftStories: _draftStories,
                  stats: _dashboardStats,
                ),
              ),

              const SizedBox(height: 16),

              // Sección de borradores (si hay)
              if (_draftStories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DraftsSection(
                    draftStories: _draftStories,
                    onRefresh: _loadDashboardData,
                  ),
                ),

              if (_draftStories.isNotEmpty) const SizedBox(height: 16),

              // Progreso hacia el libro
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _BookProgressSection(
                  stats: _dashboardStats,
                  lastPublishedStory: _lastPublishedStory,
                ),
              ),

              const SizedBox(height: 16),

              // Actividades recientes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RecentActivitiesSection(
                  activity: _dashboardStats?['recent_activity'] ?? [],
                  subscriberDashboard: _subscriberDashboard,
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sección de bienvenida mejorada con sugerencias
class _WelcomeSection extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<StoryTag> allTags;
  final List<Story> draftStories;
  final Map<String, dynamic>? stats;

  const _WelcomeSection({
    required this.userProfile,
    required this.allTags,
    required this.draftStories,
    required this.stats,
  });

  List<String> _getSuggestedTopics() {
    // Obtener etiquetas usadas en historias existentes
    final usedTags = allTags.map((t) => t.name.toLowerCase()).toSet();

    // Lista de temas sugeridos comunes
    const commonTopics = [
      'Familia',
      'Viajes',
      'Infancia',
      'Amigos',
      'Trabajo',
      'Mascotas',
      'Hobbies',
      'Logros',
      'Aventuras',
      'Momentos especiales',
      'Aprendizajes',
      'Celebraciones',
      'Naturaleza',
      'Arte',
      'Música',
      'Comida',
      'Deportes',
      'Tradiciones',
      'Sueños',
      'Reflexiones',
    ];

    // Filtrar temas que no se han usado
    final unusedTopics = commonTopics
        .where((topic) => !usedTags.contains(topic.toLowerCase()))
        .toList();

    // Mezclar y tomar 3 aleatorios
    unusedTopics.shuffle();
    return unusedTopics.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userName = userProfile?['name']?.split(' ').first ?? 'Usuario';
    final hasDrafts = draftStories.isNotEmpty;
    final totalStories = stats?['total_stories'] ?? 0;
    final suggestedTopics = _getSuggestedTopics();

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola $userName! 👋',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalStories == 0
                            ? '¡Es momento de crear tu primera historia!'
                            : hasDrafts
                                ? 'Tienes ${draftStories.length} borrador${draftStories.length > 1 ? 'es' : ''} esperando'
                                : '¿Qué historia contarás hoy?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (suggestedTopics.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                '💡 Temas que podrías explorar:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedTopics.map((topic) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      topic,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const StoryEditorPage(),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Nueva historia'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonal(
                  onPressed: () => _openEditorWithSuggestions(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Icon(Icons.lightbulb_outline, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openEditorWithSuggestions(BuildContext context) {
    // TODO: Implementar apertura del editor con el modal de sugerencias abierto
    // Por ahora simplemente abrimos el editor
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryEditorPage(),
      ),
    );
  }
}

/// Sección de borradores
class _DraftsSection extends StatelessWidget {
  final List<Story> draftStories;
  final VoidCallback onRefresh;

  const _DraftsSection({
    required this.draftStories,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayDrafts = draftStories.take(3).toList();

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: colorScheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borradores',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${draftStories.length} historia${draftStories.length > 1 ? 's' : ''} en progreso',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...displayDrafts.map((draft) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DraftCard(
                  draft: draft,
                  onRefresh: onRefresh,
                ),
              );
            }),
            if (draftStories.length > 3) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Navegar a la pestaña de borradores en Historias
                    DefaultTabController.of(context)?.animateTo(1);
                  },
                  child: Text(
                    'Ver todos los borradores (${draftStories.length})',
                    style: TextStyle(
                      color: colorScheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  final Story draft;
  final VoidCallback onRefresh;

  const _DraftCard({
    required this.draft,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeAgo = _getTimeAgo(draft.updatedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoryEditorPage(storyId: draft.id),
            ),
          );
          onRefresh();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit,
                  size: 20,
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isEmpty ? 'Sin título' : draft.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Editado $timeAgo',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'ahora';
    }
  }
}

/// Sección de progreso hacia el libro
class _BookProgressSection extends StatelessWidget {
  final Map<String, dynamic>? stats;
  final Story? lastPublishedStory;

  const _BookProgressSection({
    required this.stats,
    required this.lastPublishedStory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final publishedStories = stats?['published_stories'] ?? 0;
    const requiredStories = 20;
    final progress = (publishedStories / requiredStories).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: colorScheme.tertiary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: colorScheme.tertiary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso hacia tu libro',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$publishedStories de $requiredStories historias',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.tertiary),
              ),
            ),
            const SizedBox(height: 16),
            if (lastPublishedStory != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: colorScheme.tertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Última publicada: "${lastPublishedStory!.title}"',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () {
                  // Navegar a la pestaña de publicadas en Historias
                  DefaultTabController.of(context)?.animateTo(2);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: colorScheme.onTertiary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Ver historias publicadas'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sección de actividades recientes
class _RecentActivitiesSection extends StatelessWidget {
  final List<dynamic> activity;
  final SubscriberDashboardData? subscriberDashboard;

  const _RecentActivitiesSection({
    required this.activity,
    required this.subscriberDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Combinar todas las actividades
    final activities = <_ActivityItem>[];

    // Agregar actividades del autor
    for (final act in activity.take(5)) {
      if (act is UserActivity) {
        activities.add(_ActivityItem(
          icon: _getActivityIcon(act.activityType.name),
          title: act.displayMessage,
          subtitle: _formatTimeAgo(act.createdAt),
          color: colorScheme.primary,
          date: act.createdAt,
        ));
      }
    }

    // Agregar comentarios de suscriptores
    if (subscriberDashboard != null) {
      for (final comment in subscriberDashboard!.recentComments.take(3)) {
        activities.add(_ActivityItem(
          icon: Icons.chat_bubble,
          title: '${comment.subscriberName ?? 'Suscriptor'} comentó',
          subtitle: _truncate(comment.content, maxLength: 60),
          color: colorScheme.secondary,
          date: comment.createdAt,
        ));
      }

      // Agregar reacciones de suscriptores
      for (final reaction in subscriberDashboard!.recentReactions.take(3)) {
        activities.add(_ActivityItem(
          icon: Icons.favorite,
          title: '${reaction.subscriberName ?? 'Suscriptor'} dio corazón',
          subtitle: 'En "${reaction.storyTitle}"',
          color: Colors.red,
          date: reaction.createdAt,
        ));
      }

      // Agregar suscriptores recién confirmados
      final recentConfirmed = subscriberDashboard!.subscribers
          .where((s) => s.status == 'confirmed' && s.lastAccessAt != null)
          .toList()
        ..sort((a, b) => b.lastAccessAt!.compareTo(a.lastAccessAt!));

      for (final subscriber in recentConfirmed.take(2)) {
        activities.add(_ActivityItem(
          icon: Icons.person_add,
          title: '${subscriber.name} se unió',
          subtitle: 'Nuevo suscriptor confirmado',
          color: colorScheme.tertiary,
          date: subscriber.lastAccessAt!,
        ));
      }
    }

    // Ordenar por fecha y tomar las últimas 6
    activities.sort((a, b) => b.date.compareTo(a.date));
    final displayActivities = activities.take(6).toList();

    if (displayActivities.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.notifications_none,
                size: 64,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No hay actividad reciente',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Las publicaciones, reacciones y comentarios aparecerán aquí',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.timeline,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Actividades recientes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...displayActivities.map((activity) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: activity.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        activity.icon,
                        size: 20,
                        color: activity.color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (activity.subtitle.isNotEmpty)
                            Text(
                              activity.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'story_created':
      case 'storyCreated':
        return Icons.add_circle;
      case 'story_updated':
      case 'storyUpdated':
        return Icons.edit;
      case 'story_published':
      case 'storyPublished':
        return Icons.publish;
      case 'photo_added':
      case 'photoAdded':
        return Icons.photo;
      case 'voice_recorded':
      case 'voiceRecorded':
        return Icons.mic;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimeAgo(DateTime date) {
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

  String _truncate(String text, {int maxLength = 60}) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final DateTime date;

  _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.date,
  });
}
