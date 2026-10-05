// 실제 OpenAI 를 한 번 불러 응답 원문을 docs/samples/ 에 남긴다.
//
//   dart run scripts/sample_generation.dart --dart-define=OPENAI_API_KEY=sk-...
//
// 프롬프트를 튜닝할 때 이 원문을 보고 판단한다. 키는 인자로만 들어오고 파일에 남지 않는다.
import 'dart:convert';
import 'dart:io';

import 'package:pure_app/config/env.dart';
import 'package:pure_app/data/chips.dart';
import 'package:pure_app/models/motion_signature.dart';
import 'package:pure_app/services/generation/generation_client.dart';
import 'package:pure_app/services/generation/openai_client.dart';

Future<void> main() async {
  if (!Env.hasApiKey) {
    stderr.writeln('OPENAI_API_KEY 가 없습니다. --dart-define 으로 넘기세요.');
    exit(1);
  }

  final client = OpenAIClient();
  final out = StringBuffer()
    ..writeln('# 생성 샘플')
    ..writeln()
    ..writeln('모델: `${Env.model}` · 시그니처: 시드(Lively / Waits till I\'m near / Quick & bouncy)')
    ..writeln();

  for (final chip in kHomeChips) {
    stdout.writeln('▸ ${chip.label}');
    try {
      final r = await client.generate(GenerationRequest(
        signature: MotionSignature.seed,
        text: chip.label,
        chipId: chip.id,
      ));
      final steps = r.spec.recipe.steps
          .map((s) => '${s.behavior} ×${s.repeat} '
              '(speed ${s.speed.toStringAsFixed(2)}, amp ${s.amplitude.toStringAsFixed(2)}'
              '${s.face == null ? '' : ', face ${s.face}'})')
          .join(' → ');
      out
        ..writeln('## ${chip.label}')
        ..writeln()
        ..writeln('- **name**: ${r.spec.name}')
        ..writeln('- **face**: ${r.spec.face}')
        ..writeln('- **steps**: $steps')
        ..writeln('- **reasoning**: ${r.spec.reasoning}')
        ..writeln()
        ..writeln('<details><summary>원문</summary>')
        ..writeln()
        ..writeln('```json')
        ..writeln(const JsonEncoder.withIndent('  ')
            .convert(jsonDecode(r.raw)))
        ..writeln('```')
        ..writeln()
        ..writeln('</details>')
        ..writeln();
    } catch (e) {
      stdout.writeln('  실패: $e');
      out..writeln('## ${chip.label}')..writeln()..writeln('실패: $e')..writeln();
    }
  }

  final file = File('docs/samples/generation.md');
  await file.create(recursive: true);
  await file.writeAsString(out.toString());
  stdout.writeln('\n→ ${file.path} 에 저장했습니다.');
  client.dispose();
  exit(0);
}
