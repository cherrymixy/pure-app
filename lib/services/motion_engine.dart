import '../data/behaviors.dart';
import '../data/demo_recipes.dart';
import '../data/situations.dart';
import '../models/clip.dart';
import '../models/motion_signature.dart';
import '../models/recipe.dart';
import '../models/saved_motion.dart';

/// 시그니처가 번역된 재생 파라미터.
class PlaybackParams {
  const PlaybackParams({
    required this.speed,
    required this.amplitude,
    required this.idleBehavior,
    this.greetPrefix,
  });

  /// 재생 속도 배율. sim 의 playRecipe/setIdle 에 그대로 넘긴다.
  final double speed;

  /// 동작 크기 배율.
  final double amplitude;

  /// 아무것도 재생하지 않을 때 돌 동작.
  final String idleBehavior;

  /// 인사 앞에 한 번 끼워 넣을 동작. null 이면 없음 (관계 방식 반영).
  final String? greetPrefix;

  @override
  String toString() =>
      'PlaybackParams(speed: ${speed.toStringAsFixed(2)}, '
      'amplitude: ${amplitude.toStringAsFixed(2)}, idle: $idleBehavior, '
      'greetPrefix: $greetPrefix)';
}

/// 검증 결과. 고친 내용을 [reasons] 로 남긴다 — 조용히 바꾸지 않는다.
class ValidationResult<T> {
  const ValidationResult.ok(this.value, [this.reasons = const []]);
  const ValidationResult.failed(this.reasons) : value = null;

  final T? value;

  /// 무엇을 버리거나 잘랐는지. 비어 있으면 손대지 않았다는 뜻.
  final List<String> reasons;

  bool get ok => value != null;
  bool get changed => reasons.isNotEmpty;
}

/// 시그니처 번역 · GPT 출력 검증 · 데모 매칭 · 이름 제안.
///
/// 순수 함수 묶음이다. 시뮬레이터도, 저장소도, 네트워크도 모른다.
abstract final class MotionEngine {
  // ------------------------------------------------------------ 튜닝 상수
  //
  // PRD §6-9 초안값. STEP 11 뒤에 눈으로 보고 조정한다.

  /// lively 0→100 이 만드는 속도 범위.
  static const double speedAtLivelyMin = 0.7;
  static const double speedAtLivelyMax = 1.4;

  /// bold 0→100 이 만드는 진폭 범위.
  static const double amplitudeAtBoldMin = 0.6;
  static const double amplitudeAtBoldMax = 1.3;

  /// richness 0→100 이 진폭에 얹는 배율.
  static const double richnessFactorMin = 0.85;
  static const double richnessFactorMax = 1.15;

  /// 시그니처가 만들 수 있는 최대 진폭.
  ///
  /// 실측(`sim/tools/check-ranges.ts`)으로 정한 값이다. 15종을 리타겟·오버레이까지
  /// 포함해 1/120초로 샘플링해 robot.xml 관절 범위와 대조한 결과:
  ///
  ///   1.02  전부 범위 안
  ///   1.04  focus 가 head_tilt 를 0.4° 넘음
  ///   1.15  wake 가 shoulder_pitch 를 1.3° 넘음
  ///   1.30  wake 6.1°, focus 8.7°
  ///   1.35  여기서부터 happy 도 넘기 시작
  ///
  /// 여유가 거의 없어서(1.03배부터 넘는다) 클리핑을 완전히 피하려면 표현 범위를
  /// 버려야 한다. 넘치는 지점이 전부 **머무는 자세**(focus 는 3초 홀드, wake 는
  /// 기지개의 정점)라 끊김이 아니라 "더는 못 굽힌다"로 보이므로 받아들이고,
  /// 자주 쓰는 happy 가 깨끗하게 유지되는 1.30 을 상한으로 둔다.
  static const double maxSignatureAmplitude = 1.3;
  static const double minSignatureAmplitude = 0.5;

