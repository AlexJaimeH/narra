import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/public_access/story_access_manager.dart';
import 'package:narra/services/public_access/story_access_record.dart';
import 'package:narra/services/public_access/public_author_profile.dart';
import 'package:narra/services/public_access/story_feedback_service.dart';
import 'package:narra/services/public_access/story_public_access_service.dart';
import 'package:narra/services/public_story_service.dart';
import 'package:narra/services/story_share_link_builder.dart';
import 'package:narra/supabase/supabase_config.dart';

class StoryBlogPageArguments {
  const StoryBlogPageArguments({
    this.story,
    this.share,
  });

  final Story? story;
  final StorySharePayload? share;
}

class StoryBlogPage extends StatefulWidget {
  const StoryBlogPage({
    super.key,
    required this.storyId,
    this.initialStory,
    this.initialShare,
  });

  final String storyId;
  final Story? initialStory;
  final StorySharePayload? initialShare;

  @override
  State<StoryBlogPage> createState() => _StoryBlogPageState();
}

class _StoryBlogPageState extends State<StoryBlogPage> {
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  final Set<String> _replySubmitting = <String>{};

  Story? _story;
  StoryAccessRecord? _accessRecord;
  StorySharePayload? _sharePayload;
  PublicAuthorProfile? _authorProfile;
  List<Story> _recommendedStories = const [];
  final List<StoryFeedbackComment> _comments = [];

  bool _isLoading = true;
  bool _isHearted = false;
  bool _isSubmittingComment = false;
  bool _isFeedbackLoading = false;
  bool _isUpdatingReaction = false;
  String? _errorMessage;
  String? _shareValidationMessage;
  String? _replyingToCommentId;
  int _totalComments = 0;

  @override
  void initState() {
    super.initState();
    _sharePayload = widget.initialShare ?? StorySharePayload.fromUri(Uri.base);
    _loadStory();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _replyControllers.clear();
    super.dispose();
  }

  StoryShareTarget? get _currentShareTarget {
    final record = _accessRecord;
    if (record == null || record.subscriberId == 'author') {
      return null;
    }
    return StoryShareTarget(
      id: record.subscriberId,
      name: record.subscriberName,
      token: record.accessToken,
      source: record.source,
    );
  }

  StorySharePayload? get _resolvedSharePayload {
    final record = _accessRecord;
    if (record != null && record.subscriberId != 'author') {
      return StorySharePayload(
        subscriberId: record.subscriberId,
        subscriberName: record.subscriberName,
        token: record.accessToken,
        source: record.source,
      );
    }
    return _sharePayload;
  }

  bool get _canInteract {
    final record = _accessRecord;
    if (record == null) return false;
    return record.subscriberId != 'author';
  }

  TextEditingController _replyControllerFor(String commentId) {
    return _replyControllers.putIfAbsent(
      commentId,
      () => TextEditingController(),
    );
  }

  void _pruneReplyControllers(List<StoryFeedbackComment> comments) {
    final validIds = <String>{};

    void collect(StoryFeedbackComment comment) {
      validIds.add(comment.id);
      for (final child in comment.replies) {
        collect(child);
      }
    }

    for (final comment in comments) {
      collect(comment);
    }

    final staleControllers =
        _replyControllers.keys.where((id) => !validIds.contains(id)).toList();
    for (final id in staleControllers) {
      _replyControllers.remove(id)?.dispose();
    }

    if (_replyingToCommentId != null &&
        !validIds.contains(_replyingToCommentId!)) {
      _replyingToCommentId = null;
    }
  }

