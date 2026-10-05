#!/usr/bin/env bash
#
# sim/ 을 빌드해 Flutter 에셋으로 옮긴다.
#
#   ./scripts/build_sim.sh
#
# 산출물은 assets/sim/ 에 들어가고 git 에는 올라가지 않는다(.gitignore).
# Flutter 는 InAppLocalhostServer 로 이걸 http://localhost:8080/assets/sim/ 에 서빙한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/sim"

if [ ! -d node_modules ]; then
  echo "▸ sim 의존성 설치"
  npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund
fi

echo "▸ 타입 검사"
npm run --silent typecheck

echo "▸ 빌드"
npm run --silent build

DEST="$ROOT/assets/sim"
echo "▸ $DEST 로 복사"
# .gitkeep 은 남긴다 — pubspec 의 assets 선언이 빈 폴더에서도 깨지지 않게.
rsync -a --delete --exclude '.gitkeep' "$ROOT/sim/dist/" "$DEST/"
touch "$DEST/.gitkeep"

# Flutter 의 폴더 에셋 선언은 하위 폴더를 포함하지 않는다. 하나라도 빠지면 로컬 서버가
# 200 에 0바이트를 돌려주고 시뮬레이터는 로딩 화면에서 멈춘다 — 에러 하나 없이.
echo "▸ pubspec 에셋 선언 검사"
MISSING=""
while IFS= read -r dir; do
  REL="${dir#"$ROOT/"}/"
  grep -qF -- "- $REL" "$ROOT/pubspec.yaml" || MISSING="$MISSING    - $REL"$'\n'
done < <(find "$DEST" -type d)

if [ -n "$MISSING" ]; then
  echo "✗ pubspec.yaml 의 flutter.assets 에 아래 줄이 빠졌습니다:" >&2
  printf '%s' "$MISSING" >&2
  echo "  (빠지면 서버가 200/0바이트를 돌려주고 앱이 로딩에서 멈춥니다)" >&2
  exit 1
fi

echo "▸ 완료"
du -sh "$DEST"
find "$DEST" -maxdepth 1 -mindepth 1 | sort | sed 's|^|    |'
