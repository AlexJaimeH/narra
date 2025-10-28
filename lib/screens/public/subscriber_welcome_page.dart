import 'dart:async';

import 'package:flutter/material.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/public_access/public_author_profile.dart';
import 'package:narra/services/public_access/story_access_manager.dart';
import 'package:narra/services/public_access/story_access_record.dart';
import 'package:narra/services/public_access/story_feedback_service.dart';
import 'package:narra/services/public_access/story_public_access_service.dart';
import 'package:narra/services/public_access/story_feedback_service.dart';
import 'package:narra/services/public_story_service.dart';
import 'package:narra/services/story_share_link_builder.dart';

class SubscriberWelcomePage extends StatefulWidget {
  const SubscriberWelcomePage({
    super.key,
    required this.subscriberId,
  });

  final String subscriberId;

  @override
  State<SubscriberWelcomePage> createState() => _SubscriberWelcomePageState();
}

class _SubscriberWelcomePageState extends State<SubscriberWelcomePage> {
  bool _isLoading = true;
  String? _errorMessage;
  StoryAccessRecord? _accessRecord;
  PublicAuthorProfile? _authorProfile;
  String? _subscriberName;
  List<Story> _stories = const [];
  Story? _highlightStory;
  bool _highlightHearted = false;
  bool _showWelcomeBanner = false;
  bool _isUnsubscribed = false;
  bool _isUnsubscribing = false;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_initialize);
  }

  Future<void> _loadHighlightFeedback(Story story) async {
    final record = _accessRecord;
    final token = record?.accessToken;
    if (record == null || token == null || token.isEmpty) {
      return;
    }

    try {
      final feedback = await StoryFeedbackService.fetchState(
        authorId: story.userId,
        storyId: story.id,
        subscriberId: record.subscriberId,
        token: token,
        source: 'subscriber-library',
      );
      if (!mounted) return;
      setState(() {
        _highlightHearted = feedback.hasReacted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _highlightHearted = false;
      });
    }
  }

  Future<void> _initialize() async {
    final payload = _InvitePayload.fromCurrentUri(widget.subscriberId);
    if (payload == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'El enlace parece incompleto. Solicita uno nuevo al autor.';
      });
      return;
    }

    try {
      final record = await StoryPublicAccessService.registerAccess(
        authorId: payload.authorId,
        subscriberId: widget.subscriberId,
        token: payload.token,
        source: payload.source ?? 'invite',
        eventType: 'invite_opened',
      );

      if (record == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Este enlace ya no es válido. Pide uno nuevo al autor.';
        });
        return;
      }

      StoryAccessManager.grantAccess(
        authorId: payload.authorId,
        subscriberId: record.subscriberId,
        subscriberName: record.subscriberName,
        accessToken: record.accessToken,
        source: record.source,
        grantedAt: record.grantedAt,
        status: record.status,
        supabaseUrl: record.supabaseUrl,
        supabaseAnonKey: record.supabaseAnonKey,
      );

      final latestStories = await PublicStoryService.getLatestStories(
        authorId: payload.authorId,
        limit: 8,
      );
      final sortedStories = List<Story>.from(latestStories)
        ..sort((a, b) {
          DateTime resolveDate(Story story) =>
              story.publishedAt ?? story.updatedAt;
          return resolveDate(b).compareTo(resolveDate(a));
        });

      final profile =
          await PublicStoryService.getAuthorProfile(payload.authorId);

      String? authorName = payload.authorDisplayName;
      if (authorName == null || authorName.trim().isEmpty) {
        if (profile != null) {
          authorName = profile.resolvedDisplayName;
        } else if (sortedStories.isNotEmpty) {
          authorName = sortedStories.first.authorDisplayName ??
              sortedStories.first.authorName;
        }
      }

      authorName ??=
          await PublicStoryService.getAuthorDisplayName(payload.authorId) ??
              'Tu autor/a en Narra';

      final highlightStory =
          sortedStories.isNotEmpty ? sortedStories.first : null;

      final effectiveProfile = (profile != null)
          ? profile.copyWith(
              displayName: profile.displayName ?? authorName,
              name: profile.name ?? authorName,
              avatarUrl: profile.avatarUrl ?? highlightStory?.authorAvatarUrl,
            )
          : PublicAuthorProfile(
              id: payload.authorId,
              name: authorName,
              displayName: authorName,
              avatarUrl: highlightStory?.authorAvatarUrl,
              tagline: null,
              summary: null,
              coverImageUrl: null,
            );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _accessRecord = record;
        _authorProfile = effectiveProfile;
        _subscriberName =
            payload.subscriberName ?? record.subscriberName ?? 'Suscriptor';
        _stories = sortedStories;
        _highlightStory = highlightStory;
        _showWelcomeBanner =
            payload.showWelcomeBanner || (payload.source ?? '') == 'invite';
        _isUnsubscribed = record.status == 'unsubscribed';
      });

      if (highlightStory != null && !_isUnsubscribed) {
        await _refreshHighlightFeedback(highlightStory);
      }
    } on StoryPublicAccessException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'No pudimos validar tu enlace en este momento. Inténtalo de nuevo más tarde.';
      });
    }
  }

  Future<void> _refreshHighlightFeedback(Story story) async {
    final record = _accessRecord;
    final token = record?.accessToken;
    if (record == null || token == null || token.isEmpty) {
      return;
    }

    try {
      final feedback = await StoryFeedbackService.fetchState(
        authorId: story.userId,
        storyId: story.id,
        subscriberId: record.subscriberId,
        token: token,
        source: 'subscriber-library',
        supabaseUrl: record.supabaseUrl,
        supabaseAnonKey: record.supabaseAnonKey,
      );
      if (!mounted) return;
      setState(() {
        _highlightHearted = feedback.hasReacted;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _highlightHearted = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 20),
                  Text(
                    'No pudimos validar tu acceso',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushReplacementNamed('/'),
                    icon: const Icon(Icons.home_outlined),
                    label: const Text('Ir al inicio de Narra'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final profile = _authorProfile;
    final subscriberName = _subscriberName ?? 'Suscriptor';
    final displayName = profile?.resolvedDisplayName ?? 'Tu autor/a en Narra';
    final highlightStory = !_isUnsubscribed ? _highlightStory : null;
    final otherStories =
        highlightStory != null ? _stories.skip(1).toList() : _stories;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface,
                colorScheme.surfaceVariant.withOpacity(0.35),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroSection(
                      context: context,
                      profile: profile,
                      subscriberName: subscriberName,
                      onReadLatest: highlightStory != null && !_isUnsubscribed
                          ? () => _openStory(highlightStory)
                          : null,
                      totalStories: _stories.length,
                      isUnsubscribed: _isUnsubscribed,
                      highlightHearted: _highlightHearted,
                      highlightStory: highlightStory,
                    ),
                    if (_showWelcomeBanner && !_isUnsubscribed) ...[
                      const SizedBox(height: 24),
                      _buildAccessInfoCard(
                        context: context,
                        subscriberName: subscriberName,
                        authorName: displayName,
                      ),
                    ],
                    if (highlightStory != null && !_isUnsubscribed) ...[
                      const SizedBox(height: 32),
                      _FeaturedStoryCard(
                        story: highlightStory,
                        onOpen: () => _openStory(highlightStory),
                        highlightHearted: _highlightHearted,
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (_isUnsubscribed)
                      _buildUnsubscribedBanner(context, displayName)
                    else if (_stories.isEmpty)
                      _buildEmptyStoriesState(
                        context: context,
                        authorName: displayName,
                      )
                    else if (otherStories.isNotEmpty)
                      _buildStoriesSection(
                        context: context,
                        stories: otherStories,
                      ),
                    const SizedBox(height: 32),
                    _buildUnsubscribeSection(context, displayName),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required BuildContext context,
    required PublicAuthorProfile? profile,
    required String subscriberName,
    VoidCallback? onReadLatest,
    required int totalStories,
    required bool isUnsubscribed,
    required bool highlightHearted,
    Story? highlightStory,
  }) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 720;
    final hasCover = profile?.coverImageUrl?.trim().isNotEmpty == true;
    final displayName = profile?.resolvedDisplayName ?? 'Tu autor/a en Narra';
    final tagline = profile?.tagline?.trim();
    final summary = profile?.summary?.trim();
    final fallbackSummary =
        'Este es tu espacio privado para leer las historias que $displayName comparte contigo.';

    final statsChips = _buildAuthorStats(
      theme: theme,
      totalStories: totalStories,
      highlightStory: highlightStory,
      highlightHearted: highlightHearted,
      isCompact: isCompact,
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.15),
            blurRadius: 60,
            offset: const Offset(0, 20),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
        child: Stack(
          children: [
            // Background - Cover image or gradient
            if (hasCover)
              Positioned.fill(
                child: Image.network(
                  profile!.coverImageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasCover
                        ? [
                            const Color(0xFFfdfbf7).withOpacity(0.96),
                            const Color(0xFFf0ebe3).withOpacity(0.92),
                          ]
                        : [
                            const Color(0xFFfaf5ff), // Light purple
                            const Color(0xFFfdfbf7), // Cream
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(isCompact ? 24 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7c3aed).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.waving_hand, size: 16, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Hola, $subscriberName',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isCompact ? 20 : 24),
                  // Author info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _AuthorPortrait(avatarUrl: profile?.avatarUrl, isCompact: isCompact),
                      SizedBox(width: isCompact ? 16 : 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: (isCompact
                                ? theme.textTheme.headlineSmall
                                : theme.textTheme.headlineLarge)?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.5,
                                color: const Color(0xFF1f1b16),
                              ),
                            ),
                            if (tagline?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                tagline!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFF6d28d9),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 20 : 24),
                  // Description
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Text(
                      summary?.isNotEmpty == true ? summary! : fallbackSummary,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.65,
                        fontSize: isCompact ? 16 : 17,
                        color: const Color(0xFF4b5563),
                      ),
                    ),
                  ),
                  // Stats chips
                  if (statsChips.isNotEmpty) ...[
                    SizedBox(height: isCompact ? 20 : 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: statsChips,
                    ),
                  ],
                  // Action buttons
                  SizedBox(height: isCompact ? 24 : 32),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (onReadLatest != null && !isUnsubscribed)
                        ElevatedButton.icon(
                          onPressed: onReadLatest,
                          icon: const Icon(Icons.auto_stories, size: 20),
                          label: Text(isCompact ? 'Leer última historia' : 'Leer la historia más reciente'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8b5cf6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 20 : 28,
                              vertical: isCompact ? 14 : 18,
                            ),
                            elevation: 0,
                            shadowColor: const Color(0xFF7c3aed).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/'),
                        icon: const Icon(Icons.explore_outlined, size: 20),
                        label: const Text('Explorar Narra'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6d28d9),
                          side: const BorderSide(color: Color(0xFF8b5cf6), width: 2),
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 20 : 28,
                            vertical: isCompact ? 14 : 18,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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

  Widget _buildAccessInfoCard({
    required BuildContext context,
    required String subscriberName,
    required String authorName,
  }) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 600;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFfaf5ff), Color(0xFFf3e8ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF8b5cf6).withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.1),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCompact ? 20 : 28),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7c3aed).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.white,
                size: 28,
              ),
            ),
            SizedBox(width: isCompact ? 16 : 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✨ Acceso Confirmado',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF6d28d9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Guardamos que eres $subscriberName. Cada vez que $authorName publique un nuevo recuerdo podrás abrirlo desde aquí, reaccionar con corazones y dejar comentarios privados.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.65,
                      fontSize: 15,
                      color: const Color(0xFF4b5563),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.email_outlined, size: 16, color: Color(0xFF8b5cf6)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Recibirás un correo con cada nueva historia',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6d28d9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildStoriesSection({
    required BuildContext context,
    required List<Story> stories,
  }) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 720;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7c3aed).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.menu_book,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Más Historias',
                    style: (isCompact
                      ? theme.textTheme.headlineSmall
                      : theme.textTheme.headlineMedium)?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1f1b16),
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    '${stories.length} ${stories.length == 1 ? 'historia publicada' : 'historias publicadas'}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6b7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          children: stories
              .map(
                (story) => _StoryGridCard(
                  story: story,
                  onOpen: () => _openStory(story),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  List<Widget> _buildAuthorStats({
    required ThemeData theme,
    required int totalStories,
    Story? highlightStory,
    bool highlightHearted = false,
    bool isCompact = false,
  }) {
    final chips = <Widget>[];

    if (totalStories > 0) {
      final label = totalStories == 1
          ? '1 historia publicada'
          : '$totalStories historias publicadas';
      chips.add(_StatChip(
        icon: Icons.auto_stories_outlined,
        label: label,
      ));
    }

    final lastDate = highlightStory?.publishedAt ?? highlightStory?.updatedAt;
    if (lastDate != null) {
      chips.add(_StatChip(
        icon: Icons.calendar_month_outlined,
        label: 'Última historia ${_formatRelativeDate(lastDate)}',
      ));
    }

    if (highlightHearted) {
      chips.add(_StatChip(
        icon: Icons.favorite,
        label: 'Marcaste con un corazón',
      ));
    }

    return chips;
  }

  Widget _buildEmptyStoriesState({
    required BuildContext context,
    required String authorName,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty,
                    color: colorScheme.primary, size: 32),
                const SizedBox(width: 16),
                Text(
                  'Todavía no hay historias publicadas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$authorName está preparando sus primeros recuerdos. Te avisaremos en cuanto llegue el primero.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsubscribedBanner(BuildContext context, String authorName) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.mail_outline, color: colorScheme.primary, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Te diste de baja de las historias de $authorName',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si cambias de opinión, pídele a $authorName que te envíe un nuevo enlace mágico cuando publique algo especial para ti.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
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

  Widget _buildUnsubscribeSection(BuildContext context, String authorName) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Ya no quieres recibir historias?',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes darte de baja en cualquier momento. Tu decisión se aplicará de inmediato y $authorName dejará de enviarte recuerdos por correo.',
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_isUnsubscribed)
              FilledButton.tonalIcon(
                onPressed: null,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Ya estás dado de baja'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _isUnsubscribing ? null : _handleUnsubscribe,
                icon: _isUnsubscribing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout),
                label:
                    Text(_isUnsubscribing ? 'Dando de baja…' : 'Darse de baja'),
              ),
          ],
        ),
      ),
    );
  }

  void _openStory(Story story) {
    final record = _accessRecord;
    if (record == null) return;

    final link = StoryShareLinkBuilder.buildStoryLink(
      story: story,
      subscriber: StoryShareTarget(
        id: record.subscriberId,
        name: record.subscriberName,
        token: record.accessToken,
        source: record.source,
      ),
      source: record.source,
    );

    final routeName = _routeNameFromUri(link);
    Navigator.of(context).pushReplacementNamed(routeName);
  }

  Future<void> _handleUnsubscribe() async {
    if (_isUnsubscribing) return;
    final record = _accessRecord;
    final token = record?.accessToken;
    if (record == null || token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No encontramos tu enlace mágico para darte de baja.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Darse de baja'),
          content: const Text(
            'Dejarás de recibir historias y necesitarás un nuevo enlace si deseas volver. ¿Seguro que quieres continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, darme de baja'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isUnsubscribing = true);

    try {
      final success = await StoryPublicAccessService.unsubscribe(
        authorId: record.authorId,
        subscriberId: record.subscriberId,
        token: token,
        source: 'subscriber-library',
      );

      if (!success) {
        throw StoryPublicAccessException(
          statusCode: 500,
          message: 'No pudimos confirmar la baja.',
        );
      }

      StoryAccessManager.revokeAccess(record.authorId);

      if (!mounted) return;
      setState(() {
        _isUnsubscribing = false;
        _isUnsubscribed = true;
        _showWelcomeBanner = false;
        _stories = const [];
        _highlightStory = null;
        _highlightHearted = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baja confirmada. Gracias por acompañar al autor.'),
        ),
      );
    } on StoryPublicAccessException catch (error) {
      if (!mounted) return;
      setState(() => _isUnsubscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUnsubscribing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos darte de baja. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  String _routeNameFromUri(Uri link) {
    final rawPath =
        link.path.isEmpty ? '/' : '/${link.path}'.replaceAll('//', '/');
    if (link.hasQuery) {
      return '$rawPath?${link.query}';
    }
    return rawPath;
  }
}

class _AuthorPortrait extends StatelessWidget {
  const _AuthorPortrait({
    required this.avatarUrl,
    this.size,
    this.isCompact = false,
  });

  final String? avatarUrl;
  final double? size;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final effectiveSize = size ?? (isCompact ? 64.0 : 80.0);
    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: effectiveSize / 2,
        backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
            ? NetworkImage(avatarUrl!)
            : null,
        backgroundColor: const Color(0xFFf3e8ff),
        child: avatarUrl == null || avatarUrl!.trim().isEmpty
            ? Icon(
                Icons.person,
                color: const Color(0xFF8b5cf6),
                size: effectiveSize / 1.5,
              )
            : null,
      ),
    );
  }
}

