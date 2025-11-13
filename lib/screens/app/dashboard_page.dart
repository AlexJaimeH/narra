import 'dart:async';

import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:narra/api/narra_api.dart';
import 'package:narra/repositories/user_repository.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/services/subscriber_service.dart';
import 'package:narra/services/story_share_link_builder.dart';
import 'package:narra/services/user_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'story_editor_page.dart';
import 'app_navigation.dart';
import 'subscribers_page.dart';
import 'dashboard_walkthrough_controller.dart';

enum _DashboardWalkthroughStep {
  menu,
  createStory,
  ghostWriter,
  bookProgress,
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    this.menuKey,
    this.walkthroughController,
  });

  final GlobalKey? menuKey;
  final DashboardWalkthroughController? walkthroughController;

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
  bool _shouldShowGhostWriterIntro = false;
  List<String> _cachedSuggestedTopics = [];
  bool _isWalkthroughActive = false;
  bool _shouldShowWalkthrough = false;
  final List<_DashboardWalkthroughStep> _walkthroughSteps = [];
  int _currentWalkthroughStepIndex = 0;
  bool _isAdvancingWalkthrough = false;

  // Keys para el walkthrough
  final GlobalKey _createStoryKey = GlobalKey();
  final GlobalKey _ghostWriterKey = GlobalKey();
  final GlobalKey _bookProgressKey = GlobalKey();

  // ScrollController para el walkthrough
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    widget.walkthroughController?.setTapHandler(null);
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _calculateSuggestedTopics(List<StoryTag> allTags) {
    final usedTags = allTags.map((t) => t.name.toLowerCase()).toSet();

    const excludedTopics = {
      'otros momentos',
      'recuerdos unicos',
      'recuerdos únicos',
      'sin categoría',
      'sin categoria',
      'naturaleza',
      'recuperacion',
      'recuperación',
      'cultura',
      'hogar',
      'amistad',
      'graduación',
      'graduacion',
      'mentoría laboral',
      'mentoria laboral',
      'fe y esperanza',
      'recetas favoritas',
      'música',
      'musica',
      'tecnología',
      'tecnologia',
      'conversaciones especiales',
    };

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
      'Arte',
      'Música',
      'Comida',
      'Deportes',
      'Tradiciones',
      'Sueños',
      'Reflexiones',
      'Amor',
      'Salud',
      'Educación',
      'Fotografía',
      'Tecnología',
      'Libros',
      'Cine',
      'Juegos',
      'Voluntariado',
      'Emprendimiento',
    ];

    final unusedTopics = commonTopics
        .where((topic) =>
            !usedTags.contains(topic.toLowerCase()) &&
            !excludedTopics.contains(topic.toLowerCase()))
        .toList();

    unusedTopics.shuffle();
    return unusedTopics.take(5).toList();
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
      final publishedStories = allStories.where((s) => s.isPublished).toList()
        ..sort((a, b) => (b.publishedAt ?? b.updatedAt)
            .compareTo(a.publishedAt ?? a.updatedAt));
      final lastPublished =
          publishedStories.isNotEmpty ? publishedStories.first : null;

      // Check if should show ghost writer intro
      final shouldShowIntro = await UserService.shouldShowGhostWriterIntro();

      final shouldShowWalkthrough =
          await UserService.shouldShowHomeWalkthrough();

      if (mounted) {
        // Calculate suggested topics once to avoid random changes on rebuild
        final suggestedTopics = _calculateSuggestedTopics(allTags);

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
          _shouldShowGhostWriterIntro = shouldShowIntro;
          _cachedSuggestedTopics = suggestedTopics;
          _isLoading = false;
          _shouldShowWalkthrough = shouldShowWalkthrough;
        });

        _checkAndShowWalkthrough();
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

  Future<void> _checkAndShowWalkthrough() async {
    if (!mounted) return;

    if (!_shouldShowWalkthrough || _isWalkthroughActive) {
      return;
    }

    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _shouldShowWalkthrough && !_isWalkthroughActive) {
        _startWalkthrough();
      }
    });
  }

  void _updateWalkthroughControllerBinding() {
    widget.walkthroughController?.setTapHandler(
      _isWalkthroughActive ? _handleWalkthroughTap : null,
    );
  }

  void _startWalkthrough() {
    if (!mounted) return;

    final steps = <_DashboardWalkthroughStep>[];

    if (widget.menuKey != null) {
      steps.add(_DashboardWalkthroughStep.menu);
    }

    steps.add(_DashboardWalkthroughStep.createStory);

    if (_shouldShowGhostWriterIntro) {
      steps.add(_DashboardWalkthroughStep.ghostWriter);
    }

    steps.add(_DashboardWalkthroughStep.bookProgress);

    if (steps.isEmpty) {
      return;
    }

    final allContextsReady = steps
        .map(_keyForStep)
        .every((stepKey) => stepKey.currentContext != null);

    if (!allContextsReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shouldShowWalkthrough) {
          _startWalkthrough();
        }
      });
      return;
    }

    _walkthroughSteps
      ..clear()
      ..addAll(steps);
    _currentWalkthroughStepIndex = 0;

    if (!_isWalkthroughActive) {
      setState(() {
        _isWalkthroughActive = true;
      });
    }

    _updateWalkthroughControllerBinding();

    unawaited(_prepareForStep(_walkthroughSteps.first).then((_) {
      if (mounted && _isWalkthroughActive) {
        _showCurrentWalkthroughStep();
      }
    }));
  }

  Future<void> _scrollToWidget(GlobalKey key) async {
    if (!_scrollController.hasClients || key.currentContext == null) return;

    final RenderBox? box = key.currentContext!.findRenderObject() as RenderBox?;
    if (box != null && mounted) {
      final position = box.localToGlobal(Offset.zero);
      final screenHeight = MediaQuery.of(context).size.height;
      // Calcular el offset para centrar el widget
      final targetScroll = _scrollController.offset +
          position.dy -
          (screenHeight / 2) +
          (box.size.height / 2);

      await _scrollController.animateTo(
        targetScroll.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 750),
        curve: Curves.easeInOut,
      );

      await Future.delayed(const Duration(milliseconds: 450));
    }
  }

  void _handleWalkthroughTap() {
    unawaited(_advanceWalkthrough());
  }

  GlobalKey _keyForStep(_DashboardWalkthroughStep step) {
    switch (step) {
      case _DashboardWalkthroughStep.menu:
        return widget.menuKey!;
      case _DashboardWalkthroughStep.createStory:
        return _createStoryKey;
      case _DashboardWalkthroughStep.ghostWriter:
        return _ghostWriterKey;
      case _DashboardWalkthroughStep.bookProgress:
        return _bookProgressKey;
    }
  }

  Future<void> _prepareForStep(_DashboardWalkthroughStep step) async {
    if (!mounted) return;

    switch (step) {
      case _DashboardWalkthroughStep.menu:
        if (_scrollController.hasClients) {
          await _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }
        break;
      case _DashboardWalkthroughStep.createStory:
        // El widget de bienvenida ya está visible tras el menú.
        break;
      case _DashboardWalkthroughStep.ghostWriter:
        await _scrollToWidget(_ghostWriterKey);
        break;
      case _DashboardWalkthroughStep.bookProgress:
        await _scrollToWidget(_bookProgressKey);
        break;
    }
  }

  void _showCurrentWalkthroughStep() {
    if (!mounted || _walkthroughSteps.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isWalkthroughActive) {
        return;
      }

      final GlobalKey targetKey =
          _keyForStep(_walkthroughSteps[_currentWalkthroughStepIndex]);

      if (targetKey.currentContext == null) {
        Future.delayed(const Duration(milliseconds: 60), () {
          if (!mounted || !_isWalkthroughActive) {
            return;
          }

          _showCurrentWalkthroughStep();
        });
        return;
      }

      final showcase = ShowCaseWidget.of(context);
      if (showcase == null) {
        return;
      }

      showcase.startShowCase([targetKey]);
    });
  }

  Future<void> _advanceWalkthrough() async {
    if (!mounted || !_isWalkthroughActive || _walkthroughSteps.isEmpty) {
      return;
    }

    if (_isAdvancingWalkthrough) {
      return;
    }

    _isAdvancingWalkthrough = true;

    try {
      ShowCaseWidget.of(context).dismiss();
      await Future.delayed(const Duration(milliseconds: 220));

      final nextIndex = _currentWalkthroughStepIndex + 1;

      if (nextIndex >= _walkthroughSteps.length) {
        await _finishWalkthrough();
        return;
      }

      final nextStep = _walkthroughSteps[nextIndex];
      await _prepareForStep(nextStep);

      if (!mounted || !_isWalkthroughActive) {
        return;
      }

      setState(() {
        _currentWalkthroughStepIndex = nextIndex;
      });

      await Future.delayed(const Duration(milliseconds: 120));

      if (!mounted || !_isWalkthroughActive) {
        return;
      }

      _showCurrentWalkthroughStep();
    } finally {
      _isAdvancingWalkthrough = false;
    }
  }

  Future<void> _finishWalkthrough() async {
    if (!mounted) return;

    ShowCaseWidget.of(context).dismiss();

    if (mounted) {
      setState(() {
        _isWalkthroughActive = false;
        _shouldShowWalkthrough = false;
      });
      _updateWalkthroughControllerBinding();
    }

    await UserService.markHomeWalkthroughAsSeen();
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Check loading state
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scaffold = Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          controller: _scrollController,
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
                child: Showcase(
                  key: _createStoryKey,
                  description:
                      'Aquí puedes crear tus historias. Toca el botón verde para empezar a escribir tus recuerdos.',
                  descTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: Colors.white,
                  ),
                  tooltipBackgroundColor: const Color(0xFF2D7A6E),
                  textColor: Colors.white,
                  tooltipPadding: const EdgeInsets.all(20),
                  tooltipBorderRadius: BorderRadius.circular(16),
                  overlayColor: Colors.black,
                  overlayOpacity: 0.60,
                  disableDefaultTargetGestures: true,
                  onTargetClick: _handleWalkthroughTap,
                  onToolTipClick: _handleWalkthroughTap,
                  onBarrierClick: _handleWalkthroughTap,
                  child: _WelcomeSection(
                    userProfile: _userProfile,
                    allTags: _allTags,
                    draftStories: _draftStories,
                    stats: _dashboardStats,
                    suggestedTopics: _cachedSuggestedTopics,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Introducción del Ghost Writer (solo la primera vez)
              if (_shouldShowGhostWriterIntro)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Showcase(
                    key: _ghostWriterKey,
                    description:
                        'Tu Ghost Writer es un asistente inteligente que te ayuda a mejorar tus historias. Haz clic en Configurar para personalizarlo.',
                    descTextStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: Colors.white,
                    ),
                    tooltipBackgroundColor: const Color(0xFF5B21B6),
                    textColor: Colors.white,
                    tooltipPadding: const EdgeInsets.all(20),
                    tooltipBorderRadius: BorderRadius.circular(16),
                    overlayColor: Colors.black,
                    overlayOpacity: 0.60,
                    disableDefaultTargetGestures: true,
                    onTargetClick: _handleWalkthroughTap,
                    onToolTipClick: _handleWalkthroughTap,
                    onBarrierClick: _handleWalkthroughTap,
                    child: _GhostWriterIntroCard(
                      onDismiss: () {
                        setState(() => _shouldShowGhostWriterIntro = false);
                      },
                    ),
                  ),
                ),

              if (_shouldShowGhostWriterIntro) const SizedBox(height: 16),

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
                child: Showcase(
                  key: _bookProgressKey,
                  description:
                      '¡Tu meta es escribir al menos 20 historias para publicar tu libro digital! Pero no te preocupes, puedes publicarlo con más historias si lo deseas. Cada historia cuenta para tu progreso.',
                  descTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: Colors.white,
                  ),
                  tooltipBackgroundColor: const Color(0xFF6B4DE6),
                  textColor: Colors.white,
                  tooltipPadding: const EdgeInsets.all(20),
                  tooltipBorderRadius: BorderRadius.circular(16),
                  overlayColor: Colors.black,
                  overlayOpacity: 0.60,
                  disableDefaultTargetGestures: true,
                  onTargetClick: _handleWalkthroughTap,
                  onToolTipClick: _handleWalkthroughTap,
                  onBarrierClick: _handleWalkthroughTap,
                  child: _BookProgressSection(
                    stats: _dashboardStats,
                    lastPublishedStory: _lastPublishedStory,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Actividades recientes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RecentActivitiesSection(
                  activity: _dashboardStats?['recent_activity'] ?? [],
                  subscriberDashboard: _subscriberDashboard,
                  userProfile: _userProfile,
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        scaffold,
        if (_isWalkthroughActive)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleWalkthroughTap,
              onPanStart: (_) {},
              onPanUpdate: (_) {},
              onVerticalDragStart: (_) {},
              onVerticalDragUpdate: (_) {},
              onHorizontalDragStart: (_) {},
              onHorizontalDragUpdate: (_) {},
              child: Container(
                color: Colors.black.withValues(alpha: 0.02),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.walkthroughController != widget.walkthroughController) {
      oldWidget.walkthroughController?.setTapHandler(null);
      _updateWalkthroughControllerBinding();
    }
  }
}

