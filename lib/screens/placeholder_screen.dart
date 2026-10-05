import 'package:flutter/material.dart';

import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';

/// 아직 안 만든 화면 자리. 슬라이스가 진행되면서 하나씩 사라진다.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.slice});

  final String title;

  /// 어느 슬라이스에서 채워지는지.
  final String slice;

  @override
  Widget build(BuildContext context) => AppShell(
        title: title,
        onBack: Navigator.canPop(context) ? () => Navigator.pop(context) : null,
        child: GrayEmptyState(
          title: title,
          body: '$slice 에서 만듭니다.',
        ),
      );
}
