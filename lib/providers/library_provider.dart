import 'package:flutter/foundation.dart';

import '../models/motion_spec.dart';
import '../models/saved_motion.dart';
import '../repositories/data_repository.dart';
import '../services/thumbnail_store.dart';

/// 07 라이브러리 필터.
enum LibraryFilter { all, auto, manual }

/// 저장 결과 — 화면이 토스트·경고를 고르는 데 쓴다.
sealed class SaveOutcome {
  const SaveOutcome();
}

class SaveSucceeded extends SaveOutcome {
  const SaveSucceeded(this.motion, {this.demoted});

  final SavedMotion motion;

  /// 같은 상황에 있던 기존 모션. askFirst 로 내려갔다.
  final SavedMotion? demoted;
}

class SaveRejected extends SaveOutcome {
  const SaveRejected(this.reason);
  final SaveRejectReason reason;
}

enum SaveRejectReason { nameEmpty, nameTooLong, nameTaken }

/// 라이브러리 — 저장·이름변경·삭제·검색·필터.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._repo, {this.thumbnails, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DataRepository _repo;
  final ThumbnailStore? thumbnails;

  /// 테스트에서 시계를 주입한다.
  final DateTime Function() _now;

  static const int nameMin = 1;
  static const int nameMax = 20;

  // ---------------------------------------------------------------- 조회

  List<SavedMotion> get all => _repo.library;

  LibraryFilter get filter {
    final raw = _repo.setting<String>(SettingKeys.libraryFilter);
    return LibraryFilter.values.firstWhere(
      (f) => f.name == raw,
      orElse: () => LibraryFilter.all,
    );
  }

  Future<void> setFilter(LibraryFilter f) async {
    await _repo.saveSetting(SettingKeys.libraryFilter, f.name);
    notifyListeners();
  }

  /// 현재 필터를 적용한 목록.
  List<SavedMotion> get visible => switch (filter) {
        LibraryFilter.all => all,
        LibraryFilter.auto => all.where((m) => m.kind == ReactionKind.auto).toList(),
        LibraryFilter.manual => all.where((m) => m.kind != ReactionKind.auto).toList(),
      };

  /// "Plays automatically" 그룹 (07-1).
  List<SavedMotion> get autoGroup =>
      visible.where((m) => m.kind == ReactionKind.auto).toList();

  List<SavedMotion> get others => visible.where((m) => m.kind != ReactionKind.auto).toList();

  SavedMotion? byId(String id) => _repo.savedMotionById(id);

  bool get isEmpty => all.isEmpty;

  /// 07-3 검색 — 이름과 상황 문구에서 찾는다.
  List<SavedMotion> search(String query, {String Function(Situation)? situationLabel}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return visible;
    return visible.where((m) {
      if (m.name.toLowerCase().contains(q)) return true;
      final s = m.situation;
      if (s != null && situationLabel != null) {
        return situationLabel(s).toLowerCase().contains(q);
      }
      return false;
    }).toList();
  }

  // ---------------------------------------------------------------- 이름 검사

  SaveRejectReason? _checkName(String name, {String? ignoreId}) {
    final t = name.trim();
    if (t.length < nameMin) return SaveRejectReason.nameEmpty;
    if (t.length > nameMax) return SaveRejectReason.nameTooLong;
    final taken = all.any(
      (m) => m.id != ignoreId && m.name.toLowerCase() == t.toLowerCase(),
    );
    return taken ? SaveRejectReason.nameTaken : null;
  }

  bool isNameAvailable(String name, {String? ignoreId}) =>
      _checkName(name, ignoreId: ignoreId) == null;

  /// 같은 상황에 이미 자동 재생 모션이 있는가 (저장 시트의 노란 경고).
  SavedMotion? conflictFor(Situation? situation, {String? ignoreId}) {
    if (situation == null || situation == Situation.onlyWhenAsked) return null;
    final existing = _repo.autoMotionFor(situation);
    if (existing == null || existing.id == ignoreId) return null;
    return existing;
  }

  // ---------------------------------------------------------------- 저장

  /// 새 모션을 저장한다 (06-7).
  ///
  /// 같은 상황에 자동 재생 모션이 있으면 **기존 것을 askFirst 로 내리고** 새 것이
  /// auto 가 된다 (부록 D 결정). 기존 모션은 지워지지 않는다.
  Future<SaveOutcome> save({
    required String id,
    required String name,
    required MotionSpec spec,
    required String chatId,
    Situation? situation,
    ReactionKind? kind,
  }) async {
    final reason = _checkName(name);
    if (reason != null) return SaveRejected(reason);

    final resolvedKind = kind ??
        (situation == null || situation == Situation.onlyWhenAsked
            ? ReactionKind.manual
            : ReactionKind.auto);

    SavedMotion? demoted;
    if (resolvedKind == ReactionKind.auto) {
      final existing = conflictFor(situation);
      if (existing != null) {
        demoted = existing.copyWith(kind: ReactionKind.askFirst);
        await _repo.upsertSavedMotion(demoted);
      }
    }

    final motion = SavedMotion(
      id: id,
      name: name.trim(),
      spec: spec,
      kind: resolvedKind,
      situation: resolvedKind == ReactionKind.manual ? Situation.onlyWhenAsked : situation,
      savedAt: _now(),
      chatId: chatId,
    );
    await _repo.upsertSavedMotion(motion);
    notifyListeners();
    return SaveSucceeded(motion, demoted: demoted);
  }

  /// Edit in chat 후 다시 저장 — 같은 모션을 새 버전으로 덮어쓴다 (editCount+1).
  Future<SaveOutcome> saveEdited(String id, MotionSpec spec) async {
    final existing = byId(id);
    if (existing == null) return const SaveRejected(SaveRejectReason.nameEmpty);
    final old = existing.spec.thumbnailPath;
    final next = existing.copyWith(spec: spec, editCount: existing.editCount + 1);
    await _repo.upsertSavedMotion(next);
    if (old != null && old != spec.thumbnailPath) {
      await thumbnails?.delete(old);
    }
    notifyListeners();
    return SaveSucceeded(next);
  }

  Future<SaveOutcome> rename(String id, String name) async {
    final existing = byId(id);
    if (existing == null) return const SaveRejected(SaveRejectReason.nameEmpty);
    final reason = _checkName(name, ignoreId: id);
    if (reason != null) return SaveRejected(reason);
    final next = existing.copyWith(name: name.trim());
    await _repo.upsertSavedMotion(next);
    notifyListeners();
    return SaveSucceeded(next);
  }

  Future<void> delete(String id) async {
    final existing = byId(id);
    await _repo.deleteSavedMotion(id);
    await thumbnails?.delete(existing?.spec.thumbnailPath);
    notifyListeners();
  }
}
