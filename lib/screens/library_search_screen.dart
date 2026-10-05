import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../data/situations.dart';
import '../data/strings.dart';
import '../providers/library_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/gray_box.dart';
import 'library_screen.dart';

/// 07-3 검색 — 즉시 포커스, 이름·상황 검색, 일치 글자 강조.
class LibrarySearchScreen extends StatefulWidget {
  const LibrarySearchScreen({super.key});

  @override
  State<LibrarySearchScreen> createState() => _LibrarySearchScreenState();
}

class _LibrarySearchScreenState extends State<LibrarySearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final q = _query.text.trim();
    final results = library.search(q, situationLabel: situationLabel);

    return AppShell(
      onBack: () => Navigator.pop(context),
      title: null,
      showRobotStatus: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: S.librarySearchHint,
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Gray.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Gray.line),
                ),
              ),
            ),
          ),
          if (q.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  fill(S.librarySearchResults, {'count': results.length}),
                  style: const TextStyle(fontSize: 12, color: Gray.dim),
                ),
              ),
            ),
          Expanded(
            child: q.isNotEmpty && results.isEmpty
                ? GrayEmptyState(
                    title: S.emptySearchTitle,
                    body: S.emptySearchBody,
                    actionLabel: S.emptySearchAction,
                    // 검색어를 들고 홈으로 간다.
                    onAction: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                  )
                : ListView(
                    children: [
                      for (final m in results)
                        MotionCard(
                          motion: m,
                          playing: false,
                          onPlay: () => Navigator.pushNamed(
                            context,
                            AppRoutes.motionDetail,
                            arguments: m.id,
                          ),
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.motionDetail,
                            arguments: m.id,
                          ),
                          nameSpan: _highlight(m.name, q),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 일치하는 글자를 파랗게.
  InlineSpan? _highlight(String name, String query) {
    if (query.isEmpty) return null;
    final lower = name.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (i < name.length) {
      final found = lower.indexOf(q, i);
      if (found < 0) {
        spans.add(TextSpan(text: name.substring(i)));
        break;
      }
      if (found > i) spans.add(TextSpan(text: name.substring(i, found)));
      spans.add(TextSpan(
        text: name.substring(found, found + q.length),
        style: const TextStyle(color: Gray.accent),
      ));
      i = found + q.length;
    }
    return TextSpan(children: spans);
  }
}
