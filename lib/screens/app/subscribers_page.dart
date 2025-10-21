import 'package:flutter/material.dart';
import 'package:narra/services/email/email_service.dart';
import 'package:narra/services/email/subscriber_email_service.dart';
import 'package:narra/services/subscriber_service.dart';
import 'package:narra/services/user_service.dart';
import 'package:narra/supabase/supabase_config.dart';

class SubscribersPage extends StatefulWidget {
  const SubscribersPage({super.key});

  @override
  State<SubscribersPage> createState() => _SubscribersPageState();
}

enum _SubscriberFilter { all, confirmed, pending, unsubscribed }

class _SubscribersPageState extends State<SubscribersPage> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isRefreshing = false;
  SubscriberDashboardData? _dashboard;
  String? _errorMessage;
  _SubscriberFilter _filter = _SubscriberFilter.all;
  String _searchTerm = '';
  String? _authorDisplayName;
  final Set<String> _sendingInviteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard({bool silent = false}) async {
    if (_isLoading && silent) return;
    setState(() {
      if (silent) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
      _errorMessage = null;
    });

    try {
      final dashboardFuture = SubscriberService.getDashboardData(
        recentCommentLimit: 12,
        recentReactionLimit: 18,
      );
      final settingsFuture = UserService.getUserSettings();
      final profileFuture = UserService.getCurrentUserProfile();

      final dashboard = await dashboardFuture;

      Map<String, dynamic>? settings;
      Map<String, dynamic>? profile;

      try {
        settings = await settingsFuture;
      } catch (_) {
        settings = null;
      }

      try {
        profile = await profileFuture;
      } catch (_) {
        profile = null;
      }

      final displayName =
          _resolveAuthorDisplayName(settings: settings, profile: profile);
      if (!mounted) return;
      setState(() {
        _dashboard = dashboard;
        _authorDisplayName = displayName;
        if (!silent) {
          _isLoading = false;
        }
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (!silent) {
          _isLoading = false;
        }
        _isRefreshing = false;
        _errorMessage =
            'No pudimos cargar tus suscriptores. Intenta nuevamente.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar suscriptores: $error')),
      );
    }
  }

  List<Subscriber> get _filteredSubscribers {
    final dashboard = _dashboard;
    if (dashboard == null) return const [];

    final lowerQuery = _searchTerm.trim().toLowerCase();
    final engagement = dashboard.engagementBySubscriber;

    final subscribers = dashboard.subscribers.where((subscriber) {
      final matchesFilter = switch (_filter) {
        _SubscriberFilter.all => true,
        _SubscriberFilter.confirmed => subscriber.status == 'confirmed',
        _SubscriberFilter.pending => subscriber.status == 'pending',
        _SubscriberFilter.unsubscribed => subscriber.status == 'unsubscribed',
      };

      if (!matchesFilter) return false;

      if (lowerQuery.isEmpty) return true;

      final normalizedName = subscriber.name.toLowerCase();
      final normalizedEmail = subscriber.email.toLowerCase();
      return normalizedName.contains(lowerQuery) ||
          normalizedEmail.contains(lowerQuery);
    }).toList();

    DateTime? resolveDate(Subscriber subscriber) {
      final engagementDate = engagement[subscriber.id]?.lastInteractionAt;
      final lastAccess =
          subscriber.lastAccessAt ?? subscriber.magicLinkLastSentAt;
      return engagementDate ?? lastAccess ?? subscriber.createdAt;
    }

    subscribers.sort((a, b) {
      final dateA = resolveDate(a);
      final dateB = resolveDate(b);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return subscribers;
  }

  String _resolveAuthorDisplayName({
    Map<String, dynamic>? settings,
    Map<String, dynamic>? profile,
  }) {
    final settingsName = (settings?['public_author_name'] as String?)?.trim();
    if (settingsName != null && settingsName.isNotEmpty) {
      return settingsName;
    }

    final profileName = (profile?['name'] as String?)?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    return 'Tu autor/a en Narra';
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadDashboard(silent: true);
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchTerm = '';
      _filter = _SubscriberFilter.all;
    });
  }

  Future<void> _sendInvite(
    Subscriber subscriber, {
    bool showSuccessToast = true,
    bool refreshAfter = true,
  }) async {
    if (_sendingInviteIds.contains(subscriber.id)) {
      return;
    }

    final authorId = SupabaseAuth.currentUser?.id;
    if (authorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión nuevamente para enviar enlaces.'),
        ),
      );
      return;
    }

    setState(() {
      _sendingInviteIds.add(subscriber.id);
    });

    final messenger = ScaffoldMessenger.of(context);
    final displayName = (_authorDisplayName?.trim().isNotEmpty ?? false)
        ? _authorDisplayName!.trim()
        : 'Tu autor/a en Narra';

    try {
      final preparedSubscriber =
          await SubscriberService.ensureMagicKey(subscriber.id);

      await SubscriberEmailService.sendSubscriptionInvite(
        authorId: authorId,
        subscriber: preparedSubscriber,
        authorDisplayName: displayName,
        baseUri: Uri.base,
      );

      if (!mounted) return;

      if (showSuccessToast) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Listo, enviamos el enlace mágico a ${preparedSubscriber.email}.',
            ),
          ),
        );
      }

      if (refreshAfter) {
        await _loadDashboard(silent: true);
      }
    } on EmailServiceException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? 'No pudimos preparar el enlace mágico. Actualiza la página e inténtalo de nuevo.'
          : 'No se pudo enviar el enlace: $error';
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingInviteIds.remove(subscriber.id);
        });
      }
    }
  }

  Future<void> _showAddSubscriberDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final relationshipController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    final result = await showDialog<Subscriber?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Agregar suscriptor'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comparte historias con personas especiales. Recibirán un enlace mágico por correo.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del suscriptor',
                          hintText: 'Ej. Ana García',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa un nombre para mostrar en los comentarios.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'ejemplo@correo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Necesitamos el correo para enviar el enlace mágico.';
                          }
                          if (!trimmed.contains('@') ||
                              !trimmed.contains('.')) {
                            return 'Ingresa un correo válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: relationshipController,
                        decoration: const InputDecoration(
                          labelText: 'Relación (opcional)',
                          hintText: 'Familia, amistad, cliente…',
                          prefixIcon: Icon(Icons.favorite_outline),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setLocalState(() => isSaving = true);
                          try {
                            final subscriber =
                                await SubscriberService.createSubscriber(
                              name: nameController.text.trim(),
                              email: emailController.text.trim(),
                              relationship:
                                  relationshipController.text.trim().isEmpty
                                      ? null
                                      : relationshipController.text.trim(),
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop(subscriber);
                            }
                          } catch (error) {
                            setLocalState(() => isSaving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'No se pudo guardar al suscriptor: $error'),
                                ),
                              );
                            }
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1),
                  label: Text(isSaving ? 'Guardando…' : 'Agregar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Suscriptor agregado. Enviando su enlace mágico…',
          ),
        ),
      );
      await _sendInvite(result);
    }
  }

  Future<void> _confirmDeleteSubscriber(Subscriber subscriber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar suscriptor'),
        content: Text(
          '¿Seguro que quieres eliminar a ${subscriber.name}? Podrás volver a agregarlo más adelante.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SubscriberService.deleteSubscriber(subscriber.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${subscriber.name} ya no recibirá tus historias.')),
        );
        await _loadDashboard();
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar al suscriptor: $error')),
        );
      }
    }
  }

  void _openSubscriberDetails(Subscriber subscriber) {
    final engagement = _dashboard?.engagementFor(subscriber.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SubscriberDetailSheet(
        subscriber: subscriber,
        engagement: engagement,
        isSendingInvite: _sendingInviteIds.contains(subscriber.id),
        onSendInvite: () => _sendInvite(subscriber),
        onRemove: () {
          Navigator.of(context).pop();
          _confirmDeleteSubscriber(subscriber);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Suscripciones privadas'),
          actions: [
            IconButton(
              onPressed: () => _loadDashboard(),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadDashboard(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final dashboard = _dashboard;
    final subscribers = _filteredSubscribers;
    final hasAnySubscribers = (dashboard?.totalSubscribers ?? 0) > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suscripciones privadas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed:
                _isRefreshing ? null : () => _loadDashboard(silent: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FilledButton.icon(
              onPressed: _showAddSubscriberDialog,
              icon: const Icon(Icons.person_add_alt_1, size: 20),
              label: const Text('Agregar'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _IntroCard(
                  dashboard: dashboard,
                  onInvite: _showAddSubscriberDialog,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _StatsOverview(dashboard: dashboard),
              ),
            ),
            if ((dashboard?.recentComments.isNotEmpty ?? false) ||
                (dashboard?.recentReactions.isNotEmpty ?? false))
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: _RecentActivity(dashboard: dashboard!),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Buscar por nombre o correo…',
                        suffixIcon: _searchTerm.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchTerm = '');
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() => _searchTerm = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _FilterChips(
                      current: _filter,
                      onChanged: (filter) {
                        setState(() => _filter = filter);
                      },
                      counts: (
                        total: dashboard?.totalSubscribers ?? 0,
                        confirmed: dashboard?.confirmedSubscribers ?? 0,
                        pending: dashboard?.pendingSubscribers ?? 0,
                        unsubscribed: dashboard?.unsubscribedSubscribers ?? 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!hasAnySubscribers)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                  child: _EmptyState(onAdd: _showAddSubscriberDialog),
                ),
              )
            else if (subscribers.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                  child: _NoResultsPlaceholder(
                    onClearFilters: _resetFilters,
                    onAddSubscriber: _showAddSubscriberDialog,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subscriber = subscribers[index];
                    final engagement = dashboard?.engagementFor(subscriber.id);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        index == 0 ? 4 : 8,
                        16,
                        index == subscribers.length - 1 ? 24 : 8,
                      ),
                      child: _SubscriberCard(
                        subscriber: subscriber,
                        engagement: engagement,
                        onView: () => _openSubscriberDetails(subscriber),
                        onDelete: () => _confirmDeleteSubscriber(subscriber),
                        onResend: () => _sendInvite(subscriber),
                        isSendingInvite:
                            _sendingInviteIds.contains(subscriber.id),
                      ),
                    );
                  },
                  childCount: subscribers.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.dashboard, required this.onInvite});

  final SubscriberDashboardData? dashboard;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = dashboard?.totalSubscribers ?? 0;
    final engaged =
        dashboard?.subscribersEngagedWithin(const Duration(days: 7)) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.mail_outline,
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
                      'Comparte tus recuerdos en privado',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Envía enlaces mágicos únicos. Tus suscriptores pueden dejar comentarios y corazones con su nombre.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _IntroStat(
                label: 'Suscriptores',
                value: '$total',
                icon: Icons.people_outline,
              ),
              _IntroStat(
                label: 'Activos esta semana',
                value: '$engaged',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onInvite,
            icon: const Icon(Icons.alternate_email),
            label: const Text('Invitar a alguien nuevo'),
          ),
        ],
      ),
    );
  }
}

