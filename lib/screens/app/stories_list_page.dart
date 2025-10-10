import 'dart:math' as math;
import 'dart:ui' as ui;

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
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  right: -60,
                  top: -90,
                  child: _AccentOrb(
                    color: colorScheme.primary.withValues(alpha: 0.26),
                    size: 210,
                  ),
                ),
                Positioned(
                  left: -40,
                  bottom: -70,
                  child: _AccentOrb(
                    color: colorScheme.secondary.withValues(alpha: 0.2),
                    size: 170,
                  ),
                ),
                Positioned(
                  right: -120,
                  bottom: -40,
                  child: _AccentOrb(
                    color: colorScheme.tertiary.withValues(alpha: 0.14),
                    size: 220,
                  ),
                ),
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.surfaceBright.withValues(alpha: 0.95),
                          colorScheme.surface.withValues(alpha: 0.9),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 34,
                          offset: const Offset(0, 28),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 22,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      colorScheme.primary
                                          .withValues(alpha: 0.18),
                                      colorScheme.primary
                                          .withValues(alpha: 0.08),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.menu_book_rounded,
                                  color: colorScheme.primary,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mis historias',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Administra, busca y publica tus recuerdos con un espacio pensado para ti.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _loadStories(silent: true),
                                tooltip: 'Actualizar historias',
                                icon: const Icon(Icons.refresh_rounded),
                                style: IconButton.styleFrom(
                                  backgroundColor: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  foregroundColor: colorScheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.all(12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _SearchField(
                            controller: _searchController,
                            hintText:
                                'Buscar por título, contenido, etiquetas o personas...',
                            onChanged: (value) {
                              setState(() => _searchQuery = value);
                            },
                            onClear: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            onRefresh: () => _loadStories(silent: true),
                            isQueryEmpty: _searchQuery.isEmpty,
                          ),
                          const SizedBox(height: 20),
                          _StoriesSegmentedControl(
                            controller: _tabController,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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

class _AccentOrb extends StatelessWidget {
  const _AccentOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    required this.onRefresh,
    required this.isQueryEmpty,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;
  final bool isQueryEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: colorScheme.surface.withValues(alpha: 0.88),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 22,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.2),
                    colorScheme.primary.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Icon(
                Icons.search_rounded,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale:
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: child,
              ),
              child: isQueryEmpty
                  ? _SearchActionButton(
                      key: const ValueKey('filter'),
                      icon: Icons.tune_rounded,
                      tooltip: 'Actualizar lista',
                      onPressed: onRefresh,
                      background: colorScheme.primary.withValues(alpha: 0.1),
                      foreground: colorScheme.primary,
                    )
                  : _SearchActionButton(
                      key: const ValueKey('clear'),
                      icon: Icons.close_rounded,
                      tooltip: 'Limpiar búsqueda',
                      onPressed: onClear,
                      background: colorScheme.onSurface.withValues(alpha: 0.08),
                      foreground: colorScheme.onSurface,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchActionButton extends StatelessWidget {
  const _SearchActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _StoriesSegmentedControl extends StatelessWidget {
  const _StoriesSegmentedControl({
    required this.controller,
    required this.theme,
  });

  final TabController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: colorScheme.surfaceBright.withValues(alpha: 0.68),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
      ),
      child: TabBar(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        dividerColor: Colors.transparent,
        indicator: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: colorScheme.primary,
              width: 1.6,
            ),
          ),
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.18),
              colorScheme.primary.withValues(alpha: 0.1),
            ],
          ),
        ),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.25,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: InkSparkle.splashFactory,
        tabs: const [
          Tab(text: 'Todas'),
          Tab(text: 'Borradores'),
          Tab(text: 'Publicadas'),
        ],
      ),
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
      final matchesFilter = switch (filterStatus) {
        null => true,
        _ => story.status == filterStatus,
      };
      final matchesSearch = _matchesSearch(story, searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();

    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 640;
    final horizontalPadding = isCompact ? 10.0 : 20.0;

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
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          16,
          horizontalPadding,
          26,
        ),
        itemCount: filteredStories.length,
        separatorBuilder: (context, index) => Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding + (isCompact ? 4 : 16),
            isCompact ? 10 : 14,
            horizontalPadding + (isCompact ? 4 : 16),
            isCompact ? 4 : 10,
          ),
          child: _StoriesSeparator(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: 0.35),
          ),
        ),
        itemBuilder: (context, index) {
          final story = filteredStories[index];
          return StoryListCard(
            story: story,
            onActionComplete: onStoriesChanged,
            accentColor: _cardAccentColor(context, index),
          );
        },
      ),
    );
  }

  Color _cardAccentColor(BuildContext context, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = [
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.secondary,
    ];
    return palette[index % palette.length];
  }

  static bool _matchesSearch(Story story, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) {
      return true;
    }

    final tokens =
        normalizedQuery.split(' ').where((token) => token.isNotEmpty);

    final searchableFields = <String>[
      story.title,
      story.excerpt ?? '',
      _stripMarkup(story.content),
      _stripMarkup(story.voiceTranscript),
      if (story.tags != null) story.tags!.join(' '),
      if (story.storyTags.isNotEmpty)
        story.storyTags.map((tag) => tag.name).join(' '),
      if (story.people.isNotEmpty)
        story.people.map((person) => person.name).join(' '),
    ].map(_normalize).where((field) => field.isNotEmpty).toList();

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

  static bool _fuzzyContains(String normalizedText, String query) {
    if (normalizedText.contains(query)) {
      return true;
    }

    final words = normalizedText
        .split(RegExp(r'[^a-z0-9]+'))
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
    final lower = value.toLowerCase();
    final withoutMarkup = lower.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final withoutDiacritics = _removeDiacritics(withoutMarkup);
    return withoutDiacritics.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _stripMarkup(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    return value.replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  static String _removeDiacritics(String input) {
    if (input.isEmpty) {
      return input;
    }
    final buffer = StringBuffer();
    for (final codePoint in input.runes) {
      final char = String.fromCharCode(codePoint);
      buffer.write(_diacriticMap[char] ?? char);
    }
    return buffer.toString();
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

class _StoriesSeparator extends StatelessWidget {
  const _StoriesSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: color,
          ),
        ),
        Container(
          width: 30,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: color.withValues(alpha: 0.14),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_awesome,
            size: 12,
            color: color.withValues(alpha: 0.85),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: color,
          ),
        ),
      ],
    );
  }
}

