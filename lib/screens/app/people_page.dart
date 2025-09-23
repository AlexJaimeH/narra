import 'package:flutter/material.dart';
import 'package:narra/services/people_service.dart';
import 'package:narra/repositories/story_repository.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, private, family
  List<Person> _allPeople = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }
  
  Future<void> _loadPeople() async {
    try {
      final people = await PeopleService.getAllPeople();
      if (mounted) {
        setState(() {
          _allPeople = people;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar personas: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personas en mis historias'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Todas las personas'),
              ),
              const PopupMenuItem(
                value: 'family',
                child: Text('Solo familia'),
              ),
              const PopupMenuItem(
                value: 'private',
                child: Text('Personas privadas'),
              ),
            ],
            child: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar personas...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacidad automática',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Las personas marcadas como privadas harán que sus historias se publiquen sin comentarios por defecto.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // People List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PeopleList(
                    searchQuery: _searchQuery,
                    filter: _selectedFilter,
                    people: _allPeople,
                  ),
          ),
        ],
      ),
    );
  }
}

class PeopleList extends StatelessWidget {
  final String searchQuery;
  final String filter;
  final List<Person> people;

  const PeopleList({
    super.key,
    required this.searchQuery,
    required this.filter,
    required this.people,
  });

  @override
  Widget build(BuildContext context) {
    // Filter people based on search and filter
    List<Person> filteredPeople = people.where((person) {
      bool matchesSearch = searchQuery.isEmpty ||
          person.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          person.relation.toLowerCase().contains(searchQuery.toLowerCase());
      
      bool matchesFilter = filter == 'all' ||
          (filter == 'family' && person.isFamily) ||
          (filter == 'private' && person.isPrivate);

      return matchesSearch && matchesFilter;
    }).toList();

    if (filteredPeople.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty ? 'No se encontraron personas' : 'No hay personas detectadas',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty
                  ? 'Intenta con otros términos de búsqueda'
                  : 'La IA detectará automáticamente las personas cuando escribas historias',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredPeople.length,
      itemBuilder: (context, index) {
        final person = filteredPeople[index];
        return PersonCard(person: person.toMap());
      },
    );
  }
}

class PersonCard extends StatelessWidget {
  final Map<String, dynamic> person;

  const PersonCard({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showPersonDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  (person['name'] as String).split(' ').map((n) => n[0]).take(2).join(''),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Person Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person['name'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (person['isPrivate'])
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Privada',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      person['relation'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    if (person['bio'] != null && (person['bio'] as String).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        person['bio'],
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Icon(
                          Icons.library_books,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${person['storiesCount']} historia${person['storiesCount'] != 1 ? 's' : ''}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action Menu
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, value, person),
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
                  PopupMenuItem(
                    value: 'privacy',
                    child: Row(
                      children: [
                        Icon(person['isPrivate'] ? Icons.lock_open : Icons.lock),
                        const SizedBox(width: 8),
                        Text(person['isPrivate'] ? 'Hacer pública' : 'Hacer privada'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'stories',
                    child: Row(
                      children: [
                        Icon(Icons.list),
                        SizedBox(width: 8),
                        Text('Ver historias'),
                      ],
                    ),
                  ),
                ],
                child: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PersonDetailsSheet(person: person),
    );
  }

  void _handleAction(BuildContext context, String action, Map<String, dynamic> person) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, person);
        break;
      case 'privacy':
        // Toggle privacy
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              person['isPrivate']
                  ? '${person['name']} ahora es pública'
                  : '${person['name']} ahora es privada',
            ),
          ),
        );
        break;
      case 'stories':
        // Navigate to stories list filtered by this person
        break;
    }
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> person) {
    final nameController = TextEditingController(text: person['name']);
    final relationController = TextEditingController(text: person['relation']);
    final bioController = TextEditingController(text: person['bio'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar persona'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relationController,
              decoration: const InputDecoration(labelText: 'Relación'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioController,
              decoration: const InputDecoration(labelText: 'Biografía (opcional)'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Persona actualizada')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class PersonDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> person;

  const PersonDetailsSheet({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            (person['name'] as String).split(' ').map((n) => n[0]).take(2).join(''),
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person['name'],
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                person['relation'],
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bio
                    if (person['bio'] != null && (person['bio'] as String).isNotEmpty) ...[
                      Text(
                        'Biografía',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        person['bio'],
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Stats
                    Text(
                      'Estadísticas',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${person['storiesCount']}',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Historias',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                                ),
                                Column(
                                  children: [
                                    Icon(
                                      person['isPrivate'] ? Icons.lock : Icons.public,
                                      color: person['isPrivate']
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context).colorScheme.primary,
                                      size: 32,
                                    ),
                                    Text(
                                      person['isPrivate'] ? 'Privada' : 'Pública',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to stories filtered by this person
                        },
                        icon: const Icon(Icons.library_books, color: Colors.white),
                        label: const Text('Ver todas sus historias'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}