class _IntroStat extends StatelessWidget {
  const _IntroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsOverview extends StatelessWidget {
  const _StatsOverview({required this.dashboard});

  final SubscriberDashboardData? dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final total = dashboard?.totalSubscribers ?? 0;
    final confirmed = dashboard?.confirmedSubscribers ?? 0;
    final pending = dashboard?.pendingSubscribers ?? 0;
    final unsubscribed = dashboard?.unsubscribedSubscribers ?? 0;
    final hearts = dashboard?.totalReactions ?? 0;
    final comments = dashboard?.totalComments ?? 0;

    final stats = [
      _StatTile(
        icon: Icons.people_alt_outlined,
        label: 'Total de suscriptores',
        value: '$total',
        color: colorScheme.primary,
      ),
      _StatTile(
        icon: Icons.check_circle_outline,
        label: 'Confirmados',
        value: '$confirmed',
        color: Colors.teal,
      ),
      _StatTile(
        icon: Icons.hourglass_bottom,
        label: 'Pendientes',
        value: '$pending',
        color: Colors.orange,
      ),
      _StatTile(
        icon: Icons.no_accounts,
        label: 'Desuscritos',
        value: '$unsubscribed',
        color: colorScheme.error,
      ),
      _StatTile(
        icon: Icons.favorite_border,
        label: 'Corazones recibidos',
        value: '$hearts',
        color: Colors.pink,
      ),
      _StatTile(
        icon: Icons.chat_bubble_outline,
        label: 'Comentarios',
        value: '$comments',
        color: colorScheme.secondary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 840;
        final crossAxisCount = isWide ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isWide ? 3.5 : 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            return stats[index];
          },
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.current,
    required this.onChanged,
    required this.counts,
  });

