/// 홈 화면 상황 칩 (06-1).
class HomeChip {
  const HomeChip({required this.id, required this.label});

  final String id;

  /// 탭하면 입력창에 그대로 채워지는 문장.
  final String label;
}

/// 칩 5개 (PRD §5). 순서가 곧 화면 순서다.
const List<HomeChip> kHomeChips = [
  HomeChip(id: 'cameHome', label: 'Someone came home'),
  HomeChip(id: 'tired', label: "I'm so tired…"),
  HomeChip(id: 'thankYou', label: 'Thank you'),
  HomeChip(id: 'startled', label: 'That startled me!'),
  HomeChip(id: 'whatIsThis', label: 'What is this?'),
];

HomeChip? chipById(String id) {
  for (final c in kHomeChips) {
    if (c.id == id) return c;
  }
  return null;
}
