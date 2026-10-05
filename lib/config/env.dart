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

  /// 키가 주입됐는지. 로그에 키 자체를 찍지 말 것.
  static bool get hasApiKey => _apiKey.isNotEmpty;

  /// 키 본문. 네트워크 요청 헤더 외의 용도로 쓰지 않는다.
  static String? get apiKey => _apiKey.isEmpty ? null : _apiKey;
}