  final _SubscriberFilter current;
  final ValueChanged<_SubscriberFilter> onChanged;
  final ({int total, int confirmed, int pending, int unsubscribed}) counts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildChip(_SubscriberFilter filter, String label, int count) {
      final isSelected = current == filter;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Text('($count)', style: theme.textTheme.bodySmall),
          ],
        ),
        selected: isSelected,
        onSelected: (_) => onChanged(filter),
        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: isSelected ? colorScheme.primary : null,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildChip(_SubscriberFilter.all, 'Todos', counts.total),
        buildChip(_SubscriberFilter.confirmed, 'Confirmados', counts.confirmed),
        buildChip(_SubscriberFilter.pending, 'Pendientes', counts.pending),
        buildChip(
          _SubscriberFilter.unsubscribed,
          'Desuscritos',
          counts.unsubscribed,
        ),
      ],
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.dashboard});

  final SubscriberDashboardData dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comments = dashboard.recentComments;
    final reactions = dashboard.recentReactions;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Actividad reciente',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (comments.isNotEmpty) ...[
              Text('Comentarios', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...comments.take(4).map((comment) => _ActivityTile(
                    title: comment.subscriberName ?? 'Suscriptor',
                    subtitle: _truncate(comment.content),
                    trailing: _formatRelativeDate(comment.createdAt),
                    icon: Icons.chat_bubble_outline,
                    iconColor: theme.colorScheme.secondary,
                  )),
              const SizedBox(height: 16),
            ],
            if (reactions.isNotEmpty) ...[
              Text('Corazones enviados', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              ...reactions.take(6).map((reaction) => _ActivityTile(
                    title: reaction.subscriberName ?? 'Suscriptor',
                    subtitle: reaction.storyTitle,
                    trailing: _formatRelativeDate(reaction.createdAt),
                    icon: Icons.favorite,
                    iconColor: Colors.pinkAccent,
                  )),
            ],
            if (comments.isEmpty && reactions.isEmpty)
              Text(
                'Aún no hay actividad. Cuando envíes tus historias, verás aquí los comentarios y reacciones.',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({
    required this.subscriber,
    required this.engagement,
    required this.onView,
    required this.onDelete,
    required this.onResend,
    required this.isSendingInvite,
  });

  final Subscriber subscriber;
  final SubscriberEngagement? engagement;
  final VoidCallback onView;
  final VoidCallback onDelete;
  final Future<void> Function() onResend;
  final bool isSendingInvite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initials = subscriber.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .take(2)
        .map((segment) => segment.substring(0, 1))
        .join()
        .toUpperCase();

    final hearts = engagement?.totalReactions ?? 0;
    final comments = engagement?.totalComments ?? 0;
    final lastInteraction =
        engagement?.lastInteractionAt ?? subscriber.lastAccessAt;

    final status = subscriber.status;
    final (Color, String) statusDisplay = switch (status) {
      'confirmed' => (colorScheme.primary, 'Confirmado'),
      'unsubscribed' => (colorScheme.error, 'Desuscrito'),
      _ => (Colors.orange, 'Pendiente'),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        colorScheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      initials.isEmpty ? 'S' : initials,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subscriber.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: statusDisplay.$1.withValues(alpha: 0.12),
                              ),
                              child: Text(
                                statusDisplay.$2,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: statusDisplay.$1,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Reenviar enlace de suscripción',
                              onPressed:
                                  isSendingInvite ? null : () => onResend(),
                              icon: isSendingInvite
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.mark_email_read_outlined,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subscriber.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (subscriber.relationship?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              subscriber.relationship!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') {
                        onView();
                      } else if (value == 'resend') {
                        onResend();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined),
                            SizedBox(width: 8),
                            Text('Ver detalles'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'resend',
                        child: Row(
                          children: [
                            Icon(Icons.mail_outline),
                            SizedBox(width: 8),
                            Text('Reenviar enlace'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Eliminar',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _MetricChip(
                    icon: Icons.favorite_border,
                    label: 'Corazones',
                    value: hearts,
                    color: Colors.pink,
                  ),
                  _MetricChip(
                    icon: Icons.chat_bubble_outline,
                    label: 'Comentarios',
                    value: comments,
                    color: theme.colorScheme.secondary,
                  ),
                  if (lastInteraction != null)
                    _MetricChip(
                      icon: Icons.schedule,
                      label: 'Última actividad',
                      valueLabel: _formatRelativeDate(lastInteraction),
                      color: theme.colorScheme.outline,
                    )
                  else
                    _MetricChip(
                      icon: Icons.schedule,
                      label: 'Sin actividad aún',
                      valueLabel: '—',
                      color: theme.colorScheme.outline,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: isSendingInvite ? null : onResend,
                    icon: isSendingInvite
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.email_outlined),
                    label: Text(isSendingInvite
                        ? 'Enviando enlace…'
                        : 'Reenviar enlace mágico'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Ver detalles'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.value,
    this.valueLabel,
    required this.color,
  }) : assert(value != null || valueLabel != null);

  final IconData icon;
  final String label;
  final int? value;
  final String? valueLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valueLabel ?? '$value',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mail_outline, size: 64, color: theme.colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          'Todavía no has agregado suscriptores',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Invítalos para que reciban tus historias con un enlace único y puedan dejarte mensajes.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Agregar suscriptor'),
        ),
      ],
    );
  }
}