const Map<String, String> _diacriticMap = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
  'ç': 'c',
};

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
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Crear nueva historia'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: const StadiumBorder(),
                elevation: 3,
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
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
    required this.accentColor,
  });

  final Story story;
  final VoidCallback onActionComplete;
  final Color accentColor;

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
    final metadataChips = <Widget>[
      _MetadataBadge(
        icon: Icons.calendar_today,
        label: _formatDate(story.createdAt),
      ),
      if (story.wordCount > 0)
        _MetadataBadge(
          icon: Icons.text_snippet_outlined,
          label: '${story.wordCount} palabras',
        ),
      if (story.readingTime > 0)
        _MetadataBadge(
          icon: Icons.timer_outlined,
          label: '${story.readingTime} min de lectura',
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;
        final horizontalPadding = isCompact ? 16.0 : 20.0;
        final verticalPadding = isCompact ? 16.0 : 20.0;
        final titleStyle = (isCompact
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w700);
        final cardRadius = BorderRadius.circular(26);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: cardRadius,
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
                borderRadius: cardRadius,
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (coverUrl != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(26),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: colorScheme.surfaceContainerHighest,
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
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      isCompact ? 18 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: isCompact ? 42 : 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    story.title.isEmpty
                                        ? 'Sin título'
                                        : story.title,
                                    style: titleStyle,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Actualizada ${_formatDate(story.updatedAt)}',
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _StatusPill(
                                  label: story.status.displayName,
                                  color: statusColors.foreground,
                                  background: statusColors.background,
                                  icon: story.status == StoryStatus.published
                                      ? Icons.check_circle
                                      : Icons.edit_note,
                                ),
                                const SizedBox(height: 10),
                                _StoryActionsButton(
                                  onSelected: (action) => _handleStoryAction(
                                    context,
                                    story: story,
                                    onActionComplete: onActionComplete,
                                    action: action,
                                  ),
                                  itemBuilder: (menuContext) =>
                                      _buildStoryMenuItems(story),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(
                          height: 1,
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        if (excerpt.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            excerpt,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                            maxLines: isCompact ? 4 : 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tags
                                .map((tag) => _TagChip(label: tag))
                                .toList(),
                          ),
                        ],
                        if (metadataChips.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            children: metadataChips,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isCompact)
              Positioned(
                top: -10,
                left: 20,
                child: _StoryBadge(
                  index: index,
                  accentColor: accentColor,
                ),
              ),
          ],
        );
      },
    );
  }

  _StatusColors _statusColors(StoryStatus status, ColorScheme colorScheme) {
    return _storyStatusColors(status, colorScheme);
  }

  static String _formatDate(DateTime date) => _formatStoryDate(date);

  static String _fallbackExcerpt(String? content) =>
      _fallbackStoryExcerpt(content);
}

