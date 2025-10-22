import 'dart:async';

import 'package:flutter/material.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/public_access/public_author_profile.dart';
import 'package:narra/services/public_access/story_access_manager.dart';
import 'package:narra/services/public_access/story_access_record.dart';
import 'package:narra/services/public_access/story_public_access_service.dart';
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

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_initialize);
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
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: const CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 64, color: colorScheme.error),
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
        ),
      );
    }

    final profile = _authorProfile;
    final subscriberName = _subscriberName ?? 'Suscriptor';
    final displayName = profile?.resolvedDisplayName ?? 'Tu autor/a en Narra';
    final highlightStory = _highlightStory;
    final otherStories =
        highlightStory != null ? _stories.skip(1).toList() : _stories;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
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
                    onReadLatest: highlightStory != null
                        ? () => _openStory(highlightStory)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  _buildAccessInfoCard(
                    context: context,
                    subscriberName: subscriberName,
                    authorName: displayName,
                  ),
                  if (highlightStory != null) ...[
                    const SizedBox(height: 32),
                    _FeaturedStoryCard(
                      story: highlightStory,
                      onOpen: () => _openStory(highlightStory),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (otherStories.isNotEmpty)
                    _buildStoriesSection(
                      context: context,
                      stories: otherStories,
                    )
                  else
                    _buildEmptyStoriesState(
                      context: context,
                      authorName: displayName,
                    ),
                ],
              ),
            ),
          ),
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

    final path = link.path.isEmpty ? '/' : link.path;
    final routeName = link.hasQuery ? '$path?${link.query}' : path;

    Navigator.of(context).pushReplacementNamed(routeName);
  }

  Widget _buildHeroSection({
    required BuildContext context,
    required PublicAuthorProfile? profile,
    required String subscriberName,
    VoidCallback? onReadLatest,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasCover = profile?.coverImageUrl?.trim().isNotEmpty == true;
    final displayName = profile?.resolvedDisplayName ?? 'Tu autor/a en Narra';
    final tagline = profile?.tagline?.trim();
    final summary = profile?.summary?.trim();
    final fallbackSummary =
        'Este es tu espacio privado para leer los recuerdos y cartas que $displayName comparte contigo.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Stack(
        children: [
          if (hasCover)
            Positioned.fill(
              child: Image.network(
                profile!.coverImageUrl!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasCover
                      ? [
                          colorScheme.surface.withValues(alpha: 0.90),
                          colorScheme.surface.withValues(alpha: 0.78),
                        ]
                      : [
                          colorScheme.primaryContainer.withValues(alpha: 0.55),
                          colorScheme.surface,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, $subscriberName',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _AuthorPortrait(avatarUrl: profile?.avatarUrl),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                            ),
                          ),
                          if (tagline?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              tagline!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Text(
                    summary?.isNotEmpty == true ? summary! : fallbackSummary,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (onReadLatest != null)
                      FilledButton.icon(
                        onPressed: onReadLatest,
                        icon: const Icon(Icons.auto_stories_outlined),
                        label: const Text('Leer la historia más reciente'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/'),
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Explorar Narra'),
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

  Widget _buildAccessInfoCard({
    required BuildContext context,
    required String subscriberName,
    required String authorName,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      color: colorScheme.surfaceVariant.withValues(alpha: 0.35),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_user_outlined,
                color: colorScheme.primary, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acceso confirmado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Guardamos que eres $subscriberName. Cada vez que $authorName publique un nuevo recuerdo podrás abrirlo desde aquí, reaccionar con corazones y dejar comentarios privados.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'También recibirás un correo cuando haya una nueva historia dedicada a ti.',
                    style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildStoriesSection({
    required BuildContext context,
    required List<Story> stories,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Más historias publicadas',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 20,
          runSpacing: 20,
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
}

class _AuthorPortrait extends StatelessWidget {
  const _AuthorPortrait({required this.avatarUrl, this.size = 72});

  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: avatarUrl != null && avatarUrl!.trim().isNotEmpty
          ? NetworkImage(avatarUrl!)
          : null,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: avatarUrl == null || avatarUrl!.trim().isEmpty
          ? Icon(Icons.person_outline,
              color: theme.colorScheme.primary, size: size / 1.4)
          : null,
    );
  }
}

class _FeaturedStoryCard extends StatelessWidget {
  const _FeaturedStoryCard({
    required this.story,
    required this.onOpen,
  });

  final Story story;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cover = _storyCoverUrl(story);
    final readingTime = _formatReadingTime(story);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  cover,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => Container(
                    color: colorScheme.surfaceVariant,
                    child: Center(
                      child: Icon(Icons.photo_outlined,
                          color: colorScheme.onSurfaceVariant, size: 48),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Center(
                  child: Icon(Icons.auto_stories_outlined,
                      color: colorScheme.primary, size: 56),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (story.publishedAt != null)
                        _StoryChip(
                          icon: Icons.calendar_today_outlined,
                          label: _formatRelativeDate(story.publishedAt!),
                        ),
                      if (readingTime.isNotEmpty)
                        _StoryChip(
                          icon: Icons.watch_later_outlined,
                          label: readingTime,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    story.title.isEmpty ? 'Historia sin título' : story.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _buildExcerptText(
                      story.excerpt ?? story.content ?? '',
                      maxLength: 220,
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('Abrir esta historia'),
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
    final colorScheme = theme.colorScheme;
    final cover = _storyCoverUrl(story);
    final readingTime = _formatReadingTime(story);

    return SizedBox(
      width: 300,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null)
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => Container(
                      color: colorScheme.surfaceVariant,
                      child: Center(
                        child: Icon(Icons.photo_outlined,
                            color: colorScheme.onSurfaceVariant, size: 40),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (story.publishedAt != null)
                          _StoryChip(
                            icon: Icons.calendar_today_outlined,
                            label: _formatRelativeDate(story.publishedAt!),
                          ),
                        if (readingTime.isNotEmpty)
                          _StoryChip(
                            icon: Icons.watch_later_outlined,
                            label: readingTime,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      story.title.isEmpty ? 'Historia sin título' : story.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _buildExcerptText(
                        story.excerpt ?? story.content ?? '',
                        maxLength: 150,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Leer historia',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(Icons.arrow_forward_rounded,
                            color: colorScheme.primary),
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

class _StoryChip extends StatelessWidget {
  const _StoryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

String? _storyCoverUrl(Story story) {
  if (story.photos.isEmpty) return null;
  final photo = story.photos.first;
  if (photo.photoUrl.trim().isEmpty) return null;
  return photo.photoUrl;
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

class _InvitePayload {
  const _InvitePayload({
    required this.authorId,
    required this.token,
    this.subscriberName,
    this.source,
    this.authorDisplayName,
  });

  final String authorId;
  final String token;
  final String? subscriberName;
  final String? source;
  final String? authorDisplayName;

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
      // Prevent mismatched links from granting access to another subscriber.
      return null;
    }

    return _InvitePayload(
      authorId: authorId,
      token: token,
      subscriberName: params['name']?.trim(),
      source: params['source']?.trim(),
      authorDisplayName: params['authorName']?.trim(),
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
