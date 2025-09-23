import 'package:flutter/material.dart';
import 'package:narra/supabase/supabase_config.dart';
import 'package:narra/services/user_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userSettings;
  bool _isLoading = true;
  bool _isPremium = false;

  String _selectedLanguage = 'es';
  double _textScale = 1.0;
  bool _highContrast = false;
  bool _reducedMotion = false;
  String _ghostTone = 'warm';
  String _ghostPerson = 'first';
  bool _noBadWords = false;
  String _ghostFidelity = 'balanced';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      final settings = await UserService.getUserSettings();
      final isPremium = await UserService.isPremiumUser();

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userSettings = settings;
          _isPremium = isPremium;
          
          // Cargar configuraciones del usuario
          if (settings != null) {
            _selectedLanguage = settings['language'] ?? 'es';
            _ghostTone = profile?['writing_tone'] ?? 'warm';
          }
          
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

  Future<void> _upgradeToPremiun() async {
    // Simular proceso de pago
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando pago...'),
          ],
        ),
      ),
    );

    // Simular delay de pago
    await Future.delayed(const Duration(seconds: 2));

    try {
      await UserService.upgradeToPremium();
      
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de loading
        setState(() => _isPremium = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Bienvenido a Premium! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en el pago: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildSectionHeader('Perfil'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(_userProfile?['name'] ?? 'Usuario'),
                    subtitle: Text(_userProfile?['email'] ?? ''),
                    trailing: _isPremium
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '⭐ Premium',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : TextButton(
                            onPressed: _upgradeToPremiun,
                            child: const Text('Actualizar a Premium'),
                          ),
                  ),
                ],
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
                  const Divider(),
                  
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
                            onChanged: (value) {
                              setState(() {
                                _textScale = value;
                              });
                            },
                          ),
                        ),
                        const Text('A', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                  const Divider(),
                  
                  // High Contrast
                  SwitchListTile(
                    secondary: const Icon(Icons.contrast),
                    title: const Text('Alto contraste'),
                    subtitle: const Text('Mejora la visibilidad del texto'),
                    value: _highContrast,
                    onChanged: (value) {
                      setState(() {
                        _highContrast = value;
                      });
                    },
                  ),
                  const Divider(),
                  
                  // Reduced Motion
                  SwitchListTile(
                    secondary: const Icon(Icons.motion_photos_off),
                    title: const Text('Reducir movimiento'),
                    subtitle: const Text('Minimiza animaciones y transiciones'),
                    value: _reducedMotion,
                    onChanged: (value) {
                      setState(() {
                        _reducedMotion = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // AI Assistant Section
            _buildSectionHeader('Asistente de IA'),
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
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _ghostTone = value;
                          });
                          _updateUserSettings();
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'formal', child: Text('Formal')),
                        DropdownMenuItem(value: 'neutral', child: Text('Neutro')),
                        DropdownMenuItem(value: 'warm', child: Text('Cálido')),
                      ],
                    ),
                  ),
                  const Divider(),
                  
                  // Ghost Person
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Perspectiva narrativa'),
                    subtitle: Text(_getGhostPersonName(_ghostPerson)),
                    trailing: DropdownButton<String>(
                      value: _ghostPerson,
                      underline: const SizedBox(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _ghostPerson = value;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'first', child: Text('Primera persona')),
                        DropdownMenuItem(value: 'third', child: Text('Tercera persona')),
                      ],
                    ),
                  ),
                  const Divider(),
                  
                  // No Bad Words
                  SwitchListTile(
                    secondary: const Icon(Icons.block),
                    title: const Text('Sin palabras fuertes'),
                    subtitle: const Text('Evita lenguaje inapropiado en las sugerencias'),
                    value: _noBadWords,
                    onChanged: (value) {
                      setState(() {
                        _noBadWords = value;
                      });
                    },
                  ),
                  const Divider(),
                  
                  // Ghost Fidelity
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: const Text('Estilo de edición'),
                    subtitle: Text(_getGhostFidelityName(_ghostFidelity)),
                    trailing: DropdownButton<String>(
                      value: _ghostFidelity,
                      underline: const SizedBox(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _ghostFidelity = value;
                          });
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
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Descargar mis datos'),
                    subtitle: const Text('Obtén una copia de todas tus historias'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Ver originales'),
                    subtitle: const Text('Accede a textos y audios sin procesar'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _showOriginalsDialog(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: const Text('Copia de seguridad'),
                    subtitle: const Text('Configurar respaldo automático'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Account Section
            _buildSectionHeader('Cuenta'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Ayuda y soporte'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Acerca de'),
                    subtitle: const Text('Versión 1.0.0'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  const Divider(),
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
            
            const SizedBox(height: 24),
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

  void _showOriginalsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ver originales'),
        content: const Text(
          'Puedes acceder a:\n\n'
          '• Audio original de dictados\n'
          '• Transcripciones sin procesar\n'
          '• Texto antes de edición de IA\n\n'
          'Esta función garantiza que siempre puedas recuperar tu versión original.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to originals page
            },
            child: const Text('Ver mis originales'),
          ),
        ],
      ),
    );
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
              try {
                await SupabaseAuth.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/landing',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          '⚠️ ATENCIÓN: Esta acción es irreversible.\n\n'
          'Se eliminarán permanentemente:\n'
          '• Todas tus historias\n'
          '• Fotos y audios\n'
          '• Lista de suscriptores\n'
          '• Configuraciones\n\n'
          '¿Estás completamente seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalDeleteConfirmation();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
  }

  void _showFinalDeleteConfirmation() {
    final TextEditingController confirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirmación final'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para confirmar la eliminación, escribe exactamente:\n\n'
              '"ELIMINAR CUENTA"\n',
            ),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'Escribe aquí...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ValueListenableBuilder(
            valueListenable: confirmController,
            builder: (context, value, child) => ElevatedButton(
              onPressed: value.text == 'ELIMINAR CUENTA'
                  ? () async {
                      Navigator.pop(context);
                      try {
                        await UserService.deleteUserAccount();
                        if (mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/landing',
                            (route) => false,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cuenta eliminada. Lamentamos verte partir.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al eliminar cuenta: $e')),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar permanentemente'),
            ),
          ),
        ],
      ),
    );
  }
}