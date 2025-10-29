import 'package:flutter/foundation.dart';
import 'package:narra/repositories/story_repository.dart';

/// Builder that centralises how we create shareable URLs for published stories.
class StoryShareLinkBuilder {
  const StoryShareLinkBuilder._();

  static final _ShareBaseConfig _shareBaseConfig = _resolveShareBaseConfig();
  static final Uri _defaultBaseUri = _shareBaseConfig.uri;

  static _ShareBaseConfig _resolveShareBaseConfig() {
    const rawFromEnv =
        String.fromEnvironment('PUBLIC_SHARE_BASE_URL', defaultValue: '');
    const forceDefault =
        bool.fromEnvironment('PUBLIC_FORCE_SHARE_BASE', defaultValue: true);

    final trimmed = rawFromEnv.trim();
    if (trimmed.isNotEmpty) {
      final parsed = Uri.tryParse(trimmed);
      if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
        return _ShareBaseConfig(
          uri: _sanitizeBaseUri(parsed),
          force: forceDefault,
        );
      }
    }

    final fallback = Uri.parse('https://narra-8m1.pages.dev');
    return _ShareBaseConfig(
      uri: _sanitizeBaseUri(fallback),
      force: forceDefault,
    );
  }

  /// Generate a deep link to the public blog page for [story].
  static Uri buildStoryLink({
    required Story story,
    StoryShareTarget? subscriber,
    Uri? baseUri,
    String? source,
  }) {
    final resolvedBase = _resolveBaseUri(baseUri);
    final origin = _sanitizeBaseUri(resolvedBase);
    final pathSegments = <String>['blog', 'story', story.id];

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

    if (_usesHashRouting(resolvedBase)) {
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

  /// Generate a magic link for the author to view their own story
  /// This creates a special subscriber-like access but marked as the author
  static Uri buildAuthorStoryLink({
    required Story story,
    required String authorId,
    required String authorName,
    required String authorToken,
    Uri? baseUri,
  }) {
    final resolvedBase = _resolveBaseUri(baseUri);
    final origin = _sanitizeBaseUri(resolvedBase);
    final pathSegments = <String>['blog', 'story', story.id];

    final queryParameters = <String, String>{
      'author': authorId,
      'subscriber': authorId, // Use author ID as subscriber ID
      'token': authorToken,
      'name': authorName,
      'source': 'author_preview', // Special source to identify author
    };

    if (_usesHashRouting(resolvedBase)) {
      final fragmentUri = Uri(
        pathSegments: pathSegments,
        queryParameters: queryParameters,
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
      queryParameters: queryParameters,
    );
  }

  /// Generate a deep link for a subscriber invite page so they can
  /// authenticate their device before any story is shared with them.
  static Uri buildSubscriberLink({
    required String authorId,
    required StoryShareTarget subscriber,
    Uri? baseUri,
    String? source,
    String? authorDisplayName,
    bool showWelcomeBanner = false,
  }) {
    final resolvedBase = _resolveBaseUri(baseUri);
    final origin = _sanitizeBaseUri(resolvedBase);

    final queryParameters = <String, String>{
      'author': authorId,
      'subscriber': subscriber.id,
    };

    if (subscriber.token != null && subscriber.token!.isNotEmpty) {
      queryParameters['token'] = subscriber.token!;
    }

    if (subscriber.name?.isNotEmpty == true) {
      queryParameters['name'] = subscriber.name!;
    }

    if (source != null && source.isNotEmpty) {
      queryParameters['source'] = source;
    }

    if (authorDisplayName?.isNotEmpty == true) {
      queryParameters['authorName'] = authorDisplayName!;
    }

    if (showWelcomeBanner) {
      queryParameters['welcome'] = '1';
    }

    final pathSegments = <String>['blog', 'subscriber', subscriber.id];

    if (_usesHashRouting(resolvedBase)) {
      final fragmentUri = Uri(
        pathSegments: pathSegments,
        queryParameters: queryParameters,
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
      queryParameters: queryParameters,
    );
  }

  static Uri _resolveBaseUri(Uri? candidate) {
    if (_shareBaseConfig.force) {
      return _defaultBaseUri;
    }

    if (candidate != null && !_shouldFallbackToDefault(candidate)) {
      return candidate;
    }

    if (kIsWeb) {
      final base = Uri.base;
      if (!_shouldFallbackToDefault(base)) {
        return base;
      }
    }

    return _defaultBaseUri;
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

  static bool _shouldFallbackToDefault(Uri origin) {
    final host = origin.host.toLowerCase();
    if (host.isEmpty) return true;
    if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
      return true;
    }
    if (host.endsWith('.pages.dev')) {
      return true;
    }
    return false;
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

class _ShareBaseConfig {
  const _ShareBaseConfig({
    required this.uri,
    required this.force,
  });

  final Uri uri;
  final bool force;
}
