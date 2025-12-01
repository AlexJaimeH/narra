import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:narra/supabase/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MagicLinkLoginPage extends StatefulWidget {
  const MagicLinkLoginPage({super.key});

  @override
  State<MagicLinkLoginPage> createState() => _MagicLinkLoginPageState();
}

class _MagicLinkLoginPageState extends State<MagicLinkLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinFormKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  bool _isLoading = false;
  bool _isVerifying = false;
  bool _pinSent = false;
  int _failedAttempts = 0;
  final int _maxAttempts = 5;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _requestPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('/api/author-login-pin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': _emailController.text.trim()}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _pinSent = true;
            _isLoading = false;
            _failedAttempts = 0;
            _pinController.clear();
          });
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error'] ?? 'Error al enviar el correo';

        if (mounted) {
          setState(() => _isLoading = false);

          // Mostrar mensaje de error amigable
          Color snackBarColor = Colors.red.shade700;
          int duration = 6;

          // Si es 404 (usuario no existe), usar color naranja y duración más larga
          if (response.statusCode == 404) {
            snackBarColor = Colors.orange.shade700;
            duration = 10;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: snackBarColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: Duration(seconds: duration),
              action: response.statusCode == 404
                  ? SnackBarAction(
                      label: 'Entendido',
                      textColor: Colors.white,
                      onPressed: () {},
                    )
                  : null,
            ),
          );
        }
        return; // Salir sin lanzar excepción
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Extraer mensaje limpio (remover "Exception: " si existe)
        String cleanMessage = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cleanMessage),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _pinSent = false;
      _failedAttempts = 0;
      _emailController.clear();
      _pinController.clear();
    });
  }

  bool get _pinLocked => _failedAttempts >= _maxAttempts;

  Future<void> _verifyPin() async {
    if (!_pinFormKey.currentState!.validate() || _pinLocked) return;

    setState(() => _isVerifying = true);

    try {
      final email = _emailController.text.trim().toLowerCase();
      final pin = _pinController.text.trim();

      AuthResponse response;
      try {
        response = await SupabaseConfig.client.auth.verifyOTP(
          email: email,
          token: pin,
          type: OtpType.magiclink,
        );
      } on AuthException {
        rethrow;
      } catch (_) {
        throw AuthException('No se pudo conectar con el servicio de sesión. Intenta más tarde.');
      }

      if (response.session == null) {
        throw const AuthException('PIN inválido');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('¡Listo! Inicio de sesión exitoso.'),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );

      Navigator.of(context).pushReplacementNamed('/');
    } on AuthException catch (error) {
      final attempts = _failedAttempts + 1;
      setState(() => _failedAttempts = attempts);

      final remaining = (_maxAttempts - attempts).clamp(0, _maxAttempts);
      String message = error.message.isNotEmpty
          ? error.message
          : 'No pudimos validar el PIN. Inténtalo de nuevo.';

      if (attempts >= _maxAttempts) {
        message = 'Se agotaron los $_maxAttempts intentos. Solicita un nuevo PIN.';
      } else if (attempts >= 3) {
        message =
            'Ya usaste $attempts intentos. Pide un PIN nuevo para evitar bloqueos.';
      } else {
        message = '$message Te quedan $remaining intentos.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Hubo un problema al validar el PIN.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    final maxWidth = isDesktop ? 720.0 : (isTablet ? 600.0 : 520.0);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(
              left: isDesktop ? 48.0 : (isTablet ? 40.0 : 24.0),
              right: isDesktop ? 48.0 : (isTablet ? 40.0 : 24.0),
              top: isDesktop ? 64.0 : (isTablet ? 48.0 : 32.0),
              bottom: MediaQuery.of(context).viewInsets.bottom + (isDesktop ? 64.0 : (isTablet ? 48.0 : 32.0)),
            ),
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: _pinSent
                  ? _buildPinVerificationView(theme, colorScheme, isDesktop)
                  : _buildLoginForm(theme, colorScheme, isDesktop),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme, ColorScheme colorScheme, bool isDesktop) {
    final bodySize = isDesktop ? 18.0 : 17.0;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header consistente con otras páginas
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
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
                      Icons.auto_stories_rounded,
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
                          'Bienvenido a Narra',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recibe un PIN y escríbelo aquí para entrar.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Explicación clara para personas mayores
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 48,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Cómo funciona?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Escribe tu correo electrónico\n'
                  '2. Te enviamos un PIN de 6 dígitos\n'
                  '3. Escríbelo en la pantalla\n'
                  '4. ¡Listo! Entrarás a tu cuenta',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.8,
                    fontSize: bodySize,
                    color: colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Campo de email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isDesktop ? 18 : 17,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: 'Tu correo electrónico',
              labelStyle: TextStyle(fontSize: isDesktop ? 16 : 15),
              hintText: 'ejemplo@correo.com',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: isDesktop ? 17 : 16,
              ),
              prefixIcon: Icon(
                Icons.email_outlined,
                color: colorScheme.primary,
                size: 24,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo';
              }
              if (!value.contains('@')) {
                return 'Por favor ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Botón
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _requestPin,
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: colorScheme.primary.withValues(alpha: 0.5),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                      ),
                )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mail_outline, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Enviar PIN para iniciar sesión',
                        style: TextStyle(
                          fontSize: isDesktop ? 17 : 16,
                          fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Nota de seguridad
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.green.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  color: Colors.green.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No necesitas contraseña. Es seguro y fácil.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),

          // Sección informativa sobre Narra
          _buildAboutNarra(theme, colorScheme, isDesktop),
        ],
      ),
    );
  }

  Widget _buildPinVerificationView(ThemeData theme, ColorScheme colorScheme, bool isDesktop) {
    final attemptNoticeColor = _failedAttempts >= 3 ? Colors.orange.shade800 : colorScheme.onSurfaceVariant;
    final attemptsLeft = (_maxAttempts - _failedAttempts).clamp(0, _maxAttempts);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.password_rounded,
                    color: Colors.green.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PIN enviado a tu correo',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Escribe el PIN de 6 dígitos que recibiste en ${_emailController.text.trim()}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.blue.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.dialpad_rounded,
                size: 56,
                color: Colors.blue.shade700,
              ),
              const SizedBox(height: 20),
              Text(
                'Ingresa tu PIN',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isDesktop ? 26 : 24,
                  color: Colors.blue.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'El PIN vence en 15 minutos. Tienes $_maxAttempts intentos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Form(
                key: _pinFormKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        letterSpacing: 10,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••••',
                        filled: true,
                        fillColor: colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outline.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa el PIN de 6 dígitos';
                        }
                        if (value.length != 6) {
                          return 'El PIN debe tener 6 dígitos';
                        }
                        if (_pinLocked) {
                          return 'Se agotaron los intentos. Pide un nuevo PIN.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.security_rounded, size: 18, color: attemptNoticeColor),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _failedAttempts >= 3
                                ? 'Llevas $_failedAttempts intentos. Pide un PIN nuevo para evitar bloqueos.'
                                : 'Intenta con calma. Te quedan $attemptsLeft intentos.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: attemptNoticeColor,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: (_isVerifying || _pinLocked) ? null : _verifyPin,
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isVerifying
                      ? SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _pinLocked ? 'Solicita un nuevo PIN' : 'Validar PIN y entrar',
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_rounded, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '5 intentos disponibles',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Si llegas a 5 intentos fallidos, el PIN caduca. A partir del intento 3 solicita uno nuevo para evitar bloqueos.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.orange.shade900,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _requestPin,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.6)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
                      label: Text(
                        'Enviar nuevo PIN',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: (_isLoading || _isVerifying) ? null : _resetForm,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Cambiar correo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildAboutNarra(ThemeData theme, ColorScheme colorScheme, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '¿Qué es Narra?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Narra es tu compañero para escribir y preservar tus historias de vida. Un lugar seguro donde tus recuerdos se convierten en un legado digital para compartir con las personas que amas.',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontSize: isDesktop ? 16 : 15,
              height: 1.6,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),

          // Características principales
          _buildFeatureItem(
            theme,
            colorScheme,
            Icons.edit_note_rounded,
            'Editor simple y poderoso',
            'Diseñado para personas de todas las edades',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            theme,
            colorScheme,
            Icons.photo_library_rounded,
            'Fotos y audios',
            'Agrega hasta 8 fotos y grabaciones de voz',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            theme,
            colorScheme,
            Icons.smart_toy_rounded,
            'Asistente de IA',
            'Ghost Writer te ayuda a mejorar tu redacción',
          ),
          const SizedBox(height: 12),
          _buildFeatureItem(
            theme,
            colorScheme,
            Icons.family_restroom_rounded,
            'Comparte con familia',
            'Invita a tus seres queridos a leer y comentar',
          ),

          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () async {
                // Abrir landing page en el navegador
                final Uri url = Uri.parse('https://narra.mx');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: Icon(
                Icons.open_in_new_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              label: Text(
                'Conocer más sobre Narra',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme,
    ColorScheme colorScheme,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
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
                title,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
