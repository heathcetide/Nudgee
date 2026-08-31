/// Conversation persistence for the Flutter AI SDK.
///
/// Exports the `Memory` interface, the built-in dependency-free
/// implementations, and supporting types. `JsonFileMemory` resolves to a
/// `dart:io`-backed implementation on native platforms and to a stub that
/// throws `UnsupportedError` on the web.
library;

export 'conversation_summary.dart';
export 'in_memory_memory.dart';
export 'indexed_conversation.dart';
export 'json_file_memory_stub.dart'
    if (dart.library.io) 'json_file_memory_io.dart';
export 'limited_memory.dart';
export 'memory.dart';