class _FeaturedStoryCard extends StatelessWidget {
  const _FeaturedStoryCard({
    required this.story,
    required this.onOpen,
    this.highlightHearted = false,
  });

  final Story story;
  final VoidCallback onOpen;
  final bool highlightHearted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 720;
    final cover = _storyCoverUrl(story);
    final readingTime = _formatReadingTime(story);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFfdfbf7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7c3aed).withOpacity(0.12),
            blurRadius: 40,
            offset: const Offset(0, 16),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCompact ? 24 : 32),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover image or placeholder
                if (cover != null)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          cover,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFfaf5ff), Color(0xFFf3e8ff)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.photo_library_outlined,
                                color: Color(0xFF8b5cf6),
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // "DESTACADA" badge
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8b5cf6), Color(0xFF7c3aed)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7c3aed).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'MÁS RECIENTE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    height: isCompact ? 160 : 240,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFfaf5ff), Color(0xFFf3e8ff)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.auto_stories,
                      color: Color(0xFF8b5cf6),
                      size: 64,
                    ),
                  ),
                // Content
                Padding(
                  padding: EdgeInsets.all(isCompact ? 24 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meta chips
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (story.publishedAt != null)
                            _StoryChip(
                              icon: Icons.calendar_today,
                              label: _formatRelativeDate(story.publishedAt!),
                              isPurple: true,
                            ),
                          if (readingTime.isNotEmpty)
                            _StoryChip(
                              icon: Icons.schedule,
                              label: readingTime,
                              isPurple: true,
                            ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 16 : 20),
                      // Title
                      Text(
                        story.title.isEmpty ? 'Historia sin título' : story.title,
                        style: (isCompact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.3,
                          color: const Color(0xFF1f1b16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Excerpt
                      Text(
                        _buildExcerptText(
                          story.excerpt ?? story.content ?? '',
                          maxLength: 280,
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.7,
                          fontSize: 16,
                          color: const Color(0xFF4b5563),
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Heart reaction badge
                      if (highlightHearted) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFfef3c7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFfbbf24).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.favorite, color: Color(0xFFdc2626), size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Ya enviaste un corazón a esta historia',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF92400e),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: isCompact ? 20 : 24),
                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.auto_stories, size: 20),
                          label: const Text('Leer Historia Completa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8b5cf6),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 24 : 32,
                              vertical: isCompact ? 16 : 20,
                            ),
                            elevation: 0,
                            shadowColor: const Color(0xFF7c3aed).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
    );
  }
}

class _StoryGridCard extends StatelessWidget {
  const _StoryGridCard({
    required this.story,
    required this.onOpen,
  });

  final Story story;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = _storyCoverUrl(story);
    final readingTime = _formatReadingTime(story);

    return SizedBox(
      width: 380,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8b5cf6).withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7c3aed).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover image
                  _StoryThumbnail(coverUrl: cover),
                  const SizedBox(height: 16),
                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (story.publishedAt != null)
                        _StoryChip(
                          icon: Icons.calendar_today,
                          label: _formatRelativeDate(story.publishedAt!),
                          isPurple: true,
                        ),
                      if (readingTime.isNotEmpty)
                        _StoryChip(
                          icon: Icons.schedule,
                          label: readingTime,
                          isPurple: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Title
                  Text(
                    story.title.isEmpty
                        ? 'Historia sin título'
                        : story.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      color: const Color(0xFF1f1b16),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  // Excerpt
                  Text(
                    _buildExcerptText(
                      story.excerpt ?? story.content ?? '',
                      maxLength: 140,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6b7280),
                      height: 1.6,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  // CTA
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Leer historia',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF8b5cf6),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFf3e8ff),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          color: Color(0xFF8b5cf6),
                          size: 18,
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
    );
  }
}

class _StoryThumbnail extends StatelessWidget {
  const _StoryThumbnail({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: coverUrl != null && coverUrl!.trim().isNotEmpty
            ? Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFfaf5ff), Color(0xFFf3e8ff)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFF8b5cf6),
        size: 36,
      ),
    );
  }
}

