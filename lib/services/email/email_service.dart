import 'dart:convert';

import 'package:http/http.dart' as http;

class EmailServiceException implements Exception {
  EmailServiceException({
    required this.statusCode,
    required this.message,
    this.code,
    this.body,
  });

  final int statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? body;

  @override
  String toString() => 'EmailServiceException($statusCode): $message';
}

class EmailService {
  const EmailService._();

  static const String _endpoint = '/api/email';

  static Future<Map<String, dynamic>> sendEmail({
    required Iterable<String> to,
    required String subject,
    required String html,
    String? text,
    String? from,
    String? replyTo,
    Iterable<String>? cc,
    Iterable<String>? bcc,
    Iterable<String>? tags,
    Map<String, String>? headers,
  }) async {
    final recipients = to
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    if (recipients.isEmpty) {
      throw ArgumentError('Debe proporcionar al menos un destinatario.');
    }

    final payload = <String, dynamic>{
      'to': recipients,
      'subject': subject,
      'html': html,
    };

    if (text != null && text.trim().isNotEmpty) {
      payload['text'] = text;
    }

    if (from != null && from.trim().isNotEmpty) {
      payload['from'] = from.trim();
    }

    if (replyTo != null && replyTo.trim().isNotEmpty) {
      payload['replyTo'] = replyTo.trim();
    }

    void setList(String key, Iterable<String>? values) {
      if (values == null) return;
      final normalized = values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        payload[key] = normalized;
      }
    }

    setList('cc', cc);
    setList('bcc', bcc);
    setList('tags', tags);

    if (headers != null && headers.isNotEmpty) {
      payload['headers'] = headers;
    }

    final response = await http.post(
      _resolveEndpoint(),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final bodyText = utf8.decode(response.bodyBytes);
    Map<String, dynamic>? decoded;
    if (bodyText.isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(bodyText);
        if (parsed is Map<String, dynamic>) {
          decoded = parsed;
        }
      } catch (_) {
        // Ignore JSON parsing errors, handled below.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded ?? <String, dynamic>{};
    }

    throw EmailServiceException(
      statusCode: response.statusCode,
      message: decoded?['error']?.toString() ??
          'No se pudo enviar el correo electrónico.',
      code: decoded?['code']?.toString(),
      body: decoded,
    );
  }

  static Uri _resolveEndpoint() {
    final parsed = Uri.parse(_endpoint);
    if (parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }

    final base = Uri.base;
    if (base.hasScheme && base.host.isNotEmpty) {
      final sanitizedBase = Uri(
        scheme: base.scheme,
        userInfo: base.userInfo.isEmpty ? null : base.userInfo,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '/',
      );

      return sanitizedBase.resolveUri(parsed);
    }

    if (parsed.hasScheme && parsed.host.isEmpty) {
      throw ArgumentError('El endpoint de correo está mal configurado.');
    }

    return parsed;
  }
}
