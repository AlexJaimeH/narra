import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
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

// Helper para mostrar SnackBars consistentes
void _showSnackBar(BuildContext context, String message,
    {bool isError = false, bool isSuccess = false}) {
  final colorScheme = Theme.of(context).colorScheme;
  final icon = isError
      ? Icons.error_outline
      : isSuccess
          ? Icons.check_circle
          : Icons.info_outline;
  final bgColor = isError
      ? colorScheme.errorContainer
      : isSuccess
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest;
  final iconColor = isError
      ? colorScheme.error
      : isSuccess
          ? colorScheme.primary
          : colorScheme.onSurfaceVariant;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: bgColor,
      behavior: SnackBarBehavior.floating,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      content: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError
                    ? colorScheme.onErrorContainer
                    : isSuccess
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      duration: Duration(seconds: isError ? 4 : 3),
    ),
  );
}

class _SubscribersPageState extends State<SubscribersPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isRefreshing = false;
  SubscriberDashboardData? _dashboard;
  String? _errorMessage;
  _SubscriberFilter _filter = _SubscriberFilter.all;
  String _searchTerm = '';
  String? _authorDisplayName;
  final Set<String> _sendingInviteIds = <String>{};
  late AnimationController _fabController;

  // GlobalKeys para el walkthrough
  final GlobalKey _addButtonKey = GlobalKey();
  final GlobalKey _searchFieldKey = GlobalKey();
  final GlobalKey _statsCardsKey = GlobalKey();
  final GlobalKey _subscribersListKey = GlobalKey();
  final GlobalKey _filterChipsKey = GlobalKey();

  // Contexto del ShowCaseWidget builder
  BuildContext? _showcaseContext;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadDashboard();
  }

  Future<void> _checkAndShowWalkthrough() async {
    final shouldShow = await UserService.shouldShowSubscribersWalkthrough();
    if (!shouldShow || !mounted) return;

    // RADICALLY SIMPLE: Just one postFrameCallback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startWalkthrough();
    });
  }

  void _startWalkthrough() {
    if (_showcaseContext == null) return;

    // RADICALLY SIMPLE: Just add keys, no validation
    final keys = <GlobalKey>[
      _addButtonKey,
      _statsCardsKey,
      _filterChipsKey,
    ];

    // Only add list key if there are subscribers
    if ((_dashboard?.totalSubscribersIncludingUnsubscribed ?? 0) > 0) {
      keys.add(_subscribersListKey);
    }

    ShowCaseWidget.of(_showcaseContext!).startShowCase(keys);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fabController.dispose();
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
      _fabController.forward();

      // Check walkthrough after loading
      _checkAndShowWalkthrough();
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
    }
  }

  List<Subscriber> get _filteredSubscribers {
    final dashboard = _dashboard;
    if (dashboard == null) return const [];

    final lowerQuery = _searchTerm.trim().toLowerCase();
    final engagement = dashboard.engagementBySubscriber;

    final subscribers = dashboard.subscribers.where((subscriber) {
      final matchesFilter = switch (_filter) {
        _SubscriberFilter.all => subscriber.status != 'unsubscribed',
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
      _showSnackBar(
        context,
        'Debes iniciar sesión nuevamente para enviar enlaces.',
        isError: true,
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
      // Si el suscriptor está desuscrito, reactivarlo como pendiente
      final wasUnsubscribed = subscriber.status == 'unsubscribed';
      if (wasUnsubscribed) {
        await SubscriberService.reactivateUnsubscribed(subscriber.id);
      }

      final preparedSubscriber =
          await SubscriberService.ensureMagicKey(subscriber.id);

      await SubscriberEmailService.sendSubscriptionInvite(
        authorId: authorId,
        subscriber: preparedSubscriber,
        authorDisplayName: displayName,
      );

      if (!mounted) return;

      if (showSuccessToast) {
        final message = wasUnsubscribed
            ? '${preparedSubscriber.name} ha sido reactivado y se envió nuevo enlace'
            : 'Enlace enviado a ${preparedSubscriber.name}';
        _showSnackBar(
          context,
          message,
          isSuccess: true,
        );
      }

      if (refreshAfter) {
        await _loadDashboard(silent: true);
      }
    } on EmailServiceException catch (error) {
      if (!mounted) return;
      _showSnackBar(context, error.message, isError: true);
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? 'No pudimos preparar el enlace mágico. Actualiza la página e inténtalo de nuevo.'
          : 'No se pudo enviar el enlace: $error';
      _showSnackBar(context, message, isError: true);
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_add_alt_1,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Text('Nuevo suscriptor'),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invita a alguien especial a recibir tus historias mediante un enlace mágico único.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre completo',
                          hintText: 'Ej. Ana García López',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa un nombre.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'ejemplo@correo.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'El correo es necesario para el enlace mágico.';
                          }
                          if (!trimmed.contains('@') || !trimmed.contains('.')) {
                            return 'Ingresa un correo válido.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: relationshipController,
                        decoration: InputDecoration(
                          labelText: 'Relación (opcional)',
                          hintText: 'Familia, amistad, cliente…',
                          prefixIcon: const Icon(Icons.favorite_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
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
                              _showSnackBar(
                                context,
                                'No se pudo guardar: $error',
                                isError: true,
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
                      : const Icon(Icons.check),
                  label: Text(isSaving ? 'Guardando…' : 'Agregar y enviar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      _showSnackBar(context, 'Enviando enlace mágico…');
      await _sendInvite(result);
    }
  }

  Future<void> _confirmDeleteSubscriber(Subscriber subscriber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
            size: 32,
          ),
        ),
        title: const Text('Eliminar suscriptor'),
        content: Text(
          '¿Estás seguro de eliminar a ${subscriber.name}? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
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
        _showSnackBar(
          context,
          '${subscriber.name} fue eliminado',
          isSuccess: true,
        );
        await _loadDashboard();
      } catch (error) {
        if (!mounted) return;
        _showSnackBar(context, 'Error al eliminar: $error', isError: true);
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
    return ShowCaseWidget(
      blurValue: 4,
      disableBarrierInteraction: true,
      onFinish: () => UserService.markSubscribersWalkthroughAsSeen(),
      builder: (showcaseContext) {
        _showcaseContext = showcaseContext;
        return _buildContent(showcaseContext);
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Cargando suscriptores…',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 64, color: colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _loadDashboard(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dashboard = _dashboard;
    final subscribers = _filteredSubscribers;
    final hasAnySubscribers = (dashboard?.totalSubscribersIncludingUnsubscribed ?? 0) > 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Showcase(
                    key: _searchFieldKey,
                    description: 'Busca tus suscriptores por nombre o email aquí.',
                    descTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Colors.white,
                    ),
                    tooltipBackgroundColor: const Color(0xFF6366F1),
                    textColor: Colors.white,
                    tooltipPadding: const EdgeInsets.all(24),
                    tooltipBorderRadius: BorderRadius.circular(20),
                    overlayColor: Colors.black,
                    overlayOpacity: 0.60,
                    disableDefaultTargetGestures: true,
                    onTargetClick: () => ShowCaseWidget.of(context).next(),
                    onToolTipClick: () => ShowCaseWidget.of(context).next(),
                    onBarrierClick: () => ShowCaseWidget.of(context).dismiss(),
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
                                Icons.people_alt_rounded,
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
                                    'Suscriptores',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Gestiona tu audiencia, envía invitaciones y mantén el contacto con quienes siguen tus historias.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              onPressed: _isRefreshing ? null : () => _loadDashboard(silent: true),
                              tooltip: 'Actualizar suscriptores',
                              icon: _isRefreshing
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Showcase(
                  key: _statsCardsKey,
                  description: '¡Tus estadísticas al instante! Ve cuántos suscriptores tienes en total, cuántos confirmaron su invitación y cuántos están pendientes.',
                  descTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: Colors.white,
                  ),
                  tooltipBackgroundColor: const Color(0xFF10B981),
                  textColor: Colors.white,
                  tooltipPadding: const EdgeInsets.all(24),
                  tooltipBorderRadius: BorderRadius.circular(20),
                  overlayColor: Colors.black,
                  overlayOpacity: 0.60,
                  disableDefaultTargetGestures: true,
                  onTargetClick: () => ShowCaseWidget.of(context).next(),
                  onToolTipClick: () => ShowCaseWidget.of(context).next(),
                  onBarrierClick: () => ShowCaseWidget.of(context).dismiss(),
                  child: _StatsOverview(dashboard: dashboard),
                ),
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
                        filled: true,
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Buscar por nombre o correo…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
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
                    Showcase(
                      key: _filterChipsKey,
                      description: 'Filtra tus suscriptores: ve todos, solo confirmados, pendientes de confirmación o los que se dieron de baja.',
                      descTextStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: Colors.white,
                      ),
                      tooltipBackgroundColor: const Color(0xFFF59E0B),
                      textColor: Colors.white,
                      tooltipPadding: const EdgeInsets.all(24),
                      tooltipBorderRadius: BorderRadius.circular(20),
                      overlayColor: Colors.black,
                      overlayOpacity: 0.60,
                      disableDefaultTargetGestures: true,
                      onTargetClick: () => ShowCaseWidget.of(context).next(),
                      onToolTipClick: () => ShowCaseWidget.of(context).next(),
                      onBarrierClick: () => ShowCaseWidget.of(context).dismiss(),
                      child: _FilterChips(
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
                    ),
                  ],
                ),
              ),
            ),
            if (!hasAnySubscribers)
              SliverFillRemaining(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: _EmptyState(onAdd: _showAddSubscriberDialog),
                ),
              )
            else if (subscribers.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                  child: _NoResultsPlaceholder(
                    onClearFilters: _resetFilters,
                    onAddSubscriber: _showAddSubscriberDialog,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final subscriber = subscribers[index];
                      final engagement = dashboard?.engagementFor(subscriber.id);

                      // Envolver el primer item con Showcase
                      final card = _SubscriberCard(
                        subscriber: subscriber,
                        engagement: engagement,
                        onTap: () => _openSubscriberDetails(subscriber),
                        onResend: () => _sendInvite(subscriber),
                        isSendingInvite:
                            _sendingInviteIds.contains(subscriber.id),
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: index == 0
                            ? Showcase(
                                key: _subscribersListKey,
                                description: 'Aquí están todos tus suscriptores. Toca uno para ver detalles, reenviar invitación o editar su información. Ve sus reacciones y comentarios.',
                                descTextStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: Colors.white,
                                ),
                                tooltipBackgroundColor: const Color(0xFF3B82F6),
                                textColor: Colors.white,
                                tooltipPadding: const EdgeInsets.all(24),
                                tooltipBorderRadius: BorderRadius.circular(20),
                                overlayColor: Colors.black,
                                overlayOpacity: 0.60,
                                disableDefaultTargetGestures: true,
                                onTargetClick: () => ShowCaseWidget.of(context).next(),
                                onToolTipClick: () => ShowCaseWidget.of(context).next(),
                                onBarrierClick: () => ShowCaseWidget.of(context).dismiss(),
                                child: card,
                              )
                            : card,
                      );
                    },
                    childCount: subscribers.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Showcase(
        key: _addButtonKey,
        description: '¡Aquí puedes agregar nuevos suscriptores! Solo necesitas su nombre y email. Ellos recibirán una invitación y podrán ver únicamente tus historias PUBLICADAS.',
        descTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: Colors.white,
        ),
        tooltipBackgroundColor: const Color(0xFF8B5CF6),
        textColor: Colors.white,
        tooltipPadding: const EdgeInsets.all(24),
        tooltipBorderRadius: BorderRadius.circular(20),
        overlayColor: Colors.black,
        overlayOpacity: 0.60,
        disableDefaultTargetGestures: true,
        onTargetClick: () => ShowCaseWidget.of(context).next(),
        onToolTipClick: () => ShowCaseWidget.of(context).next(),
        onBarrierClick: () => ShowCaseWidget.of(context).dismiss(),
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: _fabController,
            curve: Curves.easeOutBack,
          ),
          child: FloatingActionButton.extended(
            onPressed: _showAddSubscriberDialog,
            icon: const Icon(Icons.person_add_alt_1, size: 24),
            label: const Text(
              'Agregar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            elevation: 6,
            highlightElevation: 12,
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final total = dashboard?.totalSubscribers ?? 0;
    final confirmed = dashboard?.confirmedSubscribers ?? 0;
    final hearts = dashboard?.totalReactions ?? 0;
    final comments = dashboard?.totalComments ?? 0;

    if (isMobile) {
      // En móvil: dos filas de dos cards cada una
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people_alt_outlined,
                  label: 'Total',
                  value: '$total',
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Activos',
                  value: '$confirmed',
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.favorite,
                  label: 'Corazones',
                  value: '$hearts',
                  color: colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.chat_bubble,
                  label: 'Comentarios',
                  value: '$comments',
                  color: colorScheme.tertiary,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // En desktop: una fila de cuatro cards
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_alt_outlined,
            label: 'Total',
            value: '$total',
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Activos',
            value: '$confirmed',
            color: colorScheme.tertiary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.favorite,
            label: 'Corazones',
            value: '$hearts',
            color: colorScheme.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.chat_bubble,
            label: 'Comentarios',
            value: '$comments',
            color: colorScheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
      return GestureDetector(
        onTap: () => onChanged(filter),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.onPrimary.withValues(alpha: 0.2)
                      : colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
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
    final colorScheme = theme.colorScheme;
    final comments = dashboard.recentComments.take(3).toList();
    final reactions = dashboard.recentReactions.take(4).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome,
                      color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Actividad reciente',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (comments.isEmpty && reactions.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Cuando tus suscriptores interactúen con tus historias, verás aquí su actividad.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              if (comments.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...comments.map((comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ActivityTile(
                        title: comment.subscriberName ?? 'Suscriptor',
                        subtitle: _truncate(comment.content, maxLength: 80),
                        trailing: _formatRelativeDate(comment.createdAt),
                        icon: Icons.chat_bubble,
                        iconColor: colorScheme.secondary,
                      ),
                    )),
              ],
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: reactions
                      .map((reaction) => Chip(
                            avatar: const Icon(Icons.favorite, size: 16),
                            label: Text(
                              reaction.subscriberName ?? 'Suscriptor',
                              style: theme.textTheme.bodySmall,
                            ),
                            backgroundColor:
                                colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            side: BorderSide.none,
                          ))
                      .toList(),
                ),
              ],
            ],
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
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(
          trailing,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SubscriberCard extends StatelessWidget {
  const _SubscriberCard({
    required this.subscriber,
    required this.engagement,
    required this.onTap,
    required this.onResend,
    required this.isSendingInvite,
  });

  final Subscriber subscriber;
  final SubscriberEngagement? engagement;
  final VoidCallback onTap;
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
    final status = subscriber.status;

    final (Color statusColor, IconData statusIcon, String statusLabel) =
        switch (status) {
      'confirmed' => (colorScheme.primary, Icons.check_circle, 'Activo'),
      'unsubscribed' => (colorScheme.error, Icons.block, 'Desuscrito'),
      _ => (colorScheme.tertiary, Icons.schedule, 'Pendiente'),
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: subscriber.status == 'unsubscribed' ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Hero(
                tag: 'subscriber-${subscriber.id}',
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text(
                    initials.isEmpty ? '?' : initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subscriber.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (hearts > 0)
                          _MiniMetric(
                            icon: Icons.favorite,
                            value: hearts,
                            color: colorScheme.secondary,
                          ),
                        if (hearts > 0 && comments > 0) const SizedBox(width: 8),
                        if (comments > 0)
                          _MiniMetric(
                            icon: Icons.chat_bubble,
                            value: comments,
                            color: colorScheme.tertiary,
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Reenviar enlace',
                          onPressed: isSendingInvite ? null : onResend,
                          icon: isSendingInvite
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.primary,
                                  ),
                                )
                              : Icon(Icons.send, color: colorScheme.primary),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                colorScheme.primaryContainer.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
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
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Tu comunidad empieza aquí',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Invita a personas especiales para compartir\ntus historias de forma privada y segura.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Agregar primer suscriptor'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
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

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 64, color: colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No encontramos resultados',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con otros términos o ajusta los filtros',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonal(
                onPressed: onClearFilters,
                child: const Text('Restablecer filtros'),
              ),
              OutlinedButton(
                onPressed: onAddSubscriber,
                child: const Text('Agregar nuevo'),
              ),
            ],
          ),
        ],
      ),
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

