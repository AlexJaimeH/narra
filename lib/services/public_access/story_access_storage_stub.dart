import 'story_access_record.dart';
import 'story_access_storage_base.dart';

StoryAccessStorage getStoryAccessStorage() => _MemoryStoryAccessStorage();

class _MemoryStoryAccessStorage implements StoryAccessStorage {
  final Map<String, StoryAccessRecord> _records = {};

  @override
  StoryAccessRecord? read(String authorId) => _records[authorId];

  @override
  void remove(String authorId) {
    _records.remove(authorId);
  }

  @override
  void write(StoryAccessRecord record) {
    _records[record.authorId] = record;
  }
}
