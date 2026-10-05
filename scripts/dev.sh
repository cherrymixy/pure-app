#!/usr/bin/env bash
#
# 개발 빌드/실행 — 키를 .env.local 에서 읽어 --dart-define 으로 넘긴다.
#
#   ./scripts/dev.sh run          시뮬레이터에 띄우고 핫리로드 (기본)
#   ./scripts/dev.sh install      빌드해서 설치만 (핫리로드 없음)
#   ./scripts/dev.sh sample       OpenAI 샘플 수집 (docs/samples/generation.md)
#   ./scripts/dev.sh selftest     브리지 자체검사 빌드
#
# .env.local 은 git 에 올라가지 않는다(.gitignore 의 .env.*). 키를 명령줄에 치지 않으므로
# 터미널 기록·스크린샷·로그 어디에도 남지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="$ROOT/.env.local"
DEFINES=()

if [ -f "$ENV_FILE" ]; then
  while IFS='=' read -r key value; do
    # 주석과 빈 줄은 건너뛴다.
    [[ -z "$key" || "$key" == \#* ]] && continue
    # 앞뒤 공백과 따옴표를 떼어낸다.
    key="$(echo "$key" | xargs)"
    value="${value%\"}"; value="${value#\"}"
    value="${value%\'}"; value="${value#\'}"
    [ -z "$value" ] && continue
    DEFINES+=("--dart-define=$key=$value")
  done < "$ENV_FILE"
fi

if [ ${#DEFINES[@]} -eq 0 ]; then
  echo "▸ .env.local 이 없거나 비어 있습니다 — 키 없이(데모 모드로) 진행합니다."
  echo "  키를 쓰려면:  echo 'OPENAI_API_KEY=sk-...' > .env.local"
else
  # 값은 절대 출력하지 않는다. 어떤 키가 들어갔는지만 보여준다.
  NAMES=$(printf '%s\n' "${DEFINES[@]}" | sed 's/--dart-define=\([^=]*\)=.*/\1/' | paste -sd' ' -)
  echo "▸ .env.local 에서 읽음: $NAMES"
fi

CMD="${1:-run}"
shift || true

case "$CMD" in
  run)
    exec flutter run "${DEFINES[@]+"${DEFINES[@]}"}" "$@"
    ;;
  install|selftest)
    EXTRA=()
    [ "$CMD" = "selftest" ] && EXTRA+=("--dart-define=SIM_SELFTEST=true")
    flutter build ios --debug --simulator \
      "${DEFINES[@]+"${DEFINES[@]}"}" "${EXTRA[@]+"${EXTRA[@]}"}" "$@"
    UDID="$(xcrun simctl list devices booted | grep -oE '[0-9A-F-]{36}' | head -1)"
    if [ -z "$UDID" ]; then
      echo "✗ 부팅된 시뮬레이터가 없습니다." >&2
      exit 1
    fi
    xcrun simctl terminate "$UDID" app.purebot.pure >/dev/null 2>&1 || true
    xcrun simctl install "$UDID" build/ios/iphonesimulator/Runner.app
    xcrun simctl launch "$UDID" app.purebot.pure >/dev/null
    echo "▸ 설치·실행 완료"
    ;;
  sample)
    DART_DEFINES=()
    for d in "${DEFINES[@]+"${DEFINES[@]}"}"; do
      DART_DEFINES+=("--define=${d#--dart-define=}")
    done
    exec dart run "${DART_DEFINES[@]+"${DART_DEFINES[@]}"}" scripts/sample_generation.dart
    ;;
  *)
    echo "모르는 명령: $CMD (run | install | selftest | sample)" >&2
    exit 1
    ;;
esac
