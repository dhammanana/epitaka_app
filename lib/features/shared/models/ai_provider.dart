/// Supported AI provider types.
///
/// Each provider has its own API format, base URL, and authentication.
enum AiProvider {
  gemini,
  openai,
  openrouter,
  claude,
  deepseek;

  String get displayName {
    switch (this) {
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.openai:
        return 'OpenAI-compatible';
      case AiProvider.openrouter:
        return 'OpenRouter';
      case AiProvider.claude:
        return 'Anthropic Claude';
      case AiProvider.deepseek:
        return 'DeepSeek';
    }
  }

  /// True for providers speaking the OpenAI chat-completions protocol
  /// (same request shape, only the base URL differs).
  bool get isOpenAiCompatible {
    switch (this) {
      case AiProvider.openai:
      case AiProvider.openrouter:
      case AiProvider.deepseek:
        return true;
      case AiProvider.gemini:
      case AiProvider.claude:
        return false;
    }
  }

  /// True for providers with a fixed endpoint (no base-URL field needed).
  bool get hasFixedEndpoint {
    switch (this) {
      case AiProvider.gemini:
      case AiProvider.claude:
        return true;
      case AiProvider.openai:
      case AiProvider.openrouter:
      case AiProvider.deepseek:
        return false;
    }
  }

  String get defaultBaseUrl {
    switch (this) {
      case AiProvider.gemini:
        return 'https://generativelanguage.googleapis.com/v1beta/models';
      case AiProvider.openai:
        return 'https://api.openai.com/v1';
      case AiProvider.openrouter:
        return 'https://openrouter.ai/api/v1';
      case AiProvider.claude:
        return 'https://api.anthropic.com/v1';
      case AiProvider.deepseek:
        return 'https://api.deepseek.com/v1';
    }
  }

  /// URL with instructions on how to get an API key for this provider.
  String get helpUrl {
    switch (this) {
      case AiProvider.gemini:
        return 'https://ai.google.dev/gemini-api/docs/api-key';
      case AiProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case AiProvider.openrouter:
        return 'https://openrouter.ai/docs/quickstart';
      case AiProvider.claude:
        return 'https://docs.anthropic.com/en/api/getting-started';
      case AiProvider.deepseek:
        return 'https://platform.deepseek.com/api_keys';
    }
  }

  /// A short label for the help link button.
  String get helpLabel {
    switch (this) {
      case AiProvider.gemini:
        return 'Get a Gemini API key';
      case AiProvider.openai:
        return 'Get an OpenAI API key';
      case AiProvider.openrouter:
        return 'Get an OpenRouter API key';
      case AiProvider.claude:
        return 'Get an Anthropic API key';
      case AiProvider.deepseek:
        return 'Get a DeepSeek API key';
    }
  }

  /// Direct URL where the user creates an API key for this provider.
  /// Gemini's key page is free for everyone (requires a Google account).
  String get apiKeyCreationUrl {
    switch (this) {
      case AiProvider.gemini:
        return 'https://aistudio.google.com/app/apikey';
      case AiProvider.openai:
        return 'https://platform.openai.com/api-keys';
      case AiProvider.openrouter:
        return 'https://openrouter.ai/keys';
      case AiProvider.claude:
        return 'https://console.anthropic.com/settings/keys';
      case AiProvider.deepseek:
        return 'https://platform.deepseek.com/api_keys';
    }
  }

  /// Additional help URLs for related services that use the same format.
  List<({String label, String url})> get additionalHelps {
    switch (this) {
      case AiProvider.gemini:
        return [
          (
            label: 'OpenRouter (many models)',
            url: 'https://openrouter.ai/keys',
          ),
          (label: 'DeepSeek', url: 'https://platform.deepseek.com/api_keys'),
        ];
      case AiProvider.openai:
        return [
          (
            label: 'OpenRouter (many models)',
            url: 'https://openrouter.ai/keys',
          ),
          (label: 'DeepSeek', url: 'https://platform.deepseek.com/api_keys'),
          (
            label: 'Google Gemini',
            url: 'https://ai.google.dev/gemini-api/docs/api-key',
          ),
        ];
      case AiProvider.openrouter:
        return [
          (label: 'OpenRouter models', url: 'https://openrouter.ai/models'),
          (
            label: 'Free models',
            url: 'https://openrouter.ai/collections/free-models',
          ),
          (label: 'DeepSeek', url: 'https://platform.deepseek.com/api_keys'),
          (
            label: 'Google Gemini',
            url: 'https://ai.google.dev/gemini-api/docs/api-key',
          ),
        ];
      case AiProvider.claude:
        return [
          (
            label: 'Anthropic docs',
            url: 'https://docs.anthropic.com/en/api/getting-started',
          ),
          (
            label: 'OpenRouter (Claude via OpenRouter)',
            url: 'https://openrouter.ai/keys',
          ),
        ];
      case AiProvider.deepseek:
        return [
          (
            label: 'DeepSeek docs',
            url: 'https://platform.deepseek.com/api_keys',
          ),
          (
            label: 'OpenRouter (many models)',
            url: 'https://openrouter.ai/keys',
          ),
        ];
    }
  }

  /// Deserialise from stored string.
  static AiProvider fromString(String value) {
    switch (value) {
      case 'gemini':
        return AiProvider.gemini;
      case 'openai':
        return AiProvider.openai;
      case 'openrouter':
        return AiProvider.openrouter;
      case 'claude':
      case 'anthropic':
        return AiProvider.claude;
      case 'deepseek':
        return AiProvider.deepseek;
      default:
        return AiProvider.gemini;
    }
  }

  String get serialise => name;
}
