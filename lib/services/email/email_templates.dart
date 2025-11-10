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
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light" />
    <title>$escapedTitle</title>
    <style>
      /* Forzar modo claro en clientes de email */
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: #fdfbf7 !important; color: #1f2937 !important; }
        .email-card { background: #ffffff !important; }
        .email-header { background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%) !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:#fdfbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <!-- Logo/Brand -->
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <!-- Main Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" class="email-card" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <!-- Header Section -->
                <div class="email-header" style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:40px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">✨ Nueva Historia</p>
                  </div>
                  <h1 style="font-size:32px;line-height:1.2;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">$escapedTitle</h1>
                </div>

                <!-- Content Section -->
                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">$greeting,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">$escapedAuthor acaba de compartir un nuevo recuerdo contigo. Cada historia es una ventana a sus experiencias y momentos especiales.</p>

                  ${escapedHero != null ? '<div style="margin:32px 0;border-radius:20px;overflow:hidden;box-shadow:0 12px 32px rgba(0,0,0,0.12);"><img src="$escapedHero" alt="Imagen de la historia" style="display:block;width:100%;height:auto;" /></div>' : ''}

                  ${escapedExcerpt != null ? '<div style="margin:32px 0;background:#E8F5F4;padding:28px;border-radius:20px;border-left:4px solid #4DB3A8;"><p style="margin:0;font-size:17px;line-height:1.75;color:#4b5563;font-style:italic;">"$escapedExcerpt"</p></div>' : ''}

                  <!-- CTA Button -->
                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="$escapedLink" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">📖 Leer Historia Completa</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <!-- Info Box -->
                  <div style="background:#fafaf9;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#57534e;">
                      <span style="display:inline-block;background:#4DB3A8;color:#ffffff;font-size:12px;font-weight:700;padding:4px 10px;border-radius:6px;margin-right:8px;vertical-align:middle;">PERSONALIZADO</span>
                      Este enlace es único para ti
                    </p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#78716c;">Al abrirlo te reconoceremos como <strong style="color:#1f2937;">${_escape(subscriber.name)}</strong> para que puedas dejar comentarios y reacciones en la historia.</p>
                  </div>

                  <!-- Alternative Link -->
                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, usa este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="$escapedLink" style="color:#38827A;text-decoration:none;">$escapedLink</a></p>
                  </div>
                </div>

                <!-- Footer -->
                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">Formas parte del círculo de confianza de <strong style="color:#1f2937;">$escapedAuthor</strong> en Narra</p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">¿Necesitas un nuevo enlace o prefieres no recibir más historias? Responde directamente a este mensaje y te ayudaremos.</p>
                </div>
              </td>
            </tr>
          </table>

          <!-- Bottom Spacing -->
          <div style="height:40px;"></div>
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
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="color-scheme" content="light only" />
    <meta name="supported-color-schemes" content="light" />
    <title>Tu acceso a las historias privadas de $escapedAuthor</title>
    <style>
      /* Forzar modo claro en clientes de email */
      :root { color-scheme: light only; }
      @media (prefers-color-scheme: dark) {
        body { background: #fdfbf7 !important; color: #1f2937 !important; }
        .email-card { background: #ffffff !important; }
        .email-header { background: linear-gradient(135deg, #4DB3A8 0%, #38827A 100%) !important; }
      }
    </style>
  </head>
  <body style="margin:0;padding:0;background:#fdfbf7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI','Helvetica Neue',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="max-width:660px;margin:40px auto;padding:0 20px;">
      <tr>
        <td>
          <!-- Logo/Brand -->
          <div style="text-align:center;margin-bottom:32px;">
            <img src="https://narra.mx/logo-horizontal.png" alt="Narra" style="height:36px;width:auto;" />
          </div>

          <!-- Main Card -->
          <table role="presentation" cellpadding="0" cellspacing="0" width="100%" class="email-card" style="background:#ffffff;border-radius:24px;box-shadow:0 20px 60px rgba(77,179,168,0.12),0 8px 20px rgba(0,0,0,0.06);overflow:hidden;">
            <tr>
              <td style="padding:0;">
                <!-- Header Section -->
                <div class="email-header" style="background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);padding:48px 36px;text-align:center;">
                  <div style="display:inline-block;background:rgba(255,255,255,0.25);backdrop-filter:blur(10px);border-radius:16px;padding:12px 24px;margin-bottom:20px;">
                    <p style="margin:0;font-size:14px;color:#ffffff;letter-spacing:0.08em;text-transform:uppercase;font-weight:600;">🔐 Invitación Privada</p>
                  </div>
                  <h1 style="font-size:30px;line-height:1.25;margin:0;font-weight:800;color:#ffffff;text-shadow:0 2px 8px rgba(0,0,0,0.15);">$escapedAuthor te abrió su círculo de confianza</h1>
                </div>

                <!-- Content Section -->
                <div style="padding:40px 36px;">
                  <p style="margin:0 0 24px 0;font-size:18px;line-height:1.65;color:#374151;font-weight:500;">$greeting,</p>
                  <p style="margin:0 0 28px 0;font-size:17px;line-height:1.7;color:#4b5563;">Has sido invitado a un círculo privado en Narra. Este enlace mágico te permite acceder a las historias personales que <strong style="color:#1f2937;">$escapedAuthor</strong> comparte contigo.</p>

                  <!-- Feature Boxes -->
                  <div style="background:#E8F5F4;border-radius:20px;padding:28px;margin:32px 0;border-left:4px solid #4DB3A8;">
                    <div style="margin-bottom:20px;">
                      <p style="margin:0 0 8px 0;font-size:15px;font-weight:700;color:#38827A;">✨ Acceso automático</p>
                      <p style="margin:0;font-size:14px;line-height:1.6;color:#4b5563;">Te reconoceremos como <strong style="color:#1f2937;">$escapedSubscriber</strong> cada vez que leas una historia.</p>
                    </div>
                    <div style="margin-bottom:20px;">
                      <p style="margin:0 0 8px 0;font-size:15px;font-weight:700;color:#38827A;">💬 Interacción personal</p>
                      <p style="margin:0;font-size:14px;line-height:1.6;color:#4b5563;">Podrás dejar comentarios y reacciones en cada historia.</p>
                    </div>
                    <div>
                      <p style="margin:0 0 8px 0;font-size:15px;font-weight:700;color:#38827A;">📱 Un clic por dispositivo</p>
                      <p style="margin:0;font-size:14px;line-height:1.6;color:#4b5563;">Solo necesitas hacer clic una vez en este enlace desde cada dispositivo que uses.</p>
                    </div>
                  </div>

                  <!-- CTA Button -->
                  <div style="text-align:center;margin:40px 0 32px;">
                    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto;">
                      <tr>
                        <td style="border-radius:16px;background:linear-gradient(135deg, #4DB3A8 0%, #38827A 100%);box-shadow:0 8px 24px rgba(77,179,168,0.35),0 4px 12px rgba(0,0,0,0.1);">
                          <a href="$escapedLink" style="display:inline-block;color:#ffffff;text-decoration:none;font-weight:700;font-size:17px;padding:18px 42px;border-radius:16px;letter-spacing:0.01em;">🎁 Activar Mi Acceso Privado</a>
                        </td>
                      </tr>
                    </table>
                  </div>

                  <!-- Info Box -->
                  <div style="background:#fffbeb;border:2px solid #fde047;border-radius:16px;padding:24px;margin:32px 0;">
                    <p style="margin:0 0 12px 0;font-size:15px;line-height:1.6;color:#78350f;font-weight:600;">
                      ⚡ Importante
                    </p>
                    <p style="margin:0;font-size:14px;line-height:1.65;color:#92400e;">Este enlace funciona una sola vez por dispositivo. Después de activarlo, podrás leer todas las historias privadas de $escapedAuthor sin volver a necesitar el enlace.</p>
                  </div>

                  <!-- Alternative Link -->
                  <div style="background:#f9fafb;border:2px dashed #e5e7eb;border-radius:12px;padding:20px;margin:24px 0 0 0;">
                    <p style="margin:0 0 8px 0;font-size:13px;color:#6b7280;font-weight:600;">Si el botón no funciona, copia y pega este enlace:</p>
                    <p style="margin:0;font-size:13px;word-break:break-all;"><a href="$escapedLink" style="color:#38827A;text-decoration:none;">$escapedLink</a></p>
                  </div>
                </div>

                <!-- Footer -->
                <div style="background:#fafaf9;padding:32px 36px;border-top:1px solid #e7e5e4;">
                  <p style="margin:0 0 16px 0;font-size:14px;line-height:1.6;color:#78716c;text-align:center;">Has sido agregado al círculo privado de <strong style="color:#1f2937;">$escapedAuthor</strong></p>
                  <p style="margin:0;font-size:12px;color:#a8a29e;line-height:1.6;text-align:center;">¿Necesitas un nuevo enlace o prefieres no recibir más invitaciones? Responde directamente a este mensaje y te ayudaremos.</p>
                </div>
              </td>
            </tr>
          </table>

          <!-- Bottom Spacing -->
          <div style="height:40px;"></div>
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
