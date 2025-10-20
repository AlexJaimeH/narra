import 'package:flutter/foundation.dart';
import 'package:narra/repositories/story_repository.dart';

/// Builder that centralises how we create shareable URLs for published stories.
class StoryShareLinkBuilder {
  const StoryShareLinkBuilder._();

  /// Generate a deep link to the public blog page for [story].
  static Uri buildStoryLink({
    required Story story,
    StoryShareTarget? subscriber,
    Uri? baseUri,
  }) {
    final origin = baseUri ?? _detectBaseUri();
    final pathSegments = <String>[...origin.pathSegments, 'story', story.id];

    final queryParameters = <String, String>{
      'author': story.userId,
    };

    if (subscriber != null) {
      queryParameters['subscriber'] = subscriber.id;
      if (subscriber.token != null && subscriber.token!.isNotEmpty) {
        queryParameters['token'] = subscriber.token!;
      }
      if (subscriber.name?.isNotEmpty == true) {
        queryParameters['name'] = subscriber.name!;
      }
    }

    return origin.replace(
      pathSegments: pathSegments,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  static Uri _detectBaseUri() {
    if (kIsWeb) {
      return Uri.base.replace(queryParameters: null, fragment: null);
    }

    // For non-web builds we default to production origin to keep links stable.
    return Uri.parse('https://narra.app');
  }
}

/// Metadata for the subscriber (or viewer) that will receive the share link.
class StoryShareTarget {
  const StoryShareTarget({
    required this.id,
    this.name,
    this.token,
  });

  final String id;
  final String? name;
  final String? token;
}
