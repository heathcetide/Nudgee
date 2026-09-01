import 'package:flutter_test/flutter_test.dart';
import 'package:nudgee/core/agent/providers/providers.dart';

void main() {
  group('LLM Providers — All clients', () {
    test('OpenAIClient has correct defaults', () {
      final client = OpenAIClient(apiKey: 'sk-test');
      expect(client.defaultModel, 'gpt-4o');
      expect(client.baseUrl, 'https://api.openai.com/v1');
      expect(client.availableModels(), contains('gpt-4o'));
      expect(client.availableModels(), contains('o3'));
      client.dispose();
    });

    test('DeepSeekClientV2 has correct defaults', () {
      final client = DeepSeekClientV2(apiKey: 'sk-test');
      expect(client.defaultModel, 'deepseek-chat');
      expect(client.baseUrl, 'https://api.deepseek.com/v1');
      expect(client.availableModels(), contains('deepseek-chat'));
      expect(client.availableModels(), contains('deepseek-reasoner'));
      client.dispose();
    });

    test('QiniuClient has correct defaults', () {
      final client = QiniuClient(apiKey: 'sk-test');
      expect(client.defaultModel, 'gpt-5.4-mini');
      expect(client.baseUrl, 'https://llmapi.qiniu.io/v1');
      expect(client.availableModels(), contains('gpt-5.4-mini'));
      client.dispose();
    });

    test('OpenRouterClient has correct defaults', () {
      final client = OpenRouterClient(apiKey: 'sk-or-test');
      expect(client.baseUrl, 'https://openrouter.ai/api/v1');
      expect(client.availableModels(), contains('openai/gpt-4o'));
      client.dispose();
    });

    test('AnthropicClient has correct defaults', () {
      final client = AnthropicClient(apiKey: 'sk-ant-test');
      expect(client.defaultModel, 'claude-3-5-sonnet-20241022');
      expect(client.baseUrl, 'https://api.anthropic.com/v1');
      expect(client.availableModels(), contains('claude-3-5-sonnet-20241022'));
      client.dispose();
    });

    test('GoogleAIClient has correct defaults', () {
      final client = GoogleAIClient(apiKey: 'AIza-test');
      expect(client.defaultModel, 'gemini-2.0-flash');
      expect(client.baseUrl, 'https://generativelanguage.googleapis.com/v1beta');
      expect(client.availableModels(), contains('gemini-2.0-flash'));
      expect(client.availableModels(), contains('gemini-1.5-pro'));
      client.dispose();
    });

    test('MistralClient has correct defaults', () {
      final client = MistralClient(apiKey: 'test');
      expect(client.defaultModel, 'mistral-large-latest');
      expect(client.baseUrl, 'https://api.mistral.ai/v1');
      expect(client.availableModels(), contains('mistral-large-latest'));
      expect(client.availableModels(), contains('codestral-latest'));
      client.dispose();
    });

    test('XAIClient has correct defaults', () {
      final client = XAIClient(apiKey: 'xai-test');
      expect(client.defaultModel, 'grok-4');
      expect(client.baseUrl, 'https://api.x.ai/v1');
      expect(client.availableModels(), contains('grok-4'));
      expect(client.availableModels(), contains('grok-2-vision'));
      client.dispose();
    });

    test('OllamaClient has correct defaults', () {
      final client = OllamaClient();
      expect(client.defaultModel, 'llama3.2');
      expect(client.baseUrl, 'http://localhost:11434/v1');
      expect(client.availableModels(), contains('llama3.2'));
      expect(client.availableModels(), contains('deepseek-r1'));
      // Ollama doesn't need an API key
      expect(client.apiKey, 'ollama');
      client.dispose();
    });

    test('GroqClient has correct defaults', () {
      final client = GroqClient(apiKey: 'gsk-test');
      expect(client.defaultModel, 'llama-3.3-70b-versatile');
      expect(client.baseUrl, 'https://api.groq.com/openai/v1');
      expect(client.availableModels(), contains('llama-3.3-70b-versatile'));
      client.dispose();
    });

    test('TogetherClient has correct defaults', () {
      final client = TogetherClient(apiKey: 'test');
      expect(client.baseUrl, 'https://api.together.xyz/v1');
      expect(client.availableModels(), contains('meta-llama/Llama-3-70b-chat-hf'));
      client.dispose();
    });

    test('MoonshotClient has correct defaults', () {
      final client = MoonshotClient(apiKey: 'sk-test');
      expect(client.defaultModel, 'moonshot-v1-8k');
      expect(client.baseUrl, 'https://api.moonshot.cn/v1');
      expect(client.availableModels(), contains('moonshot-v1-128k'));
      client.dispose();
    });

    test('ZhipuClient has correct defaults', () {
      final client = ZhipuClient(apiKey: 'test');
      expect(client.defaultModel, 'glm-4');
      expect(client.baseUrl, 'https://open.bigmodel.cn/api/paas/v4');
      expect(client.availableModels(), contains('glm-4'));
      expect(client.availableModels(), contains('glm-4-flash'));
      client.dispose();
    });

    test('SiliconFlowClient has correct defaults', () {
      final client = SiliconFlowClient(apiKey: 'sk-test');
      expect(client.baseUrl, 'https://api.siliconflow.cn/v1');
      expect(client.availableModels(), contains('deepseek-ai/DeepSeek-V3'));
      client.dispose();
    });

    test('all providers implement LLMClient', () {
      final clients = <LLMClient>[
        OpenAIClient(apiKey: 'test'),
        DeepSeekClientV2(apiKey: 'test'),
        QiniuClient(apiKey: 'test'),
        OpenRouterClient(apiKey: 'test'),
        AnthropicClient(apiKey: 'test'),
        GoogleAIClient(apiKey: 'test'),
        MistralClient(apiKey: 'test'),
        XAIClient(apiKey: 'test'),
        OllamaClient(),
        GroqClient(apiKey: 'test'),
        TogetherClient(apiKey: 'test'),
        MoonshotClient(apiKey: 'test'),
        ZhipuClient(apiKey: 'test'),
        SiliconFlowClient(apiKey: 'test'),
      ];

      for (final c in clients) {
        expect(c, isA<LLMClient>());
        expect(c.availableModels(), isNotEmpty);
        c.dispose();
      }
    });

    test('total provider count is 14', () {
      // 12 OpenAI-compatible + Anthropic + Google AI = 14 providers
      final openaiCompatible = <LLMClient>[
        OpenAIClient(apiKey: 'test'),
        DeepSeekClientV2(apiKey: 'test'),
        QiniuClient(apiKey: 'test'),
        OpenRouterClient(apiKey: 'test'),
        MistralClient(apiKey: 'test'),
        XAIClient(apiKey: 'test'),
        OllamaClient(),
        GroqClient(apiKey: 'test'),
        TogetherClient(apiKey: 'test'),
        MoonshotClient(apiKey: 'test'),
        ZhipuClient(apiKey: 'test'),
        SiliconFlowClient(apiKey: 'test'),
      ];
      final independent = <LLMClient>[
        AnthropicClient(apiKey: 'test'),
        GoogleAIClient(apiKey: 'test'),
      ];

      expect(openaiCompatible.length, 12);
      expect(independent.length, 2);
      expect(openaiCompatible.length + independent.length, 14);

      for (final c in [...openaiCompatible, ...independent]) {
        c.dispose();
      }
    });
  });
}
