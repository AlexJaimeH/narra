import 'dart:math' as math;
import 'dart:typed_data' as typed;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:narra/services/story_service_new.dart';
import 'package:narra/services/tag_service.dart';
import 'package:narra/services/image_upload_service.dart';
import 'package:narra/repositories/story_repository.dart';
import 'package:narra/openai/openai_service.dart';
import 'package:narra/services/voice_recorder.dart';
import 'package:narra/services/audio_upload_service.dart';
import 'package:narra/supabase/narra_client.dart';

class StoryEditorPage extends StatefulWidget {
  final String? storyId; // null for new story, id for editing existing

  const StoryEditorPage({super.key, this.storyId});

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isRecording = false;
  VoiceRecorder? _recorder;

  String _liveTranscript = '';
  String? _lastTranscriptChunk;
  bool _isPaused = false;

  bool _isRecorderConnecting = false;
  final List<String> _recorderLogs = [];
  static const int _maxRecorderLogs = 200;


  bool _hasChanges = false;
  bool _isLoading = false;
  bool _isSaving = false;
  final List<String> _selectedTags = [];
  final List<Map<String, dynamic>> _photos = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String _datesPrecision = 'day'; // day, month, year
  String _status = 'draft'; // draft, published
  Story? _currentStory;

  List<String> _availableTags = [];
  List<String> _aiSuggestions = [];
  bool _showAdvancedGhostWriter = false;
  bool _showSuggestions = false;

  // Ghost Writer configuration
  String _ghostWriterTone = 'nostálgico';
  String _ghostWriterFidelity = 'high';
  String _ghostWriterLanguage = 'español';
  String _ghostWriterAudience = 'familia';
  String _ghostWriterPerspective = 'primera persona';
  String _ghostWriterPrivacy = 'privado';
  bool _ghostWriterExpandContent = false;
  bool _ghostWriterPreserveStructure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _loadAvailableTags();

    // Load existing story if editing
    if (widget.storyId != null) {
      _loadStory();
    }

    // Listen to content changes - debounced to prevent flickering
    _contentController.addListener(_handleContentChange);
    _titleController.addListener(_handleTitleChange);

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

  @override
  void dispose() {
    _recorder?.dispose();
    _tabController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    try {
      final tags = await TagService.getAllTags();
      if (mounted) {
        setState(() {
          _availableTags = tags.map((tag) => tag.name).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _availableTags = [
            'infancia',
            'familia',
            'trabajo',
            'viaje',
            'celebración',
            'cambio',
            'aprendizaje',
            'amistad',
            'amor',
            'pérdida',
            'logro',
            'aventura',
            'hogar',
            'tradición',
            'guerra'
          ];
        });
      }
    }
  }

