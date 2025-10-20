import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/public_access/story_access_manager.dart';
import 'package:narra/services/public_access/story_access_record.dart';
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

  Story? _story;
  StoryAccessRecord? _accessRecord;
  StorySharePayload? _sharePayload;
  List<Story> _recommendedStories = const [];
  final List<_LocalComment> _comments = [];

  bool _isLoading = true;
  bool _isHearted = false;
  bool _isSubmittingComment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sharePayload = widget.initialShare ?? StorySharePayload.fromUri(Uri.base);
    _loadStory();
  }

  @override
  void dispose() {
    _commentController.dispose();
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

  Future<void> _loadStory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
      if (SupabaseAuth.currentUser?.id == story.userId) {
        accessRecord = StoryAccessManager.ensureAuthorAccess(story.userId);
      } else {
        accessRecord = StoryAccessManager.getAccess(story.userId);
        if (accessRecord == null && _sharePayload != null) {
          accessRecord = StoryAccessManager.grantAccess(
            authorId: story.userId,
            subscriberId: _sharePayload!.subscriberId,
            subscriberName: _sharePayload!.subscriberName,
            accessToken: _sharePayload!.token,
            source: _sharePayload!.source,
          );
        }
      }

      List<Story> recommendations = const [];
      if (accessRecord != null) {
        recommendations = await PublicStoryService.getRecommendedStories(
          authorId: story.userId,
          excludeStoryId: story.id,
          limit: 3,
        );
      }

      setState(() {
        _story = story;
        _accessRecord = accessRecord;
        _recommendedStories = recommendations;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Ocurrió un problema al cargar la historia.';
        _isLoading = false;
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
    final displayName =
        story.authorDisplayName ?? story.authorName ?? 'Autor/a de Narra';
    final metadataChips = _buildMetadataChips(context, story);
    final paragraphs = _splitIntoParagraphs(story.content ?? '');

    return Scrollbar(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.12),
                    colorScheme.surface,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
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
                          fontWeight: FontWeight.bold,
                          height: 1.1,
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
                                const SizedBox(height: 4),
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
            if (story.photos.isNotEmpty)
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
                      ...paragraphs.map(
                        (paragraph) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            paragraph,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ),
                      ),
                      if (story.photos.length > 1) ...[
                        const SizedBox(height: 32),
                        _AdditionalPhotosGallery(photos: story.photos.skip(1)),
                      ],
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
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _isHearted = !_isHearted;
            });
          },
          style: FilledButton.styleFrom(
            backgroundColor: _isHearted
                ? colorScheme.primary
                : colorScheme.primaryContainer,
            foregroundColor:
                _isHearted ? colorScheme.onPrimary : colorScheme.primary,
          ),
          icon: Icon(_isHearted ? Icons.favorite : Icons.favorite_border),
          label: Text(_isHearted ? 'Te encantó' : 'Enviar cariño'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'Comparte este recuerdo solo con personas de confianza.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(ThemeData theme, ColorScheme colorScheme) {
    final viewerName = _accessRecord?.subscriberName ?? 'Suscriptor';

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Comparte un comentario',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_comments.isEmpty)
              Text(
                'Sé la primera persona en dejar unas palabras para ${_story?.authorDisplayName ?? _story?.authorName ?? 'el autor'}.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ..._comments.map((comment) => _CommentTile(comment: comment)),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 5,
              minLines: 3,
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje como $viewerName...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isSubmittingComment ? null : _submitComment,
                child: _isSubmittingComment
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publicar comentario'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tu nombre se mostrará como "$viewerName".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
          Text(
            'Otras historias del autor',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Cuando haya más recuerdos publicados, aparecerán aquí.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Más historias de $displayName',
          style: theme.textTheme.titleLarge,
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
    final shareTarget = _currentShareTarget;
    final link = StoryShareLinkBuilder.buildStoryLink(
      story: story,
      subscriber: shareTarget,
    ).toString();

    return Wrap(
      spacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: link));
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Enlace copiado al portapapeles')),
            );
          },
          icon: const Icon(Icons.link),
          label: const Text('Copiar enlace'),
        ),
      ],
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmittingComment = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));

    setState(() {
      _comments.add(_LocalComment(
        authorName: _accessRecord?.subscriberName ?? 'Suscriptor',
        content: text,
        createdAt: DateTime.now(),
      ));
      _commentController.clear();
      _isSubmittingComment = false;
    });

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('¡Gracias! Tu comentario se registrará cuando esté disponible.'),
      ),
    );
  }

  String _toRouteName(Uri link) {
    final path = link.path.isEmpty ? '/' : link.path;
    if (link.hasQuery) {
      return '$path?${link.query}';
    }
    return path;
  }

  void _openRecommendedStory(Story story) {
    final shareTarget = _currentShareTarget;
    final link = StoryShareLinkBuilder.buildStoryLink(
      story: story,
      subscriber: shareTarget,
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
    final subscriberId = uri.queryParameters['subscriber'];
    if (subscriberId == null || subscriberId.isEmpty) {
      return null;
    }
    return StorySharePayload(
      subscriberId: subscriberId,
      subscriberName: uri.queryParameters['name'],
      token: uri.queryParameters['token'],
      source: uri.queryParameters['source'],
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
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodyMedium),
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

class _AdditionalPhotosGallery extends StatelessWidget {
  const _AdditionalPhotosGallery({required this.photos});

  final Iterable<StoryPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Momentos capturados', style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final photo = photos.elementAt(index);
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  photo.photoUrl,
                  width: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 280,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemCount: photos.length,
          ),
        ),
      ],
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 28,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
      backgroundImage:
          avatarUrl != null && avatarUrl!.isNotEmpty ? NetworkImage(avatarUrl!) : null,
      child: avatarUrl == null || avatarUrl!.isEmpty
          ? Icon(Icons.person, color: colorScheme.primary)
          : null,
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
    final colorScheme = theme.colorScheme;
    final cover = story.photos.isNotEmpty ? story.photos.first.photoUrl : null;
    final excerpt = story.excerpt ??
        (story.content ?? '').split('\n').firstWhere(
              (line) => line.trim().isNotEmpty,
              orElse: () => 'Un recuerdo especial',
            );

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cover != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, size: 42),
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Leer historia',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
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

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final _LocalComment comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            comment.authorName,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _formatCommentDate(comment.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(comment.content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatCommentDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Hace unos segundos';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _LocalComment {
  _LocalComment({
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String authorName;
  final String content;
  final DateTime createdAt;
}
