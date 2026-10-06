/// 빌드 시 주입되는 환경 값.
///
/// 키는 코드·.env·git에 넣지 않는다. 항상 --dart-define 으로만 전달한다:
///   flutter run --dart-define=OPENAI_API_KEY=sk-...
///
/// 키가 없으면 [hasApiKey] 가 false 가 되고, 앱은 데모 모드로 뜬다.
/// 시연 경로는 키 없이도 끝까지 돌아야 한다.
class Env {
  const Env._();

  static const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

  /// 텍스트 생성 모델.
  static const String model = String.fromEnvironment(
    'OPENAI_MODEL',
    defaultValue: 'gpt-4o-mini',
  );

  /// 영상(프레임) 입력용 비전 모델.
  static const String visionModel = String.fromEnvironment(
    'OPENAI_VISION_MODEL',
    defaultValue: 'gpt-4o',
  );

  // ---------------------------------------------------------------- Ollama
  //
  // 맥에서 도는 로컬 모델. 크레딧·인터넷 없이도 진짜 생성을 돌려 보려고 둔다
  // (승아 결정). 주소가 비어 있으면 아예 쓰지 않는다.
  //
  //   ./scripts/dev.sh run --dart-define=OLLAMA_HOST=http://localhost:11434
  //
  // 실기기에서는 맥의 LAN 주소를 넣고, 맥에서 OLLAMA_HOST=0.0.0.0 으로 띄워야 한다.

  static const String ollamaHost = String.fromEnvironment('OLLAMA_HOST');

  static const String ollamaModel = String.fromEnvironment(
    'OLLAMA_MODEL',
    // 4B 는 빠르지만 name·reasoning 문구가 눈에 띄게 거칠다. 기본은 8B.
    defaultValue: 'qwen3:8b',
  );

  static bool get hasOllama => ollamaHost.isNotEmpty;

  /// 키가 주입됐는지. 로그에 키 자체를 찍지 말 것.
  static bool get hasApiKey => _apiKey.isNotEmpty;

  /// 키 본문. 네트워크 요청 헤더 외의 용도로 쓰지 않는다.
  static String? get apiKey => _apiKey.isEmpty ? null : _apiKey;
}