  /// 로봇에 실제로 닿는 최종 진폭의 상한.
  ///
  /// 시뮬레이터는 `playRecipe(recipe, {amplitude})` 의 배율과 각 단계의 amplitude 를
  /// **곱한다**. 시그니처 최대(1.3) × 단계 최대(1.5) = 1.95 가 되는데, 실측하면
  /// 15종 중 7종이 범위를 넘고 wake 는 26.6°, focus 는 29.6° 잘린다 — 그 정도면
  /// 눈에 보인다.
  ///
  /// 그래서 [applySignature] 로 **미리 곱해서 여기서 자르고**, 재생할 때는 배율을
  /// 넘기지 않는다. 곱이 두 번 일어날 여지를 구조에서 없앤다.
  static const double maxEffectiveAmplitude = maxSignatureAmplitude;

  /// 표현(A/B/중간)이 속도에 곱하는 배율.
  static const double expressionFactorQuick = 1.2;
  static const double expressionFactorSlow = 0.8;
  static const double expressionFactorBetween = 1.0;

  /// GPT 레시피 허용 범위 (PRD §6-3).
  static const double stepSpeedMin = 0.5;
  static const double stepSpeedMax = 1.6;
  static const double stepAmplitudeMin = 0.4;
  static const double stepAmplitudeMax = 1.5;
  static const int stepRepeatMin = 1;
  static const int stepRepeatMax = 4;
  static const int maxSteps = 6;

  /// 클립 허용 범위 (PRD §6-4).
  static const double clipDurationMin = 1.0;
  static const double clipDurationMax = 8.0;
  static const int clipMaxKeys = 24;

  /// 최대 각속도(도/초). 넘으면 시간을 늘려 보정한다.
  static const double maxDegreesPerSecond = 180;

  /// "A bit softer" 한 단계.
  static const double softenerSpeedFactor = 0.85;
  static const double softenerAmplitudeFactor = 0.85;

  // ------------------------------------------------------------ 시그니처 → 재생

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  static double _pct(int v) => (v.clamp(0, 100)) / 100.0;

  static double expressionFactor(Expression e) => switch (e) {
        Expression.quickBouncy => expressionFactorQuick,
        Expression.slowSmooth => expressionFactorSlow,
        Expression.inBetween => expressionFactorBetween,
      };

  /// 성격 → 대기 모션 (PRD §6-9).
  ///
  /// lively 와 bold 축에서 가장 가까운 성격을 고른다. data/signature_options.dart 가
  /// 화면용 라벨을 들고 있다면, 여기서는 재생용 동작만 고른다.
  static String idleBehaviorFor(MotionSignature s) {
    if (s.bold >= 70) return 'curious';
    if (s.lively >= 55) return 'look_around';
    return 'doze';
  }

  /// 관계 방식 → 인사 앞에 끼울 동작 (PRD §6-9).
  ///
  ///  - comesFirst  : 먼저 앞으로 기울어 다가온다
  ///  - waitsNear   : 바로 인사
  ///  - onlyNeeded  : 작은 끄덕임만
  static String? greetPrefixFor(Relationship r) => switch (r) {
        Relationship.comesFirst => 'focus',
        Relationship.waitsNear => null,
        Relationship.onlyNeeded => 'nod',
      };

  /// 시그니처를 재생 파라미터로 번역한다.
  static PlaybackParams signatureToParams(MotionSignature s) {
    final speed = _lerp(speedAtLivelyMin, speedAtLivelyMax, _pct(s.lively)) *
        expressionFactor(s.expression);

    final amplitude =
        _lerp(amplitudeAtBoldMin, amplitudeAtBoldMax, _pct(s.bold)) *
            _lerp(richnessFactorMin, richnessFactorMax, _pct(s.richness));

    return PlaybackParams(
      speed: speed.clamp(stepSpeedMin, stepSpeedMax),
      amplitude: amplitude.clamp(minSignatureAmplitude, maxSignatureAmplitude),
      idleBehavior: idleBehaviorFor(s),
      greetPrefix: greetPrefixFor(s.relationship),
    );
  }

