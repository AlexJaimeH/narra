import 'package:flutter/material.dart';
import 'package:narra/services/subscriber_service.dart';
import 'package:narra/repositories/story_repository.dart';

class SubscribersPage extends StatefulWidget {
  const SubscribersPage({super.key});

  @override
  State<SubscribersPage> createState() => _SubscribersPageState();
}

class _SubscribersPageState extends State<SubscribersPage> {
  final TextEditingController _emailController = TextEditingController();
  List<Subscriber> _subscribers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscribers();
  }
  
  Future<void> _loadSubscribers() async {
    try {
      final subscribers = await SubscriberService.getSubscribers();
      if (mounted) {
        setState(() {
          _subscribers = subscribers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar suscriptores: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis suscriptores'),
        actions: [
          IconButton(
            onPressed: _showInviteDialog,
            icon: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Card(
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
                            'Magic Links permanentes',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cada suscriptor recibe un enlace único que nunca caduca. Pueden leer tus historias y reaccionar con ❤️.',
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
            
            const SizedBox(height: 24),
            
            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.people,
                    value: '5',
                    label: 'Suscriptores',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.favorite,
                    value: '23',
                    label: 'Reacciones',
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.comment,
                    value: '8',
                    label: 'Comentarios',
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Subscribers List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lista de suscriptores',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showInviteDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Invitar'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            const SubscribersList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    _emailController.clear();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invitar suscriptor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enviaremos un email de invitación con un enlace único que nunca caduca.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email del suscriptor',
                hintText: 'ejemplo@correo.com',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
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
              if (_emailController.text.isNotEmpty) {
                Navigator.pop(context);
                _sendInvitation(_emailController.text);
              }
            },
            child: const Text('Enviar invitación'),
          ),
        ],
      ),
    );
  }

  void _sendInvitation(String email) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitación enviada a $email'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () {
            // Handle undo
          },
        ),
      ),
    );
  }
}

class SubscribersList extends StatelessWidget {
  const SubscribersList({super.key});

  @override
  Widget build(BuildContext context) {
    final subscribers = [
      {
        'id': '1',
        'name': 'Ana García',
        'email': 'ana.garcia@email.com',
        'status': 'active',
        'joinDate': '2024-03-01',
        'lastSeen': '2024-03-15',
        'totalReactions': 12,
        'totalComments': 3,
        'avatar': null,
      },
      {
        'id': '2',
        'name': 'Carlos Rodríguez',
        'email': 'carlos.r@email.com',
        'status': 'active',
        'joinDate': '2024-02-28',
        'lastSeen': '2024-03-14',
        'totalReactions': 8,
        'totalComments': 5,
        'avatar': null,
      },
      {
        'id': '3',
        'name': 'María López',
        'email': 'maria.lopez@email.com',
        'status': 'pending',
        'joinDate': '2024-03-10',
        'lastSeen': null,
        'totalReactions': 0,
        'totalComments': 0,
        'avatar': null,
      },
      {
        'id': '4',
        'name': 'José Martínez',
        'email': 'jose.martinez@email.com',
        'status': 'active',
        'joinDate': '2024-02-15',
        'lastSeen': '2024-03-12',
        'totalReactions': 3,
        'totalComments': 0,
        'avatar': null,
      },
      {
        'id': '5',
        'name': 'Laura Sánchez',
        'email': 'laura.sanchez@email.com',
        'status': 'inactive',
        'joinDate': '2024-01-20',
        'lastSeen': '2024-02-28',
        'totalReactions': 0,
        'totalComments': 0,
        'avatar': null,
      },
    ];

    return Column(
      children: subscribers.map((subscriber) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SubscriberCard(subscriber: subscriber),
      )).toList(),
    );
  }
}

class SubscriberCard extends StatelessWidget {
  final Map<String, dynamic> subscriber;

  const SubscriberCard({super.key, required this.subscriber});

