import 'package:flutter/material.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/repositories/story_repository.dart';
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
  
  Future<void> _loadStories() async {
    try {
      final stories = await StoryServiceNew.getStories();
      if (mounted) {
        setState(() {
          _allStories = stories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historias: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis historias'),
        actions: [
          IconButton(
            onPressed: () => _loadStories(),
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar historias...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              // Tabs
              TabBar(
                controller: _tabController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                tabs: const [
                  Tab(text: 'Todas'),
                  Tab(text: 'Borradores'),
                  Tab(text: 'Publicadas'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                StoriesTab(searchQuery: _searchQuery, filter: 'all', stories: _allStories),
                StoriesTab(searchQuery: _searchQuery, filter: 'drafts', stories: _allStories),
                StoriesTab(searchQuery: _searchQuery, filter: 'published', stories: _allStories),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StoryEditorPage(),
          ),
        ).then((_) => _loadStories()),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva historia'),
      ),
    );
  }
}

class StoriesTab extends StatelessWidget {
  final String searchQuery;
  final String filter;
  final List<Story> stories;

  const StoriesTab({
    super.key,
    required this.searchQuery,
    required this.filter,
    required this.stories,
  });

  @override
  Widget build(BuildContext context) {
    // Filter stories based on filter type
    List<Story> filteredStories = stories.where((story) {
      bool matchesFilter = filter == 'all' ||
          (filter == 'drafts' && story.status == 'draft') ||
          (filter == 'published' && story.status == 'published');
      
      bool matchesSearch = searchQuery.isEmpty ||
          story.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (story.excerpt?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);

      return matchesFilter && matchesSearch;
    }).toList();

    if (filteredStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty ? 'No se encontraron historias' : 'No tienes historias aún',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda'
                  : 'Comienza creando tu primera historia',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (searchQuery.isEmpty) ...[
              const SizedBox(height: 24),
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
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredStories.length,
      itemBuilder: (context, index) {
        final story = filteredStories[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: StoryListCard(story: story.toMap()),
        );
      },
    );
  }
}

class StoryListCard extends StatelessWidget {
  final Map<String, dynamic> story;

  const StoryListCard({super.key, required this.story});

  @override
  Widget build(BuildContext context) {
    final isPublished = story['status'] == 'published';
    
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryEditorPage(storyId: story['id']),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            if (story['coverImage'] != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  story['coverImage'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Icon(
                      Icons.image,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Status
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          story['title'] ?? 'Sin título',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPublished
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPublished ? 'Publicada' : 'Borrador',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isPublished
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Excerpt
                  if (story['excerpt'] != null && story['excerpt'].isNotEmpty)
                    Text(
                      story['excerpt'],
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      'Sin extracto disponible',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Tags
                  if (story['tags'] != null && (story['tags'] as List).isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: (story['tags'] as List).map((tag) => Chip(
                        label: Text(
                          tag.toString(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      )).toList(),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Metadata
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(story['created_at'] ?? story['date'] ?? DateTime.now().toIso8601String()),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      
                      if ((story['photos'] ?? 0) > 0) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.photo_library,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${story['photos'] ?? 0}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                      
                      if (isPublished) ...[
                        if ((story['reactions'] ?? 0) > 0) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${story['reactions'] ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.red,
                            ),
                          ),
                        ],
                        if ((story['comments'] ?? 0) > 0) ...[
                          const SizedBox(width: 16),
                          Icon(
                            Icons.comment,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${story['comments'] ?? 0}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ],
                      
                      const Spacer(),
                      
                      // Action Button
                      PopupMenuButton<String>(
                        onSelected: (value) => _handleStoryAction(context, value, story),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Editar'),
                              ],
                            ),
                          ),
                          if (story['status'] == 'draft')
                            const PopupMenuItem(
                              value: 'publish',
                              child: Row(
                                children: [
                                  Icon(Icons.publish),
                                  SizedBox(width: 8),
                                  Text('Publicar'),
                                ],
                              ),
                            ),
                          if (story['status'] == 'published')
                            const PopupMenuItem(
                              value: 'unpublish',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility_off),
                                  SizedBox(width: 8),
                                  Text('Despublicar'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Eliminar', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        child: const Icon(Icons.more_vert),
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) {
      return 'Sin fecha';
    }
    
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
  
  void _handleStoryAction(BuildContext context, String action, Map<String, dynamic> story) async {
    switch (action) {
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StoryEditorPage(storyId: story['id']),
          ),
        );
        break;
      case 'publish':
        try {
          await StoryServiceNew.publishStory(story['id']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Historia publicada exitosamente')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al publicar historia: $e')),
          );
        }
        break;
      case 'unpublish':
        try {
          await StoryServiceNew.unpublishStory(story['id']);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Historia despublicada')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al despublicar historia: $e')),
          );
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar historia'),
            content: Text('¿Estás seguro de que deseas eliminar "${story['title']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await StoryServiceNew.deleteStory(story['id']);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Historia eliminada')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar historia: $e')),
            );
          }
        }
        break;
    }
  }
}