  /// 시그니처를 레시피에 미리 반영한다.
  ///
  /// 결과 레시피는 그대로 `playRecipe(recipe)` 로 보내면 되고, 배율 파라미터는
  /// **넘기지 않는다**. 넘기면 시뮬레이터가 한 번 더 곱해 범위를 크게 넘긴다.
  static Recipe applySignature(Recipe recipe, PlaybackParams params) => Recipe(
        loop: recipe.loop,
        steps: [
          for (final s in recipe.steps)
            s.copyWith(
              speed: (s.speed * params.speed).clamp(stepSpeedMin, stepSpeedMax).toDouble(),
              amplitude: (s.amplitude * params.amplitude)
                  .clamp(stepAmplitudeMin, maxEffectiveAmplitude)
                  .toDouble(),
            ),
        ],
      );

  // ------------------------------------------------------------ 레시피 검증

  /// GPT 가 낸 레시피를 안전한 형태로 만든다.
  ///
  /// OpenAI 의 strict 스키마는 minimum/maximum/maxItems 를 지원하지 않는다. 범위를
  /// 지키게 하는 곳은 여기뿐이다 (CLAUDE.md 규칙 10).
  ///
  /// 잘못된 단계는 버리고, 범위 밖 값은 자른다. 남은 단계가 없으면 실패다.
  static ValidationResult<Recipe> validateRecipe(Recipe input) {
    final reasons = <String>[];
    final steps = <RecipeStep>[];

    for (var i = 0; i < input.steps.length; i++) {
      final s = input.steps[i];

      if (!isKnownBehavior(s.behavior)) {
        reasons.add('step $i: 알 수 없는 동작 "${s.behavior}" — 버림');
        continue;
      }

      if (steps.length >= maxSteps) {
        reasons.add('step $i 이후: 단계가 $maxSteps 개를 넘어 버림');
        break;
      }

      var face = s.face;
      if (face != null && !isKnownFace(face)) {
        reasons.add('step $i: 알 수 없는 표정 "$face" — 동작 기본값으로');
        face = null;
      }

      final speed = _clampNum(s.speed, stepSpeedMin, stepSpeedMax, 1.0);
      final amplitude = _clampNum(s.amplitude, stepAmplitudeMin, stepAmplitudeMax, 1.0);
      final repeat =
          _clampNum(s.repeat.toDouble(), stepRepeatMin.toDouble(), stepRepeatMax.toDouble(), 1)
              .round();

      if (speed != s.speed) {
        reasons.add('step $i: speed ${_fmt(s.speed)} → ${_fmt(speed)}');
      }
      if (amplitude != s.amplitude) {
        reasons.add('step $i: amplitude ${_fmt(s.amplitude)} → ${_fmt(amplitude)}');
      }
      if (repeat != s.repeat) {
        reasons.add('step $i: repeat ${s.repeat} → $repeat');
      }

      steps.add(RecipeStep(
        behavior: s.behavior,
        speed: speed,
        amplitude: amplitude,
        repeat: repeat,
        face: face,
      ));
    }

    if (steps.isEmpty) {
      return ValidationResult.failed([
        ...reasons,
        '쓸 수 있는 단계가 하나도 남지 않았습니다',
      ]);
    }
    return ValidationResult.ok(Recipe(steps: steps, loop: input.loop), reasons);
  }

  static double _clampNum(double v, double lo, double hi, double fallback) {
    if (v.isNaN || v.isInfinite) return fallback;
    return v.clamp(lo, hi).toDouble();
  }

  static String _fmt(num v) => v.toStringAsFixed(2);

  // ------------------------------------------------------------ 클립 검증