class _SubscriberDetailSheetState extends State<_SubscriberDetailSheet>
    with SingleTickerProviderStateMixin {
  late Future<_SubscriberDetailData> _detailFuture;
  bool _localSendingInvite = false;
  late Subscriber _subscriber;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _subscriber = widget.subscriber;
    _detailFuture = _loadDetail();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final colorScheme = theme.colorScheme;
    final subscriber = _subscriber;
    final engagement = widget.engagement;
    final sendingInvite = _localSendingInvite || widget.isSendingInvite;

    final initials = subscriber.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .take(2)
        .map((segment) => segment.substring(0, 1))
        .join()
        .toUpperCase();

    final status = subscriber.status;
    final (Color statusColor, IconData statusIcon, String statusLabel) =
        switch (status) {
      'confirmed' => (colorScheme.primary, Icons.check_circle, 'Activo'),
      'unsubscribed' => (colorScheme.error, Icons.block, 'Desuscrito'),
      _ => (colorScheme.tertiary, Icons.schedule, 'Pendiente'),
    };

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: controller,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Hero(
                            tag: 'subscriber-${subscriber.id}',
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: statusColor.withValues(alpha: 0.15),
                              child: Text(
                                initials.isEmpty ? '?' : initials,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subscriber.name,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subscriber.email,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (subscriber.relationship?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      subscriber.relationship!,
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onRemove,
                            icon: const Icon(Icons.delete_outline),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.errorContainer
                                  .withValues(alpha: 0.5),
                              foregroundColor: colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 20, color: statusColor),
                            const SizedBox(width: 8),
                            Text(
                              statusLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _DetailMetric(
                              icon: Icons.favorite,
                              label: 'Corazones',
                              value: '${engagement?.totalReactions ?? 0}',
                              color: colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DetailMetric(
                              icon: Icons.chat_bubble,
                              label: 'Comentarios',
                              value: '${engagement?.totalComments ?? 0}',
                              color: colorScheme.tertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: sendingInvite
                              ? null
                              : () async {
                                  setState(() => _localSendingInvite = true);
                                  try {
                                    await widget.onSendInvite();
                                    if (mounted) {
                                      final refreshed = await SubscriberService
                                          .getSubscriberById(subscriber.id);
                                      setState(() {
                                        _subscriber = refreshed;
                                        _detailFuture = _loadDetail();
                                      });
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => _localSendingInvite = false);
                                    }
                                  }
                                },
                          icon: sendingInvite
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            sendingInvite
                                ? 'Enviando…'
                                : 'Reenviar enlace mágico',
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Comentarios'),
                          Tab(text: 'Reacciones'),
                        ],
                      ),
                    ],
                  ),
                ),
                FutureBuilder<_SubscriberDetailData>(
                  future: _detailFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final comments = snapshot.data?.comments ?? [];
                    final reactions = snapshot.data?.reactions ?? [];

                    // Determine which tab is active and show its content
                    return AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, child) {
                        final isCommentsTab = _tabController.index == 0;
                        if (isCommentsTab) {
                          return _CommentsTabContent(
                            comments: comments,
                            subscriber: subscriber,
                          );
                        } else {
                          return _ReactionsTabContent(
                            reactions: reactions,
                            subscriber: subscriber,
                          );
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentsTab extends StatelessWidget {
  const _CommentsTab({
    required this.comments,
    required this.subscriber,
    required this.controller,
  });

  final List<SubscriberCommentRecord> comments;
  final Subscriber subscriber;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Sin comentarios aún',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(20),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _FeedbackCard(
          icon: Icons.chat_bubble,
          color: theme.colorScheme.secondary,
          title: comment.subscriberName ?? subscriber.name,
          content: comment.content,
          metadata: '${comment.storyTitle} • ${_formatRelativeDate(comment.createdAt)}',
        );
      },
    );
  }
}

