# Changelog

All notable changes to Flutter AI SDK are documented here.

## 1.9.0 - 2026-07-27

### Batch processing

- **`FlutterAI.submitBatch`/`getBatchStatus`/`getBatchResults`/
  `waitForBatchCompletion`**: new facade methods for asynchronous batch
  processing at ~50% lower cost, backed by a new `BatchProvider`
  interface (kept separate from `BaseProvider` — only Anthropic and
  OpenAI have a batch API). Throws `AIFeatureNotSupportedError` where
  unsupported.
- **Anthropic**: `POST /v1/messages/batches`, polls
  `processing_status`, parses the JSONL results file.
- **OpenAI**: uploads a JSONL input file (`purpose=batch`), creates the
  batch job, polls `status`, downloads and parses the JSONL output file.
- New `BatchRequest`/`BatchJob`/`BatchResult` models and a `pollBatchJob`
  helper (exponential backoff, capped) shared by both providers.
- Batch results are not guaranteed to come back in submission order —
  always match by `BatchRequest.customId`/`BatchResult.customId`.
- New `AIHttpClient.postMultipart` for file uploads.

## 1.8.0 - 2026-07-27

### Embeddings

- **`FlutterAI.embed`/`embedBatch`**: new facade methods generating
  embedding vectors, backed by a new `EmbeddingProvider` interface
  (deliberately separate from `BaseProvider` — not every chat provider
  has an embeddings API). Throws `AIFeatureNotSupportedError` on
  providers that don't implement it (Anthropic, xAI, DeepSeek,
  OpenRouter).
- Implemented on **OpenAI** (`text-embedding-3-small`), **Google AI**
  (`gemini-embedding-001`, via `batchEmbedContents`), **Ollama**
  (`embeddinggemma`, local, no API key) and **Mistral**
  (`mistral-embed`, reusing the shared OpenAI-compatible wire format).
- New `EmbeddingRequest`/`EmbeddingResponse` models and a
  `cosineSimilarity` utility for comparing vectors.

## 1.7.0 - 2026-07-27

### Thinking / reasoning output

- **`ThinkingContent`**: new content type surfacing the model's
  intermediate reasoning, plus `AIResponse.thinking`/`hasThinking` and
  `Message.hasThinking` convenience accessors.
- **`AIConfig.thinking`** (`ThinkingConfig`, optional `ThinkingEffort`)
  opts in per-provider:
  - Anthropic: adaptive extended thinking (`thinking: {type: "adaptive"}`),
    effort mapped to `output_config.effort`.
  - Google AI: `generationConfig.thinkingConfig` (`includeThoughts`,
    `thinkingLevel`).
  - DeepSeek: `thinking: {type: "enabled"}`; `reasoning_content` parsed
    into `ThinkingContent` on any OpenAI-compatible provider that returns
    it, not just DeepSeek.
  - Other providers ignore the configuration.
- Streaming: new `StreamChunk.thinkingDelta`/`isThinkingDelta`, kept
  separate from regular text deltas so accumulation logic isn't polluted.
- Thinking output is informational only — it isn't replayed back to the
  model on later turns.

## 1.6.0 - 2026-07-27

### More providers

- **New providers**: Mistral AI, xAI (Grok), DeepSeek and OpenRouter — all
  expose an OpenAI-compatible chat completions API, so they're implemented
  as thin subclasses of a new `OpenAICompatibleProvider` base that reuses
  the existing OpenAI wire-format mapper unchanged.
- `AIResponse.provider` on these new providers is correctly tagged (the
  shared mapper's `parseResponse` now accepts the calling provider instead
  of always defaulting to `AIProvider.openai`).
- DeepSeek has no `/v1` segment in its base URL (`https://api.deepseek.com`),
  unlike the other three.

## 1.5.0 - 2026-07-11

### Conversation persistence

