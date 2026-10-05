import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail_platform_interface.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/message.dart';
import 'thumbnail_store.dart';

/// 영상을 고르거나 찍고, 프레임을 뽑아 GPT 에 보낼 수 있게 만든다.
///
/// 원본 파일은 앱 밖으로 나가지 않는다. API 로 가는 것은 추출한 프레임뿐이다
/// (CLAUDE.md 규칙 12).
class VideoInputService {
  VideoInputService({
    ImagePicker? picker,
    FcNativeVideoThumbnail? thumbnailer,
    this.store,
    Future<Duration?> Function(String path)? durationReader,
    Future<Uint8List?> Function(String path, int ms)? frameGrabber,
  })  : _picker = picker ?? ImagePicker(),
        _thumb = thumbnailer ?? FcNativeVideoThumbnail(),
        _readDuration = durationReader ?? _defaultDurationReader,
        _grabOverride = frameGrabber;

  final ImagePicker _picker;
  final FcNativeVideoThumbnail _thumb;
  final ThumbnailStore? store;
  final Future<Duration?> Function(String path) _readDuration;

  /// 테스트에서 네이티브 호출을 갈아끼운다.
  final Future<Uint8List?> Function(String path, int ms)? _grabOverride;

  /// GPT 비전에 보낼 프레임 수 (PRD §9).
  static const int frameCount = 8;

  /// 프레임 긴 변의 최대 픽셀.
  static const int frameMaxEdge = 512;

  /// JPEG 품질.
  static const int frameQuality = 70;

  /// 한 번에 보낼 수 있는 최대 구간 (PRD §2 06-2).
  static const Duration maxClip = Duration(seconds: 30);

  // ---------------------------------------------------------------- 고르기

  /// 앨범에서 영상을 고른다. 취소하면 null.
  Future<VideoAttachment?> pickFromGallery() => _pick(ImageSource.gallery);

  /// 카메라로 찍는다. 30초에서 자동으로 멈춘다.
  Future<VideoAttachment?> recordVideo() => _pick(ImageSource.camera);

  Future<VideoAttachment?> _pick(ImageSource source) async {
    final file = await _picker.pickVideo(
      source: source,
      // 녹화에만 적용된다. 앨범에서 고른 건 길이를 직접 읽어야 한다.
      maxDuration: maxClip,
    );
    if (file == null) return null;
    return attachmentFor(file.path);
  }

  /// 경로 하나로 첨부를 만든다. 길이를 읽고 기본 구간을 잡고 썸네일을 저장한다.
  Future<VideoAttachment?> attachmentFor(String path) async {
    final duration = await _readDuration(path);
    final seconds = (duration?.inMilliseconds ?? 0) / 1000.0;
    if (seconds <= 0) return null;

    final range = defaultRange(seconds);
    final thumbPath = await _saveThumbnail(path, atSec: range.$1);

    return VideoAttachment(
      path: path,
      thumbPath: thumbPath ?? '',
      durationSec: seconds,
      trimStart: range.$1,
      trimEnd: range.$2,
    );
  }

  /// 기본 구간. 30초 이하면 전체, 넘으면 **앞 30초**.
  ///
  /// 파일은 자르지 않는다 — 구간 값만 들고 다닌다 (PRD §9).
  static (double, double) defaultRange(double durationSec) {
    final cap = maxClip.inSeconds.toDouble();
    if (durationSec <= cap) return (0, durationSec);
    return (0, cap);
  }

  /// 사용자가 고른 구간이 유효한지 다듬는다 (06-2 Trim 시트).
  static (double, double) clampRange(
    double start,
    double end,
    double durationSec,
  ) {
    final cap = maxClip.inSeconds.toDouble();
    var s = start.clamp(0.0, durationSec).toDouble();
    var e = end.clamp(0.0, durationSec).toDouble();
    if (e <= s) e = (s + 1).clamp(0.0, durationSec).toDouble();
    if (e - s > cap) e = (s + cap).clamp(0.0, durationSec).toDouble();
    if (e - s > cap) s = e - cap;
    return (s, e);
  }

  // ---------------------------------------------------------------- 프레임

  /// 구간 안에서 고르게 [count] 개 시점을 고른다 (밀리초).
  ///
  /// 양 끝을 그대로 쓰지 않고 안쪽으로 반 칸씩 들여놓는다. 영상 첫 프레임은 페이드인이고
  /// 마지막은 끊긴 경우가 많아, 끝을 집으면 검은 화면을 뽑기 쉽다.
  static List<int> frameTimestampsMs({
    required double startSec,
    required double endSec,
    int count = frameCount,
  }) {
    if (count <= 0) return const [];
    final span = endSec - startSec;
    if (span <= 0) return List.filled(count, (startSec * 1000).round());
    if (count == 1) return [((startSec + span / 2) * 1000).round()];

    final step = span / count;
    return [
      for (var i = 0; i < count; i++)
        ((startSec + step * (i + 0.5)) * 1000).round(),
    ];
  }

  /// 구간 안에서 프레임 8장을 뽑아 data URL 로 돌려준다.
  ///
  /// 실패한 장은 건너뛴다. 한 장도 못 뽑으면 빈 목록 — 호출부는 텍스트만으로 생성한다.
  Future<List<String>> extractFrames(
    VideoAttachment video, {
    int count = frameCount,
  }) async {
    final stamps = frameTimestampsMs(
      startSec: video.trimStart,
      endSec: video.trimEnd,
      count: count,
    );

    final frames = <String>[];
    for (final ms in stamps) {
      final bytes = await _grab(video.path, ms);
      if (bytes == null || bytes.isEmpty) continue;
      frames.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    return frames;
  }

  Future<Uint8List?> _grab(String path, int ms) async {
    final override = _grabOverride;
    if (override != null) return override(path, ms);
    try {
      // width/height 는 긴 변 기준 바운딩 박스로 동작한다 — 비율은 유지된다.
      return await _thumb.saveThumbnailToBytes(
        srcFile: path,
        width: frameMaxEdge,
        height: frameMaxEdge,
        quality: frameQuality,
        format: 'jpeg',
        at: FcVideoThumbnailTime(ms, FcVideoThumbnailTimeUnit.milliseconds),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _saveThumbnail(String path, {required double atSec}) async {
    final store = this.store;
    if (store == null) return null;
    final bytes = await _grab(path, (atSec * 1000).round());
    if (bytes == null || bytes.isEmpty) return null;
    return store.saveBytes(bytes, name: 'video.jpg');
  }

  // ---------------------------------------------------------------- 길이 읽기

  /// `video_player` 로 길이만 읽는다.
  ///
  /// image_picker 는 앨범에서 고른 영상의 길이를 주지 않는다(녹화 시 상한만 걸 수 있다).
  /// 길이를 모르면 30초 초과 판정도, 프레임 시점 계산도 할 수 없다.
  static Future<Duration?> _defaultDurationReader(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      final d = controller.value.duration;
      return d > Duration.zero ? d : null;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }
}
