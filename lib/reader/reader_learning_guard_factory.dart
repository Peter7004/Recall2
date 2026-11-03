import 'reader_learning_guard.dart';
import 'reader_learning_guard_native.dart'
    if (dart.library.js_interop) 'reader_learning_guard_web.dart' as platform;

LearningWriteGuard get learningWriteGuard => platform.learningWriteGuard;
