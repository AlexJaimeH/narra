import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/supabase/narra_client.dart';
import 'package:narra/services/user_service.dart';
import 'package:narra/theme_controller.dart';
import 'package:narra/screens/app/change_email_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userSettings;
  bool _isLoading = true;
  bool _isPremium = true; // Todos pagados por requerimiento
  bool _isDownloadingData = false;

  final TextEditingController _authorNameController = TextEditingController();
  String _publicAuthorName = '';
  bool _isSavingAuthorName = false;

  String _selectedLanguage = 'es';
  double _textScale = 1.0;
  String _fontFamily = 'Montserrat';
  bool _highContrast = false;
  bool _reducedMotion = false;
  String _ghostTone = 'warm';
  String _ghostPerson = 'first';
  bool _noBadWords = true; // Nuevo valor por defecto para historias de calidad profesional
  String _ghostFidelity = 'balanced';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _authorNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      final settings = await UserService.getUserSettings();
      final isPremium = true; // Todos con acceso

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userSettings = settings;
          _isPremium = isPremium;
          
          // Cargar configuraciones del usuario
          if (settings != null) {
            _selectedLanguage = settings['language'] ?? 'es';
            _textScale = (settings['text_scale'] as num?)?.toDouble() ?? 1.0;
            _fontFamily = (settings['font_family'] as String?) ?? 'Montserrat';
            _highContrast = settings['high_contrast'] ?? false;
            _reducedMotion = settings['reduce_motion'] ?? false;
            _ghostTone = profile?['writing_tone'] ?? 'warm';
            // Preferencias AI adicionales
            _ghostPerson = (settings['ai_person'] as String?) ?? 'first';
            _noBadWords = (settings['ai_no_bad_words'] as bool?) ?? true;
            _ghostFidelity = (settings['ai_fidelity'] as String?) ?? 'balanced';
          }

          _publicAuthorName =
              settings?['public_author_name'] as String? ??
                  (profile?['name'] as String? ?? '');
          _authorNameController.text = _publicAuthorName;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar configuración: $e')),
        );
      }
    }
  }

  Future<void> _updateUserSettings() async {
    try {
      await UserService.updateUserSettings({
        'language': _selectedLanguage,
        'text_scale': _textScale,
        'font_family': _fontFamily,
        'high_contrast': _highContrast,
        'reduce_motion': _reducedMotion,
      });
      
      await UserService.updateUserProfile({
        'writing_tone': _ghostTone,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar configuración: $e')),
        );
      }
    }
  }

  Future<void> _upgradeToPremiun() async {}

  Future<void> _saveAuthorName() async {
    final newName = _authorNameController.text.trim();

    setState(() {
      _isSavingAuthorName = true;
    });

    try {
      await UserService.updateUserSettings({
        'public_author_name': newName,
      });

      if (!mounted) return;
      setState(() {
        _publicAuthorName = newName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre público actualizado')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el nombre: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAuthorName = false;
        });
      }
    }
  }

  Future<void> _downloadUserData() async {
    setState(() {
      _isDownloadingData = true;
    });

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) {
        throw Exception('No hay sesión activa');
      }

      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      final apiUrl = '${uri.scheme}://${uri.host}/api/download-user-data';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Error al descargar datos: ${response.statusCode}');
      }

      // Create a blob and download it
      final blob = html.Blob([response.bodyBytes], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'narra-mis-datos-${DateTime.now().millisecondsSinceEpoch}.zip')
        ..style.display = 'none';

      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos descargados exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar datos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadUserData,
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
                            Icons.settings_rounded,
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
                                'Ajustes',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Personaliza tu experiencia y gestiona tu cuenta.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _loadUserData,
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
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // Profile Section
            _buildSectionHeader('Perfil'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email (read-only)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.email_outlined,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Correo electrónico',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _userProfile?['email'] ?? '',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Premium',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                    ),
                    const SizedBox(height: 24),
                    // Public author name (editable)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person_outline,
                            color: colorScheme.secondary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nombre público',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Así verán tu nombre quienes reciban tus historias',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _authorNameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre público',
                        hintText: 'Ej. Familia García',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.edit_outlined),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _saveAuthorName(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingAuthorName ? null : () => _saveAuthorName(),
                        icon: _isSavingAuthorName
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isSavingAuthorName ? 'Guardando...' : 'Guardar cambios'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Change email button
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeEmailPage(
                        currentEmail: _userProfile?['email'] ?? '',
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.alternate_email,
                          color: colorScheme.tertiary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cambiar email',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Actualiza el email con el que inicias sesión',
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
            ),

            const SizedBox(height: 24),

            // Accessibility Section
            _buildSectionHeader('Accesibilidad'),
            Card(
              child: Column(
                children: [
                  // Language
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Idioma'),
                    subtitle: Text(_getLanguageName(_selectedLanguage)),
                    trailing: DropdownButton<String>(
                      value: _selectedLanguage,
                      underline: const SizedBox(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                          _updateUserSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'es', child: Text('Español')),
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'pt', child: Text('Português')),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // Text Scale
                  ListTile(
                    leading: const Icon(Icons.text_fields),
                    title: const Text('Tamaño de texto'),
                    subtitle: Text('${(_textScale * 100).round()}%'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Text('A'),
                        Expanded(
                          child: Slider(
                            value: _textScale,
                            min: 0.8,
                            max: 2.0,
                            divisions: 12,
                            onChanged: (value) async {
                              setState(() { _textScale = value; });
                              await ThemeController.instance.updateTextScale(value);
                              await _updateUserSettings();
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // High Contrast (global)
                  SwitchListTile(
                    secondary: const Icon(Icons.contrast),
                    title: const Text('Alto contraste'),
                    subtitle: const Text('Mejora la visibilidad del texto'),
                    value: _highContrast,
                    onChanged: (value) async {
                      setState(() { _highContrast = value; });
                      await ThemeController.instance.updateHighContrast(value);
                      await _updateUserSettings();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // Reduced Motion (global)
                  SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_off),
                    title: const Text('Reducir movimiento'),
                    subtitle: const Text('Minimiza animaciones y transiciones'),
                    value: _reducedMotion,
                    onChanged: (value) async {
                      setState(() { _reducedMotion = value; });
                      await ThemeController.instance.updateReduceMotion(value);
                      await _updateUserSettings();
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI Assistant Section
            _buildSectionHeader('Asistente de IA (Ghostwriter)'),
            Card(
              child: Column(
                children: [
                  // Ghost Tone
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Tono de escritura'),
                    subtitle: Text(_getGhostToneName(_ghostTone)),
                    trailing: DropdownButton<String>(
                      value: _ghostTone,
                      underline: const SizedBox(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _ghostTone = value;
                          });
                          await UserService.markGhostWriterAsConfigured();
                          await _updateUserSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'formal', child: Text('Formal')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutro')),
                        DropdownMenuItem(value: 'warm', child: Text('Cálido')),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // Ghost Person
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Perspectiva narrativa'),
                    subtitle: Text(_getGhostPersonName(_ghostPerson)),
                    trailing: DropdownButton<String>(
                      value: _ghostPerson,
                      underline: const SizedBox(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _ghostPerson = value;
                          });
                          await UserService.updateAiPreferences(
                            narrativePerson: value,
                            markAsConfigured: true,
                          );
                          await _updateUserSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'first', child: Text('Primera persona')),
                        DropdownMenuItem(value: 'third', child: Text('Tercera persona')),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // No Bad Words
                  SwitchListTile(
                    secondary: const Icon(Icons.block),
                    title: const Text('Sin palabras fuertes'),
                    subtitle: const Text('Evita lenguaje inapropiado en las sugerencias'),
                    value: _noBadWords,
                    onChanged: (value) async {
                      setState(() { _noBadWords = value; });
                      await UserService.updateAiPreferences(
                        noBadWords: value,
                        markAsConfigured: true,
                      );
                      await _updateUserSettings();
                    },
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),

                  // Additional AI instructions
                  ListTile(
                    leading: const Icon(Icons.notes),
                    title: const Text('Instrucciones adicionales'),
                    subtitle: const Text('Se aplicarán a mejoras y sugerencias'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextFormField(
                      initialValue: _userSettings?['ai_extra_instructions'] ?? '',
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Prefiere tono cercano, evita tecnicismos, usa párrafos cortos...',
                      ),
                      onChanged: (val) async {
                        _userSettings = {...?_userSettings, 'ai_extra_instructions': val};
                        await UserService.updateAiPreferences(
                          extraInstructions: val,
                          markAsConfigured: true,
                        );
                        await _updateUserSettings();
                      },
                    ),
                  ),
                  
                  // Ghost Fidelity
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Estilo de edición'),
                    subtitle: Text(_getGhostFidelityName(_ghostFidelity)),
                    trailing: DropdownButton<String>(
                      value: _ghostFidelity,
                      underline: const SizedBox(),
                      onChanged: (value) async {
                        if (value != null) {
                          setState(() {
                            _ghostFidelity = value;
                          });
                          await UserService.updateAiPreferences(
                            editingStyle: value,
                            markAsConfigured: true,
                          );
                          await _updateUserSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'faithful', child: Text('Fiel')),
                        DropdownMenuItem(value: 'balanced', child: Text('Equilibrado')),
                        DropdownMenuItem(value: 'polished', child: Text('Pulido')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Data & Privacy Section
            _buildSectionHeader('Datos y privacidad'),
            Card(
              child: ListTile(
                enabled: !_isDownloadingData,
                leading: _isDownloadingData
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                title: const Text('Descargar mis datos'),
                subtitle: Text(_isDownloadingData
                    ? 'Preparando archivo ZIP con todas tus historias...'
                    : 'Descarga un ZIP con todas tus historias, imágenes, audios y más'),
                trailing: _isDownloadingData
                    ? null
                    : const Icon(Icons.arrow_forward_ios),
                onTap: _isDownloadingData ? null : _downloadUserData,
              ),
            ),

            const SizedBox(height: 24),
            
            // Account Section
            _buildSectionHeader('Cuenta'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.feedback_outlined, color: colorScheme.primary),
                    title: const Text('Enviar feedback'),
                    subtitle: const Text('Comparte tus ideas y sugerencias'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showFeedbackDialog(),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Acerca de'),
                    subtitle: const Text('Versión 1.0.0'),
                    enabled: false,
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.24),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                    onTap: () => _showLogoutDialog(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Danger Zone
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zona de peligro',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteAccountDialog(),
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text('Eliminar cuenta', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'es': return 'Español';
      case 'en': return 'English';
      case 'pt': return 'Português';
      default: return 'Español';
    }
  }

  String _getGhostToneName(String tone) {
    switch (tone) {
      case 'formal': return 'Formal y respetuoso';
      case 'neutral': return 'Neutro y claro';
      case 'warm': return 'Cálido y cercano';
      default: return 'Cálido y cercano';
    }
  }

  String _getGhostPersonName(String person) {
    switch (person) {
      case 'first': return 'Yo hice, yo sentí...';
      case 'third': return 'Él/Ella hizo, sintió...';
      default: return 'Yo hice, yo sentí...';
    }
  }

  String _getGhostFidelityName(String fidelity) {
    switch (fidelity) {
      case 'faithful': return 'Respeta el texto original';
      case 'balanced': return 'Mejora manteniendo el estilo';
      case 'polished': return 'Perfecciona la escritura';
      default: return 'Mejora manteniendo el estilo';
    }
  }

  void _showFeedbackDialog() async {
    final messageController = TextEditingController();
    String? selectedCategory;
    int? selectedRating;
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.feedback_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Tu feedback nos ayuda')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comparte tus ideas, sugerencias o reporta problemas. Tu opinión es valiosa para mejorar Narra.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Categoría',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _CategoryChip(
                        label: 'Problema',
                        icon: Icons.bug_report_outlined,
                        value: 'bug',
                        groupValue: selectedCategory,
                        onSelected: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                      _CategoryChip(
                        label: 'Función nueva',
                        icon: Icons.lightbulb_outline,
                        value: 'feature',
                        groupValue: selectedCategory,
                        onSelected: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                      _CategoryChip(
                        label: 'Mejora',
                        icon: Icons.trending_up,
                        value: 'improvement',
                        groupValue: selectedCategory,
                        onSelected: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                      _CategoryChip(
                        label: 'Otro',
                        icon: Icons.more_horiz,
                        value: 'other',
                        groupValue: selectedCategory,
                        onSelected: (value) {
                          setState(() => selectedCategory = value);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¿Qué tan satisfecho estás con Narra?',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (index) {
                      final rating = index + 1;
                      final isSelected = selectedRating == rating;
                      return IconButton(
                        onPressed: () {
                          setState(() => selectedRating = rating);
                        },
                        icon: Icon(
                          isSelected ? Icons.star : Icons.star_border,
                          color: isSelected
                              ? Colors.amber
                              : Theme.of(context).colorScheme.outline,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    maxLength: 1000,
                    decoration: InputDecoration(
                      labelText: 'Tu mensaje',
                      hintText: 'Cuéntanos qué piensas...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSending ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: isSending || messageController.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() => isSending = true);
                        try {
                          await _sendFeedback(
                            message: messageController.text.trim(),
                            category: selectedCategory,
                            rating: selectedRating,
                          );
                          if (!mounted) return;
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Gracias por tu feedback! 🎉'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setState(() => isSending = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Error al enviar feedback: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(isSending ? 'Enviando…' : 'Enviar feedback'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _sendFeedback({
    required String message,
    String? category,
    int? rating,
  }) async {
    final userId = SupabaseAuth.currentUser?.id;
    if (userId == null) {
      throw Exception('Usuario no autenticado');
    }

    try {
      await NarraSupabaseClient.client.from('user_feedback').insert({
        'user_id': userId,
        'message': message,
        'category': category,
        'rating': rating,
        'user_email': _userProfile?['email'],
        'user_name': _userProfile?['name'],
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('No se pudo guardar el feedback: $e');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                await SupabaseAuth.signOut();
                // Redirect to React landing page (Flutter only handles /app/*)
                html.window.location.href = '/';
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al cerrar sesión: $e')),
                  );
                }
              }
            },
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Eliminar cuenta'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'ATENCIÓN',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Esta acción es permanente e irreversible.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Se eliminará todo para siempre:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _DeleteListItem(
                icon: Icons.auto_stories,
                text: 'Todas tus historias (borradores y publicadas)',
              ),
              _DeleteListItem(
                icon: Icons.image,
                text: 'Todas tus fotos',
              ),
              _DeleteListItem(
                icon: Icons.mic,
                text: 'Todas tus grabaciones de voz',
              ),
              _DeleteListItem(
                icon: Icons.people,
                text: 'Lista completa de suscriptores',
              ),
              _DeleteListItem(
                icon: Icons.history,
                text: 'Historial de versiones',
              ),
              _DeleteListItem(
                icon: Icons.settings,
                text: 'Todas tus configuraciones',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No podrás recuperar nada después de eliminar tu cuenta.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showFinalDeleteConfirmation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar con eliminación'),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final TextEditingController emailController = TextEditingController();
    final userEmail = _userProfile?['email'] ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final emailMatches = emailController.text.trim().toLowerCase() ==
                                userEmail.toLowerCase();

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Confirmación de seguridad'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Por tu seguridad, confirma que realmente quieres eliminar tu cuenta.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Escribe tu correo electrónico para confirmar:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userEmail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Tu correo electrónico',
                      hintText: 'Escribe tu correo aquí',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_outlined),
                      errorText: emailController.text.isNotEmpty && !emailMatches
                          ? 'El correo no coincide'
                          : null,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: (value) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Una vez confirmado, no hay vuelta atrás.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.red.shade900,
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
            actions: [
              TextButton(
                onPressed: () {
                  emailController.dispose();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton.icon(
                onPressed: !emailMatches
                    ? null
                    : () => _executeAccountDeletion(dialogContext),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Eliminar mi cuenta'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      emailController.dispose();
    });
  }

  Future<void> _executeAccountDeletion(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Eliminando tu cuenta...',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Por favor espera, esto puede tomar unos momentos.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final session = SupabaseConfig.client.auth.currentSession;
      if (session == null) {
        throw Exception('No hay sesión activa');
      }

      final currentUrl = html.window.location.href;
      final uri = Uri.parse(currentUrl);
      final apiUrl = '${uri.scheme}://${uri.host}/api/delete-account';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
        },
        body: json.encode({
          'email': _userProfile?['email'],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Error al eliminar cuenta: ${response.statusCode}');
      }

      // Account deleted successfully, redirect to landing page
      html.window.location.href = '/';
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar cuenta: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final String? groupValue;
  final ValueChanged<String> onSelected;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _DeleteListItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DeleteListItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}