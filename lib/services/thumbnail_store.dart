import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 썸네일 파일 보관소.
///
/// 두 종류가 들어온다:
///  - 시뮬레이터 `capture()` 가 준 PNG dataURL (라이브러리 카드·상세)
///  - 첨부 영상의 첫 프레임 JPEG (채팅 말풍선)
///
/// 교체할 때 옛 파일을 반드시 지운다. 피드백으로 재생성할 때마다 썸네일이 새로 생기는데
/// 그냥 두면 전시 내내 디스크에 쌓인다.
class ThumbnailStore {
  ThumbnailStore(this.directory);

  static Future<ThumbnailStore> forApp() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/thumbnails');
    if (!await dir.exists()) await dir.create(recursive: true);
    return ThumbnailStore(dir);
  }

  final Directory directory;

  /// `data:image/png;base64,...` 를 파일로 저장하고 경로를 돌려준다.
  ///
  /// [replacing] 에 옛 경로를 주면 저장이 끝난 뒤 지운다.
  Future<String?> savePngDataUrl(
    String dataUrl, {
    required String id,
    String? replacing,
  }) async {
    final bytes = decodeDataUrl(dataUrl);
    if (bytes == null || bytes.isEmpty) return null;
    return saveBytes(bytes, name: '$id.png', replacing: replacing);
  }

  /// 바이트를 그대로 저장한다 (영상 썸네일 JPEG 등).
  Future<String?> saveBytes(
    Uint8List bytes, {
    required String name,
    String? replacing,
  }) async {
    try {
      if (!await directory.exists()) await directory.create(recursive: true);
      // 같은 이름이면 캐시가 옛 그림을 쥐고 있을 수 있어 매번 새 이름을 쓴다.
      final unique = '${DateTime.now().microsecondsSinceEpoch}_$name';
      final file = File('${directory.path}/$unique');
      await file.writeAsBytes(bytes, flush: true);
      if (replacing != null && replacing != file.path) await delete(replacing);
      return file.path;
    } catch (_) {
      // 썸네일이 없다고 시연이 멈추면 안 된다. 호출부는 null 을 플레이스홀더로 다룬다.
      return null;
    }
  }

  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 라이브러리·대화에서 더 이상 참조하지 않는 파일을 치운다.
  /// "Reset demo data" 와 모션 삭제 뒤에 부른다.
  Future<int> pruneExcept(Set<String> keepPaths) async {
    var removed = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (keepPaths.contains(entity.path)) continue;
        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
    } catch (_) {}
    return removed;
  }

  /// `data:[<mime>][;base64],<data>` 를 바이트로. 형식이 아니면 null.
  static Uint8List? decodeDataUrl(String dataUrl) {
    final comma = dataUrl.indexOf(',');
    if (!dataUrl.startsWith('data:') || comma < 0) return null;
    final meta = dataUrl.substring(5, comma);
    final payload = dataUrl.substring(comma + 1);
    try {
      if (meta.contains('base64')) return base64Decode(payload);
      return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
    } catch (_) {
      return null;
    }
  }
}