  /// GPT Tier 2 클립을 안전한 형태로 만든다.
  ///
  /// [jointRanges] 는 `SimReady.limits` 에서 온다 — robot.xml 에서 런타임에 읽은
  /// 값이라 Dart 쪽 상수 파일과 어긋날 일이 없다. 비어 있으면 범위 검사는 건너뛴다.
  ///
  /// 각속도가 최대치를 넘으면 **값을 깎지 않고 시간을 늘린다** — 궤적의 모양을
  /// 지키면서 느리게 만드는 쪽이, 포즈를 잘라 움직임을 뭉개는 것보다 낫다.
  static ValidationResult<Clip> validateClip(
    Clip input, {
    Map<String, (double, double)> jointRanges = const {},
  }) {
    final reasons = <String>[];

    if (input.format != Clip.formatV1) {
      return ValidationResult.failed(['지원하지 않는 clip format: ${input.format}']);
    }

    // 1) 관절 이름을 거른다. 모르는 이름은 조용히 0 으로 만들지 않고 버린다.
    final tracks = <String, List<ClipKey>>{};
    for (final entry in input.tracks.entries) {
      if (!isKnownJoint(entry.key)) {
        reasons.add('알 수 없는 관절 "${entry.key}" — 버림');
        continue;
      }
      tracks[entry.key] = [...entry.value];
    }
    if (tracks.isEmpty) {
      return ValidationResult.failed([...reasons, '쓸 수 있는 관절 트랙이 없습니다']);
    }

    var duration = _clampNum(input.duration, clipDurationMin, clipDurationMax, clipDurationMin);
    if (duration != input.duration) {
      reasons.add('duration ${_fmt(input.duration)}s → ${_fmt(duration)}s');
    }

    // 2) 키프레임을 정리한다 — 시각 정렬·클램프, 이징 검사, 값 범위 클램프.
    var droppedKeys = 0;
    var clampedValues = 0;
    for (final joint in tracks.keys.toList()) {
      final range = jointRanges[joint];
      final keys = <ClipKey>[];
      for (final k in tracks[joint]!) {
        if (k.t.isNaN || k.value.isNaN || k.t.isInfinite || k.value.isInfinite) {
          droppedKeys++;
          continue;
        }
        var easing = k.easing;
        if (!isKnownEasing(easing)) {
          reasons.add('알 수 없는 easing "$easing" — ease_in_out 으로');
          easing = 'ease_in_out';
        }
        var value = k.value;
        if (range != null) {
          final clamped = value.clamp(range.$1, range.$2).toDouble();
          if (clamped != value) {
            clampedValues++;
            value = clamped;
          }
        }
        keys.add(ClipKey(t: k.t.clamp(0.0, duration).toDouble(), value: value, easing: easing));
      }
      keys.sort((a, b) => a.t.compareTo(b.t));
      if (keys.isEmpty) {
        tracks.remove(joint);
        reasons.add('$joint: 쓸 수 있는 키가 없어 트랙을 버림');
      } else {
        tracks[joint] = keys;
      }
    }
    if (droppedKeys > 0) reasons.add('숫자가 아닌 키 $droppedKeys 개 버림');
    if (clampedValues > 0) reasons.add('관절 범위를 넘은 값 $clampedValues 개 클램프');

    if (tracks.isEmpty) {
      return ValidationResult.failed([...reasons, '쓸 수 있는 관절 트랙이 없습니다']);
    }

    // 3) 키 개수 상한. 넘으면 뒤쪽을 버린다 (앞쪽이 동작의 시작이라 더 중요하다).
    var total = tracks.values.fold<int>(0, (a, b) => a + b.length);
    if (total > clipMaxKeys) {
      reasons.add('키프레임 $total 개 → $clipMaxKeys 개로 줄임');
      final order = tracks.keys.toList();
      while (total > clipMaxKeys) {
        // 가장 긴 트랙에서 하나씩 덜어낸다.
        order.sort((a, b) => tracks[b]!.length.compareTo(tracks[a]!.length));
        final longest = tracks[order.first]!;
        if (longest.length <= 2) break;
        longest.removeLast();
        total--;
      }
    }

    // 4) 각속도. 넘는 구간이 있으면 전체 시간을 같은 비율로 늘린다.
    var scale = 1.0;
    for (final keys in tracks.values) {
      for (var i = 1; i < keys.length; i++) {
        final dt = keys[i].t - keys[i - 1].t;
        final dv = (keys[i].value - keys[i - 1].value).abs();
        if (dv <= 0) continue;
        final needed = dv / maxDegreesPerSecond;
        if (dt <= 0) {
          scale = scale > 1e9 ? scale : (needed / 1e-3);
        } else if (needed / dt > scale) {
          scale = needed / dt;
        }
      }
    }

    if (scale > 1.0) {
      final wanted = duration * scale;
      final applied = wanted.clamp(clipDurationMin, clipDurationMax).toDouble();
      final effective = applied / duration;
      reasons.add(
        '각속도 ${maxDegreesPerSecond.toInt()}°/s 초과 — 시간 ${_fmt(effective)}배로 늘림'
        '${wanted > clipDurationMax ? ' (최대 길이 ${clipDurationMax.toInt()}s 에 걸려 완전히 보정하지 못함)' : ''}',
      );
      for (final joint in tracks.keys) {
        tracks[joint] = [
          for (final k in tracks[joint]!)
            ClipKey(t: k.t * effective, value: k.value, easing: k.easing),
        ];
      }
      duration = applied;
    }

    var face = input.face;
    if (face != null && !isKnownFace(face)) {
      reasons.add('알 수 없는 표정 "$face" — 기본 표정으로');
      face = null;
    }

    return ValidationResult.ok(
      Clip(duration: duration, tracks: tracks, face: face),
      reasons,
    );
  }