class _NoResultsPlaceholder extends StatelessWidget {
  const _NoResultsPlaceholder({
    required this.onClearFilters,
    required this.onAddSubscriber,
  });

  final VoidCallback onClearFilters;
  final VoidCallback onAddSubscriber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.search_off_rounded,
            size: 60, color: colorScheme.outline.withValues(alpha: 0.9)),
        const SizedBox(height: 16),
        Text(
          'No encontramos coincidencias',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 420,
          child: Text(
            'Ajusta la búsqueda o cambia los filtros para ver a tus suscriptores. También puedes agregar a alguien nuevo al instante.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Restablecer filtros'),
            ),
            OutlinedButton.icon(
              onPressed: onAddSubscriber,
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Agregar suscriptor'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubscriberDetailSheet extends StatefulWidget {
  const _SubscriberDetailSheet({
    required this.subscriber,
    this.engagement,
    required this.onSendInvite,
    required this.isSendingInvite,
    required this.onRemove,
  });

  final Subscriber subscriber;
  final SubscriberEngagement? engagement;
  final Future<void> Function() onSendInvite;
  final bool isSendingInvite;
  final VoidCallback onRemove;

  @override
  State<_SubscriberDetailSheet> createState() => _SubscriberDetailSheetState();
}

class _SubscriberDetailSheetState extends State<_SubscriberDetailSheet> {
  late Future<_SubscriberDetailData> _detailFuture;
  bool _localSendingInvite = false;
  late Subscriber _subscriber;

