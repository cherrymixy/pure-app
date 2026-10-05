import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strings.dart';
import '../models/message.dart';
import '../providers/voice_provider.dart';
import '../services/video_input_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'app_icon.dart';
import 'gray_box.dart';

/// 06-1 / 06-2 입력창 — 텍스트 · 영상(+) · 마이크.
///
/// 음성 결과는 **입력창을 채우기만** 한다. 자동 전송하지 않는다 (PRD §9).
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.onVoiceResult,
  });

  final TextEditingController controller;

  /// 전송. 영상 첨부가 있으면 함께 넘어온다.
  final void Function(String text, VideoAttachment? video) onSend;

  final bool enabled;

  /// 음성 인식으로 입력창이 채워졌을 때. 질문형으로 갈지 판단하는 데 쓴다
  /// (부록 D: 칩·음성 → 질문형, 텍스트·영상 → 채팅).
  final ValueChanged<String>? onVoiceResult;

  @override
  State<Composer> createState() => ComposerState();
}

class ComposerState extends State<Composer> {
  VideoAttachment? _video;
  bool _picking = false;

  /// 바깥에서 칩을 눌렀을 때 입력창을 채운다.
  void fill(String text) {
    widget.controller.text = text;
    widget.controller.selection =
        TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  void clear() {
    widget.controller.clear();
    setState(() => _video = null);
  }

  bool get _canSend =>
      widget.enabled &&
      (widget.controller.text.trim().isNotEmpty || _video != null);

  void _send() {
    if (!_canSend) return;
    final text = widget.controller.text.trim();
    final video = _video;
    widget.controller.clear();
    setState(() => _video = null);
    widget.onSend(text, video);
  }

  // ---------------------------------------------------------------- 영상

  Future<void> _openAttachSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text(S.composerRecordVideo),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(S.composerChooseFromLibrary),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    final service = context.read<VideoInputService>();
    setState(() => _picking = true);
    try {
      final picked = choice == 'camera'
          ? await service.recordVideo()
          : await service.pickFromGallery();
      if (!mounted || picked == null) return;

      // 30초를 넘으면 구간을 고르게 한다 (06-2 Trim 시트).
      final attachment = picked.durationSec > VideoInputService.maxClip.inSeconds
          ? await _openTrimSheet(picked)
          : picked;
      if (!mounted) return;
      setState(() => _video = attachment);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<VideoAttachment?> _openTrimSheet(VideoAttachment video) async {
    var start = video.trimStart;
    final cap = VideoInputService.maxClip.inSeconds.toDouble();

    return showModalBottomSheet<VideoAttachment>(
      context: context,
      isDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final end = (start + cap).clamp(0.0, video.durationSec);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(S.composerTrimTitle,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    '${_mmss(start)} – ${_mmss(end)}  '
                    '(of ${_mmss(video.durationSec)})',
                    style: const TextStyle(fontSize: 12, color: Gray.dim),
                  ),
                  Slider(
                    value: start,
                    max: (video.durationSec - cap).clamp(0.0, video.durationSec),
                    onChanged: (v) => setSheet(() => start = v),
                  ),
                  FilledButton(
                    onPressed: () {
                      final range = VideoInputService.clampRange(
                        start,
                        start + cap,
                        video.durationSec,
                      );
                      Navigator.pop(
                        context,
                        VideoAttachment(
                          path: video.path,
                          thumbPath: video.thumbPath,
                          durationSec: video.durationSec,
                          trimStart: range.$1,
                          trimEnd: range.$2,
                        ),
                      );
                    },
                    child: const Text(S.composerTrimUse),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(S.actionCancel),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static String _mmss(double seconds) {
    final s = seconds.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------- 마이크

  Future<void> _toggleMic() async {
    final voice = context.read<VoiceProvider>();
    if (voice.isListening) {
      await voice.stop();
      return;
    }

    final ok = await voice.start(
      consumer: VoiceConsumer.composer,
      onFinal: (text) {
        if (!mounted) return;
        fill(text);
        widget.onVoiceResult?.call(text);
      },
    );
    if (!mounted || ok) return;

    if (voice.isPermissionDenied) {
      await showPermissionSheet(context, S.permMicTitle);
    }
  }

  // ---------------------------------------------------------------- 그리기

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceProvider>();
    final listening = voice.isListening;

    return SafeArea(
      top: false,
      child: Padding(
        // 시안: 입력창 좌우 여백 22 (402 - 358 의 절반), 바닥에서 약간 띄움.
        padding: const EdgeInsets.fromLTRB(22, 0, 22, AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listening || voice.text.isNotEmpty) _VoiceBar(voice: voice),
            if (_video != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                child: _VideoChip(
                  video: _video!,
                  onRemove: () => setState(() => _video = null),
                ),
              ),
            // 시안 `Composer` (455:4296): 높이 59 · radius/full · 왼쪽 패딩 16 ·
            // 오른쪽 8 · 요소 간격 12 · drop-shadow 0 4 8 rgba(0,0,0,.06).
            Container(
              height: 59,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0F000000),
                    offset: Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.only(left: AppSpacing.x16, right: AppSpacing.x8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.enabled && !_picking ? _openAttachSheet : null,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: _picking
                          ? const Padding(
                              padding: EdgeInsets.all(3),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const AppIcon(AppIconName.plus, size: 24),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled && !listening,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                      style: AppTextStyles.bodyL,
                      decoration: InputDecoration(
                        // 시안 문구.
                        hintText: listening ? S.composerListening : S.homeInputHint,
                        hintStyle: AppTextStyles.bodyL.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x12),
                  // 시안 `Action`: 43 원형, bg/inverse, 아이콘 22.
                  _ActionButton(
                    onTap: widget.enabled
                        ? (_canSend ? _send : _toggleMic)
                        : null,
                    listening: listening,
                    sending: _canSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 입력창 오른쪽의 검은 원형 버튼. 글자가 있으면 전송, 없으면 마이크.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onTap,
    required this.listening,
    required this.sending,
  });

  final VoidCallback? onTap;
  final bool listening;
  final bool sending;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: listening ? AppColors.statusError : AppColors.bgInverse,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 43,
          height: 43,
          child: Center(
            child: listening
                ? const Icon(Icons.stop, size: 20, color: AppColors.iconOnInverse)
                : sending
                    ? const Icon(Icons.arrow_upward,
                        size: 20, color: AppColors.iconOnInverse)
                    : const AppIcon(
                        AppIconName.mic,
                        size: 22,
                        color: AppColors.iconOnInverse,
                      ),
          ),
        ),
      ),
    );
  }
}

class _VoiceBar extends StatelessWidget {
  const _VoiceBar({required this.voice});
  final VoiceProvider voice;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            // 파형 자리 — 음량에 따라 자라는 막대. STEP 24 에서 진짜 파형으로.
            AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 8 + voice.level * 56,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bgBrand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                voice.text.isEmpty ? S.composerListening : voice.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyS.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

class _VideoChip extends StatelessWidget {
  const _VideoChip({required this.video, required this.onRemove});

  final VideoAttachment video;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            if (video.thumbPath.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(video.thumbPath),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 40, height: 40),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${video.selectedSec.toStringAsFixed(0)}s selected',
                style: const TextStyle(fontSize: 12, color: Gray.dim),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

/// 01-E1 권한 재요청 시트.
Future<void> showPermissionSheet(BuildContext context, String title) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(S.permBody,
                style: TextStyle(fontSize: 13, color: Gray.dim)),
            const SizedBox(height: 16),
            FilledButton(
              // 설정 열기는 실제 연결이 필요하다. 회색박스에서는 닫기만 한다.
              onPressed: () => Navigator.pop(context),
              child: const Text(S.actionOpenSettings),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(S.actionNotNow),
            ),
          ],
        ),
      ),
    ),
  );
}