/// Sección de bienvenida mejorada con sugerencias
class _WelcomeSection extends StatelessWidget {
  final Map<String, dynamic>? userProfile;
  final List<StoryTag> allTags;
  final List<Story> draftStories;
  final Map<String, dynamic>? stats;
  final List<String> suggestedTopics;

  const _WelcomeSection({
    required this.userProfile,
    required this.allTags,
    required this.draftStories,
    required this.stats,
    required this.suggestedTopics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Corregido: usar nombre completo en lugar de solo el primer nombre
    final userName = userProfile?['name'] ?? 'Usuario';
    final hasDrafts = draftStories.isNotEmpty;
    final totalStories = stats?['total_stories'] ?? 0;

    return Card(
      elevation: 4,
      shadowColor: colorScheme.primary.withValues(alpha: 0.2),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.25),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Fondo decorativo con gradiente
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.06),
                    colorScheme.primaryContainer.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con saludo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, $userName!',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalStories == 0
                                ? 'Comienza tu primera historia'
                                : hasDrafts
                                    ? '${draftStories.length} borrador${draftStories.length > 1 ? 'es' : ''} esperando por ti'
                                    : '¿Qué historia compartirás hoy?',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Mensaje inspirador
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_stories,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          totalStories == 0
                              ? 'Cada gran libro empieza con una sola palabra. Hoy es tu día para escribir la tuya.'
                              : 'Tus recuerdos son tesoros. Cada historia que escribes es un regalo para el futuro.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sugerencias de temas
                if (suggestedTopics.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Temas para inspirarte:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: suggestedTopics.map((topic) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          topic,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 24),

                // Botones de acción
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
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text(
                          'Crear historia',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          shadowColor:
                              colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonal(
                      onPressed: () => _openEditorWithSuggestions(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openEditorWithSuggestions(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const StoryEditorPage(
          openSuggestionsAutomatically: true,
        ),
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

    // Usar un color más vibrante y atractivo
    final bookColor = Color.lerp(
      colorScheme.primary,
      const Color(0xFF6B4DE6), // Morado vibrante
      0.4,
    )!;

    return Card(
      elevation: 0,
      color: bookColor.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: bookColor.withValues(alpha: 0.25),
          width: 1.5,
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
                    color: bookColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: bookColor,
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
                          color: colorScheme.onSurface,
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
                    color: bookColor,
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
                valueColor: AlwaysStoppedAnimation<Color>(bookColor),
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
                    color: bookColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: bookColor,
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
              child: FilledButton(
                onPressed: () {
                  // Navegar a la página de Historias
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => _StoriesPageNavigator(),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: bookColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ver historias publicadas',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 18),
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

/// Sección de actividades recientes
class _RecentActivitiesSection extends StatelessWidget {
  final List<dynamic> activity;
  final SubscriberDashboardData? subscriberDashboard;
  final Map<String, dynamic>? userProfile;

  const _RecentActivitiesSection({
    required this.activity,
    required this.subscriberDashboard,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Combinar todas las actividades
    final activities = <_ActivityItem>[];
    final authorId = userProfile?['id'] as String?;

    // Agregar actividades del autor
    for (final act in activity.take(5)) {
      if (act is UserActivity) {
        VoidCallback? onTap;
        // Si la actividad tiene un entityId (ID de historia), navegar a esa historia
        if (act.entityId != null) {
          onTap = () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoryEditorPage(storyId: act.entityId!),
              ),
            );
          };
        }

        activities.add(_ActivityItem(
          icon: _getActivityIcon(act.activityType.name),
          title: act.displayMessage,
          subtitle: _formatTimeAgo(act.createdAt),
          color: colorScheme.primary,
          date: act.createdAt,
          onTap: onTap,
        ));
      }
    }

    // Agregar comentarios de suscriptores
    if (subscriberDashboard != null && authorId != null) {
      for (final comment in subscriberDashboard!.recentComments.take(3)) {
        VoidCallback? onTap;
        // Generar magic link para el comentario
        if (comment.subscriberId != null && comment.storyId.isNotEmpty) {
          final subscriber = subscriberDashboard!.subscribers
              .where((s) => s.id == comment.subscriberId)
              .firstOrNull;

          if (subscriber != null && subscriber.magicKey.isNotEmpty) {
            onTap = () async {
              final magicLink = StoryShareLinkBuilder.buildStoryLink(
                story: Story(
                  id: comment.storyId,
                  userId: authorId,
                  title: comment.storyTitle,
                  content: '',
                  status: StoryStatus.published,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  completenessScore: 0,
                  wordCount: 0,
                  readingTime: 0,
                  isVoiceGenerated: false,
                  storyTags: [],
                  photos: [],
                ),
                subscriber: StoryShareTarget(
                  id: subscriber.id,
                  name: subscriber.name,
                  token: subscriber.magicKey,
                  source: comment.source ?? 'dashboard',
                ),
              );

              if (await canLaunchUrl(magicLink)) {
                await launchUrl(magicLink,
                    mode: LaunchMode.externalApplication);
              }
            };
          }
        }

        activities.add(_ActivityItem(
          icon: Icons.chat_bubble,
          title: '${comment.subscriberName ?? 'Suscriptor'} comentó',
          subtitle: _truncate(comment.content, maxLength: 60),
          color: colorScheme.secondary,
          date: comment.createdAt,
          onTap: onTap,
        ));
      }

      // Agregar reacciones de suscriptores
      for (final reaction in subscriberDashboard!.recentReactions.take(3)) {
        VoidCallback? onTap;
        // Generar magic link para la reacción
        if (reaction.subscriberId != null && reaction.storyId.isNotEmpty) {
          final subscriber = subscriberDashboard!.subscribers
              .where((s) => s.id == reaction.subscriberId)
              .firstOrNull;

          if (subscriber != null && subscriber.magicKey.isNotEmpty) {
            onTap = () async {
              final magicLink = StoryShareLinkBuilder.buildStoryLink(
                story: Story(
                  id: reaction.storyId,
                  userId: authorId,
                  title: reaction.storyTitle,
                  content: '',
                  status: StoryStatus.published,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  completenessScore: 0,
                  wordCount: 0,
                  readingTime: 0,
                  isVoiceGenerated: false,
                  storyTags: [],
                  photos: [],
                ),
                subscriber: StoryShareTarget(
                  id: subscriber.id,
                  name: subscriber.name,
                  token: subscriber.magicKey,
                  source: reaction.source ?? 'dashboard',
                ),
              );

              if (await canLaunchUrl(magicLink)) {
                await launchUrl(magicLink,
                    mode: LaunchMode.externalApplication);
              }
            };
          }
        }

        activities.add(_ActivityItem(
          icon: Icons.favorite,
          title: '${reaction.subscriberName ?? 'Suscriptor'} dio corazón',
          subtitle: 'En "${reaction.storyTitle}"',
          color: Colors.red,
          date: reaction.createdAt,
          onTap: onTap,
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubscribersPage(),
              ),
            );
          },
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
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: activity.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
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
                          if (activity.onTap != null)
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                        ],
                      ),
                    ),
                  ),
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
  final VoidCallback? onTap;

  _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.date,
    this.onTap,
  });
}

/// Widget helper para navegar a la página de Historias con la pestaña de Publicadas seleccionada
class _StoriesPageNavigator extends StatefulWidget {
  @override
  State<_StoriesPageNavigator> createState() => _StoriesPageNavigatorState();
}

class _StoriesPageNavigatorState extends State<_StoriesPageNavigator> {
  @override
  void initState() {
    super.initState();
    // Navegar a la página principal con el índice de Historias
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const AppNavigation(initialIndex: 1),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar un loading mientras se navega
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Widget de introducción al Ghost Writer
class _GhostWriterIntroCard extends StatelessWidget {
  final VoidCallback onDismiss;

  const _GhostWriterIntroCard({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Color especial para el ghost writer - un morado/violeta suave pero vibrante
    final ghostWriterColor = const Color(0xFF7C3AED);

    return Card(
      elevation: 4,
      shadowColor: ghostWriterColor.withValues(alpha: 0.3),
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: ghostWriterColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Stack(
        children: [
          // Fondo decorativo sutil
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ghostWriterColor.withValues(alpha: 0.05),
                    colorScheme.primary.withValues(alpha: 0.03),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con ícono y título
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            ghostWriterColor,
                            ghostWriterColor.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: ghostWriterColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Conoce a tu Ghost Writer',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: ghostWriterColor,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tu compañero de confianza',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: ghostWriterColor.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Mensaje emotivo principal
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ghostWriterColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ghostWriterColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Imagina tener un editor profesional a tu lado, alguien que entiende tus historias y las transforma en relatos dignos de un libro. '
                    'Ese es tu Ghost Writer: un asistente inteligente que pulirá cada palabra, respetando tu voz y tus recuerdos.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Características destacadas
                _buildFeature(
                  context,
                  icon: Icons.brush_outlined,
                  title: 'Pulido profesional',
                  description: 'Mejora tu redacción manteniendo tu esencia',
                  color: ghostWriterColor,
                ),
                const SizedBox(height: 12),
                _buildFeature(
                  context,
                  icon: Icons.favorite_outline,
                  title: 'Respeta tu voz',
                  description: 'Conserva tus emociones y estilo personal',
                  color: ghostWriterColor,
                ),
                const SizedBox(height: 12),
                _buildFeature(
                  context,
                  icon: Icons.auto_stories_outlined,
                  title: 'Calidad de libro',
                  description: 'Historias listas para compartir con orgullo',
                  color: ghostWriterColor,
                ),

                const SizedBox(height: 24),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          // Navegar a ajustes del ghost writer
                          await UserService.markGhostWriterAsConfigured();
                          onDismiss();
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AppNavigation(initialIndex: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.settings, size: 20),
                        label: const Text(
                          'Configurar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: ghostWriterColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 3,
                          shadowColor: ghostWriterColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await UserService.dismissGhostWriterIntro();
                          onDismiss();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ghostWriterColor,
                          side: BorderSide(color: ghostWriterColor, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Entendido',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
    );
  }

  Widget _buildFeature(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