  Future<void> _loadStory() async {
    if (widget.storyId == null) return;

    setState(() => _isLoading = true);
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

  Future<void> _generateAISuggestions() async {
    if (_titleController.text.isEmpty && _contentController.text.isEmpty)
      return;

    try {
      final suggestions = await OpenAIService.generateStoryPrompts(
        currentTitle: _titleController.text,
        currentContent: _contentController.text,
      );
      if (mounted) {
        setState(() {
          _aiSuggestions = suggestions;
        });
      }
    } catch (e) {
      // Fail silently for AI suggestions
      print('Error generating AI suggestions: $e');
    }
  }

  int _getWordCount() {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  bool _canUseGhostWriter() {
    return _titleController.text.trim().isNotEmpty && _getWordCount() >= 400;
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
              appBar: AppBar(
                title: Text(widget.storyId == null
                    ? 'Nueva historia'
                    : 'Editar historia'),
                actions: [
                  if (_isSaving)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    TextButton(
                      onPressed: _saveDraft,
                      child: const Text('Guardar'),
                    ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(icon: Icon(Icons.edit), text: 'Escribir'),
                    Tab(icon: Icon(Icons.photo_library), text: 'Fotos'),
                    Tab(icon: Icon(Icons.calendar_today), text: 'Fechas'),
                    Tab(icon: Icon(Icons.label), text: 'Etiquetas'),
                  ],
                ),
              ),
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildWritingTab(),
                  _buildPhotosTab(),
                  _buildDatesTab(),
                  _buildTagsTab(),
                ],
              ),
              bottomNavigationBar: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Dictation bottom-sheet launcher (no inline recording state)
                    IconButton(
                      onPressed: _openDictationPanel,
                      icon: const Icon(Icons.mic),
                      color: Theme.of(context).colorScheme.primary,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Action Buttons
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _isSaving ? null : _saveDraft,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.save),
                            label: const Text('Borrador'),
                          ),
                          ElevatedButton.icon(
                            onPressed:
                                _canPublish() ? _showPublishDialog : null,
                            icon:
                                const Icon(Icons.publish, color: Colors.white),
                            label: const Text('Publicar'),
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

  Widget _buildWritingTab() {
    final wordCount = _getWordCount();

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Title Field
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Título de tu historia...',
                    hintStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const Divider(),

                // Content Field
                Expanded(
                  child: TextField(
                    controller: _contentController,
                    decoration: InputDecoration(
                      hintText: 'Cuenta tu historia...',
                      hintStyle:
                          Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                      border: InputBorder.none,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                  ),
                ),
              ],
            ),
          ),
        ),

        // AI Tools Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceVariant,
            border: Border(
              top: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tools row with horizontal scroll
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Ghost Writer Button
                          OutlinedButton.icon(
                            onPressed: _canUseGhostWriter()
                                ? _showGhostWriterDialog
                                : null,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Ghost Writer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _canUseGhostWriter()
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // AI Suggestions Button
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(
                                  () => _showSuggestions = !_showSuggestions);
                              if (_showSuggestions && _aiSuggestions.isEmpty) {
                                _generateAISuggestions();
                              }
                            },
                            icon: Icon(_showSuggestions
                                ? Icons.lightbulb
                                : Icons.lightbulb_outline),
                            label: const Text('Sugerencias'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _showSuggestions
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Three dots menu
                  PopupMenuButton<String>(
                    onSelected: _handleAppBarAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view_originals',
                        child: Row(
                          children: [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text('Ver originales'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Ghost Writer requirement note
              if (!_canUseGhostWriter())
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Ghost Writer disponible con título y 400+ palabras',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),

              // AI Suggestions
              if (_showSuggestions) ...[
                const SizedBox(height: 16),
                Text(
                  'Sugerencias para mejorar tu historia:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (_aiSuggestions.isEmpty) ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                  const SizedBox(height: 8),
                  const Text('Generando sugerencias...',
                      textAlign: TextAlign.center),
                ] else ...[
                  Text(
                    'Palabras: $wordCount',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ..._aiSuggestions.map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.help_outline,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fotos (${_photos.length}/8)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_photos.length < 8)
                ElevatedButton.icon(
                  onPressed: _addPhoto,
                  icon: const Icon(Icons.add_a_photo, color: Colors.white),
                  label: const Text('Añadir foto'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Usa "Colocar foto" para insertar placeholders [img_1] en tu texto. Puedes mover los placeholders libremente.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 16),
          if (_photos.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No hay fotos aún',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Añade hasta 8 fotos para ilustrar tu historia',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _addPhoto,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Añadir primera foto'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _photos.length,
                itemBuilder: (context, index) {
                  final photo = _photos[index];
                  return PhotoCard(
                    key: ValueKey(photo['id']),
                    photo: photo,
                    index: index,
                    onEdit: () => _editPhoto(index),
                    onDelete: () => _deletePhoto(index),
                    onInsertIntoText: () => _insertPhotoIntoText(index),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDatesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fechas de la historia',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Precisión de fechas',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
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
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('Fecha de inicio'),
                    subtitle: Text(
                      _startDate != null
                          ? _formatDate(_startDate!, _datesPrecision)
                          : 'No especificada',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _selectDate(context, true),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_busy),
                    title: const Text('Fecha de fin (opcional)'),
                    subtitle: Text(
                      _endDate != null
                          ? _formatDate(_endDate!, _datesPrecision)
                          : 'No especificada',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _selectDate(context, false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Etiquetas temáticas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ayuda a organizar y encontrar tus historias',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          if (_selectedTags.isNotEmpty) ...[
            Text(
              'Seleccionadas (${_selectedTags.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTags
                  .map((tag) => Chip(
                        label: Text(tag),
                        onDeleted: () => _toggleTag(tag),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Disponibles',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTags
                    .where((tag) => !_selectedTags.contains(tag))
                    .map((tag) => ActionChip(
                          label: Text(tag),
                          onPressed: () => _toggleTag(tag),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
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
    if (kDebugMode) {
      debugPrint(entry);
    }

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

  void _handleAppBarAction(String action) {
    switch (action) {
      case 'view_originals':
        _showOriginalsDialog();
        break;
    }
  }

  void _insertAtCursor(String text) {
    final selection = _contentController.selection;
    final full = _contentController.text;
    if (!selection.isValid) {
      _contentController.text += text;
      _contentController.selection =
          TextSelection.collapsed(offset: _contentController.text.length);
      return;
    }
    final start = selection.start;
    final end = selection.end;
    final newText = full.replaceRange(start, end, text);
    _contentController.text = newText;
    final caret = start + text.length;
    _contentController.selection = TextSelection.collapsed(offset: caret);
  }

  void _handleTranscriptChunk(String text) {
    final chunk = text.trim();
    if (chunk.isEmpty) return;

    final trimmedExisting = _liveTranscript.trimRight();
    if (chunk == _lastTranscriptChunk || trimmedExisting.endsWith(chunk)) {
      _lastTranscriptChunk = chunk;
      return;
    }

    final overlap = _computeOverlap(trimmedExisting, chunk);
    final addition = chunk.substring(overlap).trimLeft();
    if (addition.isEmpty) {
      _lastTranscriptChunk = chunk;
      return;
    }

    if (!mounted) return;

    setState(() {
      final buffer = StringBuffer(_liveTranscript);
      final needsSpaceBefore = _liveTranscript.isNotEmpty &&
          !RegExp(r'\s$').hasMatch(_liveTranscript);
      if (needsSpaceBefore) {
        buffer.write(' ');
      }
      buffer.write(addition);
      if (!RegExp(r'\s$').hasMatch(addition)) {
        buffer.write(' ');
      }
      _liveTranscript = buffer.toString();
      _lastTranscriptChunk = chunk;
    });
  }

  int _computeOverlap(String existing, String chunk) {
    if (existing.isEmpty || chunk.isEmpty) return 0;
    final maxLen = math.min(200, math.min(existing.length, chunk.length));
    for (var len = maxLen; len > 0; len--) {
      final suffix = existing.substring(existing.length - len);
      final prefix = chunk.substring(0, len);
      if (suffix == prefix) {
        return len;
      }
    }
    return 0;
  }

  Future<void> _startRecording({bool resetTranscript = false}) async {
    if (resetTranscript) {
      setState(() {
        _liveTranscript = '';
        _lastTranscriptChunk = null;
      });
    } else {
      _lastTranscriptChunk = null;
    }


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
      );
      if (!mounted) {
        await recorder.dispose();
        _isRecorderConnecting = false;

        return;
      }
      setState(() {
        _recorder = recorder;
        _isRecording = true;
        _isPaused = false;
        _isRecorderConnecting = false;
      });

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

    if (_isRecorderConnecting) return;


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
          return;
        }
        if (resumed) {
          setState(() {
            _isPaused = false;
            _isRecording = true;
            _isRecorderConnecting = false;
          });
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

    try {

      await recorder.pause();
      if (mounted) {

        setState(() {
          _isPaused = true;
          _isRecording = false;
        });
      }

      _appendRecorderLog('info', 'Grabación pausada');
    } catch (e) {
      if (mounted) {
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
    }
    _isRecorderConnecting = false;

    if (discard || audioBytes == null || audioBytes.isEmpty) {
      return;
    }

    if (_currentStory != null) {
      try {
        await AudioUploadService.uploadStoryAudio(
          storyId: _currentStory!.id,
          audioBytes: audioBytes,
          fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar el audio: $e')),
          );
        }
      }
    }

    if (mounted) {
      _appendRecorderLog('info', 'Audio listo para insertar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Dictado listo para insertar')),
      );
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
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SafeArea(
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
                Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _liveTranscript.isEmpty
                          ? 'Empieza a hablar…'
                          : _liveTranscript,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
                if (_recorderLogs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(

                    'Eventos recientes (logs)',

                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 110),
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _recentRecorderLogs().map((log) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
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
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isRecorderConnecting ||
                              _liveTranscript.trim().isEmpty
                          ? null
                          : () async {
                              final text = _liveTranscript.trim();
                              await _finalizeRecording();
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext, text);
                              }
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar a la historia'),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () async {
                        if (_liveTranscript.trim().isNotEmpty) {
                          final confirm = await showDialog<bool>(
                            context: sheetContext,
                            builder: (ctx) => AlertDialog(
                              title: const Text('¿Descartar dictado?'),
                              content: const Text(
                                  'Si cierras ahora, se perderá el fragmento grabado.'),
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
                          if (confirm != true) return;
                        }
                        await _finalizeRecording(discard: true);
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
        );
      },
    );

    if (_recorder != null) {
      await _finalizeRecording(discard: true);
    }

    if (!mounted) return;

    if (transcript != null && transcript.trim().isNotEmpty) {
      await _showTranscriptPlacementDialog(transcript.trim());
    }

    setState(() {
      _liveTranscript = '';
      _lastTranscriptChunk = null;
      _isPaused = false;
    });
  }

  Future<void> _showTranscriptPlacementDialog(String transcript) async {
    final text = _contentController.text;
    if (text.trim().isEmpty) {
      _insertAtCursor('$transcript\n\n');
      return;
    }

    final paragraphs = _parseParagraphs(text);
    if (paragraphs.isEmpty) {
      _insertTextAtPosition('\n\n$transcript\n\n', text.length);
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
              _insertTextAtPosition('$transcript\n\n', 0);
            },
            icon: const Icon(Icons.first_page),
            label: const Text('Al inicio'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _insertTextAtPosition(
                  '\n\n$transcript\n\n', _contentController.text.length);
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
              _insertTextAtPosition(
                  '$transcript\n\n', paragraph['position'] as int);
            },
            icon: const Icon(Icons.vertical_align_top),
            label: const Text('Antes'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(parentDialog);
              _insertTextAtPosition(
                  '\n\n$transcript\n\n', paragraph['endPosition'] as int);
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
                        _insertTextAtPosition(
                            '$transcript\n\n', paragraph['position'] as int);
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
                        _insertTextAtPosition('\n\n$transcript\n\n',
                            paragraph['endPosition'] as int);
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

  Future<void> _saveDraft() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
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

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrador guardado')),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
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
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
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

  Future<void> _showGhostWriterDialog() async {
    if (!_canUseGhostWriter()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ghost Writer requiere título y al menos 500 palabras'),
        ),
      );
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ghost Writer IA'),
          content: SizedBox(
            width: double.maxFinite,
            height: _showAdvancedGhostWriter ? 400 : 200,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Basic configuration
                  const Text(
                    'Configuración básica',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _ghostWriterTone,
                    decoration: const InputDecoration(
                      labelText: 'Tono',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'nostálgico', child: Text('Nostálgico')),
                      DropdownMenuItem(value: 'alegre', child: Text('Alegre')),
                      DropdownMenuItem(
                          value: 'emotivo', child: Text('Emotivo')),
                      DropdownMenuItem(
                          value: 'reflexivo', child: Text('Reflexivo')),
                      DropdownMenuItem(
                          value: 'divertido', child: Text('Divertido')),
                    ],
                    onChanged: (value) =>
                        setState(() => _ghostWriterTone = value!),
                  ),

                  const SizedBox(height: 16),

                  // Advanced options toggle
                  Row(
                    children: [
                      Checkbox(
                        value: _showAdvancedGhostWriter,
                        onChanged: (value) => setState(
                            () => _showAdvancedGhostWriter = value ?? false),
                      ),
                      const Text('Mostrar opciones avanzadas'),
                    ],
                  ),

                  // Advanced configuration
                  if (_showAdvancedGhostWriter) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Opciones avanzadas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ghostWriterFidelity,
                      decoration: const InputDecoration(
                        labelText: 'Fidelidad al texto original',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'high',
                            child: Text('Alta - cambios mínimos')),
                        DropdownMenuItem(
                            value: 'medium',
                            child: Text('Media - mejoras moderadas')),
                        DropdownMenuItem(
                            value: 'creative',
                            child: Text('Creativa - interpretación libre')),
                      ],
                      onChanged: (value) =>
                          setState(() => _ghostWriterFidelity = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ghostWriterAudience,
                      decoration: const InputDecoration(
                        labelText: 'Audiencia objetivo',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'familia', child: Text('Familia')),
                        DropdownMenuItem(
                            value: 'amigos', child: Text('Amigos')),
                        DropdownMenuItem(
                            value: 'público', child: Text('Público general')),
                      ],
                      onChanged: (value) =>
                          setState(() => _ghostWriterAudience = value!),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Expandir contenido'),
                      subtitle: const Text('Añadir más detalles y contexto'),
                      value: _ghostWriterExpandContent,
                      onChanged: (value) =>
                          setState(() => _ghostWriterExpandContent = value),
                    ),
                    SwitchListTile(
                      title: const Text('Preservar estructura'),
                      subtitle: const Text('Mantener organización de párrafos'),
                      value: _ghostWriterPreserveStructure,
                      onChanged: (value) =>
                          setState(() => _ghostWriterPreserveStructure = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {
                'tone': _ghostWriterTone,
                'fidelity': _ghostWriterFidelity,
                'language': _ghostWriterLanguage,
                'audience': _ghostWriterAudience,
                'perspective': _ghostWriterPerspective,
                'privacy': _ghostWriterPrivacy,
                'expandContent': _ghostWriterExpandContent,
                'preserveStructure': _ghostWriterPreserveStructure,
              }),
              child: const Text('Mejorar texto'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      _applyGhostWriter(result);
    }
  }

  Future<void> _applyGhostWriter(Map<String, dynamic> params) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Ghost Writer mejorando tu historia...'),
            SizedBox(height: 8),
            Text(
              'Esto puede tomar unos momentos',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await OpenAIService.improveStoryText(
        originalText: _contentController.text,
        title: _titleController.text,
        tone: params['tone'],
        fidelity: params['fidelity'],
        language: params['language'],
        audience: params['audience'],
        perspective: params['perspective'],
        privacy: params['privacy'],
        expandContent: params['expandContent'],
        preserveStructure: params['preserveStructure'],
      );

      Navigator.pop(context); // Close loading dialog

      // Show results dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ghost Writer - Resultados'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cambios realizados:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(result['changes_summary']),
                const SizedBox(height: 16),
                Text(
                  'Palabras: ${result['word_count']}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                if (result['suggestions'].isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Sugerencias adicionales:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...result['suggestions'].map((suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(suggestion)),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mantener original'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Apply the improved text
                setState(() {
                  _contentController.text = result['polished_text'];
                  _hasChanges = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Texto mejorado por Ghost Writer'),
                  ),
                );
              },
              child: const Text('Aplicar mejoras'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en Ghost Writer: $e')),
      );
    }
  }

  void _showOriginalsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Versiones originales'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 48, color: Colors.blue),
            SizedBox(height: 16),
            Text('No hay versiones anteriores guardadas.'),
            SizedBox(height: 16),
            Text(
              'Las versiones originales se guardan automáticamente cuando usas el Ghost Writer.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image preview
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: _buildImageWidget(context),
            ),
          ),

          // Photo details
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(photo['fileName'] ?? 'Foto ${index + 1}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo['caption']?.isNotEmpty == true
                      ? photo['caption']
                      : 'Sin descripción',
                ),
                Row(
                  children: [
                    if (!photo['uploaded']) ...[
                      Icon(
                        Icons.cloud_upload,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pendiente de subir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        Icons.cloud_done,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Subida al servidor',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
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
          ),

          // Colocar foto button
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onInsertIntoText,
                icon: const Icon(Icons.add_to_photos),
                label: const Text('Colocar foto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
