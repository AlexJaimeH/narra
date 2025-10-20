import 'story_access_storage_base.dart';
import 'story_access_storage_stub.dart'
    if (dart.library.html) 'story_access_storage_web.dart';

StoryAccessStorage createStoryAccessStorage() => getStoryAccessStorage();