class _CommentsTabContent extends StatelessWidget {
  const _CommentsTabContent({
    required this.comments,
    required this.subscriber,
  });

  final List<SubscriberCommentRecord> comments;
  final Subscriber subscriber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin comentarios aún',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...comments.map((comment) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _FeedbackCard(
              icon: Icons.chat_bubble,
              color: theme.colorScheme.secondary,
              title: comment.subscriberName ?? subscriber.name,
              content: comment.content,
              metadata: '${comment.storyTitle} • ${_formatRelativeDate(comment.createdAt)}',
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ReactionsTab extends StatelessWidget {
  const _ReactionsTab({
    required this.reactions,
    required this.subscriber,
    required this.controller,
  });

  final List<SubscriberReactionRecord> reactions;
  final Subscriber subscriber;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (reactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_outline,
                size: 64,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Sin reacciones aún',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.all(20),
      itemCount: reactions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final reaction = reactions[index];
        return _FeedbackCard(
          icon: Icons.favorite,
          color: theme.colorScheme.secondary,
          title: reaction.storyTitle,
          content: null,
          metadata: _formatRelativeDate(reaction.createdAt),
        );
      },
    );
  }
}

class _ReactionsTabContent extends StatelessWidget {
  const _ReactionsTabContent({
    required this.reactions,
    required this.subscriber,
  });

  final List<SubscriberReactionRecord> reactions;
  final Subscriber subscriber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (reactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_outline,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin reacciones aún',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...reactions.map((reaction) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: _FeedbackCard(
              icon: Icons.favorite,
              color: theme.colorScheme.secondary,
              title: reaction.storyTitle,
              content: null,
              metadata: _formatRelativeDate(reaction.createdAt),
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.icon,
    required this.color,
    required this.title,
    this.content,
    required this.metadata,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? content;
  final String metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (content != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    content!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  metadata,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

String _truncate(String text, {int maxLength = 140}) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}…';
}

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
  if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
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
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
