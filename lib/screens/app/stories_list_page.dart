import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/screens/public/story_blog_page.dart';
import 'package:narra/services/email/email_service.dart';
import 'package:narra/services/email/subscriber_email_service.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/services/story_share_link_builder.dart';
import 'package:narra/services/subscriber_service.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:url_launcher/url_launcher.dart';

import 'story_editor_page.dart';

/// Tipos de ordenamiento para las historias
enum StorySortType {
  modifiedDate,  // Por fecha de modificación (más reciente primero)
  storyDate,     // Por fecha de la historia (si no tiene fecha, al final)
  title,         // Por título alfabético
}

extension StorySortTypeExtension on StorySortType {
  String get label {
    switch (this) {
      case StorySortType.modifiedDate:
        return 'Fecha de modificación';
      case StorySortType.storyDate:
        return 'Fecha de la historia';
      case StorySortType.title:
        return 'Título';
    }
  }

  IconData get icon {
    switch (this) {
      case StorySortType.modifiedDate:
        return Icons.update;
      case StorySortType.storyDate:
        return Icons.event;
      case StorySortType.title:
        return Icons.sort_by_alpha;
    }
  }
}

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
  final Set<String> _sendingStoryEmails = <String>{};

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

  Future<void> _sendStoryToSubscribers(
    BuildContext context,
    Story story,
    List<Subscriber> selectedSubscribers,
  ) async {
    final storyId = story.id;
    if (_sendingStoryEmails.contains(storyId)) {
      return;
    }

    setState(() {
      _sendingStoryEmails.add(storyId);
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      if (selectedSubscribers.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No has seleccionado ningún suscriptor.'),
          ),
        );
        return;
      }

      final summary = await SubscriberEmailService.sendStoryPublished(
        story: story,
        subscribers: selectedSubscribers,
        authorDisplayName:
            story.authorDisplayName ?? story.authorName ?? 'Autor/a de Narra',
      );

      if (!mounted) return;

      if (summary.sent == 0 && summary.hasFailures) {
        final failedNames = summary.failures
            .map((failure) => failure.subscriber.name)
            .where((name) => name.isNotEmpty)
            .toList();
        final message = failedNames.isNotEmpty
            ? 'No se pudo enviar la historia a ${failedNames.take(3).join(', ')}.'
            : 'No se pudo enviar la historia por correo.';
        messenger.showSnackBar(SnackBar(content: Text(message)));
        return;
      }

      final baseMessage = summary.sent == 1
          ? 'Historia enviada por correo a 1 suscriptor.'
          : 'Historia enviada por correo a ${summary.sent} suscriptores.';

      if (summary.hasFailures) {
        final failedNames = summary.failures
            .map((failure) => failure.subscriber.name)
            .where((name) => name.isNotEmpty)
            .toList();
        if (failedNames.isEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '$baseMessage Algunos correos no se pudieron entregar.',
              ),
            ),
          );
        } else {
          final truncated = failedNames.take(3).join(', ');
          final extra = summary.failures.length > 3
              ? ' y ${summary.failures.length - 3} más'
              : '';
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '$baseMessage No se pudo enviar a $truncated$extra.',
              ),
            ),
          );
        }
      } else {
        messenger.showSnackBar(SnackBar(content: Text(baseMessage)));
      }
    } on EmailServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('No se pudo enviar el correo: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Ocurrió un problema al enviar la historia: ${error.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingStoryEmails.remove(storyId);
        });
      }
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
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
                                  'Mis historias',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Administra, busca y publica tus recuerdos con un espacio pensado para ti.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => _loadStories(silent: true),
                            tooltip: 'Actualizar historias',
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
                      const SizedBox(height: 10),
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
                        isQueryEmpty: _searchQuery.isEmpty,
                      ),
                      const SizedBox(height: 10),
                      _StoriesSegmentedControl(
                        controller: _tabController,
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 8),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          StoriesTab(
            stories: _allStories,
            filterStatus: null,
            searchQuery: _searchQuery,
            onRefresh: () => _loadStories(silent: true),
            onStoriesChanged: () => _loadStories(silent: true),
            onCreateStory: _openStoryCreator,
            sendingStoryEmails: _sendingStoryEmails,
            onSendStoryToSubscribers: _sendStoryToSubscribers,
          ),
          StoriesTab(
            stories: _allStories,
            filterStatus: StoryStatus.draft,
            searchQuery: _searchQuery,
            onRefresh: () => _loadStories(silent: true),
            onStoriesChanged: () => _loadStories(silent: true),
            onCreateStory: _openStoryCreator,
            sendingStoryEmails: _sendingStoryEmails,
            onSendStoryToSubscribers: _sendStoryToSubscribers,
          ),
          StoriesTab(
            stories: _allStories,
            filterStatus: StoryStatus.published,
            searchQuery: _searchQuery,
            onRefresh: () => _loadStories(silent: true),
            onStoriesChanged: () => _loadStories(silent: true),
            onCreateStory: _openStoryCreator,
            sendingStoryEmails: _sendingStoryEmails,
            onSendStoryToSubscribers: _sendStoryToSubscribers,
          ),
        ],
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
    required this.isQueryEmpty,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool isQueryEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.search_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
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
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: hintText,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              if (!isQueryEmpty) ...[
                const SizedBox(width: 8),
                _SearchActionButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Limpiar búsqueda',
                  onPressed: onClear,
                  background: colorScheme.onSurface.withValues(alpha: 0.08),
                  foreground: colorScheme.onSurface,
                ),
              ],
            ],
          ),
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
        padding: const EdgeInsets.all(10),
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
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
      ),
      child: TabBar(
        controller: controller,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: colorScheme.primary.withValues(alpha: 0.12),
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

class StoriesTab extends StatefulWidget {
  const StoriesTab({
    super.key,
    required this.stories,
    required this.filterStatus,
    required this.searchQuery,
    required this.onRefresh,
    required this.onStoriesChanged,
    required this.onCreateStory,
    required this.sendingStoryEmails,
    this.onSendStoryToSubscribers,
  });

  final List<Story> stories;
  final StoryStatus? filterStatus;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final VoidCallback onStoriesChanged;
  final Future<void> Function() onCreateStory;
  final Set<String> sendingStoryEmails;
  final Future<void> Function(
      BuildContext context, Story story, List<Subscriber> selectedSubscribers)?
      onSendStoryToSubscribers;

  @override
  State<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  StorySortType _sortType = StorySortType.modifiedDate;

  List<Story> _sortStories(List<Story> stories) {
    final sorted = List<Story>.from(stories);

    switch (_sortType) {
      case StorySortType.modifiedDate:
        sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;

      case StorySortType.storyDate:
        sorted.sort((a, b) {
          final aHasDate = a.startDate != null;
          final bHasDate = b.startDate != null;

          // Las historias sin fecha van al final
          if (!aHasDate && !bHasDate) {
            // Ambas sin fecha: ordenar por fecha de modificación
            return b.updatedAt.compareTo(a.updatedAt);
          }

          if (!aHasDate) {
            // 'a' sin fecha va al final (después de 'b')
            return 1;
          }

          if (!bHasDate) {
            // 'b' sin fecha va al final (antes de 'a')
            return -1;
          }

          // Ambas tienen fecha: ordenar por fecha de historia (más reciente primero)
          return b.startDate!.compareTo(a.startDate!);
        });
        break;

      case StorySortType.title:
        sorted.sort((a, b) {
          final titleA = a.title.toLowerCase().trim();
          final titleB = b.title.toLowerCase().trim();
          if (titleA.isEmpty && titleB.isEmpty) return 0;
          if (titleA.isEmpty) return 1;
          if (titleB.isEmpty) return -1;
          return titleA.compareTo(titleB);
        });
        break;
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStories = widget.stories.where((story) {
      final matchesFilter = switch (widget.filterStatus) {
        null => true,
        StoryStatus.published => story.isPublished,
        StoryStatus.draft =>
          !story.isPublished && story.status == StoryStatus.draft,
        StoryStatus.archived => story.status == StoryStatus.archived,
      };
      final matchesSearch = _matchesSearch(story, widget.searchQuery);
      return matchesFilter && matchesSearch;
    }).toList();

    // Aplicar ordenamiento
    final sortedStories = _sortStories(filteredStories);

    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 640;
    final horizontalPadding = isCompact ? 10.0 : 16.0;

    if (sortedStories.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        displacement: 80,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
          children: [
            _EmptyStoriesState(
              isSearching: widget.searchQuery.trim().isNotEmpty,
              filterStatus: widget.filterStatus,
              onCreateStory: widget.onCreateStory,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      displacement: 80,
      child: Column(
        children: [
          // Selector de ordenamiento
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              4,
            ),
            child: _SortSelector(
              currentSort: _sortType,
              onSortChanged: (newSort) {
                setState(() => _sortType = newSort);
              },
            ),
          ),

          // Lista de historias
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                4,
                horizontalPadding,
                16,
              ),
              itemCount: sortedStories.length,
              separatorBuilder: (context, index) => Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding + (isCompact ? 2 : 10),
                  isCompact ? 6 : 10,
                  horizontalPadding + (isCompact ? 2 : 10),
                  isCompact ? 2 : 6,
                ),
                child: _StoriesSeparator(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.24),
                ),
              ),
              itemBuilder: (context, index) {
                final story = sortedStories[index];
                return StoryListCard(
                  story: story,
                  onActionComplete: widget.onStoriesChanged,
                  accentColor: _cardAccentColor(context, index),
                  onSendToSubscribers: widget.onSendStoryToSubscribers == null
                      ? null
                      : (selectedSubscribers) => widget.onSendStoryToSubscribers!(
                          context, story, selectedSubscribers),
                  isSendingToSubscribers: widget.sendingStoryEmails.contains(story.id),
                );
              },
            ),
          ),
        ],
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

