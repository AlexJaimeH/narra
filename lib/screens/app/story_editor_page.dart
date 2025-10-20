import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data' as typed;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/services/tag_service.dart';
import 'package:narra/services/image_upload_service.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/openai/openai_service.dart';
import 'package:narra/services/voice_recorder.dart';
import 'package:narra/services/audio_upload_service.dart';
import 'package:narra/services/user_service.dart';
import 'package:narra/screens/app/top_navigation_bar.dart';
import 'package:narra/supabase/narra_client.dart';

class StoryEditorPage extends StatefulWidget {
  final String? storyId; // null for new story, id for editing existing

  const StoryEditorPage({super.key, this.storyId});

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

enum _GhostWriterResultAction { apply, retry, cancel }

enum _EditorExitDecision { cancel, discard, save }

class StoryCoachSection {
  const StoryCoachSection({
    required this.title,
    required this.purpose,
    required this.items,
    this.description,
  });

  final String title;
  final String purpose;
  final List<String> items;
  final String? description;

  factory StoryCoachSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];

    final rawDescription = (json['description'] as String?)?.trim();

    return StoryCoachSection(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Ideas clave',
      purpose: (json['purpose'] as String?)?.trim().isNotEmpty == true
          ? json['purpose'] as String
          : 'ideas',
      description: rawDescription?.isNotEmpty == true ? rawDescription : null,
      items: items,
    );
  }
}

class StoryCoachPlan {
  const StoryCoachPlan({
    required this.status,
    required this.summary,
    required this.sections,
    required this.nextSteps,
    required this.encouragement,
    this.missingPieces = const [],
    this.warmups = const [],
  });

  final String status;
  final String summary;
  final List<StoryCoachSection> sections;
  final List<String> nextSteps;
  final List<String> missingPieces;
  final List<String> warmups;
  final String encouragement;

  bool get isComplete => status == 'complete';
  bool get isStarting => status == 'starting_out';

  factory StoryCoachPlan.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(String key) {
      final value = json[key];
      if (value is List) {
        return value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    final sectionsRaw = json['sections'];
    final sections = sectionsRaw is List
        ? sectionsRaw
            .whereType<Map<String, dynamic>>()
            .map((section) => StoryCoachSection.fromJson(section))
            .where((section) => section.items.isNotEmpty)
            .toList()
        : <StoryCoachSection>[];

    return StoryCoachPlan(
      status: (json['status'] as String?)?.trim().isNotEmpty == true
          ? json['status'] as String
          : 'in_progress',
      summary: (json['summary'] as String?)?.trim() ??
          'Aquí tienes ideas para seguir avanzando.',
      sections: sections,
      nextSteps: parseStringList('next_steps'),
      encouragement: (json['encouragement'] as String?)?.trim() ??
          'Continúa escribiendo a tu ritmo, lo estás haciendo muy bien.',
      missingPieces: parseStringList('missing_pieces'),
      warmups: parseStringList('warmups'),
    );
  }
}

class _TagOption {
  const _TagOption({
    required this.name,
    required this.color,
    required this.category,
    this.emoji,
  });

  final String name;
  final Color color;
  final String category;
  final String? emoji;

  _TagOption copyWith({
    String? name,
    Color? color,
    String? category,
    String? emoji,
  }) {
    return _TagOption(
      name: name ?? this.name,
      color: color ?? this.color,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
    );
  }
}

class _TagPaletteSection {
  const _TagPaletteSection({
    required this.title,
    required this.description,
    required this.icon,
    required this.tags,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_TagOption> tags;

  _TagPaletteSection copyWith({List<_TagOption>? tags}) {
    return _TagPaletteSection(
      title: title,
      description: description,
      icon: icon,
      tags: tags ?? this.tags,
    );
  }
}

class _StoryVersionEntry {
  const _StoryVersionEntry({
    required this.title,
    required this.content,
    required this.savedAt,
    required this.reason,
  });

  final String title;
  final String content;
  final DateTime savedAt;
  final String reason;
}

class _VersionHistoryVisuals {
  const _VersionHistoryVisuals({
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.metaColor,
  });

  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final Color metaColor;
}

class _StoryEditorPageState extends State<StoryEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagSearchController = TextEditingController();
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _transcriptScrollController = ScrollController();

  bool _isTopMenuOpen = false;
  bool _isTopBarElevated = false;

  bool _isRecording = false;
  VoiceRecorder? _recorder;

  String _liveTranscript = '';
  bool _isPaused = false;

  bool _isRecorderConnecting = false;
  final List<String> _recorderLogs = [];
  static const int _maxRecorderLogs = 200;
  final Map<String, void Function(void Function())> _sheetStateUpdater = {};

  static const int _visualizerBarCount = 72;
  final Queue<double> _levelHistory = ListQueue<double>(_visualizerBarCount)
    ..addAll(List<double>.filled(_visualizerBarCount, 0.0));
  DateTime? _recordingStartedAt;
  Duration _recordingAccumulated = Duration.zero;
  Duration _recordingDuration = Duration.zero;
  Ticker? _recordingTicker;

  typed.Uint8List? _recordedAudioBytes;
  bool _recordedAudioUploaded = false;

  html.AudioElement? _playbackAudio;
  StreamSubscription<html.Event>? _playbackEndedSub;
  StreamSubscription<html.Event>? _playbackTimeUpdateSub;
  StreamSubscription<html.Event>? _playbackMetadataSub;
  double _playbackProgressSeconds = 0;
  double? _playbackDurationSeconds;
  bool _isPlaybackPlaying = false;
  String? _recordingObjectUrl;

  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isSaving = false;
  final List<String> _selectedTags = [];
  final Map<String, _TagOption> _tagLookup = {};
  final List<Map<String, dynamic>> _photos = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _datesPrecision = 'day'; // day, month, year
  String _status = 'draft'; // draft, published
  Story? _currentStory;
  final List<_StoryVersionEntry> _versionHistory = [];
  Timer? _autoVersionTimer;
  String? _lastVersionSignature;

  String _tagSearchQuery = '';
  List<_TagPaletteSection> _tagSections = [];
  StoryCoachPlan? _storyCoachPlan;
  bool _showSuggestions = false;
  bool _isSuggestionsLoading = false;
  String? _suggestionsError;
  DateTime? _suggestionsGeneratedAt;
  String _lastSuggestionsSource = '';
  static const String _suggestionsFriendlyErrorMessage =
      'Estamos teniendo dificultades para generar nuevas sugerencias en este momento. Intenta nuevamente dentro de unos segundos.';

  // Ghost Writer configuration (synced with user settings)
  String _ghostWriterTone = 'warm';
  String _ghostWriterEditingStyle = 'balanced';
  String _ghostWriterLanguage = 'es';
  String _ghostWriterPerspective = 'first';
  bool _ghostWriterAvoidProfanity = false;
  String _ghostWriterExtraInstructions = '';
  bool _isGhostWriterProcessing = false;
  Timer? _ghostWriterInstructionsDebounce;

  static const String _personalTagsTitle = 'Tus etiquetas únicas';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });

    _tagSections = _buildCuratedTagSections();
    _registerTagLookup(_tagSections);
    _tagSearchController.addListener(() {
      final nextQuery = _tagSearchController.text;
      if (_tagSearchQuery == nextQuery) return;
      if (!mounted) return;
      setState(() {
        _tagSearchQuery = nextQuery;
      });
    });

    _loadAvailableTags();
    _loadGhostWriterPreferences();

    // Load existing story if editing
    if (widget.storyId != null) {
      _loadStory();
    }

    // Listen to content changes - debounced to prevent flickering
    _contentController.addListener(_handleContentChange);
    _titleController.addListener(_handleTitleChange);

    _startAutoVersionTimer();