class _StoryBadge extends StatelessWidget {
  const _StoryBadge({required this.index, required this.accentColor});

  final int index;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accentColor.withValues(alpha: 0.9),
            accentColor.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          '#${index + 1}'.padLeft(2, '0'),
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

Future<void> _handleStoryAction(
  BuildContext context, {
  required Story story,
  required VoidCallback onActionComplete,
  required String action,
}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  switch (action) {
    case 'edit':
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => StoryEditorPage(storyId: story.id),
        ),
      );
      onActionComplete();
      break;
    case 'publish':
      try {
        await StoryServiceNew.publishStory(story.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Historia publicada exitosamente'),
          ),
        );
        onActionComplete();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error al publicar historia: $e')),
        );
      }
      break;
    case 'unpublish':
      try {
        await StoryServiceNew.unpublishStory(story.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Historia despublicada')),
        );
        onActionComplete();
      } catch (e) {
        messenger.showSnackBar(
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
          messenger.showSnackBar(
            const SnackBar(content: Text('Historia eliminada')),
          );
          onActionComplete();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('Error al eliminar historia: $e')),
          );
        }
      }
      break;
  }
}

List<PopupMenuEntry<String>> _buildStoryMenuItems(Story story) {
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

_StatusColors _storyStatusColors(
  StoryStatus status,
  ColorScheme colorScheme,
) {
  switch (status) {
    case StoryStatus.published:
      return _StatusColors(
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    case StoryStatus.draft:
      return _StatusColors(
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      );
    case StoryStatus.archived:
      return _StatusColors(
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
  }
}

String _formatStoryDate(DateTime date) {
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

String _fallbackStoryExcerpt(String? content) {
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
        border: Border.all(
          color: color.withValues(alpha: 0.16),
        ),
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
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

class _StoryActionsButton extends StatefulWidget {
  const _StoryActionsButton({
    required this.onSelected,
    required this.itemBuilder,
  });

  final Future<void> Function(String action) onSelected;
  final List<PopupMenuEntry<String>> Function(BuildContext context) itemBuilder;

  @override
  State<_StoryActionsButton> createState() => _StoryActionsButtonState();
}

class _StoryActionsButtonState extends State<_StoryActionsButton> {
  Offset? _tapPosition;

  void _storePosition(TapDownDetails details) {
    _tapPosition = details.globalPosition;
  }

  Future<void> _showMenu() async {
    final overlay = Overlay.of(context);
    if (overlay == null) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final buttonBox = context.findRenderObject() as RenderBox?;
    if (overlayBox == null) return;

    final tapPosition = _tapPosition ??
        (buttonBox != null
            ? buttonBox.localToGlobal(buttonBox.size.center(Offset.zero))
            : overlayBox.size.center(Offset.zero));

    final position = RelativeRect.fromRect(
      ui.Rect.fromCenter(center: tapPosition, width: 1, height: 1),
      Offset.zero & overlayBox.size,
    );

    final selected = await showMenu<String>(
      context: context,
      position: position,
      items: widget.itemBuilder(context),
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.surface,
    );

    _tapPosition = null;

    if (selected != null) {
      await widget.onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Opciones de historia',
      child: Tooltip(
        message: 'Opciones de historia',
        waitDuration: const Duration(milliseconds: 250),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTapDown: _storePosition,
            onTap: _showMenu,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
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
