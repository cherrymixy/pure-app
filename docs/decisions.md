# 결정 로그 (decisions.md)

> STEP 하나 끝날 때마다 한 줄. 형식: `YYYY-MM-DD · STEP n · 결정/결과`

| 날짜 | STEP | 결정 · 결과 |
|---|---|---|
| 2026-10-06 | 0 | 시작 전 세팅 완료. 폴더 구조 플레이북대로 정리(CLAUDE.md 루트, `_ref/pure-web`), git init(main), .gitignore에 `_ref/` 제외. Figma MCP 연결 확인(whoami OK, 파일 `xp0RmyE9WwsNFAF5kE88OX` 3개 페이지 접근 가능). iOS 시뮬레이터 iPhone 17 Pro / iOS 26.2 부팅. Flutter 3.44.2 · Dart 3.12.2 · Xcode 26.2 · CocoaPods 1.16.2 · Node 25.9.0. |
| 2026-10-06 | 0 | 전시 기기 확정: iPhone 14 Pro(393×852pt), 개발자 모드 ON, 무료 서명 사용(7일 만료 → 전시 전날 재설치). OpenAI 키 확보 완료(STEP 7에서 사용). 시뮬레이터도 14 Pro로 교체. |
| 2026-10-06 | 0 | 부록 D 13개 항목 전부 추천대로 승인. 신규 6건 포함: Clip 모양은 부록 B(관절별 트랙) 채택 / reasoning 영어 / Figma 402 vs 기기 393은 비율 번역 / stop()은 setIdle 전환 / joint_ranges.dart 폐기. |
| 2026-10-06 | 0 | 부록 B 계약 수정 3건 승인: (가) Clip 어댑터 + loop 기본값 명시 (나) setFace 유효 이름을 faces.json 값에서 도출 (다) ready 이벤트에 limits 실어 관절 범위를 런타임 전달. |
| 2026-10-06 | 0 | 범위 초과 포즈 4개(STRETCH +36° / SLEEP −12° / DROOP_DEEP −9° / DROOP −1°, 모두 head_tilt) → 옵션 (b) 채택. STEP 2에서 범위 안으로 리스케일. 사유: 현재는 한계에서 클램프되어 동작이 멈칫함. 영향 동작 wake·sleep·doze, 특히 doze는 Calm 성격의 대기 모션. |