/// Widget selector de ordenamiento
class _SortSelector extends StatelessWidget {
  const _SortSelector({
    required this.currentSort,
    required this.onSortChanged,
  });

  final StorySortType currentSort;
  final ValueChanged<StorySortType> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Ordenar:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: PopupMenuButton<StorySortType>(
              initialValue: currentSort,
              onSelected: onSortChanged,
              offset: const Offset(0, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              itemBuilder: (context) => [
                for (final sortType in StorySortType.values)
                  PopupMenuItem<StorySortType>(
                    value: sortType,
                    child: Row(
                      children: [
                        Icon(
                          sortType.icon,
                          size: 20,
                          color: sortType == currentSort
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            sortType.label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: sortType == currentSort
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                              fontWeight: sortType == currentSort
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (sortType == currentSort)
                          Icon(
                            Icons.check,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                      ],
                    ),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      currentSort.icon,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        currentSort.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoriesSeparator extends StatelessWidget {
  const _StoriesSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: color,
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
    this.onSendToSubscribers,
    this.isSendingToSubscribers = false,
  });

  final Story story;
  final VoidCallback onActionComplete;
  final Color accentColor;
  final Future<void> Function(List<Subscriber> selectedSubscribers)?
      onSendToSubscribers;
  final bool isSendingToSubscribers;

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
    final statusForDisplay =
        story.isPublished && story.status != StoryStatus.archived
            ? StoryStatus.published
            : story.status;
    final statusColors = _statusColors(statusForDisplay, colorScheme);
    final publishedDisplayDate = story.publishedAt ?? story.updatedAt;
    final metadataChips = <Widget>[
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
        final horizontalPadding = isCompact ? 12.0 : 16.0;
        final verticalPadding = isCompact ? 12.0 : 16.0;
        final titleStyle = (isCompact
                ? theme.textTheme.titleMedium
                : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w700);
        final cardRadius = BorderRadius.circular(18);
        final coverSize = isCompact ? 88.0 : 104.0;

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
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  verticalPadding,
                  horizontalPadding,
                  isCompact ? 14 : 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Imágenes en scroll horizontal (si existen)
                          if (story.photos.isNotEmpty) ...[
                            SizedBox(
                              height: coverSize,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: story.photos.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  return _StoryCoverThumbnail(
                                    url: story.photos[index].photoUrl,
                                    size: coverSize,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Título y acciones
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  story.title.isEmpty
                                      ? 'Sin título'
                                      : story.title,
                                  style: titleStyle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _StatusPill(
                                    label: statusForDisplay.displayName,
                                    color: statusColors.foreground,
                                    background: statusColors.background,
                                    icon: switch (statusForDisplay) {
                                      StoryStatus.published =>
                                        Icons.check_circle,
                                      StoryStatus.archived =>
                                        Icons.inventory_2_outlined,
                                      _ => Icons.edit_note,
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _StoryActionsButton(
                                    onSelected: (action) =>
                                        _handleStoryAction(
                                      context,
                                      story: story,
                                      onActionComplete: onActionComplete,
                                      action: action,
                                    ),
                                    itemBuilder: (menuContext) =>
                                        _buildStoryMenuItems(
                                      story,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Fecha de la historia y etiquetas
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              // Fecha de la historia (si existe)
                              if (_formatHistoryDate(story) != null)
                                _HistoryDateBadge(
                                  date: _formatHistoryDate(story)!,
                                  colorScheme: colorScheme,
                                ),

                              // Etiquetas
                              ...tags.map((tag) => _TagChip(label: tag)),
                            ],
                          ),

                          // Fecha de publicación (si aplica)
                          if (story.isPublished) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.public,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Publicado el '
                                    '${_formatFullDate(publishedDisplayDate)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Fecha de última modificación (en itálica)
                          const SizedBox(height: 6),
                          Text(
                            'Última modificación: ${_formatStoryDate(story.updatedAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.8),
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Extracto
                          if (excerpt.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              excerpt,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.45,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          // Metadata chips
                          if (metadataChips.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: metadataChips,
                            ),
                          ],

                          // Vista previa pública
                          if (story.isPublished) ...[
                            const SizedBox(height: 20),
                            _PublicStoryPreview(
                              story: story,
                              onViewPage: () =>
                                  _openStoryPublicPage(context, story),
                              onSendToSubscribers: onSendToSubscribers,
                              isSendingToSubscribers: isSendingToSubscribers,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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

class _StoryCoverThumbnail extends StatelessWidget {
  const _StoryCoverThumbnail({
    required this.url,
    required this.size,
  });

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.image_not_supported_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PublicStoryPreview extends StatelessWidget {
  const _PublicStoryPreview({
    required this.story,
    required this.onViewPage,
    this.onSendToSubscribers,
    this.isSendingToSubscribers = false,
  });

  final Story story;
  final VoidCallback onViewPage;
  final Future<void> Function(List<Subscriber> selectedSubscribers)?
      onSendToSubscribers;
  final bool isSendingToSubscribers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final publishedAt = story.publishedAt ?? story.updatedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Página pública disponible',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (publishedAt != null) ...[
            Text(
              'Publicado el ${_formatFullDate(publishedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Comparte tu historia con enlaces seguros personalizados.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: _PublicStoryLinkButton(onPressed: onViewPage),
          ),
          if (onSendToSubscribers != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSendingToSubscribers
                    ? null
                    : () async {
                        await _showSubscriberSelectionModal(
                          context,
                          story,
                          onSendToSubscribers!,
                        );
                      },
                icon: isSendingToSubscribers
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group),
                label: Text(
                  isSendingToSubscribers
                      ? 'Enviando...'
                      : 'Compartir a suscriptores',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicStoryLinkButton extends StatelessWidget {
  const _PublicStoryLinkButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = Color.lerp(colorScheme.primary, colorScheme.tertiary, 0.35)!;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, accent],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ver historia publicada',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colorScheme.onPrimary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


Future<void> _showSubscriberSelectionModal(
  BuildContext context,
  Story story,
  Future<void> Function(List<Subscriber> selectedSubscribers)
      onSendToSubscribers,
) async {
  final subscribers = await SubscriberService.getConfirmedSubscribers();

  if (!context.mounted) return;

  if (subscribers.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todavía no tienes suscriptores confirmados.'),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _SubscriberSelectionDialog(
      story: story,
      subscribers: subscribers,
      onSendToSubscribers: onSendToSubscribers,
    ),
  );
}

class _SubscriberSelectionDialog extends StatefulWidget {
  const _SubscriberSelectionDialog({
    required this.story,
    required this.subscribers,
    required this.onSendToSubscribers,
  });

  final Story story;
  final List<Subscriber> subscribers;
  final Future<void> Function(List<Subscriber> selectedSubscribers)
      onSendToSubscribers;

  @override
  State<_SubscriberSelectionDialog> createState() =>
      _SubscriberSelectionDialogState();
}

class _SubscriberSelectionDialogState
    extends State<_SubscriberSelectionDialog> {
  late Set<String> _selectedIds;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Start with all subscribers selected
    _selectedIds = widget.subscribers.map((s) => s.id).toSet();
  }

  void _toggleAll(bool selectAll) {
    setState(() {
      if (selectAll) {
        _selectedIds = widget.subscribers.map((s) => s.id).toSet();
      } else {
        _selectedIds.clear();
      }
    });
  }

  void _toggleSubscriber(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _sendToSelected() async {
    if (_selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un suscriptor'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final selectedSubscribers = widget.subscribers
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    try {
      await widget.onSendToSubscribers(selectedSubscribers);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allSelected = _selectedIds.length == widget.subscribers.length;
    final noneSelected = _selectedIds.isEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.group,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Seleccionar suscriptores',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSending
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona a quién enviar "${widget.story.title}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSending
                              ? null
                              : () => _toggleAll(!allSelected),
                          icon: Icon(
                            allSelected
                                ? Icons.deselect
                                : Icons.select_all_rounded,
                            size: 18,
                          ),
                          label: Text(
                            allSelected
                                ? 'Deseleccionar todos'
                                : 'Seleccionar todos',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.subscribers.length,
                itemBuilder: (context, index) {
                  final subscriber = widget.subscribers[index];
                  final isSelected = _selectedIds.contains(subscriber.id);

                  return CheckboxListTile(
                    enabled: !_isSending,
                    value: isSelected,
                    onChanged: (_) => _toggleSubscriber(subscriber.id),
                    title: Text(
                      subscriber.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      subscriber.email,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.trailing,
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_selectedIds.length} de ${widget.subscribers.length} seleccionados',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        _isSending || noneSelected ? null : _sendToSelected,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSending
                          ? 'Enviando...'
                          : 'Enviar a seleccionados',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openStoryPublicPage(BuildContext context, Story story) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  // Get current user info for author magic link
  final currentUser = SupabaseAuth.currentUser;
  if (currentUser == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Error: Usuario no autenticado'),
      ),
    );
    return;
  }

  // Build author magic link
  // The token must be the author ID as string (validated in the backend)
  final link = StoryShareLinkBuilder.buildAuthorStoryLink(
    story: story,
    authorId: currentUser.id,
    authorName: currentUser.userMetadata?['full_name']?.toString() ??
        currentUser.email ??
        'Autor',
    authorToken: currentUser.id, // Token must match author_id for validation
  );

  final routeName = '/story/${story.id}';
  final routeArguments = StoryBlogPageArguments(
    story: story,
  );

  try {
    final launched = await launchUrl(
      link,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );

    if (launched) {
      return;
    }
  } catch (_) {
    // Fall back to the in-app viewer below when launching the browser fails.
  }

  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'No se pudo abrir la página pública en una pestaña nueva. Mostrando la vista dentro de la app.',
      ),
    ),
  );

  navigator.pushNamed(
    routeName,
    arguments: routeArguments,
  );
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
    if (story.isDraft)
      const PopupMenuItem(
        value: 'publish',
        child: _PopupMenuRow(
          icon: Icons.publish_outlined,
          label: 'Publicar',
        ),
      ),
    if (story.isPublished)
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

String _formatFullDate(DateTime date) {
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  final month = months[date.month - 1];
  return '${date.day} de $month de ${date.year}';
}

/// Formatea la fecha de la historia según su precisión
String? _formatHistoryDate(Story story) {
  final startDate = story.startDate;
  if (startDate == null) return null;

  final precision = story.datesPrecision ?? 'day';

  try {
    switch (precision) {
      case 'year':
        return startDate.year.toString();
      case 'month':
        const months = [
          'Enero',
          'Febrero',
          'Marzo',
          'Abril',
          'Mayo',
          'Junio',
          'Julio',
          'Agosto',
          'Septiembre',
          'Octubre',
          'Noviembre',
          'Diciembre',
        ];
        return '${months[startDate.month - 1]} ${startDate.year}';
      case 'day':
      default:
        const months = [
          'enero',
          'febrero',
          'marzo',
          'abril',
          'mayo',
          'junio',
          'julio',
          'agosto',
          'septiembre',
          'octubre',
          'noviembre',
          'diciembre',
        ];
        return '${startDate.day} de ${months[startDate.month - 1]} de ${startDate.year}';
    }
  } catch (e) {
    return null;
  }
}

String _fallbackStoryExcerpt(String? content) {
  if (content == null || content.isEmpty) {
    return '';
  }
  final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
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
            borderRadius: BorderRadius.circular(12),
            onTapDown: _storePosition,
            onTap: _showMenu,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.more_horiz_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Badge para mostrar la fecha de la historia (como en el blog de React)
class _HistoryDateBadge extends StatelessWidget {
  const _HistoryDateBadge({
    required this.date,
    required this.colorScheme,
  });

  final String date;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event,
            size: 14,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              date,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
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
