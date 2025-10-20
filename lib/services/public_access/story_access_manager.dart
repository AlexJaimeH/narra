import 'story_access_record.dart';
import 'story_access_storage.dart';
import 'story_access_storage_base.dart';

/// High level API to store and retrieve which viewers can access an author's
/// public stories. This layer hides the storage mechanism (cookies on web,
/// in-memory fallback elsewhere) from the UI widgets.
class StoryAccessManager {
  StoryAccessManager._();

  static final StoryAccessStorage _storage = createStoryAccessStorage();

  static StoryAccessRecord? getAccess(String authorId) => _storage.read(authorId);

  static bool hasAccess(String authorId) => getAccess(authorId) != null;

  static StoryAccessRecord grantAccess({
    required String authorId,
    required String subscriberId,
    String? subscriberName,
    String? accessToken,
    String? source,
  }) {
    final existing = _storage.read(authorId);
    if (existing != null && existing.subscriberId == subscriberId) {
      final updated = existing.copyWith(
        subscriberName: subscriberName ?? existing.subscriberName,
        accessToken: accessToken ?? existing.accessToken,
        source: source ?? existing.source,
      );
      _storage.write(updated);
      return updated;
    }

    final record = StoryAccessRecord(
      authorId: authorId,
      subscriberId: subscriberId,
      subscriberName: subscriberName,
      accessToken: accessToken,
      grantedAt: DateTime.now(),
      source: source,
    );
    _storage.write(record);
    return record;
  }

  static StoryAccessRecord ensureAuthorAccess(String authorId) {
    final existing = _storage.read(authorId);
    if (existing != null) {
      return existing;
    }

    final record = StoryAccessRecord(
      authorId: authorId,
      subscriberId: 'author',
      subscriberName: 'Autor/a',
      grantedAt: DateTime.now(),
      source: 'author',
    );
    _storage.write(record);
    return record;
  }

  static void revokeAccess(String authorId) {
    _storage.remove(authorId);
  }
}
