import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EmailChangeConfirmPage extends StatefulWidget {
  final String token;

  const EmailChangeConfirmPage({
    super.key,
    required this.token,
  });

  @override
  State<EmailChangeConfirmPage> createState() => _EmailChangeConfirmPageState();
}

class _EmailChangeConfirmPageState extends State<EmailChangeConfirmPage> {
  bool _isLoading = true;
  bool _success = false;
  String _message = '';
  String? _newEmail;

  @override
  void initState() {
    super.initState();
    _confirmEmailChange();
  }

  Future<void> _confirmEmailChange() async {
    try {
      final response = await http.get(
        Uri.parse('/api/email-change-confirm?token=${widget.token}'),
      );

      final data = jsonDecode(response.body);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _success = response.statusCode == 200 && data['success'] == true;
          _message = data['message'] ??
              (_success
                  ? 'Email cambiado exitosamente'
                  : 'Error al confirmar el cambio');
          _newEmail = data['newEmail'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo o icono
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _isLoading
                        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
                        : _success
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : Icon(
                          _success ? Icons.check_circle : Icons.error,
                          size: 64,
                          color: _success ? Colors.green : Colors.red,
                        ),
                ),

                const SizedBox(height: 32),

                Text(
                  _isLoading
                      ? 'Confirmando cambio de email...'
                      : _success
                          ? '¡Email confirmado!'
                          : 'Error al confirmar',
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

                if (_success && _newEmail != null) ...[
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
                        const Text(
                          'Tu nuevo email es:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _newEmail!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                if (!_isLoading) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        // Redirigir al login o dashboard
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/app',
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.home),
                      label: Text(_success
                          ? 'Ir al inicio'
                          : 'Volver al inicio'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (!_success) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _confirmEmailChange();
                      },
                      child: const Text('Intentar de nuevo'),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
