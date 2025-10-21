import 'package:narra/repositories/story_repository.dart';
import 'package:narra/services/email/email_service.dart';
import 'package:narra/services/email/email_templates.dart';
import 'package:narra/services/story_share_link_builder.dart';
import 'package:narra/services/subscriber_service.dart';

class SubscriberEmailFailure {
  const SubscriberEmailFailure({
    required this.subscriber,
    required this.message,
  });

  final Subscriber subscriber;
  final String message;
}

class SubscriberEmailSummary {
  const SubscriberEmailSummary({
    required this.sent,
    required this.failures,
  });

  final int sent;
  final List<SubscriberEmailFailure> failures;

  bool get hasFailures => failures.isNotEmpty;
}

class SubscriberEmailService {
  const SubscriberEmailService._();

  static Future<SubscriberEmailSummary> sendStoryPublished({
    required Story story,
    required List<Subscriber> subscribers,
    required String authorDisplayName,
    Uri? baseUri,
  }) async {
    if (subscribers.isEmpty) {
      return const SubscriberEmailSummary(sent: 0, failures: []);
    }

    final heroImage =
        story.photos.isNotEmpty ? story.photos.first.photoUrl : null;
    final previewText = story.excerpt ?? _fallbackExcerpt(story.content);
    final failures = <SubscriberEmailFailure>[];
    var sentCount = 0;

    for (final subscriber in subscribers) {
      Subscriber current = subscriber;
      var token = current.magicKey.trim();

      if (token.isEmpty) {
        try {
          current = await SubscriberService.ensureMagicKey(subscriber.id);
          token = current.magicKey.trim();
        } catch (error) {
          failures.add(SubscriberEmailFailure(
            subscriber: subscriber,
            message:
                'No pudimos preparar un enlace mágico para ${subscriber.email}: $error',
          ));
          continue;
        }
      }

      final shareTarget = StoryShareTarget(
        id: current.id,
        name: current.name,
        token: token,
        source: 'email',
      );

      final link = StoryShareLinkBuilder.buildStoryLink(
        story: story,
        subscriber: shareTarget,
        baseUri: baseUri,
        source: 'email',
      );

      final html = EmailTemplates.storyPublishedHtml(
        story: story,
        subscriber: current,
        storyLink: link,
        authorDisplayName: authorDisplayName,
        previewText: previewText,
        heroImageUrl: heroImage,
      );

      final text = EmailTemplates.storyPublishedPlainText(
        story: story,
        subscriber: current,
        storyLink: link,
        authorDisplayName: authorDisplayName,
        previewText: previewText,
      );

      final subjectAuthor =
          authorDisplayName.isEmpty ? 'Tu autor en Narra' : authorDisplayName;
      final subjectTitle = story.title.trim().isEmpty
          ? 'una nueva historia'
          : '"${story.title.trim()}"';
      final subject = '$subjectAuthor compartió $subjectTitle contigo';

      try {
        await EmailService.sendEmail(
          to: [current.email],
          subject: subject,
          html: html,
          text: text,
          tags: const ['story-published'],
        );
        await SubscriberService.markMagicLinkSent(current.id);
        try {
          await SubscriberService.recordAccessEvent(
            subscriberId: current.id,
            storyId: story.id,
            eventType: 'link_sent',
            accessToken: token,
            metadata: const {
              'channel': 'email',
              'template': 'story-published',
            },
          );
        } catch (_) {
          // El correo se envió correctamente; ignoramos fallas de auditoría.
        }
        sentCount += 1;
      } on EmailServiceException catch (error) {
        failures.add(SubscriberEmailFailure(
          subscriber: current,
          message: error.message,
        ));
      } catch (error) {
        failures.add(SubscriberEmailFailure(
          subscriber: current,
          message: error.toString(),
        ));
      }
    }

    return SubscriberEmailSummary(sent: sentCount, failures: failures);
  }

  static Future<void> sendSubscriptionInvite({
    required String authorId,
    required Subscriber subscriber,
    required String authorDisplayName,
    Uri? baseUri,
  }) async {
    final token = subscriber.magicKey.trim();
    if (token.isEmpty) {
      throw StateError('El suscriptor no tiene un enlace mágico configurado.');
    }

    final shareTarget = StoryShareTarget(
      id: subscriber.id,
      name: subscriber.name,
      token: token,
      source: 'email-invite',
    );

    final link = StoryShareLinkBuilder.buildSubscriberLink(
      authorId: authorId,
      subscriber: shareTarget,
      baseUri: baseUri,
      source: 'email-invite',
      authorDisplayName: authorDisplayName,
    );

    final html = EmailTemplates.subscriberInviteHtml(
      subscriber: subscriber,
      inviteLink: link,
      authorDisplayName: authorDisplayName,
    );

    final text = EmailTemplates.subscriberInvitePlainText(
      subscriber: subscriber,
      inviteLink: link,
      authorDisplayName: authorDisplayName,
    );

    final normalizedAuthor = authorDisplayName.trim().isEmpty
        ? 'Tu autor en Narra'
        : authorDisplayName.trim();
    final subject =
        '$normalizedAuthor te invita a sus historias privadas en Narra';

    await EmailService.sendEmail(
      to: [subscriber.email],
      subject: subject,
      html: html,
      text: text,
      tags: const ['subscriber-invite'],
    );

    await SubscriberService.markMagicLinkSent(subscriber.id);
    try {
      await SubscriberService.recordAccessEvent(
        subscriberId: subscriber.id,
        eventType: 'link_sent',
        accessToken: token,
        metadata: const {
          'channel': 'email',
          'template': 'subscriber-invite',
        },
      );
    } catch (_) {
      // La invitación ya se envió; si el registro de auditoría falla no rompemos el flujo.
    }
  }

  static String? _fallbackExcerpt(String? content) {
    if (content == null || content.trim().isEmpty) {
      return null;
    }

    final normalized = content.replaceAll('\r', '\n');
    final snippet = normalized.trim();
    if (snippet.length <= 220) {
      return snippet;
    }
    return snippet.substring(0, 217).trimRight() + '…';
  }
}
