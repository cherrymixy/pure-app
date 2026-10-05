import 'package:flutter/foundation.dart';

import '../models/message.dart';
import '../models/motion_spec.dart';
import '../repositories/data_repository.dart';

/// 대화 — 채팅(06-2~06-5)과 질문형(06-9)이 **같은 Chat 위에** 올라간다 (부록 D 결정).
///
/// 생성 자체는 하지 않는다. 메시지를 넣고 상태를 바꾸는 것까지만 — 실제 생성은
/// STEP 7 의 GenerationService 가 맡고, 결과를 여기로 넘긴다.
class ChatProvider extends ChangeNotifier {
  ChatProvider(
    this._repo, {
    DateTime Function()? now,
    String Function()? idGenerator,
  })  : _now = now ?? DateTime.now,
        _newId = idGenerator ?? _defaultId;

  final DataRepository _repo;
  final DateTime Function() _now;
  final String Function() _newId;

  static int _seq = 0;
  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_seq++}';

  String? _currentChatId;

  // ---------------------------------------------------------------- 조회

  /// 최근 활동 순 (06-8 목록).
  List<Chat> get chats => _repo.chats;

  Chat? get current => _currentChatId == null ? null : _repo.chatById(_currentChatId!);

  String? get currentId => _currentChatId;

  List<Message> get messages => current?.messages ?? const [];

  bool get hasCurrent => current != null;

  /// 06-5 피드백의 기준이 되는 가장 최근 로봇 답장.
  Message? get lastReply => current?.lastRobotReply;

  /// 06-8 의 "n saved" — 이 대화에서 저장된 모션 수.
  int savedCountFor(String chatId, Iterable<String> savedChatIds) =>
      savedChatIds.where((id) => id == chatId).length;

  // ---------------------------------------------------------------- 대화 열기

  /// 새 대화를 시작한다 (사이드바 New motion, 홈 진입).
  Future<String> startNew() async {
    final chat = Chat(
      id: 'chat.${_newId()}',
      messages: const [],
      createdAt: _now(),
      lastActiveAt: _now(),
    );
    await _repo.upsertChat(chat);
    _currentChatId = chat.id;
    notifyListeners();
    return chat.id;
  }

  /// 기존 대화로 들어간다 (06-8, Edit in chat).
  Future<bool> open(String chatId) async {
    if (_repo.chatById(chatId) == null) return false;
    _currentChatId = chatId;
    notifyListeners();
    return true;
  }

  /// 현재 대화가 없으면 만든다.
  Future<String> ensureCurrent() async =>
      _currentChatId ?? await startNew();

  Future<void> deleteChat(String chatId) async {
    await _repo.deleteChat(chatId);
    if (_currentChatId == chatId) _currentChatId = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------- 메시지

  Future<void> _commit(Chat chat) async {
    await _repo.upsertChat(chat.copyWith(lastActiveAt: _now()));
    notifyListeners();
  }

  /// 사용자 메시지를 넣는다. 텍스트·영상 둘 다 없으면 아무것도 하지 않는다.
  Future<Message?> addUserMessage({String? text, VideoAttachment? video}) async {
    final trimmed = text?.trim();
    if ((trimmed == null || trimmed.isEmpty) && video == null) return null;

    final chatId = await ensureCurrent();
    final chat = _repo.chatById(chatId)!;
    final msg = Message(
      id: 'msg.${_newId()}',
      sender: Sender.user,
      text: trimmed,
      video: video,
      status: MessageStatus.sent,
      createdAt: _now(),
    );
    await _commit(chat.copyWith(messages: [...chat.messages, msg]));
    return msg;
  }

  /// 생성 중 자리(점 3개)를 만든다. 반환한 id 로 나중에 채운다.
  Future<Message> addPendingReply() async {
    final chatId = await ensureCurrent();
    final chat = _repo.chatById(chatId)!;
    final msg = Message(
      id: 'msg.${_newId()}',
      sender: Sender.robot,
      status: MessageStatus.generating,
      createdAt: _now(),
    );
    await _commit(chat.copyWith(messages: [...chat.messages, msg]));
    return msg;
  }

  /// 생성 성공 — 자리를 결과로 채운다.
  Future<void> completeReply(String messageId, MotionSpec spec) =>
      _updateMessage(messageId, (m) => m.copyWith(status: MessageStatus.done, spec: spec));

  /// 생성 실패 — 06-E1 말풍선.
  Future<void> failReply(String messageId, {String? text}) =>
      _updateMessage(messageId, (m) => m.copyWith(status: MessageStatus.failed, text: text));

  /// 생성 중이던 답장을 취소하고 지운다 (생성 중 새 전송).
  Future<void> cancelPending() async {
    final chat = current;
    if (chat == null) return;
    final next =
        chat.messages.where((m) => m.status != MessageStatus.generating).toList();
    if (next.length == chat.messages.length) return;
    await _commit(chat.copyWith(messages: next));
  }

  Future<void> _updateMessage(String messageId, Message Function(Message) update) async {
    final chat = current;
    if (chat == null) return;
    final i = chat.messages.indexWhere((m) => m.id == messageId);
    if (i < 0) return;
    final next = [...chat.messages];
    next[i] = update(next[i]);
    await _commit(chat.copyWith(messages: next));
  }

  /// 메시지 하나의 모션을 교체한다 (썸네일이 나중에 붙을 때).
  Future<void> attachThumbnail(String messageId, String path) async {
    final chat = current;
    if (chat == null) return;
    final i = chat.messages.indexWhere((m) => m.id == messageId);
    if (i < 0 || chat.messages[i].spec == null) return;
    final next = [...chat.messages];
    next[i] = next[i].copyWith(spec: next[i].spec!.copyWith(thumbnailPath: path));
    await _commit(chat.copyWith(messages: next));
  }

  /// 다음 버전 번호 — 피드백 재생성마다 올라간다 (06-5).
  int nextVersion() => (lastReply?.spec?.version ?? 0) + 1;
}
