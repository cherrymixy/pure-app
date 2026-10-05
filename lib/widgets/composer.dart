import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/strings.dart';
import '../models/message.dart';
import '../providers/voice_provider.dart';
import '../services/video_input_service.dart';
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
  });

  final TextEditingController controller;

  /// 전송. 영상 첨부가 있으면 함께 넘어온다.
  final void Function(String text, VideoAttachment? video) onSend;

  final bool enabled;

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
        if (mounted) fill(text);
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

    return Material(
      color: Gray.bg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (listening || voice.text.isNotEmpty) _VoiceBar(voice: voice),
              if (_video != null) _VideoChip(
                video: _video!,
                onRemove: () => setState(() => _video = null),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: widget.enabled && !_picking ? _openAttachSheet : null,
                    icon: _picking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      enabled: widget.enabled && !listening,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: listening ? S.composerListening : S.homeInputHint,
                        filled: true,
                        fillColor: Gray.card,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Gray.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: Gray.line),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_canSend)
                    IconButton.filled(
                      onPressed: _send,
                      icon: const Icon(Icons.arrow_upward, size: 20),
                    )
                  else
                    IconButton.filled(
                      onPressed: widget.enabled ? _toggleMic : null,
                      style: IconButton.styleFrom(
                        backgroundColor: listening ? Colors.red.shade600 : Gray.accent,
                      ),
                      icon: Icon(listening ? Icons.stop : Icons.mic, size: 20),
                    ),
                ],
              ),
            ],
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
                color: Gray.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                voice.text.isEmpty ? S.composerListening : voice.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Gray.dim),
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
