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

/// 라이브러리 목록의 한 줄 — 시안 07-1 의 문구를 그대로 둔다.
///
/// 앞글자만 소문자로 바꾸는 식으로 만들면 "When i say I'm tired" 처럼 대명사 I 가
/// 뭉개진다. 네 줄뿐이라 사전으로 둔다.
const Map<Situation, String> kWhenLabels = {
  Situation.comesHome: 'When someone comes home',
  Situation.tired: "When I say I'm tired",
  Situation.startled: 'When something startles me',
  Situation.onlyWhenAsked: 'Only when I ask',
};

String whenLabel(Situation s) => kWhenLabels[s] ?? situationLabel(s);

/// 라이브러리 카드·상세의 "Plays automatically when …" 문구.
String playsAutomaticallyWhen(Situation s) =>
    isAutoSituation(s) ? 'Plays automatically when ${_lower(situationLabel(s))}' : 'Only when I ask';

/// 카드·상세에 보여 줄 한 줄.
///
/// 종류가 셋인데 둘로만 표시하면 **밀려난 모션이 수동 모션처럼 보인다** —
/// 같은 상황에 새 모션을 저장하면 기존 것은 지워지지 않고 askFirst 로 내려가는데,
/// 그 상태가 "Only when I ask" 로 나오면 사용자는 상황 연결이 끊긴 줄 안다.
String reactionLabel(ReactionKind kind, Situation? situation) => switch (kind) {
      ReactionKind.auto when situation != null => situationLabel(situation),
      ReactionKind.auto => '',
      ReactionKind.askFirst when situation != null =>
        'Asks before playing · ${_lower(situationLabel(situation))}',
      ReactionKind.askFirst => 'Asks before playing',
      ReactionKind.manual => 'Only when I ask',
    };

/// 상세 화면의 긴 문구.
String reactionDetail(ReactionKind kind, Situation? situation) => switch (kind) {
      ReactionKind.auto when situation != null => playsAutomaticallyWhen(situation),
      ReactionKind.askFirst when situation != null =>
        'Asks before playing when ${_lower(situationLabel(situation))}',
      ReactionKind.manual || _ => 'Only when I ask',
    };

String _lower(String label) =>
    label.isEmpty ? label : label[0].toLowerCase() + label.substring(1);