  @override
  Widget build(BuildContext context) {
    final status = subscriber['status'] as String;
    final statusColor = status == 'active'
        ? Theme.of(context).colorScheme.primary
        : status == 'pending'
            ? Colors.orange
            : Theme.of(context).colorScheme.outline;
    
    final statusText = status == 'active'
        ? 'Activo'
        : status == 'pending'
            ? 'Pendiente'
            : 'Inactivo';

    return Card(
      child: InkWell(
        onTap: () => _showSubscriberDetails(context),
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
                  (subscriber['name'] as String).split(' ').map((n) => n[0]).take(2).join(''),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Subscriber Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subscriber['name'],
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            border: Border.all(color: statusColor, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 4),
                    
                    Text(
                      subscriber['email'],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        if (status == 'active') ...[
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${subscriber['totalReactions']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.comment,
                            size: 16,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${subscriber['totalComments']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 16),
                        ],
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Desde ${_formatDate(subscriber['joinDate'])}',
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
                onSelected: (value) => _handleAction(context, value, subscriber),
                itemBuilder: (context) => [
                  if (status == 'pending')
                    const PopupMenuItem(
                      value: 'resend',
                      child: Row(
                        children: [
                          Icon(Icons.refresh),
                          SizedBox(width: 8),
                          Text('Reenviar invitación'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'rotate_token',
                    child: Row(
                      children: [
                        Icon(Icons.key),
                        SizedBox(width: 8),
                        Text('Renovar enlace'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'copy_link',
                    child: Row(
                      children: [
                        Icon(Icons.copy),
                        SizedBox(width: 8),
                        Text('Copiar enlace'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle, color: Colors.red),
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
        ),
      ),
    );
  }

  void _showSubscriberDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SubscriberDetailsSheet(subscriber: subscriber),
    );
  }

  void _handleAction(BuildContext context, String action, Map<String, dynamic> subscriber) {
    switch (action) {
      case 'resend':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitación reenviada a ${subscriber['email']}')),
        );
        break;
      case 'rotate_token':
        _showRotateTokenDialog(context, subscriber);
        break;
      case 'copy_link':
        // Copy magic link to clipboard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enlace copiado al portapapeles')),
        );
        break;
      case 'remove':
        _showRemoveDialog(context, subscriber);
        break;
    }
  }

  void _showRotateTokenDialog(BuildContext context, Map<String, dynamic> subscriber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renovar enlace'),
        content: Text(
          'Esto creará un nuevo enlace único para ${subscriber['name']}. El enlace anterior dejará de funcionar.\n\n¿Estás seguro?',
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
                SnackBar(content: Text('Enlace renovado para ${subscriber['name']}')),
              );
            },
            child: const Text('Renovar'),
          ),
        ],
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, Map<String, dynamic> subscriber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar suscriptor'),
        content: Text(
          '¿Estás seguro de que quieres eliminar a ${subscriber['name']}?\n\nEsta acción no se puede deshacer.',
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
                SnackBar(content: Text('${subscriber['name']} eliminado')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                   'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class SubscriberDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> subscriber;

  const SubscriberDetailsSheet({super.key, required this.subscriber});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
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
                            (subscriber['name'] as String).split(' ').map((n) => n[0]).take(2).join(''),
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
                                subscriber['name'],
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                subscriber['email'],
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '${subscriber['totalReactions']}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Icon(Icons.favorite, color: Colors.red),
                                  Text(
                                    'Reacciones',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text(
                                    '${subscriber['totalComments']}',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(Icons.comment, color: Theme.of(context).colorScheme.secondary),
                                  Text(
                                    'Comentarios',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Info
                    Text(
                      'Información',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Se unió:', style: Theme.of(context).textTheme.bodyMedium),
                                Text(
                                  _formatDate(subscriber['joinDate']),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Última visita:', style: Theme.of(context).textTheme.bodyMedium),
                                Text(
                                  subscriber['lastSeen'] != null
                                      ? _formatDate(subscriber['lastSeen'])
                                      : 'Nunca',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Enlace copiado al portapapeles')),
                          );
                        },
                        icon: const Icon(Icons.copy, color: Colors.white),
                        label: const Text('Copiar enlace mágico'),
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

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
                   'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}