import 'dart:convert';
import 'dart:html' as html;

import 'story_access_record.dart';
import 'story_access_storage_base.dart';

StoryAccessStorage getStoryAccessStorage() => _CookieStoryAccessStorage();

class _CookieStoryAccessStorage implements StoryAccessStorage {
  static const _cookiePrefix = 'narra_author_access_';
  static final int _maxAge = const Duration(days: 365).inSeconds;

  @override
  StoryAccessRecord? read(String authorId) {
    final rawCookies = html.document.cookie;
    if (rawCookies == null || rawCookies.isEmpty) {
      return null;
    }

    final key = _cookieKey(authorId);
    final entries = rawCookies.split(';');
    for (final entry in entries) {
      final trimmed = entry.trim();
      if (trimmed.startsWith('$key=')) {
        final encoded = trimmed.substring(key.length + 1);
        return _decode(encoded);
      }
    }
    return null;
  }

  @override
  void remove(String authorId) {
    final key = _cookieKey(authorId);
    final secureSuffix = html.window.location.protocol == 'https:'
        ? '; Secure'
        : '';
    html.document.cookie =
        '$key=; path=/; max-age=0; SameSite=Lax$secureSuffix';
  }

  @override
  void write(StoryAccessRecord record) {
    final key = _cookieKey(record.authorId);
    final encoded = _encode(record);
    final secureSuffix = html.window.location.protocol == 'https:'
        ? '; Secure'
        : '';
    html.document.cookie =
        '$key=$encoded; path=/; max-age=$_maxAge; SameSite=Lax$secureSuffix';
  }

  String _cookieKey(String authorId) => '$_cookiePrefix$authorId';

  String _encode(StoryAccessRecord record) {
    final jsonString = jsonEncode(record.toJson());
    final base64 = base64Encode(utf8.encode(jsonString));
    return Uri.encodeComponent(base64);
  }

  StoryAccessRecord? _decode(String encoded) {
    try {
      final decoded = Uri.decodeComponent(encoded);
      final jsonString = utf8.decode(base64Decode(decoded));
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return StoryAccessRecord.fromJson(jsonMap);
    } catch (_) {
      return null;
    }
  }
}