class _StoryChip extends StatelessWidget {
  const _StoryChip({
    required this.icon,
    required this.label,
    this.isPurple = false,
  });

  final IconData icon;
  final String label;
  final bool isPurple;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isPurple
            ? const Color(0xFFf3e8ff)
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: isPurple
            ? Border.all(color: const Color(0xFF8b5cf6).withOpacity(0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isPurple
                ? const Color(0xFF7c3aed)
                : colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isPurple
                  ? const Color(0xFF6d28d9)
                  : colorScheme.onSecondaryContainer,
              fontWeight: isPurple ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return 'Hace instantes';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
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
  return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
}

String _formatReadingTime(Story story) {
  final minutes = story.readingTime;
  if (minutes <= 0) return '';
  if (minutes == 1) return '1 min de lectura';
  return '$minutes min de lectura';
}

String _buildExcerptText(String raw, {int maxLength = 160}) {
  final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (clean.length <= maxLength) return clean;
  return '${clean.substring(0, maxLength - 1).trimRight()}…';
}

String? _storyCoverUrl(Story story) {
  if (story.photos.isEmpty) return null;
  final photo = story.photos.first;
  if (photo.photoUrl.trim().isEmpty) return null;
  return photo.photoUrl;
}

class _InvitePayload {
  const _InvitePayload({
    required this.authorId,
    required this.token,
    this.subscriberName,
    this.source,
    this.authorDisplayName,
    required this.showWelcomeBanner,
  });

  final String authorId;
  final String token;
  final String? subscriberName;
  final String? source;
  final String? authorDisplayName;
  final bool showWelcomeBanner;

  static _InvitePayload? fromCurrentUri(String subscriberId) {
    final base = Uri.base;
    final params = <String, String>{};
    params.addAll(base.queryParameters);

    if (params['subscriber'] == null &&
        base.hasFragment &&
        base.fragment.isNotEmpty) {
      final fragment =
          base.fragment.startsWith('/') ? base.fragment : '/${base.fragment}';
      final fragmentUri = Uri.tryParse(fragment);
      if (fragmentUri != null) {
        params.addAll(fragmentUri.queryParameters);
      }
    }

    final authorId = params['author']?.trim();
    final token = params['token']?.trim();

    if (authorId == null ||
        authorId.isEmpty ||
        token == null ||
        token.isEmpty) {
      return null;
    }

    final subscriberParam = params['subscriber']?.trim();
    if (subscriberParam != null &&
        subscriberParam.isNotEmpty &&
        subscriberParam != subscriberId) {
      return null;
    }

    return _InvitePayload(
      authorId: authorId,
      token: token,
      subscriberName: params['name']?.trim(),
      source: params['source']?.trim(),
      authorDisplayName: params['authorName']?.trim(),
      showWelcomeBanner: _parseBool(params['welcome']),
    );
  }
}

bool _parseBool(String? raw) {
  if (raw == null) return false;
  final normalized = raw.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}
