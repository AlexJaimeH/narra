import 'dart:async';

import 'package:flutter/material.dart';
import 'package:narra/repositories/story_repository.dart';
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
  String? _authorName;
  String? _subscriberName;
  List<Story> _stories = const [];

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

      final stories = await PublicStoryService.getLatestStories(
        authorId: payload.authorId,
        limit: 3,
      );

      var authorName = payload.authorDisplayName;
      if (authorName == null || authorName.isEmpty) {
        authorName = stories.isNotEmpty
            ? (stories.first.authorDisplayName ?? stories.first.authorName)
            : null;
      }
      authorName ??=
          await PublicStoryService.getAuthorDisplayName(payload.authorId) ??
              'Tu autor/a en Narra';

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _accessRecord = record;
        _authorName = authorName;
        _subscriberName =
            payload.subscriberName ?? record.subscriberName ?? 'Suscriptor';
        _stories = stories;
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

    final subscriberName = _subscriberName ?? 'Suscriptor';
    final authorName = _authorName ?? 'Tu autor/a en Narra';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 32,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola, $subscriberName!',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Guardamos tu acceso privado para leer las historias de $authorName en este dispositivo.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'También te enviaremos por correo cada nueva historia que publique $authorName para que no te pierdas ninguna.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lock_open_rounded,
                                  size: 28,
                                  color: colorScheme.onPrimaryContainer),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Cada vez que abras un enlace nuevo desde aquí, te reconoceremos como $subscriberName para que puedas dejar comentarios y corazones.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: _stories.isEmpty
                                  ? null
                                  : () => _openStory(_stories.first),
                              icon: const Icon(Icons.bookmark_added_outlined),
                              label: Text(_stories.isEmpty
                                  ? 'Aún no hay historias'
                                  : 'Leer la historia más reciente'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context)
                                  .pushReplacementNamed('/'),
                              icon: const Icon(Icons.home_outlined),
                              label: const Text('Explorar Narra'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_stories.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Historias recomendadas',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: _stories
                          .map((story) => _StoryPreviewCard(
                                story: story,
                                onOpen: () => _openStory(story),
                              ))
                          .toList(),
                    ),
                  ],
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
}

class _StoryPreviewCard extends StatelessWidget {
  const _StoryPreviewCard({
    required this.story,
    required this.onOpen,
  });

  final Story story;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 260,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    story.publishedAt != null
                        ? _formatRelativeDate(story.publishedAt!)
                        : 'Nueva',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  story.title.isEmpty ? 'Historia sin título' : story.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _buildExcerpt(story.excerpt ?? story.content ?? ''),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
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
        ),
      ),
    );
  }

  String _buildExcerpt(String content) {
    final clean = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 120) return clean;
    return '${clean.substring(0, 117).trimRight()}…';
  }
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
