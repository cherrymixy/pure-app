#!/usr/bin/env bash
#
# 전시용 — 아이폰에 릴리스 빌드를 설치한다.
#
#   ./scripts/install_device.sh            연결된 아이폰 하나에 설치
#   ./scripts/install_device.sh <device-id> 기기를 지정해서 설치
#
# 키는 .env.local 에서 읽는다 (scripts/_env.sh). 명령줄에 키를 치지 않는다.
#
# ⚠ 무료 Apple ID 로 서명하면 프로비저닝 프로파일이 **7일**짜리다. 기간이 지나면
#   앱이 기기에서 아예 안 켜진다. **전시 전날 이 스크립트를 한 번 더 돌릴 것.**
#   처음 설치한 뒤에는 기기에서 한 번
#   설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 → 신뢰 를 눌러야 실행된다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/_env.sh
source "$ROOT/scripts/_env.sh"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  # 시뮬레이터·맥·웹을 뺀 진짜 기기만 고른다.
  DEVICE="$(flutter devices --machine 2>/dev/null \
    | python3 -c 'import json,sys; d=[x for x in json.load(sys.stdin) if x.get("targetPlatform","").startswith("ios") and not x.get("emulator")]; print(d[0]["id"] if len(d)==1 else "")')"
fi

if [ -z "$DEVICE" ]; then
  echo "✗ 아이폰을 찾지 못했습니다 (또는 둘 이상 연결돼 있습니다)." >&2
  echo "  flutter devices 로 id 를 확인하고 인자로 넘기세요." >&2
  exit 1
fi

echo "▸ 기기: $DEVICE"
echo "▸ 릴리스 빌드…"
flutter build ios --release "${DEFINES[@]+"${DEFINES[@]}"}"

echo "▸ 설치…"
flutter install -d "$DEVICE" --release

cat <<'TIP'

▸ 설치 완료.

  처음이면 기기에서 한 번:
    설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 → 신뢰

  전시 전 점검:
    - 자동 잠금 끄기 / 저전력 모드 끄기(WebGL 느려짐) / 밝기 고정 / 방해금지
    - 손쉬운 사용 → 가이드 접근으로 앱 고정
    - 비행기 모드로 한 번(데모 모드), 와이파이로 한 번(생성) 리허설
TIP