    if (widget.storyId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _captureVersion(
          reason: 'Versión inicial',
          includeIfUnchanged: true,
        );
      });
    }

    // Generate initial AI suggestions when suggestions are shown
  }

  void _handleContentChange() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
    // Note: We could add placeholder detection here if needed
    // but for now we keep it simple - users can manually manage placeholders
  }

  void _handleTitleChange() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    final offset = notification.metrics.pixels;
    final shouldElevate = offset > 12;
    final shouldCloseMenu = _isTopMenuOpen && offset > 12;

    if (shouldElevate != _isTopBarElevated || shouldCloseMenu) {
      setState(() {
        _isTopBarElevated = shouldElevate;
        if (shouldCloseMenu) {
          _isTopMenuOpen = false;
        }
      });
    }

    return false;
  }

  void _toggleTopMenu() {
    setState(() {
      _isTopMenuOpen = !_isTopMenuOpen;
    });
  }

  Future<bool> _confirmLeaveEditor() async {
    if (!mounted) {
      return false;
    }

    if (!_hasChanges) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Salir del editor?'),
          content: const Text(
            'Estás por salir del editor de historias. ¿Quieres continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salir'),
            ),
          ],
        ),
      );

      return shouldLeave ?? false;
    }

    final decision = await showDialog<_EditorExitDecision>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir del editor?'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Qué deseas hacer antes de salir?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _EditorExitDecision.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _EditorExitDecision.discard),
            child: const Text('Descartar'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _EditorExitDecision.save),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    switch (decision) {
      case _EditorExitDecision.discard:
        if (mounted) {
          setState(() => _hasChanges = false);
        } else {
          _hasChanges = false;
        }
        return true;
      case _EditorExitDecision.save:
        final saved = await _saveDraft();
        if (saved) {
          if (mounted) {
            setState(() => _hasChanges = false);
          } else {
            _hasChanges = false;
          }
          return true;
        }
        return false;
      case _EditorExitDecision.cancel:
      case null:
        return false;
    }
  }

  void _handleTopNavSelection(int index) async {
    setState(() {
      _isTopMenuOpen = false;
    });

    if (!await _confirmLeaveEditor()) {
      return;
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/app',
      (route) =>
          route.settings.name == '/' || route.settings.name == '/landing',
      arguments: index,
    );
  }

  Future<void> _handleTopNavCreateStory() async {
    setState(() {
      _isTopMenuOpen = false;
    });

    if (!await _confirmLeaveEditor()) {
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const StoryEditorPage(),
      ),
    );
  }

  @override
  void dispose() {
    _recorder?.dispose();
    _recordingTicker?.dispose();
    _recordingTicker = null;
    _disposePlaybackAudio();
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _editorScrollController.dispose();
    _transcriptScrollController.dispose();
    _tagSearchController.dispose();
    _ghostWriterInstructionsDebounce?.cancel();
    _autoVersionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await TagService.getAllTags();
      if (mounted) {
        final sections = _mergeTagSectionsWithUserTags(tags);
        _updateTagSections(sections);
      }
    } catch (e) {
      if (mounted) {
        _updateTagSections(_buildCuratedTagSections());
      }
    }
  }

  Future<void> _loadGhostWriterPreferences() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      final settings = await UserService.getUserSettings();
      if (!mounted) return;
      setState(() {
        _ghostWriterTone = (profile?['writing_tone'] as String?) ?? 'warm';
        _ghostWriterPerspective =
            (settings?['ai_person'] as String?) ?? 'first';
        _ghostWriterEditingStyle =
            (settings?['ai_fidelity'] as String?) ?? 'balanced';
        _ghostWriterAvoidProfanity =
            (settings?['ai_no_bad_words'] as bool?) ?? false;
        _ghostWriterExtraInstructions =
            (settings?['ai_extra_instructions'] as String?)?.trim() ?? '';
        _ghostWriterLanguage = (settings?['language'] as String?) ?? 'es';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los ajustes de Ghost Writer: $e',
          ),
        ),
      );
    }
  }

  Future<void> _loadStory() async {
    if (widget.storyId == null) return;

    setState(() {
      _isLoading = true;
      _versionHistory.clear();
    });
    _lastVersionSignature = null;
    try {
      final story = await StoryServiceNew.getStoryById(widget.storyId!);
      if (story != null && mounted) {
        // Load story photos from database
        final storyData =
            await NarraSupabaseClient.getStoryById(widget.storyId!);
        final photos = <Map<String, dynamic>>[];

        if (storyData != null && storyData['story_photos'] != null) {
          final storyPhotos = storyData['story_photos'] as List<dynamic>;
          for (int i = 0; i < storyPhotos.length; i++) {
            final photo = storyPhotos[i] as Map<String, dynamic>;
            photos.add({
              'id': photo['id'],
              'path': photo['photo_url'],
              'bytes': null, // Will be null for already uploaded photos
              'fileName': _getFileNameFromUrl(photo['photo_url']),
              'caption': photo['caption'] ?? '',
              'alt': photo['caption'] ?? '', // Use caption as alt text
              'uploaded': true, // Already uploaded to server
              'position': photo['position'] ?? i,
            });
          }
        }

        setState(() {
          _currentStory = story;
          _titleController.text = story.title;
          _contentController.text = story.content ?? '';
          _selectedTags.clear();
          _selectedTags.addAll(story.tags ?? []);
          _startDate = story.startDate;
          _endDate = story.endDate;
          _datesPrecision = story.datesPrecision ?? 'day';
          _status = story.status.name;
          _photos.clear();
          _photos.addAll(photos);
          _hasChanges = false;
          _isLoading = false;
        });
        _captureVersion(
          reason: 'Versión original',
          includeIfUnchanged: true,
          savedAt: story.updatedAt,
        );
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _ensureSelectedTagsInPalette();
        });
        // Initialize AI suggestions
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historia: $e')),
        );
      }
    }
  }

  Future<void> _generateAISuggestions({bool force = false}) async {
    if (!mounted) return;

    final sourceKey =
        '${_titleController.text.trim()}|${_contentController.text.trim()}';

    if (!force &&
        _storyCoachPlan != null &&
        _lastSuggestionsSource == sourceKey) {
      return;
    }

    if (_isSuggestionsLoading) return;

    setState(() {
      _isSuggestionsLoading = true;
      _suggestionsError = null;
    });

    try {
      final planJson = await OpenAIService.generateStoryCoachPlan(
        title: _titleController.text,
        content: _contentController.text,
      );
      if (!mounted) return;
      setState(() {
        _storyCoachPlan = StoryCoachPlan.fromJson(planJson);
        _lastSuggestionsSource = sourceKey;
        _suggestionsGeneratedAt = DateTime.now();
        _isSuggestionsLoading = false;
      });
    } on OpenAIProxyException catch (error) {
      debugPrint('Story coach suggestions error: ${error.message}');
      if (!mounted) return;
      setState(() {
        _suggestionsError = _suggestionsFriendlyErrorMessage;
        _isSuggestionsLoading = false;
      });
    } catch (error) {
      debugPrint('Unexpected story coach suggestions error: $error');
      if (!mounted) return;
      setState(() {
        _suggestionsError = _suggestionsFriendlyErrorMessage;
        _isSuggestionsLoading = false;
      });
    }
  }

  String _suggestionsStatusLabel(String status) {
    switch (status) {
      case 'complete':
        return 'Historia completa';
      case 'starting_out':
        return 'Listo para comenzar';
      case 'needs_more':
        return 'Faltan detalles clave';
      case 'in_progress':
        return 'En progreso';
      default:
        return 'Recomendaciones personalizadas';
    }
  }

  Color _suggestionsStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'complete':
        return colorScheme.secondary;
      case 'starting_out':
        return colorScheme.tertiary;
      case 'needs_more':
        return colorScheme.error;
      default:
        return colorScheme.primary;
    }
  }

  IconData _suggestionsSectionIcon(String purpose) {
    switch (purpose) {
      case 'questions':
        return Icons.quiz_outlined;
      case 'memories':
        return Icons.photo_album_outlined;
      case 'edits':
        return Icons.edit_note;
      case 'reflection':
        return Icons.self_improvement;
      case 'ideas':
      default:
        return Icons.tips_and_updates_outlined;
    }
  }

  Color _suggestionsSectionColor(String purpose, ColorScheme colorScheme) {
    switch (purpose) {
      case 'questions':
        return colorScheme.primary.withValues(alpha: 0.12);
      case 'memories':
        return colorScheme.tertiary.withValues(alpha: 0.12);
      case 'edits':
        return colorScheme.secondary.withValues(alpha: 0.12);
      case 'reflection':
        return colorScheme.surfaceTint.withValues(alpha: 0.12);
      default:
        return colorScheme.surfaceVariant.withValues(alpha: 0.18);
    }
  }

  String? _formattedSuggestionsTimestamp() {
    final generated = _suggestionsGeneratedAt;
    if (generated == null) return null;

    final local = generated.toLocal();
    final now = DateTime.now();
    final isSameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final timeLabel = TimeOfDay.fromDateTime(local).format(context);
    if (isSameDay) {
      return 'Actualizado hoy a las $timeLabel';
    }

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    return 'Actualizado el $day/$month/$year a las $timeLabel';
  }

  Widget _buildSuggestionsLoading(ThemeData theme, ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(colorScheme.primary),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Analizando tu historia y preparando sugerencias personalizadas...',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsError(
    ThemeData theme,
    ColorScheme colorScheme,
    String message,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.errorContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se pudieron generar sugerencias en este momento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _generateAISuggestions(force: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryCoachPlanCard(
    ThemeData theme,
    ColorScheme colorScheme,
    StoryCoachPlan plan,
  ) {
    final statusColor = _suggestionsStatusColor(plan.status, colorScheme)
        .withValues(alpha: 0.85);
    final statusLabel = _suggestionsStatusLabel(plan.status);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isSuggestionsLoading)
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: statusColor,
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.4),
                ),
              ),
            if (_isSuggestionsLoading) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_rounded, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.summary,
                        style:
                            theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (plan.missingPieces.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(18),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flag_outlined, color: colorScheme.error),
                        const SizedBox(width: 8),
                        Text(
                          'Información que puedes detallar más',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...plan.missingPieces.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.radio_button_unchecked,
                              size: 14,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            for (final section in plan.sections) ...[
              const SizedBox(height: 18),
              _buildStoryCoachSection(section, theme, colorScheme),
            ],
            if (plan.nextSteps.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Siguientes pasos sugeridos',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...plan.nextSteps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (plan.warmups.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                plan.isStarting
                    ? 'Ideas para comenzar a escribir'
                    : 'Preguntas extra para inspirarte',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...plan.warmups.map(
                (idea) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          idea,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.favorite_outline,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.encouragement,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                      ),
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

  Widget _buildStoryCoachSection(
    StoryCoachSection section,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final backgroundColor =
        _suggestionsSectionColor(section.purpose, colorScheme);
    final icon = _suggestionsSectionIcon(section.purpose);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (section.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        section.description!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsPlaceholder(
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Obtén orientación personalizada',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Presiona "Generar nueva sugerencia" para recibir ideas y preguntas que te acompañen a escribir tu historia.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  int _getWordCount() {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  bool _canUseGhostWriter() {
    return _getWordCount() >= 300;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) {
        if (!didPop && _hasChanges) {
          _showDiscardChangesDialog();
        }
      },
      child: _isLoading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final tabContent = _buildActiveTabContent();
                    const List<AppNavigationItem> navItems = [
                      AppNavigationItem(label: 'Inicio', icon: Icons.dashboard),
                      AppNavigationItem(
                        label: 'Historias',
                        icon: Icons.library_books,
                      ),
                      AppNavigationItem(label: 'Personas', icon: Icons.people),
                      AppNavigationItem(
                        label: 'Suscriptores',
                        icon: Icons.email,
                      ),
                      AppNavigationItem(label: 'Ajustes', icon: Icons.settings),
                    ];
                    final isCompactNav = constraints.maxWidth < 840;

                    List<Widget> buildEditorSlivers(double extraBottomPadding) {
                      final slivers = <Widget>[
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverToBoxAdapter(
                            child: _EditorHeader(
                              controller: _tabController,
                              isNewStory: widget.storyId == null,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 12),
                        ),
                        SliverPadding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompactNav ? 12 : 24,
                          ),
                          sliver: SliverToBoxAdapter(child: tabContent),
                        ),
                      ];

                      if (extraBottomPadding > 0) {
                        slivers.add(
                          SliverToBoxAdapter(
                            child: SizedBox(height: extraBottomPadding),
                          ),
                        );
                      }

                      return slivers;
                    }

                    Widget buildScrollableBody(
                        {double extraBottomPadding = 0}) {
                      final scrollView = CustomScrollView(
                        controller: _editorScrollController,
                        physics: const ClampingScrollPhysics(),
                        slivers: buildEditorSlivers(extraBottomPadding),
                      );

                      final decoratedScrollView = isCompactNav
                          ? scrollView
                          : Scrollbar(
                              controller: _editorScrollController,
                              child: scrollView,
                            );

                      return NotificationListener<ScrollNotification>(
                        onNotification: _handleScrollNotification,
                        child: decoratedScrollView,
                      );
                    }

                    return Column(
                      children: [
                        AppTopNavigationBar(
                          items: navItems,
                          currentIndex: 1,
                          isCompact: isCompactNav,
                          isMenuOpen: _isTopMenuOpen,
                          isScrolled: _isTopBarElevated,
                          onItemSelected: _handleTopNavSelection,
                          onCreateStory: _handleTopNavCreateStory,
                          onToggleMenu: _toggleTopMenu,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: buildScrollableBody(
                            extraBottomPadding: isCompactNav ? 16 : 0,
                          ),
                        ),
                        if (isCompactNav)
                          _buildBottomBarShell(
                            maxWidth: constraints.maxWidth,
                            isCompactNav: true,
                          ),
                      ],
                    );
                  },
                ),
              ),
              bottomNavigationBar: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompactNav = constraints.maxWidth < 840;
                  if (isCompactNav) {
                    return const SizedBox.shrink();
                  }

                  return _buildBottomBarShell(
                    maxWidth: constraints.maxWidth,
                    isCompactNav: false,
                  );
                },
              ),
            ),
    );
  }

  Widget _buildBottomBarShell({
    required double maxWidth,
    required bool isCompactNav,
  }) {
    final horizontalPadding = isCompactNav ? 12.0 : 16.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          8,
          horizontalPadding,
          isCompactNav ? 12 : 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: _EditorBottomBar(
            isSaving: _isSaving,
            onSaveDraft: () {
              unawaited(_saveDraft());
            },
            onPublish: _showPublishDialog,
            onOpenDictation: _openDictationPanel,
            canPublish: _canPublish(),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_tabController.index) {
      case 1:
        return _buildPhotosTab();
      case 2:
        return _buildDatesTab();
      case 3:
        return _buildTagsTab();
      default:
        return _buildWritingTab();
    }
  }

  Widget _buildWritingTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wordCount = _getWordCount();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final cardPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 20 : 28,
          vertical: isCompact ? 20 : 28,
        );
        final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
          height: 1.48,
        );
        final fontSize = bodyStyle?.fontSize ?? 16;
        final lineHeight = (bodyStyle?.height ?? 1.48) * fontSize;
        final minContentHeight = lineHeight * 10;
        final fieldRadius = BorderRadius.circular(isCompact ? 22 : 24);
        final fieldFillColor =
            colorScheme.surfaceContainerHighest.withValues(alpha: isCompact ? 0.75 : 0.6);
        final fieldBorderColor =
            colorScheme.outlineVariant.withValues(alpha: 0.28);

        BoxDecoration buildFieldDecoration() {
          return BoxDecoration(
            color: fieldFillColor,
            borderRadius: fieldRadius,
            border: Border.all(color: fieldBorderColor),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          );
        }

        Widget buildTitleField() {
          return DecoratedBox(
            decoration: buildFieldDecoration(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 18 : 24,
                vertical: isCompact ? 14 : 18,
              ),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Título de tu historia...',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                enableSuggestions: false,
                autocorrect: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          );
        }

        Widget buildContentField() {
          return DecoratedBox(
            decoration: buildFieldDecoration(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 18 : 24,
                isCompact ? 16 : 22,
                isCompact ? 18 : 24,
                isCompact ? 22 : 28,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: minContentHeight,
                ),
                child: TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: 'Cuenta tu historia...',
                    border: InputBorder.none,
                    hintStyle: bodyStyle?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  style: bodyStyle,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 10,
                  textAlignVertical: TextAlignVertical.top,
                  enableSuggestions: false,
                  autocorrect: false,
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
          );
        }

        Widget buildInfoPill(IconData icon, String label) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh.withValues(
                alpha: isCompact ? 0.65 : 0.55,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final actionHeight = isCompact ? 42.0 : 46.0;
        final actionSpacing = isCompact ? 10.0 : 14.0;
        final actionRunSpacing = isCompact ? 10.0 : 12.0;

        final editorChildren = <Widget>[
          Text(
            'Tu historia',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),
          buildTitleField(),
          SizedBox(height: isCompact ? 18 : 24),
          Text(
            'Narración',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: isCompact ? 12 : 16),
          buildContentField(),
          SizedBox(height: isCompact ? 18 : 26),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: actionSpacing,
                  runSpacing: actionRunSpacing,
                  children: [
                    SizedBox(
                      height: actionHeight,
                      child: OutlinedButton.icon(
                        onPressed: _isGhostWriterProcessing
                            ? null
                            : _handleGhostWriterPressed,
                        icon: _isGhostWriterProcessing
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation(
                                    colorScheme.primary,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.auto_fix_high,
                                color: _canUseGhostWriter()
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                        label: Text(
                          _isGhostWriterProcessing
                              ? 'Trabajando...'
                              : 'Ghost Writer',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 20,
                            vertical: isCompact ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          foregroundColor: _canUseGhostWriter()
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          side: BorderSide(
                            color: _canUseGhostWriter()
                                ? colorScheme.primary.withValues(alpha: 0.55)
                                : colorScheme.outlineVariant.withValues(alpha: 0.7),
                          ),
                          textStyle: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: actionHeight,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _showSuggestions = !_showSuggestions);
                          if (_showSuggestions) {
                            _generateAISuggestions();
                          }
                        },
                        icon: Icon(
                          _showSuggestions
                              ? Icons.lightbulb
                              : Icons.lightbulb_outline,
                        ),
                        label: const Text('Sugerencias'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 16 : 20,
                            vertical: isCompact ? 10 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          foregroundColor: _showSuggestions
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          side: BorderSide(
                            color: _showSuggestions
                                ? colorScheme.primary.withValues(alpha: 0.55)
                                : colorScheme.outlineVariant.withValues(alpha: 0.6),
                          ),
                          textStyle: theme.textTheme.labelLarge,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isCompact ? 8 : 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: isCompact ? 0.7 : 0.55,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  onSelected: _handleAppBarAction,
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 10 : 12,
                    vertical: isCompact ? 6 : 8,
                  ),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view_versions',
                      child: Row(
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 8),
                          Text('Historial de versiones'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ];

        final timestampLabel = _formattedSuggestionsTimestamp();
        editorChildren.add(
          Padding(
            padding: EdgeInsets.only(top: isCompact ? 10 : 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                buildInfoPill(Icons.text_fields_rounded, 'Palabras: $wordCount'),
                if (_showSuggestions && timestampLabel != null)
                  buildInfoPill(Icons.schedule, timestampLabel),
              ],
            ),
          ),
        );

        if (_showSuggestions) {
          editorChildren.add(SizedBox(height: isCompact ? 18 : 24));

          final header = isCompact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acompañamiento inteligente para tu historia',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isSuggestionsLoading
                          ? null
                          : () => _generateAISuggestions(force: true),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generar nueva sugerencia'),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        'Acompañamiento inteligente para tu historia',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: _isSuggestionsLoading
                          ? null
                          : () => _generateAISuggestions(force: true),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generar nueva sugerencia'),
                    ),
                  ],
                );

          editorChildren.add(header);
          editorChildren.add(SizedBox(height: isCompact ? 14 : 18));

          Widget suggestionsContent;
          if (_isSuggestionsLoading && _storyCoachPlan == null) {
            suggestionsContent = _buildSuggestionsLoading(theme, colorScheme);
          } else if (_suggestionsError != null) {
            suggestionsContent =
                _buildSuggestionsError(theme, colorScheme, _suggestionsError!);
          } else if (_storyCoachPlan != null) {
            suggestionsContent = _buildStoryCoachPlanCard(
              theme,
              colorScheme,
              _storyCoachPlan!,
            );
          } else {
            suggestionsContent =
                _buildSuggestionsPlaceholder(theme, colorScheme);
          }

          editorChildren.add(suggestionsContent);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            isCompact ? 6 : 10,
            12,
            isCompact ? 16 : 20,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(28),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: cardPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: editorChildren,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotosTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final outerPadding = EdgeInsets.fromLTRB(
          12,
          isCompact ? 12 : 16,
          12,
          isCompact ? 12 : 16,
        );
        final innerPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 18 : 24,
          vertical: isCompact ? 18 : 24,
        );

        return Padding(
          padding: outerPadding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: innerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Fotos (${_photos.length}/8)',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_photos.length < 8)
                        FilledButton.tonalIcon(
                          onPressed: _addPhoto,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Añadir foto'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            shape: const StadiumBorder(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Usa "Colocar foto" para insertar placeholders [img_1] en tu texto. Puedes mover los placeholders libremente.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_photos.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.photo_library_outlined,
                      title: 'No hay fotos aún',
                      message: 'Añade hasta 8 fotos para ilustrar tu historia',
                      actionLabel: 'Añadir primera foto',
                      onAction: _addPhoto,
                    )
                  else
                    Column(
                      children: [
                        for (var index = 0;
                            index < _photos.length;
                            index++) ...[
                          PhotoCard(
                            key: ValueKey(_photos[index]['id']),
                            photo: _photos[index],
                            index: index,
                            onEdit: () => _editPhoto(index),
                            onDelete: () => _deletePhoto(index),
                            onInsertIntoText: () => _insertPhotoIntoText(index),
                          ),
                          if (index != _photos.length - 1)
                            const SizedBox(height: 14),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDatesTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final outerPadding = EdgeInsets.fromLTRB(
          12,
          isCompact ? 12 : 16,
          12,
          isCompact ? 12 : 16,
        );
        final innerPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 18 : 24,
          vertical: isCompact ? 18 : 24,
        );
        final cardRadius = BorderRadius.circular(24);

        return Padding(
          padding: outerPadding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: innerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fechas de la historia',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Define cuándo sucedió tu recuerdo para darle contexto.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: cardRadius,
                      color: colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.55),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 20,
                        vertical: isCompact ? 16 : 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Precisión de fechas',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'day', label: Text('Día')),
                              ButtonSegment(value: 'month', label: Text('Mes')),
                              ButtonSegment(value: 'year', label: Text('Año')),
                            ],
                            selected: {_datesPrecision},
                            onSelectionChanged: (selection) {
                              setState(() {
                                _datesPrecision = selection.first;
                              });
                            },
                            style: ButtonStyle(
                              shape: WidgetStateProperty.all(
                                const StadiumBorder(),
                              ),
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: cardRadius,
                      color: colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.55),
                    ),
                    child: Column(
                      children: [
                        _DateTile(
                          icon: Icons.event,
                          title: 'Fecha de inicio',
                          subtitle: _startDate != null
                              ? _formatDate(_startDate!, _datesPrecision)
                              : 'No especificada',
                          onTap: () => _selectDate(context, true),
                        ),
                        Divider(
                          height: 1,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.15),
                        ),
                        _DateTile(
                          icon: Icons.event_busy,
                          title: 'Fecha de fin (opcional)',
                          subtitle: _endDate != null
                              ? _formatDate(_endDate!, _datesPrecision)
                              : 'No especificada',
                          onTap: () => _selectDate(context, false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagsTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final visibleSections = _visibleTagSections;
    final hasSearch = _tagSearchQuery.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final outerPadding = EdgeInsets.fromLTRB(
          12,
          isCompact ? 12 : 16,
          12,
          isCompact ? 12 : 16,
        );
        final innerPadding = EdgeInsets.symmetric(
          horizontal: isCompact ? 18 : 24,
          vertical: isCompact ? 18 : 24,
        );

        return Padding(
          padding: outerPadding,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: innerPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_offer_outlined,
                          color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Etiquetas temáticas',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Elige etiquetas que ayuden a tu familia a navegar por tus recuerdos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _tagSearchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _tagSearchQuery.isNotEmpty
                          ? IconButton(
                              tooltip: 'Limpiar búsqueda',
                              onPressed: () {
                                _tagSearchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                      hintText:
                          'Busca momentos como infancia, viajes, amistades...',
                      filled: true,
                      fillColor: colorScheme.surfaceVariant
                          .withValues(alpha: isCompact ? 0.25 : 0.18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    textInputAction: TextInputAction.search,
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _selectedTags.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            key: const ValueKey('selected-tags'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ya elegiste (${_selectedTags.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _selectedTags
                                    .map((tag) => _buildSelectedTagChip(tag))
                                    .toList(),
                              ),
                              const SizedBox(height: 22),
                            ],
                          ),
                  ),
                  Text(
                    hasSearch
                        ? 'Resultados para "${_tagSearchQuery.trim()}"'
                        : 'Explora por categorías',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visibleSections.isEmpty)
                    _buildEmptyTagSearchState(theme, isCompact)
                  else
                    Column(
                      children: visibleSections
                          .map((section) =>
                              _buildTagSectionCard(section, isCompact))
                          .toList(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<_TagPaletteSection> get _visibleTagSections {
    final query = _tagSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _tagSections;

    return _tagSections
        .map((section) {
          final matches = section.tags
              .where((tag) => tag.name.toLowerCase().contains(query))
              .toList();
          if (matches.isEmpty) return null;
          return section.copyWith(tags: matches);
        })
        .whereType<_TagPaletteSection>()
        .toList();
  }

  Widget _buildSelectedTagChip(String tagName) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final option = _getTagOption(tagName);
    final color = option?.color ?? colorScheme.secondaryContainer;
    final onColor = _onColorFor(color);

    return InputChip(
      avatar: option?.emoji != null
          ? Text(option!.emoji!, style: const TextStyle(fontSize: 18))
          : null,
      label: Text(tagName),
      onDeleted: () => _toggleTag(tagName),
      deleteIcon: const Icon(Icons.close_rounded, size: 18),
      deleteIconColor: onColor.withValues(alpha: 0.9),
      backgroundColor: color.withValues(alpha: 0.3),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        color: onColor,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildEmptyTagSearchState(ThemeData theme, bool isCompact) {
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 18 : 26,
        vertical: isCompact ? 28 : 34,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: colorScheme.surfaceVariant.withValues(alpha: 0.18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore,
              color: colorScheme.primary, size: isCompact ? 32 : 36),
          const SizedBox(height: 12),
          Text(
            'No encontramos etiquetas con esa búsqueda.',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Prueba con palabras como familia, escuela, viajes, salud o tecnología.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTagSectionCard(
      _TagPaletteSection section, bool isCompactLayout) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = section.tags.isNotEmpty
        ? section.tags.first.color
        : colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: isCompactLayout ? 16 : 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.14),
              accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompactLayout ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(section.icon, color: accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                section.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children:
                    section.tags.map((tag) => _buildTagChip(tag)).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(_TagOption tag) {
    final theme = Theme.of(context);
    final isSelected = _isTagSelected(tag.name);
    final baseColor = tag.color;
    final onBase = _onColorFor(baseColor);

    return FilterChip(
      avatar: tag.emoji != null
          ? Text(tag.emoji!, style: const TextStyle(fontSize: 18))
          : null,
      label: Text(tag.name),
      selected: isSelected,
      onSelected: (_) => _toggleTag(tag.name),
      showCheckmark: true,
      checkmarkColor: onBase,
      backgroundColor: baseColor.withValues(alpha: 0.12),
      selectedColor: baseColor.withValues(alpha: 0.24),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: isSelected ? onBase : theme.colorScheme.onSurface,
      ),
      side: BorderSide(
        color: baseColor.withValues(alpha: isSelected ? 0.6 : 0.35),
      ),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  void _updateTagSections(List<_TagPaletteSection> sections) {
    setState(() {
      _tagSections = sections;
      _registerTagLookup(_tagSections);
    });
  }

  void _registerTagLookup(List<_TagPaletteSection> sections) {
    _tagLookup
      ..clear()
      ..addEntries(sections.expand((section) => section.tags).map(
            (tag) => MapEntry(tag.name.toLowerCase(), tag),
          ));
  }

  List<_TagPaletteSection> _mergeTagSectionsWithUserTags(List<Tag> userTags) {
    final sections = _buildCuratedTagSections();

    for (final userTag in userTags) {
      final rawName = userTag.name.trim();
      if (rawName.isEmpty) continue;
      final normalized = rawName.toLowerCase();
      bool matchedCurated = false;

      for (var sectionIndex = 0;
          sectionIndex < sections.length && !matchedCurated;
          sectionIndex++) {
        final section = sections[sectionIndex];
        final tagIndex = section.tags.indexWhere(
          (tag) => tag.name.toLowerCase() == normalized,
        );
        if (tagIndex != -1) {
          final updatedTags = List<_TagOption>.from(section.tags);
          updatedTags[tagIndex] = updatedTags[tagIndex]
              .copyWith(color: _colorFromHex(userTag.color));
          sections[sectionIndex] = section.copyWith(tags: updatedTags);
          matchedCurated = true;
        }
      }

      if (!matchedCurated) {
        final customTag = _TagOption(
          name: rawName,
          color: _colorFromHex(userTag.color),
          category: _personalTagsTitle,
          emoji: null,
        );
        _applyCustomTags(sections, [customTag]);
      }
    }

    return sections;
  }

  void _ensureSelectedTagsInPalette() {
    if (_selectedTags.isEmpty) return;
    final theme = Theme.of(context);
    final accent = theme.colorScheme.secondary;
    final missing = <_TagOption>[];

    for (final tag in _selectedTags) {
      final normalized = tag.toLowerCase();
      if (_tagLookup.containsKey(normalized)) continue;
      missing.add(_TagOption(
        name: tag,
        color: accent,
        category: _personalTagsTitle,
      ));
    }

    if (missing.isEmpty) return;
    setState(() {
      _applyCustomTags(_tagSections, missing);
      _registerTagLookup(_tagSections);
    });
  }

  void _applyCustomTags(
    List<_TagPaletteSection> sections,
    List<_TagOption> newTags,
  ) {
    if (newTags.isEmpty) return;

    final sortedTags = List<_TagOption>.from(newTags)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final existingIndex =
        sections.indexWhere((section) => section.title == _personalTagsTitle);

    if (existingIndex != -1) {
      final existingSection = sections[existingIndex];
      final existingNames =
          existingSection.tags.map((tag) => tag.name.toLowerCase()).toSet();
      final mergedTags = List<_TagOption>.from(existingSection.tags);

      for (final tag in sortedTags) {
        if (existingNames.contains(tag.name.toLowerCase())) continue;
        mergedTags.add(tag);
        existingNames.add(tag.name.toLowerCase());
      }

      mergedTags
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      sections[existingIndex] = existingSection.copyWith(tags: mergedTags);
    } else {
      sections.insert(
        0,
        _TagPaletteSection(
          title: _personalTagsTitle,
          description:
              'Etiquetas personalizadas que has creado para tu familia.',
          icon: Icons.auto_awesome,
          tags: sortedTags,
        ),
      );
    }
  }

  List<_TagPaletteSection> _buildCuratedTagSections() {
    return [
      _TagPaletteSection(
        title: 'Raíces y familia',
        description:
            'Recuerdos del hogar, figuras importantes y tradiciones que marcaron tu infancia.',
        icon: Icons.family_restroom,
        tags: [
          _TagOption(
            name: 'Familia',
            color: const Color(0xFFF97362),
            category: 'Raíces y familia',
            emoji: '🏡',
          ),
          _TagOption(
            name: 'Infancia',
            color: const Color(0xFFFABF58),
            category: 'Raíces y familia',
            emoji: '🧸',
          ),
          _TagOption(
            name: 'Padres',
            color: const Color(0xFFFF8A80),
            category: 'Raíces y familia',
            emoji: '❤️',
          ),
          _TagOption(
            name: 'Hermanos',
            color: const Color(0xFFFFAFCC),
            category: 'Raíces y familia',
            emoji: '🤗',
          ),
          _TagOption(
            name: 'Tradiciones familiares',
            color: const Color(0xFFFFD166),
            category: 'Raíces y familia',
            emoji: '🎎',
          ),
          _TagOption(
            name: 'Hogar',
            color: const Color(0xFFFFC4A8),
            category: 'Raíces y familia',
            emoji: '🏠',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Amor y amistades',
        description:
            'Personas especiales, vínculos afectivos y momentos que hicieron latir tu corazón.',
        icon: Icons.favorite_outline,
        tags: [
          _TagOption(
            name: 'Historia de amor',
            color: const Color(0xFFFF8FA2),
            category: 'Amor y amistades',
            emoji: '💕',
          ),
          _TagOption(
            name: 'Pareja',
            color: const Color(0xFFFB6F92),
            category: 'Amor y amistades',
            emoji: '💑',
          ),
          _TagOption(
            name: 'Matrimonio',
            color: const Color(0xFFFFC6A5),
            category: 'Amor y amistades',
            emoji: '💍',
          ),
          _TagOption(
            name: 'Hijos',
            color: const Color(0xFFFFB347),
            category: 'Amor y amistades',
            emoji: '👶',
          ),
          _TagOption(
            name: 'Nietos',
            color: const Color(0xFFFFD6BA),
            category: 'Amor y amistades',
            emoji: '👵',
          ),
          _TagOption(
            name: 'Amistad',
            color: const Color(0xFF74C69D),
            category: 'Amor y amistades',
            emoji: '🤝',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Escuela y formación',
        description:
            'Aulas, aprendizajes, maestros y descubrimientos que formaron tu manera de ver la vida.',
        icon: Icons.school,
        tags: [
          _TagOption(
            name: 'Escuela',
            color: const Color(0xFF4BA3C3),
            category: 'Escuela y formación',
            emoji: '🏫',
          ),
          _TagOption(
            name: 'Universidad',
            color: const Color(0xFF6C63FF),
            category: 'Escuela y formación',
            emoji: '🎓',
          ),
          _TagOption(
            name: 'Mentores',
            color: const Color(0xFF89A1EF),
            category: 'Escuela y formación',
            emoji: '🧑‍🏫',
          ),
          _TagOption(
            name: 'Primer día de clases',
            color: const Color(0xFF80C7FF),
            category: 'Escuela y formación',
            emoji: '📚',
          ),
          _TagOption(
            name: 'Graduación',
            color: const Color(0xFF9381FF),
            category: 'Escuela y formación',
            emoji: '🎉',
          ),
          _TagOption(
            name: 'Actividades escolares',
            color: const Color(0xFF59C3C3),
            category: 'Escuela y formación',
            emoji: '🎨',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Trabajo y propósito',
        description:
            'Profesiones, vocaciones y proyectos que te dieron identidad y sentido.',
        icon: Icons.work_outline,
        tags: [
          _TagOption(
            name: 'Primer trabajo',
            color: const Color(0xFF0077B6),
            category: 'Trabajo y propósito',
            emoji: '💼',
          ),
          _TagOption(
            name: 'Carrera profesional',
            color: const Color(0xFF00B4D8),
            category: 'Trabajo y propósito',
            emoji: '📈',
          ),
          _TagOption(
            name: 'Emprendimiento',
            color: const Color(0xFF48CAE4),
            category: 'Trabajo y propósito',
            emoji: '🚀',
          ),
          _TagOption(
            name: 'Mentoría laboral',
            color: const Color(0xFF8ECAE6),
            category: 'Trabajo y propósito',
            emoji: '🧭',
          ),
          _TagOption(
            name: 'Jubilación',
            color: const Color(0xFF90E0EF),
            category: 'Trabajo y propósito',
            emoji: '⛱️',
          ),
          _TagOption(
            name: 'Servicio comunitario',
            color: const Color(0xFF6BCB77),
            category: 'Trabajo y propósito',
            emoji: '🤲',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Aventuras y viajes',
        description:
            'Travesías, cambios de ciudad y experiencias que te mostraron nuevos horizontes.',
        icon: Icons.flight_takeoff,
        tags: [
          _TagOption(
            name: 'Viajes',
            color: const Color(0xFF00A6FB),
            category: 'Aventuras y viajes',
            emoji: '✈️',
          ),
          _TagOption(
            name: 'Mudanzas',
            color: const Color(0xFF72EFDD),
            category: 'Aventuras y viajes',
            emoji: '🚚',
          ),
          _TagOption(
            name: 'Naturaleza',
            color: const Color(0xFF2BB673),
            category: 'Aventuras y viajes',
            emoji: '🌿',
          ),
          _TagOption(
            name: 'Cultura',
            color: const Color(0xFFFFC857),
            category: 'Aventuras y viajes',
            emoji: '🎭',
          ),
          _TagOption(
            name: 'Descubrimientos',
            color: const Color(0xFF4D96FF),
            category: 'Aventuras y viajes',
            emoji: '🧭',
          ),
          _TagOption(
            name: 'Aventura en carretera',
            color: const Color(0xFF5E60CE),
            category: 'Aventuras y viajes',
            emoji: '🛣️',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Logros y celebraciones',
        description:
            'Metas alcanzadas, sorpresas y momentos brillantes para compartir con los tuyos.',
        icon: Icons.emoji_events_outlined,
        tags: [
          _TagOption(
            name: 'Logros',
            color: const Color(0xFFFFB703),
            category: 'Logros y celebraciones',
            emoji: '🏆',
          ),
          _TagOption(
            name: 'Sueños cumplidos',
            color: const Color(0xFFFF9E00),
            category: 'Logros y celebraciones',
            emoji: '🌟',
          ),
          _TagOption(
            name: 'Celebraciones familiares',
            color: const Color(0xFFFFD670),
            category: 'Logros y celebraciones',
            emoji: '🎊',
          ),
          _TagOption(
            name: 'Reconocimientos',
            color: const Color(0xFFFFC8DD),
            category: 'Logros y celebraciones',
            emoji: '🥇',
          ),
          _TagOption(
            name: 'Momentos de orgullo',
            color: const Color(0xFFFF8FAB),
            category: 'Logros y celebraciones',
            emoji: '🙌',
          ),
          _TagOption(
            name: 'Cumpleaños memorables',
            color: const Color(0xFFFFC4D6),
            category: 'Logros y celebraciones',
            emoji: '🎂',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Desafíos y resiliencia',
        description:
            'Historias de fortaleza, aprendizajes difíciles y caminos de sanación.',
        icon: Icons.psychology_alt_outlined,
        tags: [
          _TagOption(
            name: 'Enfermedad',
            color: const Color(0xFF9D4EDD),
            category: 'Desafíos y resiliencia',
            emoji: '💜',
          ),
          _TagOption(
            name: 'Recuperación',
            color: const Color(0xFFB15EFF),
            category: 'Desafíos y resiliencia',
            emoji: '🦋',
          ),
          _TagOption(
            name: 'Momentos difíciles',
            color: const Color(0xFF845EC2),
            category: 'Desafíos y resiliencia',
            emoji: '⛈️',
          ),
          _TagOption(
            name: 'Pérdidas',
            color: const Color(0xFF6D597A),
            category: 'Desafíos y resiliencia',
            emoji: '🕯️',
          ),
          _TagOption(
            name: 'Fe y esperanza',
            color: const Color(0xFF80CED7),
            category: 'Desafíos y resiliencia',
            emoji: '🕊️',
          ),
          _TagOption(
            name: 'Lecciones de vida',
            color: const Color(0xFF577590),
            category: 'Desafíos y resiliencia',
            emoji: '📖',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Momentos cotidianos',
        description:
            'Pequeños detalles, pasatiempos y costumbres que hacen tu vida única.',
        icon: Icons.local_florist_outlined,
        tags: [
          _TagOption(
            name: 'Hobbies',
            color: const Color(0xFF06D6A0),
            category: 'Momentos cotidianos',
            emoji: '🎨',
          ),
          _TagOption(
            name: 'Mascotas',
            color: const Color(0xFFFFA69E),
            category: 'Momentos cotidianos',
            emoji: '🐾',
          ),
          _TagOption(
            name: 'Recetas favoritas',
            color: const Color(0xFFFFC15E),
            category: 'Momentos cotidianos',
            emoji: '🍲',
          ),
          _TagOption(
            name: 'Música',
            color: const Color(0xFF118AB2),
            category: 'Momentos cotidianos',
            emoji: '🎶',
          ),
          _TagOption(
            name: 'Tecnología',
            color: const Color(0xFF73B0FF),
            category: 'Momentos cotidianos',
            emoji: '💡',
          ),
          _TagOption(
            name: 'Conversaciones especiales',
            color: const Color(0xFF9EADC8),
            category: 'Momentos cotidianos',
            emoji: '🗣️',
          ),
        ],
      ),
      _TagPaletteSection(
        title: 'Para todo lo demás',
        description:
            'Etiquetas versátiles para recuerdos únicos que quieres conservar.',
        icon: Icons.auto_awesome_outlined,
        tags: [
          _TagOption(
            name: 'Otros momentos',
            color: const Color(0xFFB0BEC5),
            category: 'Para todo lo demás',
            emoji: '✨',
          ),
          _TagOption(
            name: 'Recuerdos únicos',
            color: const Color(0xFFCDB4DB),
            category: 'Para todo lo demás',
            emoji: '🌀',
          ),
          _TagOption(
            name: 'Sin categoría',
            color: const Color(0xFFE2E2E2),
            category: 'Para todo lo demás',
            emoji: '📁',
          ),
        ],
      ),
    ];
  }

  _TagOption? _getTagOption(String name) {
    return _tagLookup[name.toLowerCase()];
  }

  Color _colorFromHex(String? hex) {
    if (hex == null || hex.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }

    final sanitized = hex.replaceAll('#', '').trim();

    try {
      if (sanitized.length == 6) {
        return Color(int.parse('FF$sanitized', radix: 16));
      }
      if (sanitized.length == 8) {
        return Color(int.parse(sanitized, radix: 16));
      }
    } catch (_) {
      // Ignore and fallback below
    }

    return Theme.of(context).colorScheme.primary;
  }

  Color _onColorFor(Color color) {
    return color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
  }

  bool _isTagSelected(String tag) {
    final normalized = tag.toLowerCase();
    return _selectedTags
        .any((selected) => selected.toLowerCase() == normalized);
  }

  // Helper Methods
  String get _recorderStatusLabel {
    if (_isRecorderConnecting) return 'Conectando...';
    if (_isRecording && !_isPaused) return 'Grabando...';
    if (_isPaused) return 'Pausado';
    return _liveTranscript.isNotEmpty ? 'Listo' : 'Listo';
  }

  void _appendRecorderLog(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final entry = '[$timestamp][$level] $message';
    _recorderLogs.add(entry);
    if (_recorderLogs.length > _maxRecorderLogs) {
      _recorderLogs.removeRange(
        0,
        _recorderLogs.length - _maxRecorderLogs,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  List<String> _recentRecorderLogs({int maxItems = 6}) {
    if (_recorderLogs.length <= maxItems) {
      return List<String>.from(_recorderLogs);
    }
    return _recorderLogs.sublist(_recorderLogs.length - maxItems);
  }

  void _resetLevelHistory() {
    _levelHistory
      ..clear()
      ..addAll(List<double>.filled(_visualizerBarCount, 0.0));
  }

  Duration _currentRecordingDuration() {
    if (_recordingStartedAt == null) {
      return _recordingAccumulated;
    }
    final elapsed = DateTime.now().difference(_recordingStartedAt!);
    return _recordingAccumulated + elapsed;
  }

  void _updateRecordingDuration(Duration duration) {
    final sheetUpdated = _refreshDictationSheet(
      mutateState: () => _recordingDuration = duration,
    );
    if (!sheetUpdated) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      } else {
        _recordingDuration = duration;
      }
    }
  }

  void _ensureRecordingTicker() {
    _recordingTicker ??= createTicker((_) {
      _updateRecordingDuration(_currentRecordingDuration());
    });
  }

  void _startDurationTicker() {
    _ensureRecordingTicker();
    _updateRecordingDuration(_currentRecordingDuration());
    final ticker = _recordingTicker;
    if (ticker != null && !ticker.isActive) {
      ticker.start();
    }
  }

  void _pauseDurationTicker() {
    _recordingAccumulated = _currentRecordingDuration();
    _recordingStartedAt = null;
    final ticker = _recordingTicker;
    if (ticker != null && ticker.isActive) {
      ticker.stop();
    }
    _updateRecordingDuration(_recordingAccumulated);
  }

  void _stopDurationTicker({bool reset = false}) {
    final ticker = _recordingTicker;
    if (ticker != null && ticker.isActive) {
      ticker.stop();
    }
    if (reset) {
      _recordingAccumulated = Duration.zero;
      _recordingStartedAt = null;
      _updateRecordingDuration(Duration.zero);
      return;
    }

    _recordingAccumulated = _currentRecordingDuration();
    _recordingStartedAt = null;
    _updateRecordingDuration(_recordingAccumulated);
  }

  void _handleMicLevel(double level) {
    final clamped = level.clamp(0.0, 1.0);
    final previous = _levelHistory.isEmpty ? clamped : _levelHistory.last;
    final smoothed = (previous * 0.35) + (clamped * 0.65);
    if (_levelHistory.length >= _visualizerBarCount) {
      _levelHistory.removeFirst();
    }
    _levelHistory.add(smoothed);

    final sheetUpdated = _refreshDictationSheet();
    if (!sheetUpdated && mounted) {
      setState(() {});
    }
  }

  bool _refreshDictationSheet({VoidCallback? mutateState}) {
    mutateState?.call();
    final updater = _sheetStateUpdater['dictation'];
    if (updater != null) {
      try {
        updater(() {});
        return true;
      } catch (_) {
        // Ignore errors when the sheet is closing.
      }
    }
    return false;
  }

  void _stopPlayback({bool resetPosition = true}) {
    final audio = _playbackAudio;
    if (audio == null) {
      if (resetPosition) {
        _playbackProgressSeconds = 0;
      }
      _isPlaybackPlaying = false;
      return;
    }

    audio.pause();
    if (resetPosition) {
      audio.currentTime = 0;
    }

    if (mounted) {
      setState(() {
        _isPlaybackPlaying = false;
        if (resetPosition) {
          _playbackProgressSeconds = 0;
        }
      });
    } else {
      _isPlaybackPlaying = false;
      if (resetPosition) {
        _playbackProgressSeconds = 0;
      }
    }
  }

  void _disposePlaybackAudio() {
    _stopPlayback();
    _playbackEndedSub?.cancel();
    _playbackTimeUpdateSub?.cancel();
    _playbackMetadataSub?.cancel();
    _playbackEndedSub = null;
    _playbackTimeUpdateSub = null;
    _playbackMetadataSub = null;

    final url = _recordingObjectUrl;
    if (url != null) {
      html.Url.revokeObjectUrl(url);
      _recordingObjectUrl = null;
    }

    _playbackAudio = null;
    _playbackDurationSeconds = null;
    _playbackProgressSeconds = 0;
  }

  Future<void> _preparePlaybackAudio(typed.Uint8List bytes) async {
    _disposePlaybackAudio();

    final blob = html.Blob([bytes], 'audio/webm');
    final url = html.Url.createObjectUrl(blob);
    final audio = html.AudioElement()
      ..src = url
      ..preload = 'auto'
      ..controls = false;

    _recordingObjectUrl = url;
    _playbackAudio = audio;
    _isPlaybackPlaying = false;
    _playbackProgressSeconds = 0;
    _playbackDurationSeconds = null;

    _playbackEndedSub = audio.onEnded.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaybackPlaying = false;
          _playbackProgressSeconds = 0;
        });
      } else {
        _isPlaybackPlaying = false;
        _playbackProgressSeconds = 0;
      }
    });

    _playbackTimeUpdateSub = audio.onTimeUpdate.listen((_) {
      final current = (audio.currentTime ?? 0).toDouble();
      if (mounted) {
        setState(() {
          _playbackProgressSeconds = current;
        });
      } else {
        _playbackProgressSeconds = current;
      }
    });

    _playbackMetadataSub = audio.onLoadedMetadata.listen((_) {
      final duration = audio.duration;
      if (duration.isFinite && duration > 0) {
        final seconds = duration.toDouble();
        if (mounted) {
          setState(() {
            _playbackDurationSeconds = seconds;
          });
        } else {
          _playbackDurationSeconds = seconds;
        }
      }
    });
  }

  Future<void> _togglePlayback() async {
    final audio = _playbackAudio;
    if (audio == null) {
      return;
    }

    if (_isPlaybackPlaying) {
      _stopPlayback();
      return;
    }

    try {
      await audio.play();
      if (mounted) {
        setState(() {
          _isPlaybackPlaying = true;
        });
      } else {
        _isPlaybackPlaying = true;
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reproducir el audio: $error')),
      );
    }
  }

  void _clearRecordedAudio() {
    _stopPlayback();
    _disposePlaybackAudio();
    _recordedAudioBytes = null;
    _recordedAudioUploaded = false;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildWaveformBars(BuildContext context) {
    final levels = _levelHistory.toList(growable: false);
    final theme = Theme.of(context);
    final isActive = _isRecording && !_isPaused;
    final baseColor = isActive ? Colors.redAccent : theme.colorScheme.primary;
    final softAlpha = _isPaused ? 0.25 : 0.55;
    final highlightAlpha = math.min(1.0, softAlpha + 0.1);
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        baseColor.withValues(alpha: 0.9),
        baseColor.withValues(alpha: softAlpha),
      ],
    );
    final shimmerColor = baseColor.withValues(alpha: isActive ? 0.2 : 0.12);

    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barCount = levels.length;
              if (barCount == 0) {
                return const SizedBox.expand();
              }

              const spacing = 1.8;
              final totalSpacing = spacing * (barCount - 1);
              final barWidth = math.max(
                2.0,
                (constraints.maxWidth - totalSpacing) / barCount,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            shimmerColor,
                            baseColor.withValues(alpha: highlightAlpha),
                            shimmerColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(barCount, (index) {
                      final double value =
                          levels[index].clamp(0.0, 1.0).toDouble();
                      final targetHeight = 8 + value * 36;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == barCount - 1 ? 0 : spacing,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 45),
                            curve: Curves.easeOutCubic,
                            width: barWidth,
                            height: targetHeight,
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(
                                barWidth.clamp(1.8, 6.0),
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color:
                                            baseColor.withValues(alpha: 0.16),
                                        blurRadius: 6,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 1.2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackSeconds = _recordingDuration.inMilliseconds > 0
        ? _recordingDuration.inMilliseconds / 1000.0
        : 0.0;
    final candidateSeconds = _playbackDurationSeconds ?? fallbackSeconds;
    final totalSeconds = candidateSeconds.isFinite && candidateSeconds > 0
        ? candidateSeconds
        : fallbackSeconds;
    final clampedProgress = totalSeconds <= 0
        ? 0.0
        : (_playbackProgressSeconds / totalSeconds).clamp(0.0, 1.0);
    final totalDuration = totalSeconds <= 0
        ? _recordingDuration
        : Duration(milliseconds: (totalSeconds * 1000).round());
    final currentDuration = Duration(
      milliseconds: (_playbackProgressSeconds * 1000).round(),
    );

    final statusLabel = _recordedAudioUploaded
        ? 'Audio guardado con la historia'
        : 'Se guardará al guardar la historia';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed:
                  _playbackAudio == null ? null : () => _togglePlayback(),
              icon: Icon(_isPlaybackPlaying ? Icons.stop : Icons.play_arrow),
              tooltip: _isPlaybackPlaying
                  ? 'Detener reproducción'
                  : 'Reproducir audio',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: clampedProgress),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDuration(currentDuration)} / ${_formatDuration(totalDuration)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          statusLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  void _handleAppBarAction(String action) {
    switch (action) {
      case 'view_versions':
        _showVersionHistory();
        break;
    }
  }

  void _startAutoVersionTimer() {
    _autoVersionTimer?.cancel();
    _autoVersionTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      if (!_hasChanges) return;
      if (_titleController.text.trim().isEmpty &&
          _contentController.text.trim().isEmpty) {
        return;
      }
      _captureVersion(reason: 'Guardado automático (5 minutos)');
    });
  }

  String _buildVersionSignature(String title, String content) {
    return '${title.trim()}\n${content.trim()}';
  }

  void _captureVersion({
    required String reason,
    bool includeIfUnchanged = false,
    DateTime? savedAt,
  }) {
    if (!mounted) return;
    final title = _titleController.text;
    final content = _contentController.text;
    final signature = _buildVersionSignature(title, content);

    if (!includeIfUnchanged && signature == _lastVersionSignature) {
      return;
    }

    final entry = _StoryVersionEntry(
      title: title,
      content: content,
      savedAt: (savedAt ?? DateTime.now()).toLocal(),
      reason: reason,
    );

    setState(() {
      _versionHistory.insert(0, entry);
      if (_versionHistory.length > 60) {
        _versionHistory.removeRange(60, _versionHistory.length);
      }
      _lastVersionSignature = signature;
    });
  }

  void _applyTranscriptInsertion(VoidCallback insertion) {
    _captureVersion(reason: 'Estado previo al dictado');
    insertion();
    _captureVersion(reason: 'Se añadió un dictado');
  }

  String _formatVersionTimestamp(DateTime timestamp) {
    final localizations = MaterialLocalizations.of(context);
    final localTime = timestamp.toLocal();
    final dateLabel = localizations.formatShortDate(localTime);
    final timeLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localTime),
      alwaysUse24HourFormat: true,
    );
    return '$dateLabel · $timeLabel';
  }

  _VersionHistoryVisuals _resolveVersionHistoryVisuals(
    String reason,
    ThemeData theme,
  ) {
    final colorScheme = theme.colorScheme;
    final normalized = reason.toLowerCase();

    bool matchesAny(Iterable<String> values) {
      for (final candidate in values) {
        if (normalized.contains(candidate)) {
          return true;
        }
      }
      return false;
    }

    IconData icon = Icons.history_rounded;
    Color accent = colorScheme.primary;

    void assign(IconData newIcon, Color newAccent) {
      icon = newIcon;
      accent = newAccent;
    }

    if (matchesAny(['estado previo', 'estado antes'])) {
      assign(Icons.layers_rounded, colorScheme.outline);
    } else if (matchesAny(['versión inicial', 'version inicial'])) {
      assign(Icons.auto_awesome_rounded, colorScheme.secondary);
    } else if (matchesAny(['borrador'])) {
      assign(Icons.save_alt_rounded, colorScheme.primary);
    } else if (matchesAny(['ghost writer', 'ghostwriter'])) {
      assign(Icons.auto_fix_high_rounded, colorScheme.tertiary);
    } else if (matchesAny(
        ['dictado', 'transcrip', 'transcripción', 'transcripcion'])) {
      assign(Icons.mic_rounded, colorScheme.secondary);
    } else if (matchesAny(['restaur', 'restaurar'])) {
      assign(Icons.restart_alt_rounded, colorScheme.secondary);
    } else if (matchesAny(['automático', 'automatico', '5 minutos'])) {
      assign(Icons.schedule_rounded, colorScheme.outline);
    }

    final Color iconBackground = accent == colorScheme.outline
        ? colorScheme.outlineVariant.withValues(alpha: 0.18)
        : accent.withValues(alpha: 0.16);
    final Color metaColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.8);

    return _VersionHistoryVisuals(
      icon: icon,
      accent: accent,
      iconBackground: iconBackground,
      metaColor: metaColor,
    );
  }

  void _insertAtCursor(String text) {
    final selection = _contentController.selection;
    final full = _contentController.text;
    if (!selection.isValid) {
      _contentController.text += text;
      _contentController.selection =
          TextSelection.collapsed(offset: _contentController.text.length);
    } else {
      final start = selection.start;
      final end = selection.end;
      final newText = full.replaceRange(start, end, text);
      _contentController.text = newText;
      final caret = start + text.length;
      _contentController.selection = TextSelection.collapsed(offset: caret);
    }
    setState(() {
      _hasChanges = true;
    });
  }

  void _scrollTranscriptToBottom() {
    if (!_transcriptScrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_transcriptScrollController.hasClients) {
        return;
      }

      final position = _transcriptScrollController.position;
      final target = position.maxScrollExtent;
      if (position.pixels >= target) {
        return;
      }

      _transcriptScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleTranscriptChunk(String text) {
    final sanitized = text;

    if (!mounted) {
      _liveTranscript = sanitized;
      return;
    }

    if (_liveTranscript == sanitized) {
      return;
    }

    setState(() {
      _liveTranscript = sanitized;
    });

    final sheetUpdater = _sheetStateUpdater['dictation'];
    sheetUpdater?.call(() {
      _scrollTranscriptToBottom();
    });

    _scrollTranscriptToBottom();

    if (sanitized.isEmpty) {
      return;
    }
  }

  Future<void> _startRecording({bool resetTranscript = false}) async {
    if (resetTranscript) {
      if (mounted) {
        setState(() {
          _liveTranscript = '';
        });
      } else {
        _liveTranscript = '';
      }
    }

    _clearRecordedAudio();
    _resetLevelHistory();
    _stopDurationTicker(reset: true);

    if (mounted) {
      setState(() {
        _isRecorderConnecting = true;
        _recorderLogs.clear();
      });
    } else {
      _isRecorderConnecting = true;
      _recorderLogs.clear();
    }

    final recorder = VoiceRecorder();
    try {
      await recorder.start(
        onText: _handleTranscriptChunk,
        onLog: _appendRecorderLog,
        onLevel: _handleMicLevel,
      );
      if (!mounted) {
        await recorder.dispose();
        _isRecorderConnecting = false;
        _isRecording = false;
        _isPaused = false;
        return;
      }
      setState(() {
        _recorder = recorder;
        _isRecording = true;
        _isPaused = false;
        _isRecorderConnecting = false;
        _recordingStartedAt = DateTime.now();
        _recordingAccumulated = Duration.zero;
        _recordingDuration = Duration.zero;
      });
      _startDurationTicker();

      if (resetTranscript) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 Grabando... toca pausa para descansar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      await recorder.dispose();

      if (!mounted) {
        _isRecorderConnecting = false;
        _isRecording = false;
        _isPaused = false;
        return;
      }
      setState(() {
        _recorder = null;
        _isRecording = false;
        _isPaused = false;
        _isRecorderConnecting = false;
      });
      _appendRecorderLog('error', 'No se pudo iniciar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo iniciar la transcripción: $e')),
      );
    }
  }

  Future<void> _togglePauseResume() async {
    if (_isRecorderConnecting) {
      return;
    }

    final recorder = _recorder;
    if (recorder == null) {
      await _startRecording(resetTranscript: false);
      return;
    }

    if (_isPaused) {
      if (mounted) {
        setState(() => _isRecorderConnecting = true);
      } else {
        _isRecorderConnecting = true;
      }
      try {
        final resumed = await recorder.resume();
        if (!mounted) {
          _isRecorderConnecting = false;
          _isRecording = resumed;
          _isPaused = !resumed;
          return;
        }
        if (resumed) {
          setState(() {
            _isPaused = false;
            _isRecording = true;
            _isRecorderConnecting = false;
            _recordingStartedAt = DateTime.now();
          });
          _startDurationTicker();
          _appendRecorderLog('info', 'Grabación reanudada');
        } else {
          await recorder.dispose();
          setState(() {
            _recorder = null;
            _isPaused = false;
            _isRecording = false;
            _isRecorderConnecting = false;
          });
          _appendRecorderLog(
              'warning', 'No se pudo reanudar, reiniciando sesión');
          await _startRecording(resetTranscript: false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isRecorderConnecting = false);
          _appendRecorderLog('error', 'No se pudo reanudar: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo reanudar: $e')),
          );
        }
      } finally {
        if (!mounted) {
          _isRecorderConnecting = false;
        }
      }
      return;
    }

    setState(() => _isRecorderConnecting = true);
    try {
      await recorder.pause();
      _pauseDurationTicker();
      if (mounted) {
        setState(() {
          _isPaused = true;
          _isRecording = false;
          _isRecorderConnecting = false;
        });
      }
      _appendRecorderLog('info', 'Grabación pausada');
    } catch (e) {
      if (mounted) {
        setState(() => _isRecorderConnecting = false);
        _appendRecorderLog('error', 'No se pudo pausar: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo pausar: $e')),
        );
      }
    }
  }

  Future<void> _finalizeRecording({bool discard = false}) async {
    final recorder = _recorder;
    if (recorder == null) return;

    typed.Uint8List? audioBytes;
    try {
      audioBytes = await recorder.stop();
    } catch (e) {
      if (mounted) {
        _appendRecorderLog('error', 'Error al detener grabación: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al detener la grabación: $e')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _recorder = null;
        _isRecording = false;
        _isPaused = false;

        _isRecorderConnecting = false;
      });
    } else {
      _recorder = null;
      _isRecording = false;
      _isPaused = false;
      _isRecorderConnecting = false;
    }

    _stopDurationTicker(reset: discard);
    if (discard || audioBytes == null || audioBytes.isEmpty) {
      if (discard) {
        _clearRecordedAudio();
        _resetLevelHistory();
      }
      return;
    }

    _recordedAudioBytes = audioBytes;
    _recordedAudioUploaded = false;
    await _preparePlaybackAudio(audioBytes);
    _resetLevelHistory();

    if (mounted) {
      setState(() {
        _hasChanges = true;
      });
      _appendRecorderLog('info', 'Audio listo para insertar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Dictado listo. Se guardará al guardar la historia'),
        ),
      );
    } else {
      _hasChanges = true;
    }
  }

  Future<void> _openDictationPanel() async {
    if (_isRecording) return;

    try {
      await _startRecording(resetTranscript: true);
    } catch (_) {
      return;
    }

    final transcript = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (builderContext, setSheetState) {
            // Actualizar el estado del bottom sheet cuando cambie la transcripción
            if (!_sheetStateUpdater.containsKey('dictation')) {
              _sheetStateUpdater['dictation'] = setSheetState;
            }

            final maxSheetHeight =
                MediaQuery.of(builderContext).size.height * 0.7;
            final transcriptMaxHeight = math.min(
              math.max(180.0, maxSheetHeight - 160),
              maxSheetHeight,
            );

            return PopScope(
              canPop: false,
              onPopInvoked: (didPop) async {
                if (didPop) return;
                final shouldClose = await _handleDictationDismiss(sheetContext);
                if (shouldClose && sheetContext.mounted) {
                  Navigator.pop(sheetContext, null);
                }
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  24 + MediaQuery.of(sheetContext).viewInsets.bottom,
                ),
                child: SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxSheetHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isRecorderConnecting
                                  ? Icons.hourglass_top
                                  : (_isRecording && !_isPaused
                                      ? Icons.mic
                                      : Icons.play_arrow),
                              color: _isRecorderConnecting
                                  ? Theme.of(context).colorScheme.outline
                                  : (_isRecording && !_isPaused
                                      ? Colors.red
                                      : Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(_recorderStatusLabel),
                            const Spacer(),
                            IconButton(
                              tooltip: _isRecorderConnecting
                                  ? 'Preparando...'
                                  : (_isPaused ? 'Reanudar' : 'Pausar'),
                              onPressed: _isRecorderConnecting
                                  ? null
                                  : () async {
                                      FocusScope.of(sheetContext)
                                          .requestFocus(FocusNode());
                                      await _togglePauseResume();
                                      setSheetState(() {});
                                    },
                              icon: Icon(
                                _isPaused || !_isRecording
                                    ? Icons.play_arrow
                                    : Icons.pause,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isRecorderConnecting ||
                            _isRecording ||
                            _isPaused ||
                            _recordedAudioBytes != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: (_isRecording && !_isPaused)
                                            ? Colors.red
                                            : Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDuration(_recordingDuration),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (_isPaused) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceVariant,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Pausado',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildWaveformBars(context),
                                if (_recordedAudioBytes != null) ...[
                                  const SizedBox(height: 12),
                                  _buildPlaybackControls(context),
                                ],
                              ],
                            ),
                          ),
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: transcriptMaxHeight),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Scrollbar(
                              controller: _transcriptScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _transcriptScrollController,
                                child: Text(
                                  _liveTranscript.isEmpty
                                      ? 'Empieza a hablar…'
                                      : _liveTranscript,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isRecorderConnecting ||
                                        _liveTranscript.trim().isEmpty
                                    ? null
                                    : () {
                                        final text = _liveTranscript.trim();
                                        unawaited(
                                          _finalizeRecording().catchError(
                                            (error, stackTrace) {
                                              _appendRecorderLog(
                                                'error',
                                                'Error al finalizar: $error',
                                              );
                                            },
                                          ),
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext, text);
                                        }
                                      },
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar a la historia'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () async {
                                final shouldClose =
                                    await _handleDictationDismiss(sheetContext);
                                if (!shouldClose) return;
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext, null);
                                }
                              },
                              child: const Text('Cerrar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // Limpiar el updater del bottom sheet
    _sheetStateUpdater.remove('dictation');

    if (_recorder != null) {
      await _finalizeRecording(discard: true);
    }

    if (!mounted) return;

    if (transcript != null && transcript.trim().isNotEmpty) {
      await _showTranscriptPlacementDialog(transcript.trim());
    }

    setState(() {
      _liveTranscript = '';
      _isPaused = false;
    });
  }

  Future<bool> _handleDictationDismiss(BuildContext sheetContext) async {
    if (_liveTranscript.trim().isEmpty) {
      unawaited(
        _finalizeRecording(discard: true).catchError((error, stackTrace) {
          _appendRecorderLog('error', 'Error al descartar: $error');
        }),
      );
      return true;
    }

    final confirm = await showDialog<bool>(
      context: sheetContext,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar dictado?'),
        content: const Text(
          'Si cierras ahora, se perderá el fragmento grabado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      unawaited(
        _finalizeRecording(discard: true).catchError((error, stackTrace) {
          _appendRecorderLog('error', 'Error al descartar: $error');
        }),
      );
      return true;
    }

    return false;
  }

  Future<void> _showTranscriptPlacementDialog(String transcript) async {
    final text = _contentController.text;
    if (text.trim().isEmpty) {
      _applyTranscriptInsertion(() {
        _insertAtCursor('$transcript\n\n');
      });
      return;
    }

    final paragraphs = _parseParagraphs(text);
    if (paragraphs.isEmpty) {
      _applyTranscriptInsertion(() {
        _insertTextAtPosition('\n\n$transcript\n\n', text.length);
      });
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Dónde colocar el dictado?'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView.builder(
            itemCount: paragraphs.length,
            itemBuilder: (context, index) {
              final paragraph = paragraphs[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        _showTranscriptBeforeAfterDialog(
                          dialogContext,
                          paragraph,
                          index + 1,
                          transcript,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Párrafo ${index + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.expand_more),
                                  iconSize: 20,
                                  onPressed: () {
                                    _showTranscriptFullDialog(
                                      dialogContext,
                                      paragraph,
                                      index + 1,
                                      transcript,
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              paragraph['preview'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca para insertar el dictado antes o después',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _applyTranscriptInsertion(() {
                _insertTextAtPosition('$transcript\n\n', 0);
              });
            },
            icon: const Icon(Icons.first_page),
            label: const Text('Al inicio'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _applyTranscriptInsertion(() {
                _insertTextAtPosition(
                    '\n\n$transcript\n\n', _contentController.text.length);
              });
            },
            icon: const Icon(Icons.last_page),
            label: const Text('Al final'),
          ),
        ],
      ),
    );
  }

  void _showTranscriptBeforeAfterDialog(
    BuildContext parentDialog,
    Map<String, dynamic> paragraph,
    int paragraphNumber,
    String transcript,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dictado en párrafo $paragraphNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                paragraph['preview'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿Dónde quieres colocar el dictado?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(parentDialog);
              _applyTranscriptInsertion(() {
                _insertTextAtPosition(
                    '$transcript\n\n', paragraph['position'] as int);
              });
            },
            icon: const Icon(Icons.vertical_align_top),
            label: const Text('Antes'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(parentDialog);
              _applyTranscriptInsertion(() {
                _insertTextAtPosition(
                    '\n\n$transcript\n\n', paragraph['endPosition'] as int);
              });
            },
            icon: const Icon(Icons.vertical_align_bottom),
            label: const Text('Después'),
          ),
        ],
      ),
    );
  }

  void _showTranscriptFullDialog(
    BuildContext parentDialog,
    Map<String, dynamic> paragraph,
    int paragraphNumber,
    String transcript,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Párrafo $paragraphNumber completo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paragraph['text'] as String,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿Dónde quieres colocar el dictado?'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(parentDialog);
                        _applyTranscriptInsertion(() {
                          _insertTextAtPosition(
                              '$transcript\n\n', paragraph['position'] as int);
                        });
                      },
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text('Antes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(parentDialog);
                        _applyTranscriptInsertion(() {
                          _insertTextAtPosition('\n\n$transcript\n\n',
                              paragraph['endPosition'] as int);
                        });
                      },
                      icon: const Icon(Icons.vertical_align_bottom),
                      label: const Text('Después'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _insertTextAtPosition(String text, int position) {
    final full = _contentController.text;
    final safe = position.clamp(0, full.length);
    final before = full.substring(0, safe);
    final after = full.substring(safe);
    _contentController.text = before + text + after;
    _contentController.selection =
        TextSelection.collapsed(offset: (before + text).length);
    setState(() {
      _hasChanges = true;
    });
  }

  bool _canPublish() {
    return _titleController.text.isNotEmpty &&
        _contentController.text.isNotEmpty;
  }

  Future<bool> _saveDraft() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return false;
    }

    setState(() => _isSaving = true);

    try {
      // Get current user
      final user = NarraSupabaseClient.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      if (_currentStory == null) {
        // Create new story with minimal data first
        final now = DateTime.now().toIso8601String();
        final content = _contentController.text.trim();

        final storyData = {
          'title': _titleController.text.trim(),
          'content': content,
          'user_id': user.id,
          'status': 'draft',
          'created_at': now,
          'updated_at': now,
        };

        // Add optional fields only if they exist
        if (_startDate != null) {
          storyData['story_date'] = _startDate!.toIso8601String();
        }

        // Direct Supabase insert
        final client = NarraSupabaseClient.client;
        final result =
            await client.from('stories').insert(storyData).select().single();

        _currentStory = Story.fromMap(result);
      } else {
        // Update existing story
        final content = _contentController.text.trim();

        final updates = {
          'title': _titleController.text.trim(),
          'content': content,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Add optional fields
        if (_startDate != null) {
          updates['story_date'] = _startDate!.toIso8601String();
        }

        final client = NarraSupabaseClient.client;
        await client
            .from('stories')
            .update(updates)
            .eq('id', _currentStory!.id)
            .eq('user_id', user.id);
      }

      // Upload and save photos
      await _uploadAndSavePhotos();
      final audioUploaded = await _uploadPendingAudio();

      setState(() {
        _hasChanges = !audioUploaded;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            audioUploaded
                ? 'Borrador guardado'
                : 'Borrador guardado. Audio pendiente por subir',
          ),
        ),
      );
      _captureVersion(reason: 'Borrador guardado');
      return true;
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
      return false;
    }
  }

  Future<void> _uploadAndSavePhotos() async {
    if (_currentStory == null || _photos.isEmpty) return;

    final storyId = _currentStory!.id;

    // Process each photo that needs to be uploaded
    for (int i = 0; i < _photos.length; i++) {
      final photo = _photos[i];

      if (!photo['uploaded'] && photo['bytes'] != null) {
        try {
          // Upload image to storage
          final imageUrl = await ImageUploadService.uploadStoryImage(
            storyId: storyId,
            imageBytes: photo['bytes'],
            fileName:
                ImageUploadService.getOptimizedFileName(photo['fileName']),
            mimeType: ImageUploadService.getMimeType(photo['fileName']),
          );

          // Save photo reference to database
          await NarraSupabaseClient.addPhotoToStory(
            storyId: storyId,
            photoUrl: imageUrl,
            caption: photo['caption'] ?? '',
            position: i,
          );

          // Update photo data to reflect it's now uploaded
          setState(() {
            _photos[i]['uploaded'] = true;
            _photos[i]['path'] = imageUrl;
            _photos[i]['bytes'] = null; // Clear bytes to save memory
          });
        } catch (e) {
          if (kDebugMode) {
            print('Error uploading photo ${i + 1}: $e');
          }
          // Continue with other photos even if one fails
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error subiendo foto ${i + 1}: $e')),
          );
        }
      } else if (photo['uploaded'] && photo['id'] != null) {
        // Update caption for already uploaded photos if changed
        try {
          final client = NarraSupabaseClient.client;
          await client.from('story_photos').update({
            'caption': photo['caption'] ?? '',
            'position': i,
          }).eq('id', photo['id']);
        } catch (e) {
          if (kDebugMode) {
            print('Error updating photo caption: $e');
          }
        }
      }
    }
  }

  Future<bool> _uploadPendingAudio() async {
    if (_currentStory == null) {
      return true;
    }

    if (_recordedAudioBytes == null ||
        _recordedAudioBytes!.isEmpty ||
        _recordedAudioUploaded) {
      return true;
    }

    try {
      final url = await AudioUploadService.uploadStoryAudio(
        storyId: _currentStory!.id,
        audioBytes: _recordedAudioBytes!,
        fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
      );
      if (mounted) {
        setState(() {
          _recordedAudioUploaded = true;
        });
      } else {
        _recordedAudioUploaded = true;
      }
      _appendRecorderLog('info', 'Audio guardado en Supabase: $url');
      return true;
    } catch (e) {
      if (mounted) {
        _appendRecorderLog('error', 'Error al guardar el audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el audio: $e')),
        );
      }
      return false;
    }
  }

  Future<void> _publishStory() async {
    try {
      // Save first if there are changes
      if (_hasChanges) {
        await _saveDraft();
      }

      if (_currentStory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Historia no encontrada')),
        );
        return;
      }

      await StoryServiceNew.publishStory(_currentStory!.id);

      setState(() {
        _status = 'published';
      });

      Navigator.pop(context); // Return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Historia publicada y enviada a suscriptores'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al publicar: $e')),
      );
    }
  }

  void _showPublishDialog() {
    // Validate required fields
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio para publicar')),
      );
      return;
    }

    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El contenido es obligatorio para publicar')),
      );
      return;
    }

    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Por favor, añade al menos la fecha aproximada de tu historia para poder publicarla'),
          duration: Duration(seconds: 4),
        ),
      );
      // Switch to dates tab to help user
      _tabController.animateTo(2);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publicar historia'),
        content: const Text(
          '¿Estás listo para publicar tu historia? Se enviará a todos tus suscriptores.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _publishStory();
            },
            child: const Text('Publicar'),
          ),
        ],
      ),
    );
  }

  void _showDiscardChangesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content:
            const Text('Tienes cambios sin guardar. ¿Quieres descartarlos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Descartar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _saveDraft();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 8 fotos por historia')),
      );
      return;
    }

    // Show options for selecting image source
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería de fotos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Archivos'),
              onTap: () => Navigator.pop(context, 'files'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      String? imagePath;
      String? fileName;
      typed.Uint8List? imageBytes;

      if (source == 'gallery' || source == 'camera') {
        // Use ImagePicker for gallery and camera
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source:
              source == 'gallery' ? ImageSource.gallery : ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          imagePath = image.path;
          fileName = image.name;

          // On web, we need to read bytes
          if (kIsWeb) {
            imageBytes = await image.readAsBytes();
          }
        }
      } else if (source == 'files') {
        // Use FilePicker for file system access
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
          withData: kIsWeb, // Only get bytes on web
        );

        if (result != null && result.files.isNotEmpty) {
          PlatformFile file = result.files.first;
          imagePath = file.path;
          fileName = file.name;
          imageBytes = file.bytes;
        }
      }

      if (imagePath != null || imageBytes != null) {
        // Create image data structure
        final imageId = DateTime.now().millisecondsSinceEpoch.toString();

        setState(() {
          _photos.add({
            'id': imageId,
            'path': imagePath, // Local file path (mobile)
            'bytes': imageBytes, // Image bytes (web)
            'fileName': fileName ?? 'image_$imageId.jpg',
            'caption': '',
            'alt': '',
            'uploaded': false, // Track if uploaded to server
          });
          _hasChanges = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Imagen agregada: ${fileName ?? 'imagen'}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  void _editPhoto(int index) {
    final photo = _photos[index];
    final TextEditingController captionController =
        TextEditingController(text: photo['caption'] ?? '');
    final TextEditingController altController =
        TextEditingController(text: photo['alt'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar foto ${index + 1}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image preview
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: photo['bytes'] != null
                        ? Image.memory(
                            photo['bytes'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 48),
                          )
                        : photo['path'] != null &&
                                photo['path'].toString().startsWith('http')
                            ? Image.network(
                                photo['path'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, size: 48),
                              )
                            : Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceVariant,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image,
                                      size: 32,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      photo['fileName'] ?? 'Imagen',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ),

                const SizedBox(height: 16),

                // Caption field
                TextField(
                  controller: captionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción de la foto',
                    hintText: 'Describe qué muestra esta foto...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),

                const SizedBox(height: 12),

                // Alt text field
                TextField(
                  controller: altController,
                  decoration: const InputDecoration(
                    labelText: 'Texto alternativo (opcional)',
                    hintText: 'Para accesibilidad...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              captionController.dispose();
              altController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _photos[index]['caption'] = captionController.text;
                _photos[index]['alt'] = altController.text;
                _hasChanges = true;
              });
              captionController.dispose();
              altController.dispose();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Foto actualizada')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deletePhoto(int index) async {
    final photo = _photos[index];

    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: Text(
            '¿Estás seguro de que quieres eliminar esta foto? Esta acción no se puede deshacer y eliminará todos los placeholders [img_${index + 1}] del texto.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      // If photo is uploaded, delete from storage and database
      if (photo['uploaded']) {
        if (photo['path'] != null) {
          await ImageUploadService.deleteStoryImage(photo['path']);
        }
        if (photo['id'] != null) {
          await NarraSupabaseClient.removePhotoFromStory(photo['id']);
        }
      }

      // Remove all placeholders for this image from text
      final deletedImageIndex = index + 1;
      final pattern = RegExp(r'\[img_' + deletedImageIndex.toString() + r'\]');
      final currentText = _contentController.text;
      final cleanedText = currentText.replaceAll(pattern, '');
      _contentController.text = cleanedText;

      setState(() {
        _photos.removeAt(index);

        // Update placeholders for remaining images (renumber)
        final updatedText = _renumberImagePlaceholders(cleanedText, index);
        _contentController.text = updatedText;

        _hasChanges = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('✓ Foto eliminada y placeholders actualizados')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar foto: $e')),
      );
    }
  }

  // Helper function to renumber image placeholders after deletion
  String _renumberImagePlaceholders(String text, int deletedIndex) {
    String updatedText = text;

    // For all photos after the deleted one, reduce their index by 1
    for (int i = deletedIndex + 1; i < _photos.length + 1; i++) {
      final oldPlaceholder = '[img_${i + 1}]';
      final newPlaceholder = '[img_$i]';
      updatedText = updatedText.replaceAll(oldPlaceholder, newPlaceholder);
    }

    return updatedText;
  }

  void _insertPhotoIntoText(int index) {
    final text = _contentController.text;

    if (text.trim().isEmpty) {
      // If no content, just insert at the beginning
      _insertPhotoPlaceholder(index, 0);
      return;
    }

    // Parse text into paragraphs
    final paragraphs = _parseParagraphs(text);

    if (paragraphs.isEmpty) {
      // If no paragraphs found, insert at the end
      _insertPhotoPlaceholder(index, text.length);
      return;
    }

    // Show paragraph selection dialog
    _showParagraphSelectionDialog(index, paragraphs);
  }

  List<Map<String, dynamic>> _parseParagraphs(String text) {
    final paragraphs = <Map<String, dynamic>>[];
    final breakExp = RegExp(r'\n[ \t]*\n');
    int start = 0;
    for (final match in breakExp.allMatches(text)) {
      final end = match.start;
      final segment = text.substring(start, end);
      if (segment.trim().isNotEmpty) {
        paragraphs.add({
          'text': segment,
          'preview': _getParagraphPreview(segment),
          'position': start,
          'endPosition': end,
        });
      }
      start = match.end;
    }
    if (start <= text.length) {
      final segment = text.substring(start, text.length);
      if (segment.trim().isNotEmpty) {
        paragraphs.add({
          'text': segment,
          'preview': _getParagraphPreview(segment),
          'position': start,
          'endPosition': text.length,
        });
      }
    }
    return paragraphs;
  }

  String _getParagraphPreview(String paragraph) {
    final lines = paragraph.split('\n');
    if (lines.isEmpty) return '';

    if (lines.length == 1) {
      // Single line - show up to 100 characters
      final line = lines[0].trim();
      if (line.length <= 100) return line;
      return '${line.substring(0, 100)}...';
    } else {
      // Multiple lines - show first two lines
      final firstLine = lines[0].trim();
      final secondLine = lines.length > 1 ? lines[1].trim() : '';

      final preview =
          secondLine.isNotEmpty ? '$firstLine\n$secondLine' : firstLine;

      if (preview.length <= 100) return preview;
      return '${preview.substring(0, 100)}...';
    }
  }

  void _showParagraphSelectionDialog(
      int imageIndex, List<Map<String, dynamic>> paragraphs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Dónde colocar la imagen ${imageIndex + 1}?'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: paragraphs.length,
            itemBuilder: (context, paragraphIndex) {
              final paragraph = paragraphs[paragraphIndex];
              final preview = paragraph['preview'] as String;
              final isExpanded =
                  false; // We could add state for expansion if needed

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    // Main paragraph card with tap functionality
                    InkWell(
                      onTap: () {
                        // Show before/after dialog for quick selection
                        _showBeforeAfterDialog(
                            context, imageIndex, paragraph, paragraphIndex + 1);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Párrafo ${paragraphIndex + 1}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                // Expansion arrow (optional - for full text view)
                                IconButton(
                                  icon: const Icon(Icons.expand_more),
                                  onPressed: () {
                                    _showFullParagraphDialog(
                                        context,
                                        imageIndex,
                                        paragraph,
                                        paragraphIndex + 1);
                                  },
                                  iconSize: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Toca para seleccionar dónde colocar la imagen',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontStyle: FontStyle.italic,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _insertPhotoPlaceholder(imageIndex, 0);
            },
            icon: const Icon(Icons.first_page),
            label: const Text('Al inicio'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _insertPhotoPlaceholder(
                  imageIndex, _contentController.text.length);
            },
            icon: const Icon(Icons.last_page),
            label: const Text('Al final'),
          ),
        ],
      ),
    );
  }

  void _showBeforeAfterDialog(BuildContext context, int imageIndex,
      Map<String, dynamic> paragraph, int paragraphNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Imagen ${imageIndex + 1} en Párrafo $paragraphNumber'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                paragraph['preview'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿Dónde quieres colocar la imagen?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close this dialog
              Navigator.pop(context); // Close the paragraph selection dialog
              _insertPhotoPlaceholder(imageIndex, paragraph['position'] as int);
            },
            icon: const Icon(Icons.vertical_align_top),
            label: const Text('Antes'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close this dialog
              Navigator.pop(context); // Close the paragraph selection dialog
              _insertPhotoPlaceholder(
                  imageIndex, paragraph['endPosition'] as int);
            },
            icon: const Icon(Icons.vertical_align_bottom),
            label: const Text('Después'),
          ),
        ],
      ),
    );
  }

  void _showFullParagraphDialog(BuildContext context, int imageIndex,
      Map<String, dynamic> paragraph, int paragraphNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Párrafo $paragraphNumber completo'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paragraph['text'] as String,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              const Text('¿Dónde quieres colocar la imagen?'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close this dialog
                        Navigator.pop(
                            context); // Close the paragraph selection dialog
                        _insertPhotoPlaceholder(
                            imageIndex, paragraph['position'] as int);
                      },
                      icon: const Icon(Icons.vertical_align_top),
                      label: const Text('Antes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close this dialog
                        Navigator.pop(
                            context); // Close the paragraph selection dialog
                        _insertPhotoPlaceholder(
                            imageIndex, paragraph['endPosition'] as int);
                      },
                      icon: const Icon(Icons.vertical_align_bottom),
                      label: const Text('Después'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _insertPhotoPlaceholder(int imageIndex, int position) {
    final originalText = _contentController.text;
    final photoPlaceholder = '[img_${imageIndex + 1}]';

    // Build the text with the new placeholder inserted exactly at the requested position
    final safePosition = position.clamp(0, originalText.length);
    final beforeText = originalText.substring(0, safePosition);
    final afterText = originalText.substring(safePosition);

    String withInserted;
    if (safePosition == 0) {
      withInserted = '$photoPlaceholder\n\n$originalText';
    } else if (safePosition >= originalText.length) {
      withInserted = '$originalText\n\n$photoPlaceholder';
    } else {
      withInserted = beforeText + '\n\n$photoPlaceholder\n\n' + afterText;
    }

    // Protect the newly inserted placeholder with a unique token to avoid removing it
    final keepToken = '__NARRA_KEEP_IMG_${imageIndex + 1}__';
    final insertedIndexHint = safePosition; // Hint where to search from
    final insertedIndex =
        withInserted.indexOf(photoPlaceholder, insertedIndexHint);
    if (insertedIndex >= 0) {
      withInserted = withInserted.replaceRange(
        insertedIndex,
        insertedIndex + photoPlaceholder.length,
        keepToken,
      );
    }

    // Remove any previous occurrences of this placeholder (and their padding) except the kept one
    String cleaned = _removeAllPlaceholdersExceptToken(
        withInserted, imageIndex + 1, keepToken);

    // Restore the kept token back to the placeholder
    cleaned = cleaned.replaceAll(keepToken, photoPlaceholder);

    // Collapse 3+ newlines into 2 for neat spacing
    cleaned = cleaned.replaceAll(RegExp(r'\n[ \t]*\n[ \t]*\n+'), '\n\n');

    _contentController.text = cleaned;

    // Position cursor just after the inserted placeholder
    final finalIndex = cleaned.indexOf(
        photoPlaceholder, (safePosition - 2).clamp(0, cleaned.length));
    final cursorAfter = finalIndex >= 0
        ? (finalIndex + photoPlaceholder.length + 2).clamp(0, cleaned.length)
        : cleaned.length;
    _contentController.selection = TextSelection.fromPosition(
      TextPosition(offset: cursorAfter),
    );

    setState(() => _hasChanges = true);
    _tabController.animateTo(0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ Imagen ${imageIndex + 1} colocada en el texto'),
        action: SnackBarAction(
          label: 'Ver',
          onPressed: () => _tabController.animateTo(0),
        ),
      ),
    );
  }

  String _removeAllPlaceholdersExceptToken(
      String text, int imageNumber, String keepToken) {
    final placeholder = '[img_$imageNumber]';
    // Temporarily replace the kept token to avoid interference
    var temp = text.replaceAll(
        placeholder, placeholder); // no-op to ensure placeholder variable used
    temp = text;

    // Remove occurrences in the middle with surrounding blank lines → keep a single blank separation
    final middlePattern = RegExp('\\n[ \\t]*\\n[ \\t]*' +
        RegExp.escape(placeholder) +
        '[ \\t]*\\n[ \\t]*\\n');
    temp = temp.replaceAllMapped(middlePattern, (m) => '\n\n');

    // Beginning of text
    final startPattern =
        RegExp('^' + RegExp.escape(placeholder) + '[ \\t]*\\n[ \\t]*\\n');
    temp = temp.replaceAll(startPattern, '');

    // End of text
    final endPattern =
        RegExp('\\n[ \\t]*\\n[ \\t]*' + RegExp.escape(placeholder) + r'[ 	]*$');
    temp = temp.replaceAll(endPattern, '');

    // Any remaining single placeholders (without padding)
    final loosePattern = RegExp(
        '(?<!' + RegExp.escape(keepToken) + ')' + RegExp.escape(placeholder));
    temp = temp.replaceAll(loosePattern, '');

    return temp;
  }

  void _selectDate(BuildContext context, bool isStartDate) async {
    DateTime? picked;

    if (_datesPrecision == 'day') {
      // Full date picker for day precision
      picked = await showDatePicker(
        context: context,
        initialDate: isStartDate
            ? (_startDate ?? DateTime.now())
            : (_endDate ?? _startDate ?? DateTime.now()),
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
      );
    } else if (_datesPrecision == 'month') {
      // Month and year picker
      picked = await showDialog<DateTime>(
        context: context,
        builder: (context) => _buildMonthYearPicker(
          isStartDate
              ? (_startDate ?? DateTime.now())
              : (_endDate ?? _startDate ?? DateTime.now()),
        ),
      );
    } else {
      // Year only picker
      picked = await showDialog<DateTime>(
        context: context,
        builder: (context) => _buildYearPicker(
          isStartDate
              ? (_startDate ?? DateTime.now())
              : (_endDate ?? _startDate ?? DateTime.now()),
        ),
      );
    }

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked!;
          if (_endDate != null && _endDate!.isBefore(picked!)) {
            _endDate = picked!;
          }
        } else {
          _endDate = picked!;
        }
        _hasChanges = true;
      });
    }
  }

  Widget _buildMonthYearPicker(DateTime initialDate) {
    int selectedYear = initialDate.year;
    int selectedMonth = initialDate.month;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Seleccionar mes y año'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Year selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: selectedYear > 1900
                          ? () => setDialogState(() => selectedYear--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$selectedYear',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: selectedYear < DateTime.now().year
                          ? () => setDialogState(() => selectedYear++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Month grid
                SizedBox(
                  height: 180,
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: List.generate(12, (index) {
                      final monthNames = [
                        'Ene',
                        'Feb',
                        'Mar',
                        'Abr',
                        'May',
                        'Jun',
                        'Jul',
                        'Ago',
                        'Sep',
                        'Oct',
                        'Nov',
                        'Dic'
                      ];
                      final month = index + 1;
                      final isSelected = month == selectedMonth;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => selectedMonth = month),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                monthNames[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(
                    context, DateTime(selectedYear, selectedMonth, 1));
              },
              child: const Text('Seleccionar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildYearPicker(DateTime initialDate) {
    int selectedYear = initialDate.year;
    late int startYear;

    // Initialize startYear to show 9 years centered around selected year
    int getStartYear(int year) {
      return ((year - 1900) ~/ 9) * 9 + 1900;
    }

    startYear = getStartYear(selectedYear);

    return StatefulBuilder(
      builder: (context, setDialogState) {
        List<int> getYearRange() {
          List<int> years = [];
          for (int i = 0; i < 9; i++) {
            int year = startYear + i;
            if (year <= DateTime.now().year) {
              years.add(year);
            }
          }
          return years;
        }

        final years = getYearRange();

        return AlertDialog(
          title: const Text('Seleccionar año'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Navigation buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: startYear > 1900
                          ? () => setDialogState(() => startYear -= 9)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      '$startYear - ${startYear + 8}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      onPressed: (startYear + 8) < DateTime.now().year
                          ? () => setDialogState(() => startYear += 9)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Year grid (3x3)
                SizedBox(
                  height: 180,
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    childAspectRatio: 2.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: years.map((year) {
                      final isSelected = year == selectedYear;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              setDialogState(() => selectedYear = year),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$year',
                                style: TextStyle(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa las flechas para ver más años',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, DateTime(selectedYear, 1, 1));
              },
              child: const Text('Seleccionar'),
            ),
          ],
        );
      },
    );
  }

  String _generateExcerpt(String content) {
    if (content.isEmpty) {
      return 'Sin contenido';
    }

    // Remove extra whitespace and get first 150 characters
    final cleanContent = content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleanContent.length <= 150) {
      return cleanContent;
    }

    // Find a good breaking point (end of sentence or word)
    final truncated = cleanContent.substring(0, 150);
    final lastPeriod = truncated.lastIndexOf('.');
    final lastSpace = truncated.lastIndexOf(' ');

    if (lastPeriod > 100) {
      return truncated.substring(0, lastPeriod + 1);
    } else if (lastSpace > 100) {
      return '${truncated.substring(0, lastSpace)}...';
    } else {
      return '$truncated...';
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      final normalized = tag.toLowerCase();
      final existingIndex =
          _selectedTags.indexWhere((item) => item.toLowerCase() == normalized);
      if (existingIndex != -1) {
        _selectedTags.removeAt(existingIndex);
      } else {
        final display = _getTagOption(tag)?.name ?? tag;
        _selectedTags.add(display);
      }
      _hasChanges = true;
    });
  }

  String _formatDate(DateTime date, String precision) {
    switch (precision) {
      case 'year':
        return '${date.year}';
      case 'month':
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
          'dic'
        ];
        return '${months[date.month - 1]} ${date.year}';
      case 'day':
      default:
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
          'dic'
        ];
        return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  String _getFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        final fileName = pathSegments.last;
        // Remove timestamp prefix if it exists (e.g., "1234567890_image.jpg" -> "image.jpg")
        final underscoreIndex = fileName.indexOf('_');
        if (underscoreIndex > 0 && RegExp(r'^\d+_').hasMatch(fileName)) {
          return fileName.substring(underscoreIndex + 1);
        }
        return fileName;
      }
      return 'imagen.jpg';
    } catch (e) {
      return 'imagen.jpg';
    }
  }

  void _handleGhostWriterPressed() {
    if (_isGhostWriterProcessing) return;
    if (!_canUseGhostWriter()) {
      final missingWords = math.max(0, 300 - _getWordCount());
      final message = missingWords > 0
          ? 'Ghost Writer se activa al superar las 300 palabras. Te faltan '
              '$missingWords ${missingWords == 1 ? 'palabra' : 'palabras'}.'
          : 'Ghost Writer se activa al superar las 300 palabras.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    _runGhostWriter();
  }

  Future<void> _runGhostWriter() async {
    if (_isGhostWriterProcessing) return;

    setState(() => _isGhostWriterProcessing = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  width: 48,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Ghost Writer está trabajando...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Estamos puliendo tu historia para que luzca lista para un libro.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final result = await OpenAIService.improveStoryText(
        originalText: _contentController.text,
        title: _titleController.text,
        tone: _ghostWriterTone,
        fidelity: _ghostWriterEditingStyle,
        language: _ghostWriterLanguage,
        perspective: _ghostWriterPerspective,
        avoidProfanity: _ghostWriterAvoidProfanity,
        extraInstructions: _ghostWriterExtraInstructions.trim(),
      );

      if (mounted) {
        await Navigator.of(context).maybePop();
        setState(() => _isGhostWriterProcessing = false);
      }

      if (!mounted) {
        return;
      }

      final action = await _showGhostWriterResultDialog(result);

      if (!mounted || action == null) {
        return;
      }

      if (action == _GhostWriterResultAction.apply) {
        final polished =
            (result['polished_text'] as String?) ?? _contentController.text;
        _captureVersion(reason: 'Estado previo a Ghost Writer');
        setState(() {
          _contentController.text = polished;
          _hasChanges = true;
        });
        _captureVersion(reason: 'Ghost Writer afinó tu historia');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Texto mejorado por Ghost Writer'),
          ),
        );
      } else if (action == _GhostWriterResultAction.retry) {
        await _runGhostWriter();
      }
    } catch (e) {
      if (mounted) {
        await Navigator.of(context).maybePop();
        setState(() => _isGhostWriterProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en Ghost Writer: $e')),
        );
      }
    }
  }

  Future<_GhostWriterResultAction?> _showGhostWriterResultDialog(
    Map<String, dynamic> result,
  ) async {
    final polished =
        (result['polished_text'] as String?) ?? _contentController.text;
    final summary = (result['changes_summary'] as String?) ?? '';
    final toneAnalysis = (result['tone_analysis'] as String?) ?? '';
    final suggestionsRaw = result['suggestions'];
    final suggestions = suggestionsRaw is List
        ? suggestionsRaw.whereType<String>().toList()
        : <String>[];
    final wordCount = result['word_count'];
    final polishedWordCount = wordCount is num
        ? wordCount.toInt()
        : polished.split(RegExp(r'\s+')).length;

    final instructionsController =
        TextEditingController(text: _ghostWriterExtraInstructions);

    try {
      return await showDialog<_GhostWriterResultAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              final media = MediaQuery.of(context);
              final isCompact = media.size.width < 640;
              final horizontalPadding = isCompact ? 16.0 : 24.0;
              final verticalPadding = isCompact ? 20.0 : 28.0;
              final maxWidth = math.min(media.size.width - 32, 760.0);
              final textAreaHeight =
                  math.min(isCompact ? 240.0 : 360.0, media.size.height * 0.45);

              Widget buildChip(IconData icon, String label) {
                return Chip(
                  avatar: Icon(icon, size: 16, color: colorScheme.primary),
                  label: Text(label),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: colorScheme.primary.withValues(alpha: 0.25),
                  ),
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.08),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                );
              }

              final chips = <Widget>[
                buildChip(
                    Icons.article_outlined, '$polishedWordCount palabras'),
                buildChip(Icons.palette_outlined,
                    _ghostWriterToneLabel(_ghostWriterTone)),
                buildChip(Icons.tune,
                    _ghostWriterEditingStyleLabel(_ghostWriterEditingStyle)),
                buildChip(Icons.record_voice_over,
                    _ghostWriterPerspectiveLabel(_ghostWriterPerspective)),
                buildChip(Icons.translate,
                    _ghostWriterLanguageLabel(_ghostWriterLanguage)),
              ];

              if (_ghostWriterAvoidProfanity) {
                chips.add(buildChip(Icons.shield_outlined, 'Lenguaje amable'));
              }

              return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.auto_fix_high,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ghost Writer afinó tu historia',
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Revisa los cambios sugeridos antes de aplicarlos a tu borrador.',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: chips,
                          ),
                          if (summary.isNotEmpty ||
                              toneAnalysis.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (summary.isNotEmpty) ...[
                                    Text(
                                      'Qué mejoró',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(summary),
                                  ],
                                  if (summary.isNotEmpty &&
                                      toneAnalysis.isNotEmpty)
                                    const SizedBox(height: 12),
                                  if (toneAnalysis.isNotEmpty) ...[
                                    Text(
                                      'Tono aplicado',
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(toneAnalysis),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Text(
                            'Texto mejorado',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant,
                              ),
                            ),
                            child: SizedBox(
                              height: textAreaHeight,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: SelectableText(
                                    polished,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (suggestions.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            Text(
                              'Sugerencias para seguir puliendo',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...suggestions.map(
                              (suggestion) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      size: 18,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(suggestion)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Theme(
                            data: theme.copyWith(
                                dividerColor: Colors.transparent),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: ExpansionTile(
                                initiallyExpanded: false,
                                tilePadding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                backgroundColor: colorScheme.surfaceVariant
                                    .withValues(alpha: 0.4),
                                collapsedBackgroundColor: colorScheme
                                    .surfaceVariant
                                    .withValues(alpha: 0.3),
                                title: Row(
                                  children: [
                                    Icon(
                                      Icons.settings_suggest,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Ajustes de Ghost Writer'),
                                  ],
                                ),
                                subtitle: Text(
                                  _ghostWriterSummaryLabel(),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 8, 16, 16),
                                    child: Column(
                                      children: [
                                        DropdownButtonFormField<String>(
                                          value: _ghostWriterTone,
                                          decoration: const InputDecoration(
                                            labelText: 'Tono de escritura',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'formal',
                                              child: Text('Formal'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'neutral',
                                              child: Text('Neutro'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'warm',
                                              child: Text('Cálido'),
                                            ),
                                          ],
                                          onChanged: (value) async {
                                            if (value == null) return;
                                            setDialogState(
                                              () => _ghostWriterTone = value,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _ghostWriterTone = value;
                                              });
                                            } else {
                                              _ghostWriterTone = value;
                                            }
                                            await _persistGhostWriterPreferences(
                                              tone: value,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                          value: _ghostWriterEditingStyle,
                                          decoration: const InputDecoration(
                                            labelText: 'Estilo de edición',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'faithful',
                                              child:
                                                  Text('Muy fiel al original'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'balanced',
                                              child: Text('Equilibrado'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'polished',
                                              child: Text('Pulido y elegante'),
                                            ),
                                          ],
                                          onChanged: (value) async {
                                            if (value == null) return;
                                            setDialogState(
                                              () => _ghostWriterEditingStyle =
                                                  value,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _ghostWriterEditingStyle =
                                                    value;
                                              });
                                            } else {
                                              _ghostWriterEditingStyle = value;
                                            }
                                            await _persistGhostWriterPreferences(
                                              editingStyle: value,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                          value: _ghostWriterPerspective,
                                          decoration: const InputDecoration(
                                            labelText: 'Perspectiva narrativa',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'first',
                                              child: Text('Primera persona'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'third',
                                              child: Text('Tercera persona'),
                                            ),
                                          ],
                                          onChanged: (value) async {
                                            if (value == null) return;
                                            setDialogState(
                                              () => _ghostWriterPerspective =
                                                  value,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _ghostWriterPerspective = value;
                                              });
                                            } else {
                                              _ghostWriterPerspective = value;
                                            }
                                            await _persistGhostWriterPreferences(
                                              perspective: value,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        SwitchListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                              'Evitar palabras fuertes'),
                                          subtitle: const Text(
                                              'Mantiene el lenguaje amable y adecuado para todas las edades.'),
                                          value: _ghostWriterAvoidProfanity,
                                          onChanged: (value) async {
                                            setDialogState(
                                              () => _ghostWriterAvoidProfanity =
                                                  value,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _ghostWriterAvoidProfanity =
                                                    value;
                                              });
                                            } else {
                                              _ghostWriterAvoidProfanity =
                                                  value;
                                            }
                                            await _persistGhostWriterPreferences(
                                              avoidProfanity: value,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextField(
                                          controller: instructionsController,
                                          maxLines: 3,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Instrucciones adicionales',
                                            hintText:
                                                'Ej. Prefiere párrafos cortos, destaca nombres de familiares...',
                                            border: OutlineInputBorder(),
                                          ),
                                          onChanged: (value) {
                                            setDialogState(
                                              () =>
                                                  _ghostWriterExtraInstructions =
                                                      value,
                                            );
                                            if (mounted) {
                                              setState(() {
                                                _ghostWriterExtraInstructions =
                                                    value;
                                              });
                                            } else {
                                              _ghostWriterExtraInstructions =
                                                  value;
                                            }
                                            _scheduleGhostWriterInstructionsUpdate(
                                              value,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(
                                  _GhostWriterResultAction.cancel,
                                ),
                                child: const Text('Cancelar'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(
                                  _GhostWriterResultAction.retry,
                                ),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Volver a intentar'),
                              ),
                              FilledButton.icon(
                                onPressed: () => Navigator.of(context).pop(
                                  _GhostWriterResultAction.apply,
                                ),
                                icon: const Icon(Icons.check_circle),
                                label: const Text('Aceptar cambios'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      instructionsController.dispose();
    }
  }

  Future<void> _persistGhostWriterPreferences({
    String? tone,
    String? perspective,
    String? editingStyle,
    bool? avoidProfanity,
    String? extraInstructions,
  }) async {
    try {
      await UserService.updateAiPreferences(
        writingTone: tone,
        narrativePerson: perspective,
        editingStyle: editingStyle,
        noBadWords: avoidProfanity,
        extraInstructions: extraInstructions,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('No se pudieron guardar los ajustes de Ghost Writer: $e'),
        ),
      );
    }
  }

  void _scheduleGhostWriterInstructionsUpdate(String value) {
    _ghostWriterInstructionsDebounce?.cancel();
    _ghostWriterInstructionsDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _persistGhostWriterPreferences(
        extraInstructions: value.trim(),
      ),
    );
  }

  String _ghostWriterToneLabel(String tone) {
    switch (tone) {
      case 'formal':
        return 'Formal';
      case 'neutral':
        return 'Neutro';
      case 'warm':
      default:
        return 'Cálido';
    }
  }

  String _ghostWriterEditingStyleLabel(String style) {
    switch (style) {
      case 'faithful':
        return 'Muy fiel';
      case 'polished':
        return 'Pulido';
      case 'balanced':
      default:
        return 'Equilibrado';
    }
  }

  String _ghostWriterPerspectiveLabel(String perspective) {
    switch (perspective) {
      case 'third':
        return 'Tercera persona';
      case 'first':
      default:
        return 'Primera persona';
    }
  }

  String _ghostWriterLanguageLabel(String code) {
    switch (code) {
      case 'en':
        return 'Inglés';
      case 'pt':
        return 'Portugués';
      default:
        return 'Español';
    }
  }

  String _ghostWriterSummaryLabel() {
    final parts = [
      _ghostWriterToneLabel(_ghostWriterTone),
      _ghostWriterEditingStyleLabel(_ghostWriterEditingStyle),
      _ghostWriterPerspectiveLabel(_ghostWriterPerspective),
      _ghostWriterLanguageLabel(_ghostWriterLanguage),
    ];
    if (_ghostWriterAvoidProfanity) {
      parts.add('Lenguaje amable');
    }
    return parts.join(' · ');
  }

  Future<void> _showVersionHistory() async {
    if (!mounted) return;

    if (_versionHistory.isEmpty) {
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Historial de versiones'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48, color: Colors.blue),
              SizedBox(height: 16),
              Text('Aún no hay versiones guardadas para esta historia.'),
              SizedBox(height: 16),
              Text(
                'Guarda borradores, usa Ghost Writer o pega tus transcripciones para ir creando un historial.',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
      return;
    }

    _StoryVersionEntry? selectedEntry = _versionHistory.first;

    final restored = await showDialog<_StoryVersionEntry>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;
            final media = MediaQuery.of(context);
            final maxWidth = math.min(media.size.width * 0.9, 780.0);
            final maxHeight = math.min(media.size.height * 0.8, 520.0);

            Widget buildHistoryList() {
              return ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    itemCount: _versionHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = _versionHistory[index];
                      final visuals =
                          _resolveVersionHistoryVisuals(entry.reason, theme);
                      final isSelected = identical(entry, selectedEntry);
                      return InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setDialogState(() {
                            selectedEntry = entry;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? visuals.accent.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? visuals.accent.withValues(alpha: 0.38)
                                  : colorScheme.outlineVariant
                                      .withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: visuals.iconBackground,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  visuals.icon,
                                  size: 20,
                                  color: visuals.accent == colorScheme.outline
                                      ? colorScheme.onSurfaceVariant
                                      : visuals.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      entry.reason,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatVersionTimestamp(entry.savedAt),
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: visuals.metaColor,
                                      ),
                                    ),
                                    if (entry.content.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        entry.content.trim(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.75),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            Widget buildPreview() {
              final entry = selectedEntry!;
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      colorScheme.surfaceContainerHigh.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.reason,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatVersionTimestamp(entry.savedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      entry.title.isEmpty ? 'Sin título' : entry.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              child: Text(
                                entry.content.isEmpty
                                    ? 'Esta versión no tenía contenido aún.'
                                    : entry.content,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.history, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Historial de versiones',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: maxWidth,
                child: SizedBox(
                  height: maxHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 640;
                      if (isCompact) {
                        return Column(
                          children: [
                            Expanded(child: buildHistoryList()),
                            const SizedBox(height: 12),
                            Expanded(child: buildPreview()),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: buildHistoryList()),
                          const SizedBox(width: 16),
                          Expanded(flex: 4, child: buildPreview()),
                        ],
                      );
                    },
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(dialogContext, selectedEntry),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Restaurar versión'),
                ),
              ],
            );
          },
        );
      },
    );

    if (restored == null) return;

    final restoredLabel = _formatVersionTimestamp(restored.savedAt);
    _captureVersion(
      reason: 'Estado antes de restaurar',
      includeIfUnchanged: true,
    );
    setState(() {
      _titleController.text = restored.title;
      _contentController.text = restored.content;
      _hasChanges = true;
    });
    _captureVersion(reason: 'Versión restaurada ($restoredLabel)');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Restauraste la versión de $restoredLabel')),
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.controller,
    required this.isNewStory,
  });

  final TabController controller;
  final bool isNewStory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = isNewStory ? 'Nueva historia' : 'Editar historia';
    final description = isNewStory
        ? 'Escribe y publica un nuevo recuerdo con todas las herramientas.'
        : 'Actualiza y pule tu historia manteniendo un flujo de trabajo claro.';
    final icon =
        isNewStory ? Icons.auto_stories_rounded : Icons.edit_note_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                    icon,
                    size: 28,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditorSegmentedControl(
              controller: controller,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSegmentedControl extends StatelessWidget {
  const _EditorSegmentedControl({
    required this.controller,
    required this.theme,
  });

  final TabController controller;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
        indicatorSize: TabBarIndicatorSize.tab,
        splashFactory: InkSparkle.splashFactory,
        tabs: const [
          Tab(text: 'Escribir'),
          Tab(text: 'Fotos'),
          Tab(text: 'Fechas'),
          Tab(text: 'Etiquetas'),
        ],
      ),
    );
  }
}

class _EditorBottomBar extends StatelessWidget {
  const _EditorBottomBar({
    required this.isSaving,
    required this.onSaveDraft,
    required this.onPublish,
    required this.onOpenDictation,
    required this.canPublish,
  });

  final bool isSaving;
  final VoidCallback onSaveDraft;
  final VoidCallback onPublish;
  final VoidCallback onOpenDictation;
  final bool canPublish;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;
          final horizontalPadding = isCompact ? 12.0 : 18.0;
          final verticalPadding = isCompact ? 12.0 : 14.0;
          final buttonHeight = isCompact ? 44.0 : 48.0;
          final compactButtonPadding = EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: isCompact ? 10 : 14,
          );
          final compactIconSize = isCompact ? 20.0 : 24.0;
          final compactSpacing = isCompact ? 6.0 : 8.0;

          Widget micButton() => IconButton(
                onPressed: onOpenDictation,
                icon: Icon(
                  Icons.mic_rounded,
                  size: compactIconSize + (isCompact ? 2 : 0),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                  foregroundColor: colorScheme.primary,
                  minimumSize: Size.square(buttonHeight),
                  padding: EdgeInsets.all(isCompact ? 12 : 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              );

          ButtonStyle buildButtonStyle({required bool compact}) {
            final base = FilledButton.styleFrom(
              padding: compact
                  ? compactButtonPadding
                  : const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              minimumSize: Size(compact ? 0 : 64, compact ? buttonHeight : 48),
              shape: const StadiumBorder(),
              textStyle:
                  compact ? Theme.of(context).textTheme.labelLarge : null,
            );

            if (!compact) {
              return base;
            }

            return base.copyWith(
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            );
          }

          Widget draftButton(bool compact) {
            final button = FilledButton.tonal(
              onPressed: isSaving ? null : onSaveDraft,
              style: buildButtonStyle(compact: compact).copyWith(
                padding: WidgetStatePropertyAll(
                  compact
                      ? EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSaving)
                    SizedBox(
                      width: compact ? 18 : 20,
                      height: compact ? 18 : 20,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.save_outlined,
                      size: compactIconSize,
                    ),
                  SizedBox(width: compactSpacing),
                  Flexible(
                    child: Text(
                      isSaving ? 'Guardando...' : 'Borrador',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            if (!compact) {
              return button;
            }

            return SizedBox(height: buttonHeight, child: button);
          }

          Widget publishButton(bool compact) {
            final button = FilledButton(
              onPressed: canPublish ? onPublish : null,
              style: buildButtonStyle(compact: compact).copyWith(
                padding: WidgetStatePropertyAll(
                  compact
                      ? EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                      : const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.publish_rounded,
                    size: compactIconSize,
                  ),
                  SizedBox(width: compactSpacing),
                  Flexible(
                    child: const Text(
                      'Publicar',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );

            if (!compact) {
              return button;
            }

            return SizedBox(height: buttonHeight, child: button);
          }

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            child: isCompact
                ? Row(
                    children: [
                      micButton(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: draftButton(true)),
                            const SizedBox(width: 10),
                            Expanded(child: publishButton(true)),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      micButton(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            draftButton(false),
                            const SizedBox(width: 12),
                            publishButton(false),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _EditorScrollPhysics extends ClampingScrollPhysics {
  const _EditorScrollPhysics({super.parent});

  @override
  _EditorScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _EditorScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) {
      return false;
    }
    return super.shouldAcceptUserOffset(metrics);
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              icon,
              size: 56,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.tonalIcon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.edit_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoCard extends StatelessWidget {
  final Map<String, dynamic> photo;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onInsertIntoText;

  const PhotoCard({
    super.key,
    required this.photo,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onInsertIntoText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.55),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: _buildImageWidget(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '#${index + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photo['fileName'] ?? 'Foto ${index + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        photo['caption']?.isNotEmpty == true
                            ? photo['caption']
                            : 'Sin descripción',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            photo['uploaded']
                                ? Icons.cloud_done
                                : Icons.cloud_upload,
                            size: 16,
                            color: photo['uploaded']
                                ? Colors.green
                                : colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            photo['uploaded']
                                ? 'Subida al servidor'
                                : 'Pendiente de subir',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: photo['uploaded']
                                  ? Colors.green
                                  : colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    } else if (value == 'insert') {
                      onInsertIntoText();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'insert',
                      child: Row(
                        children: [
                          Icon(Icons.add_to_photos),
                          SizedBox(width: 8),
                          Text('Colocar foto'),
                        ],
                      ),
                    ),
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
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInsertIntoText,
                icon: const Icon(Icons.add_to_photos),
                label: const Text('Colocar foto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(BuildContext context) {
    // Handle different image sources based on what's available
    if (photo['bytes'] != null) {
      // Use bytes if available (works on all platforms)
      return Image.memory(
        photo['bytes'],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } else if (photo['path'] != null &&
        photo['path'].toString().startsWith('http')) {
      // If it's a URL (already uploaded), use network image
      return Image.network(
        photo['path'],
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      );
    } else {
      // Show placeholder with filename while image isn't processed
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                photo['fileName'] ?? 'Imagen',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Imagen seleccionada',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('Error al cargar imagen'),
          ],
        ),
      ),
    );
  }
}
