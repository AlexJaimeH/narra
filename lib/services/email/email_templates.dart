import 'dart:convert';

import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/subscriber_service.dart';

class EmailTemplates {
  EmailTemplates._();

  static final HtmlEscape _htmlEscape = const HtmlEscape();

  static String _escape(String value) => _htmlEscape.convert(value);

  static String storyPublishedHtml({
    required Story story,
    required Subscriber subscriber,
    required Uri storyLink,
    required String authorDisplayName,
    String? previewText,
    String? heroImageUrl,
  }) {
    final title =
        story.title.trim().isEmpty ? 'Una nueva historia' : story.title.trim();
    final greeting = subscriber.name.trim().isEmpty
        ? 'Hola'
        : 'Hola ${subscriber.name.split(' ').first}';
    final escapedLink = _escape(storyLink.toString());
    final excerpt =
        (previewText ?? story.excerpt ?? _firstParagraph(story))?.trim();
    final escapedExcerpt =
        excerpt != null && excerpt.isNotEmpty ? _escape(excerpt) : null;
    final escapedHero =
        heroImageUrl?.isNotEmpty == true ? _escape(heroImageUrl!) : null;

    final escapedTitle = _escape(title);
    final escapedAuthor = _escape(
        authorDisplayName.isEmpty ? 'Tu autor/a en Narra' : authorDisplayName);

    return '''
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>$escapedTitle</title>
  </head>
  <body style="margin:0;padding:0;background-color:#f4f3f0;font-family:'Helvetica Neue',Arial,sans-serif;color:#2d2a26;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:640px;margin:0 auto;padding:24px 16px;">
      <tr>
        <td style="background:#ffffff;border-radius:20px;padding:32px;box-shadow:0 12px 40px rgba(15,23,42,0.08);">
          <p style="margin:0;font-size:16px;color:#6b5b50;letter-spacing:0.04em;text-transform:uppercase;">$escapedAuthor compartió un recuerdo contigo</p>
          <h1 style="font-size:28px;line-height:1.25;margin:16px 0 12px;font-weight:700;color:#1f1b16;">$escapedTitle</h1>
          <p style="margin:0;font-size:17px;line-height:1.6;color:#443f39;">$greeting, $escapedAuthor acaba de publicar una historia para ti en Narra.</p>

          ${escapedHero != null ? '<div style="margin:28px 0;border-radius:16px;overflow:hidden;"><img src="$escapedHero" alt="" style="display:block;width:100%;height:auto;" /></div>' : ''}

          ${escapedExcerpt != null ? '<p style="margin:0;font-size:17px;line-height:1.65;color:#443f39;background-color:#f7f4ef;padding:20px;border-radius:16px;">$escapedExcerpt</p>' : ''}

          <div style="text-align:center;margin:32px 0 24px;">
            <a href="$escapedLink" style="display:inline-block;background-color:#7f5af0;color:#ffffff;text-decoration:none;font-weight:600;font-size:16px;padding:16px 32px;border-radius:999px;">Leer historia completa</a>
          </div>

          <p style="margin:0;font-size:15px;line-height:1.6;color:#6b5b50;">Este enlace es único para ti. Al abrirlo te reconoceremos como <strong>${_escape(subscriber.name)}</strong> para que puedas dejar comentarios y reacciones.</p>
          <p style="margin:16px 0 0;font-size:14px;line-height:1.6;color:#8c8176;">Si el botón no funciona, copia y pega este enlace en tu navegador:<br /><a href="$escapedLink" style="color:#7f5af0;">$escapedLink</a></p>
          <hr style="border:none;border-top:1px solid #ece7e1;margin:32px 0;" />
          <p style="margin:0;font-size:12px;color:#a59b92;line-height:1.5;">Recibiste este correo porque formas parte del círculo de confianza de $escapedAuthor en Narra. Si necesitas un nuevo enlace o quieres dejar de recibir historias, responde directamente a este mensaje.</p>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
  }

  static String storyPublishedPlainText({
    required Story story,
    required Subscriber subscriber,
    required Uri storyLink,
    required String authorDisplayName,
    String? previewText,
  }) {
    final title = story.title.trim().isEmpty
        ? 'una nueva historia'
        : '"${story.title.trim()}"';
    final buffer = StringBuffer();

    final greeting = subscriber.name.trim().isEmpty
        ? 'Hola'
        : 'Hola ${subscriber.name.split(' ').first}';
    buffer.writeln('$greeting,');
    buffer.writeln('');
    final author =
        authorDisplayName.isEmpty ? 'Tu autor/a en Narra' : authorDisplayName;
    buffer.writeln('$author publicó $title para ti.');

    final excerpt =
        (previewText ?? story.excerpt ?? _firstParagraph(story))?.trim();
    if (excerpt != null && excerpt.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(excerpt);
    }

    buffer
      ..writeln('')
      ..writeln('Léela aquí: ${storyLink.toString()}')
      ..writeln('')
      ..writeln(
          'Este enlace es único para ti. Si necesitas uno nuevo, responde directamente al autor.');

    return buffer.toString();
  }

  static String subscriberInviteHtml({
    required Subscriber subscriber,
    required Uri inviteLink,
    required String authorDisplayName,
  }) {
    final greeting = subscriber.name.trim().isEmpty
        ? 'Hola'
        : 'Hola ${_escape(subscriber.name.split(' ').first)}';
    final escapedLink = _escape(inviteLink.toString());
    final escapedAuthor = _escape(
        authorDisplayName.isEmpty ? 'tu autor/a en Narra' : authorDisplayName);
    final escapedSubscriber =
        subscriber.name.isEmpty ? 'tú' : _escape(subscriber.name);

    return '''
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="utf-8" />
    <title>Tu acceso a las historias privadas de $escapedAuthor</title>
  </head>
  <body style="margin:0;padding:0;background-color:#f4f3f0;font-family:'Helvetica Neue',Arial,sans-serif;color:#2d2a26;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:640px;margin:0 auto;padding:24px 16px;">
      <tr>
        <td style="background:#ffffff;border-radius:20px;padding:36px;box-shadow:0 18px 40px rgba(15,23,42,0.08);">
          <p style="margin:0;font-size:15px;letter-spacing:0.08em;text-transform:uppercase;color:#8c8176;">Invitación privada</p>
          <h1 style="margin:12px 0 16px;font-size:28px;line-height:1.2;color:#1f1b16;">$escapedAuthor te abrió su círculo</h1>
          <p style="margin:0;font-size:17px;line-height:1.65;color:#443f39;">$greeting, usamos este enlace único para reconocer que eres <strong>$escapedSubscriber</strong> al leer historias en Narra.</p>

          <div style="margin:32px 0 28px;text-align:center;">
            <a href="$escapedLink" style="display:inline-block;background-color:#7f5af0;color:#ffffff;text-decoration:none;font-weight:600;font-size:17px;padding:18px 34px;border-radius:999px;">Guardar mi acceso privado</a>
          </div>

          <p style="margin:0;font-size:15px;line-height:1.65;color:#6b5b50;">El enlace funciona una sola vez por dispositivo. Después de abrirlo podrás leer cualquier historia privada de $escapedAuthor sin volver a pedir acceso.</p>
          <p style="margin:18px 0 0;font-size:14px;line-height:1.6;color:#8c8176;">Si el botón no funciona, copia y pega este enlace en tu navegador:<br /><a href="$escapedLink" style="color:#7f5af0;">$escapedLink</a></p>
          <hr style="border:none;border-top:1px solid #ece7e1;margin:32px 0;" />
          <p style="margin:0;font-size:12px;color:#a59b92;line-height:1.5;">Recibiste este correo porque $escapedAuthor te agregó como suscriptor privado en Narra. Si necesitas un nuevo enlace o deseas dejar de recibir recuerdos, responde directamente a este correo.</p>
        </td>
      </tr>
    </table>
  </body>
</html>
''';
  }

  static String subscriberInvitePlainText({
    required Subscriber subscriber,
    required Uri inviteLink,
    required String authorDisplayName,
  }) {
    final buffer = StringBuffer();
    final greeting = subscriber.name.trim().isEmpty
        ? 'Hola'
        : 'Hola ${subscriber.name.split(' ').first}';
    final author =
        authorDisplayName.isEmpty ? 'tu autor/a en Narra' : authorDisplayName;

    buffer
      ..writeln('$greeting,')
      ..writeln('')
      ..writeln(
          '$author te compartió un acceso privado para leer sus historias en Narra.')
      ..writeln(
          'Guarda este enlace único, reconocerá que eres ${subscriber.name.isEmpty ? 'tú' : subscriber.name} cada vez que abras una historia:')
      ..writeln('')
      ..writeln(inviteLink.toString())
      ..writeln('')
      ..writeln(
          'Funciona una vez por dispositivo. Si necesitas otro, responde este correo para que puedan enviártelo de nuevo.');

    return buffer.toString();
  }

  static String? _firstParagraph(Story story) {
    final content = story.content;
    if (content == null || content.trim().isEmpty) {
      return null;
    }

    final normalized = content.replaceAll('\r', '\n');
    final paragraphs = normalized
        .split('\n\n')
        .map((block) => block.trim())
        .where((block) => block.isNotEmpty);
    return paragraphs.isNotEmpty ? paragraphs.first : normalized.trim();
  }
}
