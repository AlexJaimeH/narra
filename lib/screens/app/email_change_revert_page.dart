import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailChangeRevertPage extends StatefulWidget {
  final String token;

  const EmailChangeRevertPage({
    super.key,
    required this.token,
  });

  @override
  State<EmailChangeRevertPage> createState() => _EmailChangeRevertPageState();
}

class _EmailChangeRevertPageState extends State<EmailChangeRevertPage> {
  bool _isLoading = false;
  bool _confirmed = false;
  bool _success = false;
  String _message = '';
  String? _oldEmail;
  bool? _wasConfirmed;

  Future<void> _revertEmailChange() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse('/api/email-change-revert?token=${widget.token}'),
      );

      final data = jsonDecode(response.body);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _confirmed = true;
          _success = response.statusCode == 200 && data['success'] == true;
          _message = data['message'] ??
              (_success
                  ? 'Cambio revertido exitosamente'
                  : 'Error al revertir el cambio');
          _oldEmail = data['oldEmail'];
          _wasConfirmed = data['wasConfirmed'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _confirmed = true;
          _success = false;
          _message = 'Error de conexión: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (!_confirmed) {
      // Mostrar pantalla de confirmación
      return Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.undo,
                      size: 64,
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(height: 32),

                  Text(
                    '¿Cancelar cambio de email?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Estás a punto de cancelar o revertir el cambio de email. Esta acción es irreversible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '¿Qué va a pasar?',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '• Si el cambio aún no se confirmó, se cancelará la solicitud.\n'
                          '• Si ya se confirmó, tu email volverá al anterior.\n'
                          '• Podrás seguir iniciando sesión normalmente.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isLoading ? null : _revertEmailChange,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.undo),
                      label: Text(_isLoading
                          ? 'Procesando...'
                          : 'Confirmar cancelación'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.error,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/app',
                        (route) => false,
                      );
                    },
                    child: const Text('Cancelar y volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Mostrar resultado
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _success
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _success ? Icons.check_circle : Icons.error,
                    size: 64,
                    color: _success ? Colors.green : Colors.red,
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  _success
                      ? _wasConfirmed == true
                          ? '¡Cambio revertido!'
                          : '¡Solicitud cancelada!'
                      : 'Error al procesar',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                Text(
                  _message,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),

                if (_success && _oldEmail != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.email, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _wasConfirmed == true
                              ? 'Tu email ha sido restaurado a:'
                              : 'Tu email sigue siendo:',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _oldEmail!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/app',
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Ir al inicio'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