  // ------------------------------------------------------------ Softener

  /// "A bit softer" / "Softer" — 속도와 크기를 한 단계 낮춘다 (05-4, 06-9 공용).
  static Recipe applySoftener(Recipe input) => Recipe(
        loop: input.loop,
        steps: [
          for (final s in input.steps)
            s.copyWith(
              speed: (s.speed * softenerSpeedFactor).clamp(stepSpeedMin, stepSpeedMax).toDouble(),
              amplitude: (s.amplitude * softenerAmplitudeFactor)
                  .clamp(stepAmplitudeMin, stepAmplitudeMax)
                  .toDouble(),
            ),
        ],
      );

  // ------------------------------------------------------------ 데모 매칭

  /// 오프라인·실패일 때 입력에 가장 가까운 데모 레시피를 고른다.
  ///
  /// 점수: 질문 트리 리프가 맞으면 압도적으로 우선, 칩이 맞으면 크게 가산,
  /// 그다음 키워드 일치. 아무것도 안 맞으면 [kDemoFallback] — 반드시 뭔가는 재생된다.
  static DemoRecipe demoMatch(
    String input, {
    String? chipId,
    String? whenOptionId,
    String? howOptionId,
    Situation? situation,
  }) {
    // 질문형에서 왔으면 리프가 가장 정확하다.
    if (howOptionId != null) {
      return demoRecipeForLeaf(
        chipId: chipId,
        whenOptionId: whenOptionId,
        howOptionId: howOptionId,
      );
    }

    final text = input.toLowerCase();
    DemoRecipe? best;
    var bestScore = 0.0;

    for (final d in kDemoRecipes) {
      var score = 0.0;
      if (chipId != null && d.chipId == chipId) score += 100;
      if (situation != null && d.chipId != null) {
        // 칩과 상황의 느슨한 연결 — 칩 id 가 상황 이름을 담고 있다.
        if (situation.name.toLowerCase().contains(d.chipId!.toLowerCase()) ||
            d.chipId!.toLowerCase().contains(situation.name.toLowerCase())) {
          score += 20;
        }
      }
      for (final k in d.keywords) {
        if (text.contains(k)) score += 1 + k.length / 10;
      }
      // 리프 레시피는 자유 입력에서 덜 선호한다 (칩 기본이 더 일반적이다).
      if (d.isLeaf) score *= 0.8;

      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }

    return best ?? kDemoFallback;
  }

