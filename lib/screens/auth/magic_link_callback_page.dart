import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:narra/supabase/supabase_config.dart';

class MagicLinkCallbackPage extends StatefulWidget {
  final String token;

  const MagicLinkCallbackPage({
    super.key,
    required this.token,
  });

  @override
  State<MagicLinkCallbackPage> createState() => _MagicLinkCallbackPageState();
}

class _MagicLinkCallbackPageState extends State<MagicLinkCallbackPage> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _validateAndLogin();
  }

  Future<void> _validateAndLogin() async {
    try {
      // Validar el token con el API
      final response = await http.post(
        Uri.parse('/api/author-magic-validate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': widget.token}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['auth'] != null) {
          final auth = data['auth'];
          final accessToken = auth['access_token'];
          final refreshToken = auth['refresh_token'];

          if (accessToken != null && refreshToken != null) {
            // Usar Supabase para establecer la sesión con los tokens
            final supabase = SupabaseConfig.client;

            // Intentar recuperar la sesión con el refresh token
            final authResponse = await supabase.auth.recoverSession(refreshToken);

            if (authResponse?.session != null) {
              if (mounted) {
                setState(() {
                  _success = true;
                  _isLoading = false;
                });

                // Esperar un momento para mostrar el mensaje de éxito
                await Future.delayed(const Duration(seconds: 2));

                // Navegar a la app
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/app');
                }
              }
            } else {
              throw Exception('No se pudo establecer la sesión');
            }
          } else {
            throw Exception('No se recibieron tokens de autenticación');
          }
        } else {
          throw Exception(data['error'] ?? 'Error al validar el enlace');
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['error'] ?? 'Error al validar el enlace');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32.0),
          child: _isLoading
              ? _buildLoadingView()
              : _success
                  ? _buildSuccessView()
                  : _buildErrorView(),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 48),
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            strokeWidth: 5,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Iniciando sesión...',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Por favor espera un momento',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_circle_outline_rounded,
            size: 80,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 48),
        Text(
          '¡Sesión iniciada!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 32,
            color: Colors.green.shade700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Bienvenido a Narra',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 80,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 48),
        Text(
          'Enlace inválido o expirado',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.red.shade700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.red.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                _errorMessage ?? 'El enlace ya fue usado o expiró.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Los enlaces solo funcionan una vez y expiran en 15 minutos.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/app/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Solicitar nuevo enlace',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