  @override
  void initState() {
    super.initState();
    _subscriber = widget.subscriber;
    _detailFuture = _loadDetail();
  }

  Future<_SubscriberDetailData> _loadDetail() async {
    final comments = await SubscriberService.getCommentsForSubscriber(
      _subscriber.id,
      limit: 40,
    );
    final reactions = await SubscriberService.getReactionsForSubscriber(
      _subscriber.id,
      limit: 40,
    );
    return _SubscriberDetailData(comments: comments, reactions: reactions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriber = _subscriber;
    final engagement = widget.engagement;
    final sendingInvite = _localSendingInvite || widget.isSendingInvite;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: FutureBuilder<_SubscriberDetailData>(
              future: _detailFuture,
              builder: (context, snapshot) {
                final comments = snapshot.data?.comments ?? const [];
                final reactions = snapshot.data?.reactions ?? const [];

                return CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subscriber.name,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        subscriber.email,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      if (subscriber.relationship?.isNotEmpty ==
                                          true)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            subscriber.relationship!,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar suscriptor',
                                  onPressed: widget.onRemove,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                _MetricChip(
                                  icon: Icons.favorite,
                                  label: 'Corazones',
                                  value: engagement?.totalReactions ?? 0,
                                  color: Colors.pink,
                                ),
                                _MetricChip(
                                  icon: Icons.chat_bubble_outline,
                                  label: 'Comentarios',
                                  value: engagement?.totalComments ?? 0,
                                  color: theme.colorScheme.secondary,
                                ),
                                _MetricChip(
                                  icon: Icons.link,
                                  label: 'Enlace generado',
                                  valueLabel: _formatLongDate(
                                    subscriber.magicKeyCreatedAt ??
                                        subscriber.createdAt,
                                  ),
                                  color: theme.colorScheme.outline,
                                ),
                                _MetricChip(
                                  icon: Icons.mark_email_read_outlined,
                                  label: 'Último envío',
                                  valueLabel:
                                      subscriber.magicLinkLastSentAt != null
                                          ? _formatRelativeDate(
                                              subscriber.magicLinkLastSentAt!,
                                            )
                                          : 'Nunca enviado',
                                  color: theme.colorScheme.primary,
                                ),
                                _MetricChip(
                                  icon: Icons.schedule,
                                  label: 'Último acceso',
                                  valueLabel: subscriber.lastAccessAt != null
                                      ? _formatRelativeDate(
                                          subscriber.lastAccessAt!)
                                      : 'Sin registro',
                                  color: theme.colorScheme.outline,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: sendingInvite
                                      ? null
                                      : () async {
                                          setState(
                                              () => _localSendingInvite = true);
                                          try {
                                            await widget.onSendInvite();
                                            try {
                                              final refreshed =
                                                  await SubscriberService
                                                      .getSubscriberById(
                                                subscriber.id,
                                              );
                                              if (mounted) {
                                                setState(() {
                                                  _subscriber = refreshed;
                                                  _detailFuture = _loadDetail();
                                                });
                                              }
                                            } catch (_) {
                                              // Si la recarga falla, ignoramos; el envío ya fue gestionado.
                                            }
                                          } finally {
                                            if (mounted) {
                                              setState(() =>
                                                  _localSendingInvite = false);
                                            }
                                          }
                                        },
                                  icon: sendingInvite
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.email_outlined),
                                  label: Text(
                                    sendingInvite
                                        ? 'Enviando enlace…'
                                        : 'Reenviar enlace mágico',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          child: Text(
                            'Comentarios',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (comments.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text(
                              'Todavía no ha dejado comentarios.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final comment = comments[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: _SubscriberFeedbackEntry(
                                  icon: Icons.chat_bubble_outline,
                                  accentColor: theme.colorScheme.secondary,
                                  content: [
                                    Text(
                                      comment.subscriberName ?? subscriber.name,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      comment.content,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${comment.storyTitle} • ${_formatRelativeDate(comment.createdAt)}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: comments.length,
                          ),
                        ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Text(
                            'Reacciones enviadas',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      if (reactions.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            child: Text(
                              'Aún no ha reaccionado con corazones.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final reaction = reactions[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                child: _SubscriberFeedbackEntry(
                                  icon: Icons.favorite,
                                  accentColor: Colors.pink,
                                  content: [
                                    Text(
                                      reaction.storyTitle,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatRelativeDate(reaction.createdAt),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            childCount: reactions.length,
                          ),
                        ),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _SubscriberDetailData {
  const _SubscriberDetailData({
    required this.comments,
    required this.reactions,
  });

  final List<SubscriberCommentRecord> comments;
  final List<SubscriberReactionRecord> reactions;
}

class _SubscriberFeedbackEntry extends StatelessWidget {
  const _SubscriberFeedbackEntry({
    required this.icon,
    required this.accentColor,
    required this.content,
  });

  final IconData icon;
  final Color accentColor;
  final List<Widget> content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _truncate(String text, {int maxLength = 140}) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Hace instantes';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
  return _formatLongDate(date);
}

String _formatLongDate(DateTime date) {
  final months = [
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
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}
