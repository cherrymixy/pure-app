# .env.local 에서 키를 읽어 DEFINES 배열에 --dart-define 꼴로 담는다.
#
# dev.sh 와 install_device.sh 가 함께 쓴다. 값은 **절대 출력하지 않는다** —
# 터미널 기록·스크린샷·로그 어디에도 키가 남으면 안 된다 (CLAUDE.md 규칙 12).
#
# source 로 불러 쓴다. ROOT 가 먼저 정해져 있어야 한다.

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
  # 어떤 키가 들어갔는지 이름만 보여준다.
  NAMES=$(printf '%s\n' "${DEFINES[@]}" | sed 's/--dart-define=\([^=]*\)=.*/\1/' | paste -sd' ' -)
  echo "▸ .env.local 에서 읽음: $NAMES"
fi