  // ------------------------------------------------------------ 이름 제안

  /// 상황별 기본 이름.
  static const Map<Situation, String> _situationNames = {
    Situation.comesHome: 'Welcome home',
    Situation.tired: 'Gentle cheer-up',
    Situation.startled: 'Startled hop',
    Situation.onlyWhenAsked: 'New motion',
  };

  static const Set<String> _stopWords = {
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'am',
    'i', 'me', 'my', 'you', 'your', 'it', 'its', 'this', 'that',
    'so', 'very', 'just', 'really', 'and', 'or', 'but', 'to', 'of',
    'in', 'on', 'at', 'for', 'with', 'when', 'then', 'do', 'did', 'does',
    'has', 'have', 'had', 'can', 'will', 'would', 'should',
  };

  /// 저장 시트의 이름 자동 제안 (06-7). GPT 없이 규칙만으로.
  ///
  /// 상황이 있으면 사전 이름을, 없으면 마지막 사용자 문장에서 뜻 있는 단어 두세 개를
  /// 뽑아 쓴다. [taken] 을 주면 겹치지 않게 번호를 붙인다.
  static String suggestName({
    Situation? situation,
    String? lastUserText,
    Iterable<String> taken = const [],
    int maxLength = 20,
  }) {
    final base = _baseName(situation: situation, lastUserText: lastUserText);
    return _makeUnique(base, taken, maxLength);
  }

  static String _baseName({Situation? situation, String? lastUserText}) {
    if (situation != null && situation != Situation.onlyWhenAsked) {
      return _situationNames[situation]!;
    }

    final text = (lastUserText ?? '').trim();
    if (text.isNotEmpty) {
      final words = text
          .toLowerCase()
          .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty && !_stopWords.contains(w))
          .take(3)
          .toList();
      if (words.isNotEmpty) {
        final joined = words.join(' ');
        return joined[0].toUpperCase() + joined.substring(1);
      }
    }

    return _situationNames[Situation.onlyWhenAsked]!;
  }

  static String _makeUnique(String base, Iterable<String> taken, int maxLength) {
    final used = taken.map((e) => e.toLowerCase().trim()).toSet();
    var name = base.length > maxLength ? base.substring(0, maxLength).trim() : base;
    if (!used.contains(name.toLowerCase())) return name;

    for (var n = 2; n <= 99; n++) {
      final suffix = ' $n';
      final room = maxLength - suffix.length;
      final head = base.length > room ? base.substring(0, room).trim() : base;
      name = '$head$suffix';
      if (!used.contains(name.toLowerCase())) return name;
    }
    return name;
  }

  // ------------------------------------------------------------ 보조

  /// 레시피가 대략 몇 초짜리인지. 저장 시트·재생 바의 예상 시간에 쓴다.
  ///
  /// 정확한 길이는 sim 안의 키프레임 데이터가 정하므로 어림값이다. 루프 동작은
  /// repeat 만큼만 센다.
  static double estimateSeconds(Recipe recipe, {double speed = 1.0}) {
    const perCycle = 1.4; // 동작 한 사이클의 평균 (behaviors.ts 기준 어림)
    const leadIn = 0.8;
    var total = 0.0;
    for (final s in recipe.steps) {
      total += (leadIn + perCycle * s.repeat) / (s.speed * speed).clamp(0.1, 10);
    }
    return total;
  }

  /// 상황 라벨이 필요한 곳에서 쓰기 좋은 래퍼.
  static String labelFor(Situation s) => situationLabel(s);
}