- **`Memory`**: wired up the (previously dormant, unused since v1.0.0)
  `Memory`/`InMemoryMemory`/`LimitedMemory` classes to `ContextManager` and
  `FlutterAI` — `attachMemory`/`detachMemory` for automatic background
  saves, `saveConversation`/`loadConversation` for one-shot save/restore.
- **`JsonFileMemory`**: new file-based implementation (one JSON file per
  conversation); resolves to a stub throwing `UnsupportedError` on the web,
  where `dart:io` is unavailable. No new dependency in the main package.
- **`ConversationSummary`**: lightweight metadata via `Memory.listSummaries`
  for building a conversation-list UI without loading full histories.
- Split `context/memory.dart` into a `context/persistence/` module
  (one class per file), matching the rest of the codebase.
- Fixed `Conversation`/`Message` JSON round-tripping: `updatedAt` was
  dropped on `Conversation.fromJson`; audio and document content silently
  turned into empty text on deserialization; base64 images lost their
  `detail` level and were mis-parsed as URLs.

## 1.4.0 - 2026-07-08

### Prompt caching & universal document input

- **Prompt caching**: new `AIConfig.promptCaching` (`PromptCaching`, 5 min or
  1 h TTL) — explicit `cache_control` on Anthropic; cache hit counters parsed
  on every provider (`Usage.cachedTokens`, new `Usage.cacheWriteTokens`).
- **Documents**: `DocumentContent` now works on every cloud provider —
  URL sources added on Anthropic, base64 `file` blocks added on OpenAI
  (URL passed as a text reference), Google AI unchanged. Support table in
  the README.

## 1.3.0 - 2026-07-08

### Structured outputs & token counting

- **Structured outputs**: `ResponseFormat.json(schema: ...)` now uses each
  provider's native guaranteed-schema mechanism — OpenAI `json_schema`
  (with opt-in `strict` mode), Anthropic `output_config.format`, Gemini
  `responseJsonSchema`, Ollama schema format.
- **Token counting**: new `countTokens` on providers and
  `FlutterAI.countTokens({message})` on the facade — exact server-side
  counts on Anthropic (`/messages/count_tokens`) and Google AI
  (`:countTokens`); local estimation elsewhere.

## 1.2.0 - 2026-07-07

### Architecture overhaul & new features

- **Architecture**: full restructuring into one-class-per-file modules —
  `config/`, `models/content/` (sealed hierarchy as part files),
  `models/tools/`; one folder per provider with a dedicated wire-format
  mapper; shared streaming loop in `BaseProvider` (template method);
  new `ProviderRegistry` factory supporting custom provider registration.
  The public API is unchanged.
- **Tool Runner**: automatic agentic tool-calling loop (`ToolRunner`,
  `ExecutableTool`) — parallel tool execution, error feedback to the
  model, iteration budget, observability callbacks.
- **Ollama provider**: run local models (Llama, Qwen, Gemma...) with
  streaming (NDJSON), tools, JSON mode and vision; no API key required.
- **Anthropic**: consecutive same-role messages are merged, as required
  by the API's role alternation (fixes parallel tool results).
- Dependencies upgraded for Flutter 3.44.

## 1.1.0 - 2026-07-06

### Model refresh

- Default models updated to current generations: `gpt-5.5`,
  `claude-opus-4-8`, `gemini-3.5-flash`.
- Model context limits updated (GPT-5.x, Claude 4/5, Gemini 3.x).
- Anthropic provider: never sends `temperature` and `top_p` together
  (rejected by Claude 4+); maps the `refusal` and
  `model_context_window_exceeded` stop reasons.
- Providers can receive an injected HTTP client; `FlutterAI` accepts a
  custom provider. Unit tests for all providers and a CI workflow added.
- Dependencies upgraded (`mime` 2.x, `rxdart` 0.28, `flutter_lints` 6).

## 1.0.0 - 2025-11-30

### Initial release

- Unified API for OpenAI, Anthropic and Google AI.
- Streaming with chunk events, context management and memory.
- Multimodal content (text, images, audio, documents).
- Function calling for all providers, typed error handling,
  token estimation.