  Future<void> _loadStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _shareValidationMessage = null;
    });

    try {
      final story = widget.initialStory ??
          await PublicStoryService.getPublishedStory(widget.storyId);

      if (story == null) {
        setState(() {
          _errorMessage =
              'No pudimos encontrar esta historia publicada o ya no está disponible.';
          _isLoading = false;
        });
        return;
      }

      StoryAccessRecord? accessRecord;
      String? shareValidationMessage;

      if (SupabaseAuth.currentUser?.id == story.userId) {
        accessRecord = StoryAccessManager.ensureAuthorAccess(story.userId);
      } else {
        accessRecord = StoryAccessManager.getAccess(story.userId);
        if (accessRecord == null && _sharePayload != null) {
          final payload = _sharePayload!;
          final token = payload.token;

          if (token != null && token.isNotEmpty) {
            try {
              final validated = await StoryPublicAccessService.registerAccess(
                authorId: story.userId,
                storyId: story.id,
                subscriberId: payload.subscriberId,
                token: token,
                source: payload.source,
              );

              if (validated != null) {
                accessRecord = StoryAccessManager.grantAccess(
                  authorId: story.userId,
                  subscriberId: validated.subscriberId,
                  subscriberName: validated.subscriberName,
                  accessToken: validated.accessToken,
                  source: validated.source,
                  grantedAt: validated.grantedAt,
                  status: validated.status,
                  supabaseUrl: validated.supabaseUrl,
                  supabaseAnonKey: validated.supabaseAnonKey,
                );
              } else {
                shareValidationMessage =
                    'Este enlace ya no es válido. Solicita uno nuevo al autor.';
              }
            } on StoryPublicAccessException catch (error) {
              shareValidationMessage = error.message;
            } catch (_) {
              shareValidationMessage =
                  'No pudimos validar tu enlace en este momento. Inténtalo de nuevo en unos minutos.';
            }
          } else {
            shareValidationMessage =
                'El enlace que usaste está incompleto. Pide uno nuevo al autor.';
          }
        }
      }

      StorySharePayload? updatedSharePayload = _sharePayload;
      if (accessRecord != null && accessRecord.subscriberId != 'author') {
        updatedSharePayload = StorySharePayload(
          subscriberId: accessRecord.subscriberId,
          subscriberName: accessRecord.subscriberName,
          token: accessRecord.accessToken,
          source: accessRecord.source,
        );
      }

      List<Story> recommendations = const [];
      if (accessRecord != null) {
        recommendations = await PublicStoryService.getRecommendedStories(
          authorId: story.userId,
          excludeStoryId: story.id,
          limit: 3,
        );
      }

      final authorProfile =
          await PublicStoryService.getAuthorProfile(story.userId);

      setState(() {
        _story = story;
        _accessRecord = accessRecord;
        _sharePayload = updatedSharePayload;
        _shareValidationMessage = shareValidationMessage;
        _recommendedStories = recommendations;
        _authorProfile = authorProfile;
        _isLoading = false;
      });

      if (accessRecord != null) {
        await _loadFeedbackState(
          story: story,
          accessRecord: accessRecord,
          sharePayload: updatedSharePayload,
        );
      } else {
        setState(() {
          _comments.clear();
          _isHearted = false;
          _isFeedbackLoading = false;
        });
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Ocurrió un problema al cargar la historia.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFeedbackState({
    required Story story,
    StoryAccessRecord? accessRecord,
    StorySharePayload? sharePayload,
  }) async {
    final record = accessRecord ?? _accessRecord;
    final share = sharePayload ?? _resolvedSharePayload;

    if (record == null || record.subscriberId == 'author') {
      setState(() {
        _comments.clear();
        _isHearted = false;
        _isFeedbackLoading = false;
        _replyingToCommentId = null;
        _totalComments = 0;
      });
      return;
    }

    final token = share?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isFeedbackLoading = true;
    });

    try {
      final feedback = await StoryFeedbackService.fetchState(
        authorId: story.userId,
        storyId: story.id,
        subscriberId: record.subscriberId,
        token: token,
        source: share?.source,
        supabaseUrl: record.supabaseUrl,
        supabaseAnonKey: record.supabaseAnonKey,
      );

      if (!mounted) return;
      setState(() {
        _comments
          ..clear()
          ..addAll(feedback.comments);
        _isHearted = feedback.hasReacted;
        _isFeedbackLoading = false;
        _totalComments = feedback.commentCount;
        _pruneReplyControllers(_comments);
      });
    } on StoryFeedbackException catch (error) {
      if (!mounted) return;
      setState(() {
        _isFeedbackLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isFeedbackLoading = false;
      });
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_outlined,
                    size: 48, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadStory,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_story == null) {
      return const SizedBox.shrink();
    }

    final story = _story!;
    final hasAccess = _accessRecord != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: hasAccess
            ? _buildStoryContent(context, story)
            : _buildAccessDenied(context, story),
      ),
    );
  }

  Widget _buildAccessDenied(BuildContext context, Story story) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta historia es privada',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Necesitas un enlace personalizado para leer las historias de ${story.authorDisplayName ?? story.authorName ?? 'este autor/a'}. Si ya recibiste uno, vuelve a abrirlo desde el correo o mensaje que te enviaron.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_shareValidationMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _shareValidationMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_sharePayload != null)
                    _ShareDebugInfo(share: _sharePayload!),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _loadStory,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Intentar de nuevo'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si crees que es un error, contacta con el autor directamente para que te vuelva a enviar su enlace.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoryContent(BuildContext context, Story story) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profile = _authorProfile;
    final displayName = profile?.resolvedDisplayName ??
        story.authorDisplayName ??
        story.authorName ??
        'Autor/a de Narra';
    final tagline = profile?.tagline?.trim();
    final summary = profile?.summary?.trim();
    final coverUrl = profile?.coverImageUrl;
    final hasCover = coverUrl != null && coverUrl.trim().isNotEmpty;
    final canViewLibrary =
        _accessRecord != null && _accessRecord!.subscriberId != 'author';
    final metadataChips = _buildMetadataChips(context, story);
    final content = story.content ?? '';
    final hasInlineImages = _contentHasInlineImages(content);
    final bodyWidgets = _buildStoryBodyWidgets(
      story: story,
      theme: theme,
      colorScheme: colorScheme,
      hasInlineImages: hasInlineImages,
    );

    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: BoxDecoration(
                image: hasCover
                    ? DecorationImage(
                        image: NetworkImage(coverUrl!),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        colorFilter: ColorFilter.mode(
                          colorScheme.surface.withValues(alpha: 0.92),
                          BlendMode.srcOver,
                        ),
                      )
                    : null,
                gradient: LinearGradient(
                  colors: hasCover
                      ? [
                          colorScheme.surface.withValues(alpha: 0.96),
                          colorScheme.surface.withValues(alpha: 0.88),
                        ]
                      : [
                          const Color(0xFFfdfbf7),
                          const Color(0xFFf0ebe3),
                        ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38827A).withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title.isEmpty
                            ? 'Historia sin título'
                            : story.title,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          color: const Color(0xFF1f1b16),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _AuthorAvatar(avatarUrl: story.authorAvatarUrl),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (tagline?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    tagline!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Text(
                                  _formatPublishedDate(story.createdAt),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildHeaderActions(context, story),
                        ],
                      ),
                      if (summary?.isNotEmpty == true) ...[
                        const SizedBox(height: 18),
                        Text(
                          summary!,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (canViewLibrary) ...[
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4DB3A8), Color(0xFF38827A)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4DB3A8).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _goToAuthorLibrary(story),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.collections_bookmark_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        'Ver todas las historias de $displayName',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (metadataChips.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: metadataChips,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!hasInlineImages && story.photos.isNotEmpty)
              _StoryHeroImage(photoUrl: story.photos.first.photoUrl),
            const SizedBox(height: 32),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: bodyWidgets,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildReactionsRow(theme, colorScheme),
                      const SizedBox(height: 48),
                      _buildCommentsSection(theme, colorScheme),
                      const SizedBox(height: 48),
                      _buildRecommendations(theme, colorScheme, displayName),
                      const SizedBox(height: 64),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionsRow(ThemeData theme, ColorScheme colorScheme) {
    final canReact = _canInteract;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFfdfbf7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4DB3A8).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38827A).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: _isHearted
                  ? const LinearGradient(
                      colors: [Color(0xFF4DB3A8), Color(0xFF38827A)],
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              boxShadow: _isHearted
                  ? [
                      BoxShadow(
                        color: const Color(0xFF4DB3A8).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: _isHearted ? Colors.transparent : const Color(0xFFf3e8ff),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: (!canReact || _isUpdatingReaction) ? null : _toggleReaction,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isHearted ? Icons.favorite : Icons.favorite_border,
                        color: _isHearted ? Colors.white : const Color(0xFF4DB3A8),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isUpdatingReaction
                            ? 'Enviando…'
                            : _isHearted
                                ? 'Te encantó'
                                : 'Enviar cariño',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _isHearted ? Colors.white : const Color(0xFF4DB3A8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              canReact
                  ? 'Tus corazones quedan guardados de forma privada para el autor.'
                  : 'Este botón se activará cuando accedas con tu enlace personal.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6d6d6d),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(ThemeData theme, ColorScheme colorScheme) {
    final viewerName = _accessRecord?.subscriberName ?? 'Suscriptor';
    final canComment = _canInteract;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFfdfbf7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF4DB3A8).withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38827A).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4DB3A8), Color(0xFF38827A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Comentarios',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1f1b16),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf3e8ff),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalComments',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF4DB3A8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _totalComments > 0
                  ? 'Únete a la conversación y comparte cómo te hizo sentir esta historia.'
                  : 'Sé la primera persona en dejar unas palabras para ${_story?.authorDisplayName ?? _story?.authorName ?? 'el autor'}.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (_isFeedbackLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            const SizedBox(height: 16),
            if (_comments.isNotEmpty)
              _buildCommentThreads(theme, colorScheme, viewerName)
            else if (!_isFeedbackLoading)
              _buildEmptyCommentsState(theme, colorScheme),
            const SizedBox(height: 24),
            _buildCommentComposer(
              theme: theme,
              colorScheme: colorScheme,
              canComment: canComment,
              viewerName: viewerName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentThreads(
    ThemeData theme,
    ColorScheme colorScheme,
    String viewerName,
  ) {
    final children = <Widget>[];
    for (var i = 0; i < _comments.length; i++) {
      final comment = _comments[i];
      children.add(_buildCommentThread(
        comment,
        theme,
        colorScheme,
        viewerName: viewerName,
      ));
      if (i != _comments.length - 1) {
        children.add(const SizedBox(height: 16));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildEmptyCommentsState(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cuando dejes tu comentario aparecerá aquí. Puedes contar cómo te hizo sentir la historia o mandar un saludo al autor.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentComposer({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool canComment,
    required String viewerName,
  }) {
    if (!canComment) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Necesitas abrir la historia desde tu enlace mágico para participar en los comentarios.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _commentController,
          maxLines: 5,
          minLines: 3,
          enabled: !_isSubmittingComment,
          decoration: InputDecoration(
            labelText: 'Comparte un comentario',
            hintText: 'Escribe tu mensaje como $viewerName...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Tu nombre se mostrará como "$viewerName".',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _isSubmittingComment ? null : () => _submitComment(),
              icon: _isSubmittingComment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isSubmittingComment ? 'Publicando…' : 'Publicar',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentThread(
    StoryFeedbackComment comment,
    ThemeData theme,
    ColorScheme colorScheme, {
    int depth = 0,
    required String viewerName,
  }) {
    final indent = depth * 28.0;
    final isReplying = _replyingToCommentId == comment.id;
    final controller = _replyControllerFor(comment.id);
    final isSubmittingReply = _replySubmitting.contains(comment.id);

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4DB3A8).withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38827A).withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4DB3A8).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFf3e8ff),
                    foregroundColor: const Color(0xFF4DB3A8),
                    child: Text(
                      _initialsFor(comment.authorName),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4DB3A8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              comment.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            _formatRelativeTime(comment.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        comment.content,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (_canInteract)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _replyingToCommentId =
                                    _replyingToCommentId == comment.id
                                        ? null
                                        : comment.id;
                              });
                            },
                            icon: const Icon(Icons.reply_outlined, size: 18),
                            label: Text(
                              _replyingToCommentId == comment.id
                                  ? 'Cancelar respuesta'
                                  : 'Responder',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isReplying)
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 40),
              child: _buildReplyComposer(
                controller: controller,
                commentId: comment.id,
                theme: theme,
                colorScheme: colorScheme,
                isSubmitting: isSubmittingReply,
                viewerName: viewerName,
              ),
            ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < comment.replies.length; i++) ...[
                    _buildCommentThread(
                      comment.replies[i],
                      theme,
                      colorScheme,
                      depth: depth + 1,
                      viewerName: viewerName,
                    ),
                    if (i != comment.replies.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyComposer({
    required TextEditingController controller,
    required String commentId,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool isSubmitting,
    required String viewerName,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            enabled: !isSubmitting,
            decoration: InputDecoration(
              hintText: 'Responder como $viewerName…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        setState(() {
                          controller.clear();
                          if (_replyingToCommentId == commentId) {
                            _replyingToCommentId = null;
                          }
                        });
                      },
                child: const Text('Cancelar'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isSubmitting
                    ? null
                    : () => _submitComment(parentCommentId: commentId),
                icon: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.reply_rounded),
                label: Text(isSubmitting ? 'Enviando…' : 'Responder'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Hace unos segundos';
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return 'Hace ${minutes == 1 ? '1 minuto' : '$minutes minutos'}';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      return 'Hace ${hours == 1 ? '1 hora' : '$hours horas'}';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      return 'Hace ${days == 1 ? '1 día' : '$days días'}';
    }
    final weeks = (diff.inDays / 7).floor();
    if (weeks < 5) {
      return 'Hace ${weeks == 1 ? '1 semana' : '$weeks semanas'}';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _initialsFor(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '•';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '•';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return (first + last).toUpperCase();
  }

  Widget _buildRecommendations(
    ThemeData theme,
    ColorScheme colorScheme,
    String displayName,
  ) {
    if (_recommendedStories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4DB3A8), Color(0xFF38827A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_stories,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Otras historias del autor',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1f1b16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cuando haya más recuerdos publicados, aparecerán aquí.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6d6d6d),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4DB3A8), Color(0xFF38827A)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_stories,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Más historias de $displayName',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1f1b16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            final crossAxisCount = isCompact ? 1 : 3;
            final availableWidth = constraints.maxWidth - (isCompact ? 0 : 32);
            final cardWidth = isCompact
                ? double.infinity
                : math.max(220.0, availableWidth / crossAxisCount);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _recommendedStories
                  .map((story) => SizedBox(
                        width: cardWidth,
                        child: _RecommendedCard(
                          story: story,
                          onTap: () => _openRecommendedStory(story),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  List<Widget> _buildMetadataChips(BuildContext context, Story story) {
    final chips = <Widget>[];
    if (story.readingTime > 0) {
      chips.add(_MetadataChip(
        icon: Icons.timer_outlined,
        label: '${story.readingTime} min de lectura',
      ));
    }
    if (story.wordCount > 0) {
      chips.add(_MetadataChip(
        icon: Icons.text_snippet_outlined,
        label: '${story.wordCount} palabras',
      ));
    }
    if (story.location?.isNotEmpty == true) {
      chips.add(_MetadataChip(
        icon: Icons.location_on_outlined,
        label: story.location!,
      ));
    }
    if (story.storyDateText?.isNotEmpty == true) {
      chips.add(_MetadataChip(
        icon: Icons.calendar_today,
        label: story.storyDateText!,
      ));
    }
    if (story.tags != null && story.tags!.isNotEmpty) {
      chips.add(_MetadataChip(
        icon: Icons.sell_outlined,
        label: story.tags!.take(3).join(', '),
      ));
    } else if (story.storyTags.isNotEmpty) {
      chips.add(_MetadataChip(
        icon: Icons.sell_outlined,
        label: story.storyTags.map((tag) => tag.name).take(3).join(', '),
      ));
    }
    if (chips.isEmpty) {
      chips.add(const _MetadataChip(
        icon: Icons.auto_awesome,
        label: 'Un recuerdo único',
      ));
    }
    return chips;
  }

  List<String> _splitIntoParagraphs(String content) {
    final normalized = content.replaceAll('\r', '\n');
    final paragraphs = normalized
        .split('\n\n')
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty)
        .toList();
    return paragraphs.isEmpty ? [content] : paragraphs;
  }

  bool _contentHasInlineImages(String content) {
    return RegExp(r'\[img_(\d+)\]').hasMatch(content);
  }

  List<Widget> _buildStoryBodyWidgets({
    required Story story,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool hasInlineImages,
  }) {
    final paragraphs = _splitIntoParagraphs(story.content ?? '');
    final orderedPhotos = List<StoryPhoto>.from(story.photos)
      ..sort((a, b) => a.position.compareTo(b.position));
    final usedPhotoIds = <String>{};

    if (!hasInlineImages && orderedPhotos.isNotEmpty) {
      usedPhotoIds.add(orderedPhotos.first.id);
    }

    final photosByIndex = <int, StoryPhoto>{};
    final photosByPosition = <int, StoryPhoto>{};
    for (var i = 0; i < orderedPhotos.length; i++) {
      final photo = orderedPhotos[i];
      photosByIndex[i + 1] = photo;
      if (photo.position >= 0) {
        photosByPosition[photo.position] ??= photo;
        photosByPosition[photo.position + 1] ??= photo;
      }
    }

    StoryPhoto? takePhotoForIndex(int? index) {
      StoryPhoto? candidate;
      if (index != null && index > 0) {
        candidate = photosByPosition[index] ?? photosByIndex[index];
        if (candidate != null && usedPhotoIds.contains(candidate.id)) {
          candidate = null;
        }
      }

      candidate ??= () {
        for (final photo in orderedPhotos) {
          if (!usedPhotoIds.contains(photo.id)) {
            return photo;
          }
        }
        return null;
      }();

      if (candidate == null) return null;

      usedPhotoIds.add(candidate.id);
      return candidate;
    }

    final widgets = <Widget>[];
    final imagePattern = RegExp(r'\[img_(\d+)\]');

    void addTextBlock(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      widgets.add(
        SelectableText(
          trimmed,
          style: theme.textTheme.bodyLarge?.copyWith(
            height: 1.8,
            fontSize: 18,
            color: const Color(0xFF2d2d2d),
            letterSpacing: 0.2,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 24));
    }

    for (final paragraph in paragraphs) {
      final matches = imagePattern.allMatches(paragraph);
      if (matches.isEmpty) {
        addTextBlock(paragraph);
        continue;
      }

      var cursor = 0;
      for (final match in matches) {
        final preceding = paragraph.substring(cursor, match.start);
        addTextBlock(preceding);

        final index = int.tryParse(match.group(1) ?? '');
        final photo = takePhotoForIndex(index);
        if (photo != null) {
          widgets.add(_buildImageFigure(photo, theme, colorScheme));
          widgets.add(const SizedBox(height: 24));
        }
        cursor = match.end;
      }

      final trailing = paragraph.substring(cursor);
      addTextBlock(trailing);
    }

    for (final photo in orderedPhotos) {
      if (usedPhotoIds.contains(photo.id)) continue;
      widgets.add(_buildImageFigure(photo, theme, colorScheme));
      widgets.add(const SizedBox(height: 24));
      usedPhotoIds.add(photo.id);
    }

    if (widgets.isNotEmpty && widgets.last is SizedBox) {
      widgets.removeLast();
    }

    if (widgets.isEmpty) {
      widgets.add(
        SelectableText(
          'El autor todavía no ha añadido contenido a esta historia.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      );
    }

    return widgets;
  }

  Widget _buildImageFigure(
    StoryPhoto photo,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              photo.photoUrl,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: colorScheme.onSurfaceVariant,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        if (photo.caption?.trim().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              photo.caption!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  String _formatPublishedDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    if (difference == 0) return 'Publicado hoy';
    if (difference == 1) return 'Publicado ayer';
    if (difference < 7) {
      return 'Publicado hace $difference días';
    }
    return 'Publicado el ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Widget _buildHeaderActions(BuildContext context, Story story) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFf3e8ff),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4DB3A8).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              _goToAuthorLibrary(story);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: Color(0xFF4DB3A8),
                ),
                const SizedBox(width: 8),
                Text(
                  'Volver al blog',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4DB3A8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitComment({String? parentCommentId}) async {
    final controller = parentCommentId == null
        ? _commentController
        : _replyControllerFor(parentCommentId);
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final story = _story;
    final record = _accessRecord;
    final payload = _resolvedSharePayload;

    if (story == null || record == null || record.subscriberId == 'author') {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Este comentario es solo para suscriptores.')),
      );
      return;
    }

    final token = payload?.token;
    if (token == null || token.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Necesitas un enlace válido para comentar.')),
      );
      return;
    }

    setState(() {
      if (parentCommentId == null) {
        _isSubmittingComment = true;
      } else {
        _replySubmitting.add(parentCommentId);
      }
    });

    try {
      await StoryFeedbackService.submitComment(
        authorId: story.userId,
        storyId: story.id,
        subscriberId: record.subscriberId,
        token: token,
        content: text,
        source: payload?.source,
        parentCommentId: parentCommentId,
        supabaseUrl: record.supabaseUrl,
        supabaseAnonKey: record.supabaseAnonKey,
      );

      if (!mounted) return;
      await _loadFeedbackState(
        story: story,
        accessRecord: record,
        sharePayload: payload,
      );

      if (!mounted) return;
      controller.clear();
      if (parentCommentId != null) {
        setState(() {
          if (_replyingToCommentId == parentCommentId) {
            _replyingToCommentId = null;
          }
        });
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            parentCommentId == null
                ? '¡Comentario publicado!'
                : '¡Respuesta publicada!',
          ),
        ),
      );
    } on StoryFeedbackException catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('No pudimos registrar tu comentario. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        if (parentCommentId == null) {
          _isSubmittingComment = false;
        } else {
          _replySubmitting.remove(parentCommentId);
        }
      });
    }
  }

  Future<void> _toggleReaction() async {
    final story = _story;
    final record = _accessRecord;
    final payload = _resolvedSharePayload;

    if (story == null || record == null || record.subscriberId == 'author') {
      return;
    }

    final token = payload?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final nextState = !_isHearted;

    setState(() {
      _isUpdatingReaction = true;
    });

    try {
      final confirmed = await StoryFeedbackService.setReaction(
        authorId: story.userId,
        storyId: story.id,
        subscriberId: record.subscriberId,
        token: token,
        isActive: nextState,
        source: payload?.source,
        supabaseUrl: record.supabaseUrl,
        supabaseAnonKey: record.supabaseAnonKey,
      );

      if (!mounted) return;
      setState(() {
        _isHearted = confirmed;
        _isUpdatingReaction = false;
      });

      await _loadFeedbackState(
        story: story,
        accessRecord: record,
        sharePayload: payload,
      );
    } on StoryFeedbackException catch (error) {
      if (!mounted) return;
      setState(() => _isUpdatingReaction = false);
      messenger.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdatingReaction = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('No pudimos registrar tu reacción.')),
      );
    }
  }

  String _toRouteName(Uri link) {
    final rawPath =
        link.path.isEmpty ? '/' : '/${link.path}'.replaceAll('//', '/');
    if (link.hasQuery) {
      return '$rawPath?${link.query}';
    }
    return rawPath;
  }

  void _goToAuthorLibrary(Story story) {
    final record = _accessRecord;
    if (record == null || record.subscriberId == 'author') {
      return;
    }

    final share = _resolvedSharePayload;
    final token = share?.token ?? record.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final subscriber = StoryShareTarget(
      id: record.subscriberId,
      name: record.subscriberName,
      token: token,
      source: share?.source ?? 'story-blog',
    );

    final link = StoryShareLinkBuilder.buildSubscriberLink(
      authorId: story.userId,
      subscriber: subscriber,
      source: 'story-blog',
      authorDisplayName: _authorProfile?.resolvedDisplayName ??
          story.authorDisplayName ??
          story.authorName,
      showWelcomeBanner: false,
    );

    Navigator.of(context).pushReplacementNamed(_toRouteName(link));
  }

  void _openRecommendedStory(Story story) {
    final shareTarget = _currentShareTarget;
    final link = StoryShareLinkBuilder.buildStoryLink(
      story: story,
      subscriber: shareTarget,
      source: shareTarget?.source ?? _resolvedSharePayload?.source,
    );
    Navigator.of(context).pushReplacementNamed(
      _toRouteName(link),
      arguments: StoryBlogPageArguments(
        story: story,
        share: _resolvedSharePayload,
      ),
    );
  }
}

class StorySharePayload {
  const StorySharePayload({
    required this.subscriberId,
    this.subscriberName,
    this.token,
    this.source,
  });

  final String subscriberId;
  final String? subscriberName;
  final String? token;
  final String? source;

  static StorySharePayload? fromUri(Uri uri) {
    final params = <String, String>{};
    params.addAll(uri.queryParameters);

    if ((params['subscriber'] == null || params['subscriber']!.isEmpty) &&
        uri.hasFragment &&
        uri.fragment.isNotEmpty) {
      final fragment =
          uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}';
      final fragmentUri = Uri.tryParse(fragment);
      if (fragmentUri != null) {
        params.addAll(fragmentUri.queryParameters);
      }
    }

    final subscriberId = params['subscriber'];
    if (subscriberId == null || subscriberId.isEmpty) {
      return null;
    }
    return StorySharePayload(
      subscriberId: subscriberId,
      subscriberName: params['name'],
      token: params['token'],
      source: params['source'],
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFf3e8ff),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4DB3A8).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF4DB3A8)),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6d28d9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryHeroImage extends StatelessWidget {
  const _StoryHeroImage({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(0),
        ),
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined, size: 64),
          ),
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4DB3A8).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xFFf3e8ff),
        backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
            ? NetworkImage(avatarUrl!)
            : null,
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? const Icon(Icons.person, color: Color(0xFF4DB3A8))
            : null,
      ),
    );
  }
}

class _RecommendedCard extends StatelessWidget {
  const _RecommendedCard({
    required this.story,
    required this.onTap,
  });

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = story.photos.isNotEmpty ? story.photos.first.photoUrl : null;
    final excerpt = story.excerpt ??
        (story.content ?? '').split('\n').firstWhere(
              (line) => line.trim().isNotEmpty,
              orElse: () => 'Un recuerdo especial',
            );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF4DB3A8).withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38827A).withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cover != null)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFf3e8ff), Color(0xFFfdfbf7)],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_outlined,
                          size: 48,
                          color: Color(0xFF4DB3A8),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title.isEmpty ? 'Historia sin título' : story.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1f1b16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      excerpt,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6d6d6d),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Leer historia',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4DB3A8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFf3e8ff),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: Color(0xFF4DB3A8),
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

class _ShareDebugInfo extends StatelessWidget {
  const _ShareDebugInfo({required this.share});

  final StorySharePayload share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Información del enlace recibido',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text('ID de suscriptor: ${share.subscriberId}'),
          if (share.token != null) Text('Token: ${share.token}'),
          if (share.source != null) Text('Fuente: ${share.source}'),
        ],
      ),
    );
  }
}
