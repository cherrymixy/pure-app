import '../models/saved_motion.dart';

/// 반응 상황 4종의 영어 라벨 (PRD §5).
///
/// 저장 시트(06-7)의 라디오, 라이브러리 Auto 그룹 머리말, 상세 화면 문구가
/// 전부 여기서 나온다.
const Map<Situation, String> kSituationLabels = {
  Situation.comesHome: 'Someone comes home',
  Situation.tired: "I say I'm tired",
  Situation.startled: 'Something startles me',
  Situation.onlyWhenAsked: 'Only when I ask',
};

/// 저장 시트에 보여줄 순서. onlyWhenAsked 가 마지막 — 자동 재생이 아니다.
const List<Situation> kSituationOrder = [
  Situation.comesHome,
  Situation.tired,
  Situation.startled,
  Situation.onlyWhenAsked,
];

/// 자동 재생 대상인가. onlyWhenAsked 만 아니다.
bool isAutoSituation(Situation s) => s != Situation.onlyWhenAsked;

String situationLabel(Situation s) => kSituationLabels[s] ?? '';

/// 라이브러리 카드·상세의 "Plays automatically when …" 문구.
String playsAutomaticallyWhen(Situation s) =>
    isAutoSituation(s) ? 'Plays automatically when ${_lower(situationLabel(s))}' : 'Only when I ask';

String _lower(String label) =>
    label.isEmpty ? label : label[0].toLowerCase() + label.substring(1);
