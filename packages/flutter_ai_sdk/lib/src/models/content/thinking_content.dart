part of 'content.dart';

/// Model thinking/reasoning content.
///
/// Surfaces the model's intermediate reasoning where the provider exposes
/// it: Anthropic extended thinking, Google AI thought summaries, DeepSeek
/// `reasoning_content`. See `AIConfig.thinking` to opt in.
///
/// This is informational only — it reflects a single response and isn't
/// replayed back to the model on later turns.
///
/// Example:
/// ```dart
/// final response = await ai.chat('...');
/// print(response.thinking); // null if the model didn't think out loud
/// ```
final class ThinkingContent extends Content {
  /// Creates a [ThinkingContent] with the given [text].
  ///
  /// [signature] is Anthropic's opaque verification token for the block,
  /// when present; other providers never set it.
  const ThinkingContent(this.text, {this.signature})
      : super(type: ContentType.thinking);

  /// The reasoning text.
  final String text;

  /// Anthropic's signature for this thinking block, if any.
  final String? signature;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'thinking',
        'text': text,
        if (signature != null) 'signature': signature,
      };

  @override
  List<Object?> get props => [type, text, signature];

  @override
  String toString() => 'ThinkingContent($text)';
}
