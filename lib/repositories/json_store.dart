import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// JSON 파일 하나를 안전하게 읽고 쓴다.
///
/// 쓰기는 임시 파일에 적고 rename 으로 갈아 끼운다. 전시 중 앱이 죽어도 반쯤 쓰다 만
/// 파일이 남지 않는다 — 그런 파일을 다음 실행에서 읽으면 라이브러리가 통째로 날아간다.
///
/// 쓰기 요청이 몰려도 순서를 지키고, 연속 호출은 한 번으로 합친다
/// (메시지 한 통마다 전체 상태를 쓰므로 그냥 두면 I/O 가 쌓인다).
class JsonStore {
  JsonStore(this.file, {this.debounce = const Duration(milliseconds: 120)});

  /// 테스트는 임시 디렉터리를, 앱은 documents 디렉터리를 준다.
  factory JsonStore.inDirectory(Directory dir, String name) =>
      JsonStore(File('${dir.path}/$name'));

  final File file;
  final Duration debounce;

  Timer? _timer;
  Map<String, Object?>? _pending;
  Future<void> _writing = Future.value();

  /// 읽는다. 파일이 없거나 깨졌으면 빈 맵.
  Future<Map<String, Object?>> read() async {
    try {
      if (!await file.exists()) return {};
      final text = await file.readAsString();
      if (text.trim().isEmpty) return {};
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded.cast<String, Object?>() : {};
    } catch (_) {
      // 깨진 파일은 빈 상태로 취급한다. 여기서 던지면 앱이 아예 안 뜬다.
      return {};
    }
  }

  /// 예약한다. 연속 호출은 마지막 것 하나로 합쳐진다.
  void schedule(Map<String, Object?> data) {
    _pending = data;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// 예약된 쓰기를 지금 끝낸다. 테스트와 앱 종료 시에 쓴다.
  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    final data = _pending;
    if (data == null) return _writing;
    _pending = null;
    _writing = _writing.then((_) => _write(data));
    return _writing;
  }

  Future<void> _write(Map<String, Object?> data) async {
    final tmp = File('${file.path}.tmp');
    try {
      await file.parent.create(recursive: true);
      await tmp.writeAsString(jsonEncode(data), flush: true);
      await tmp.rename(file.path);
    } catch (_) {
      // 저장 실패가 시연을 멈추게 하지 않는다. 메모리 상태는 그대로 살아 있다.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
  }

  Future<void> deleteFile() async {
    _timer?.cancel();
    _pending = null;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
