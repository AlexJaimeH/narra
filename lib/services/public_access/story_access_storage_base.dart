import 'story_access_record.dart';

abstract class StoryAccessStorage {
  StoryAccessRecord? read(String authorId);
  void write(StoryAccessRecord record);
  void remove(String authorId);
}
