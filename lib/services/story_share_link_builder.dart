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
    String? source,
  }) {
    final detectedBase = baseUri ?? _detectBaseUri();
    final origin = _sanitizeBaseUri(detectedBase);
    final pathSegments = <String>['story', story.id];

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
      if (subscriber.source?.isNotEmpty == true) {
        queryParameters['source'] = subscriber.source!;
      }
    }

    if (source != null && source.isNotEmpty) {
      queryParameters['source'] = source;
    }

    if (_usesHashRouting(detectedBase)) {
      final fragmentUri = Uri(
        pathSegments: pathSegments,
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      final fragment = fragmentUri.toString();
      final normalizedFragment =
          fragment.startsWith('/') ? fragment : '/$fragment';

      return origin.replace(
        fragment: normalizedFragment,
        queryParameters: null,
        path: origin.path.isEmpty || origin.path == '/' ? '' : origin.path,
      );
    }

    return origin.replace(
      pathSegments: pathSegments,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  static Uri _detectBaseUri() {
    if (kIsWeb) {
      return Uri.base;
    }

    // For non-web builds we default to production origin to keep links stable.
    return Uri.parse('https://narra.app');
  }

  static Uri _sanitizeBaseUri(Uri origin) {
    final base = origin.replace(queryParameters: null, fragment: null);
    if (base.pathSegments.isEmpty && (base.path.isEmpty || base.path == '/')) {
      return base.replace(
        path: '',
      );
    }

    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo.isEmpty ? null : base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  static bool _usesHashRouting(Uri origin) {
    if (!origin.hasFragment || origin.fragment.isEmpty) {
      return false;
    }

    final fragment = origin.fragment.trim();
    return fragment.startsWith('/');
  }
}

/// Metadata for the subscriber (or viewer) that will receive the share link.
class StoryShareTarget {
  const StoryShareTarget({
    required this.id,
    this.name,
    this.token,
    this.source,
  });

  final String id;
  final String? name;
  final String? token;
  final String? source;
}
