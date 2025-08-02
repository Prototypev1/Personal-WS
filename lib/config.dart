class Config {
  static var huggingFaceApiKey;

  static String baseUrl(String? flavor) {
    switch (flavor) {
      case 'prod':
        return 'https://api-inference.huggingface.co/models/gpt2';
      case 'dev':
      case null:
        return 'https://api-inference.huggingface.co/models/gpt2';
    }
    return 'https://api-inference.huggingface.co/models/gpt2';
  }
}
