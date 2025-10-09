import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/story_service_new.dart';

import 'story_editor_page.dart';

class StoriesListPage extends StatefulWidget {
  const StoriesListPage({super.key});

  @override
  State<StoriesListPage> createState() => _StoriesListPageState();
}

class _StoriesListPageState extends State<StoriesListPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  List<Story> _allStories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStories();
  }

  Future<void> _loadStories({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final stories = await StoryServiceNew.getStories();
      if (!mounted) return;
      setState(() {
        _allStories = stories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historias: $e')),
      );
    }
  }

  Future<void> _openStoryCreator() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const StoryEditorPage(),
      ),
    );
    if (!mounted) return;
    await _loadStories(silent: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis historias',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Administra, busca y publica tus recuerdos con facilidad.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => _loadStories(silent: true),
                        tooltip: 'Actualizar historias',
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText:
                          'Buscar por título, contenido, etiquetas o personas...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                              tooltip: 'Limpiar búsqueda',
                            ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      indicator: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: colorScheme.onPrimary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      overlayColor: MaterialStatePropertyAll(
                        colorScheme.primary.withValues(alpha: 0.08),
                      ),
                      tabs: const [
                        Tab(text: 'Todas'),
                        Tab(text: 'Borradores'),
                        Tab(text: 'Publicadas'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    StoriesTab(
                      stories: _allStories,
                      filterStatus: null,
                      searchQuery: _searchQuery,
                      onRefresh: () => _loadStories(silent: true),
                      onStoriesChanged: () => _loadStories(silent: true),
                      onCreateStory: _openStoryCreator,
                    ),
                    StoriesTab(
                      stories: _allStories,
                      filterStatus: StoryStatus.draft,
                      searchQuery: _searchQuery,
                      onRefresh: () => _loadStories(silent: true),
                      onStoriesChanged: () => _loadStories(silent: true),
                      onCreateStory: _openStoryCreator,
                    ),
                    StoriesTab(
                      stories: _allStories,
                      filterStatus: StoryStatus.published,
                      searchQuery: _searchQuery,
                      onRefresh: () => _loadStories(silent: true),
                      onStoriesChanged: () => _loadStories(silent: true),
                      onCreateStory: _openStoryCreator,
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class StoriesTab extends StatelessWidget {
  const StoriesTab({
    super.key,
    required this.stories,
    required this.filterStatus,
    required this.searchQuery,
    required this.onRefresh,
    required this.onStoriesChanged,
    required this.onCreateStory,
  });

  final List<Story> stories;
  final StoryStatus? filterStatus;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final VoidCallback onStoriesChanged;
  final Future<void> Function() onCreateStory;

  @override
  Widget build(BuildContext context) {
    final filteredStories = stories.where((story) {
      final matchesFilter =
          filterStatus == null || story.status == filterStatus;
      final matchesSearch = _matchesSearch(story, searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();

    if (filteredStories.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        displacement: 80,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          children: [
            _EmptyStoriesState(
              isSearching: searchQuery.trim().isNotEmpty,
              filterStatus: filterStatus,
              onCreateStory: onCreateStory,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: 80,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        itemCount: filteredStories.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final story = filteredStories[index];
          return StoryListCard(
            story: story,
            onActionComplete: onStoriesChanged,
          );
        },
      ),
    );
  }

  static bool _matchesSearch(Story story, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final searchableFields = <String>[
      story.title,
      story.excerpt ?? '',
      story.content ?? '',
      story.voiceTranscript ?? '',
      if (story.tags != null) story.tags!.join(' '),
      if (story.people.isNotEmpty)
        story.people.map((person) => person.name).join(' '),
    ];

    final tokens =
        normalizedQuery.split(' ').where((token) => token.isNotEmpty);

    for (final token in tokens) {
      final tokenMatches = searchableFields.any(
        (field) => _fuzzyContains(field, token),
      );
      if (!tokenMatches) {
        return false;
      }
    }

    return true;
  }

  static bool _fuzzyContains(String text, String query) {
    final normalizedText = _normalize(text);
    if (normalizedText.contains(query)) {
      return true;
    }

    final words = normalizedText
        .split(RegExp(r'[^a-z0-9áéíóúüñ]+'))
        .where((word) => word.isNotEmpty);

    for (final word in words) {
      if ((word.length - query.length).abs() > 2) continue;
      if (_levenshtein(word, query) <= 2) {
        return true;
      }
    }
    return false;
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int _levenshtein(String source, String target) {
    final m = source.length;
    final n = target.length;

    if (m == 0) return n;
    if (n == 0) return m;

    final distance = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      distance[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      distance[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = source[i - 1] == target[j - 1] ? 0 : 1;
        distance[i][j] = math.min(
          math.min(
            distance[i - 1][j] + 1,
            distance[i][j - 1] + 1,
          ),
          distance[i - 1][j - 1] + cost,
        );
      }
    }

    return distance[m][n];
  }
}

class _EmptyStoriesState extends StatelessWidget {
  const _EmptyStoriesState({
    required this.isSearching,
    required this.filterStatus,
    required this.onCreateStory,
  });

  final bool isSearching;
  final StoryStatus? filterStatus;
  final Future<void> Function() onCreateStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = isSearching
        ? 'No encontramos coincidencias'
        : switch (filterStatus) {
            StoryStatus.draft => 'No tienes borradores',
            StoryStatus.published => 'Aún no publicas historias',
            _ => 'No tienes historias todavía',
          };

    final subtitle = isSearching
        ? 'Prueba con otros términos o revisa la ortografía.'
        : switch (filterStatus) {
            StoryStatus.draft =>
              'Los borradores aparecerán aquí cuando guardes tu trabajo.',
            StoryStatus.published =>
              'Publica una historia para compartirla con tu comunidad.',
            _ => 'Comienza escribiendo una nueva historia para tu colección.',
          };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.auto_awesome,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreateStory,
              icon: const Icon(Icons.add),
              label: const Text('Crear nueva historia'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StoryListCard extends StatelessWidget {
  const StoryListCard({
    super.key,
    required this.story,
    required this.onActionComplete,
  });

  final Story story;
  final VoidCallback onActionComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final coverUrl =
        story.photos.isNotEmpty ? story.photos.first.photoUrl : null;
    final tags = story.tags ??
        (story.storyTags.isNotEmpty
            ? story.storyTags.map((tag) => tag.name).toList()
            : []);
    final excerpt = story.excerpt?.trim().isNotEmpty == true
        ? story.excerpt!.trim()
        : _fallbackExcerpt(story.content);
    final statusColors = _statusColors(story.status, colorScheme);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryEditorPage(storyId: story.id),
          ),
        );
        onActionComplete();
      },
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: colorScheme.surface,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colorScheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 42,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          story.title.isEmpty ? 'Sin título' : story.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusPill(
                        label: story.status.displayName,
                        color: statusColors.foreground,
                        background: statusColors.background,
                        icon: story.status == StoryStatus.published
                            ? Icons.check_circle
                            : Icons.edit_note,
                      ),
                    ],
                  ),
                  if (excerpt.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      excerpt,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  colorScheme.secondaryContainer.withValues(
                                alpha: 0.8,
                              ),
                              labelStyle: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _MetadataBadge(
                        icon: Icons.calendar_today,
                        label: _formatDate(story.createdAt),
                      ),
                      if (story.wordCount > 0) ...[
                        const SizedBox(width: 12),
                        _MetadataBadge(
                          icon: Icons.text_snippet_outlined,
                          label: '${story.wordCount} palabras',
                        ),
                      ],
                      if (story.readingTime > 0) ...[
                        const SizedBox(width: 12),
                        _MetadataBadge(
                          icon: Icons.timer_outlined,
                          label: '${story.readingTime} min de lectura',
                        ),
                      ],
                      const Spacer(),
                      PopupMenuButton<String>(
                        tooltip: 'Mostrar opciones',
                        offset: const Offset(0, 12),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        color: colorScheme.surface,
                        onSelected: (value) =>
                            _handleStoryAction(context, value),
                        itemBuilder: (context) => _buildMenuItems(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStoryAction(
    BuildContext context,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryEditorPage(storyId: story.id),
          ),
        );
        onActionComplete();
        break;
      case 'publish':
        try {
          await StoryServiceNew.publishStory(story.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Historia publicada exitosamente')),
          );
          onActionComplete();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al publicar historia: $e')),
          );
        }
        break;
      case 'unpublish':
        try {
          await StoryServiceNew.unpublishStory(story.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Historia despublicada')),
          );
          onActionComplete();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al despublicar historia: $e')),
          );
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Eliminar historia'),
            content: Text(
              '¿Estás seguro de que deseas eliminar "${story.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await StoryServiceNew.deleteStory(story.id);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Historia eliminada')),
            );
            onActionComplete();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar historia: $e')),
            );
          }
        }
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      const PopupMenuItem(
        value: 'edit',
        child: _PopupMenuRow(
          icon: Icons.edit_outlined,
          label: 'Editar',
        ),
      ),
      if (story.status == StoryStatus.draft)
        const PopupMenuItem(
          value: 'publish',
          child: _PopupMenuRow(
            icon: Icons.publish_outlined,
            label: 'Publicar',
          ),
        ),
      if (story.status == StoryStatus.published)
        const PopupMenuItem(
          value: 'unpublish',
          child: _PopupMenuRow(
            icon: Icons.visibility_off_outlined,
            label: 'Despublicar',
          ),
        ),
      const PopupMenuItem(
        value: 'delete',
        child: _PopupMenuRow(
          icon: Icons.delete_outline,
          label: 'Eliminar',
          isDestructive: true,
        ),
      ),
    ];
  }

  _StatusColors _statusColors(StoryStatus status, ColorScheme colorScheme) {
    switch (status) {
      case StoryStatus.published:
        return _StatusColors(
          background: colorScheme.primary.withValues(alpha: 0.15),
          foreground: colorScheme.primary,
        );
      case StoryStatus.draft:
        return _StatusColors(
          background: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          foreground: colorScheme.tertiary,
        );
      case StoryStatus.archived:
        return _StatusColors(
          background: colorScheme.surfaceContainerHighest,
          foreground: colorScheme.onSurfaceVariant,
        );
    }
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Hoy';
    if (difference == 1) return 'Ayer';
    if (difference < 7) return 'Hace $difference días';

    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  static String _fallbackExcerpt(String? content) {
    if (content == null || content.isEmpty) {
      return '';
    }
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    final truncated = normalized.substring(0, 160);
    final lastSpace = truncated.lastIndexOf(' ');
    return (lastSpace > 60 ? truncated.substring(0, lastSpace) : truncated) +
        '...';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataBadge extends StatelessWidget {
  const _MetadataBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupMenuRow extends StatelessWidget {
  const _PopupMenuRow({
    required this.icon,
    required this.label,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusColors {
  const _StatusColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}
