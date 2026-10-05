# 결정 로그 (decisions.md)

> STEP 하나 끝날 때마다 한 줄. 형식: `YYYY-MM-DD · STEP n · 결정/결과`

| 날짜 | STEP | 결정 · 결과 |
|---|---|---|
| 2026-10-06 | 0 | 시작 전 세팅 완료. 폴더 구조 플레이북대로 정리(CLAUDE.md 루트, `_ref/pure-web`), git init(main), .gitignore에 `_ref/` 제외. Figma MCP 연결 확인(whoami OK, 파일 `xp0RmyE9WwsNFAF5kE88OX` 3개 페이지 접근 가능). iOS 시뮬레이터 iPhone 17 Pro / iOS 26.2 부팅. Flutter 3.44.2 · Dart 3.12.2 · Xcode 26.2 · CocoaPods 1.16.2 · Node 25.9.0. |
| 2026-10-06 | 0 | 전시 기기 확정: iPhone 14 Pro(393×852pt), 개발자 모드 ON, 무료 서명 사용(7일 만료 → 전시 전날 재설치). OpenAI 키 확보 완료(STEP 7에서 사용). 시뮬레이터도 14 Pro로 교체. |
| 2026-10-06 | 0 | 부록 D 13개 항목 전부 추천대로 승인. 신규 6건 포함: Clip 모양은 부록 B(관절별 트랙) 채택 / reasoning 영어 / Figma 402 vs 기기 393은 비율 번역 / stop()은 setIdle 전환 / joint_ranges.dart 폐기. |
| 2026-10-06 | 0 | 부록 B 계약 수정 3건 승인: (가) Clip 어댑터 + loop 기본값 명시 (나) setFace 유효 이름을 faces.json 값에서 도출 (다) ready 이벤트에 limits 실어 관절 범위를 런타임 전달. |
| 2026-10-06 | 0 | 범위 초과 포즈 4개(STRETCH +36° / SLEEP −12° / DROOP_DEEP −9° / DROOP −1°, 모두 head_tilt) → 옵션 (b) 채택. STEP 2에서 범위 안으로 리스케일. 사유: 현재는 한계에서 클램프되어 동작이 멈칫함. 영향 동작 wake·sleep·doze, 특히 doze는 Calm 성격의 대기 모션. |
| 2026-10-06 | 0 | 영상 프레임 추출: `video_thumbnail` → **`fc_native_video_thumbnail` ^3.0.1** 교체. 사유: 임의 타임스탬프 정확 추출을 실측 검증(단일 키프레임 8초 영상에서 8/8 정확, 246ms, 512px 긴 변 맞춤·회전 보정 자동). 기존 패키지는 SwiftPM 미지원으로 Flutter가 향후 에러 예고, 열린 이슈 65건. 비용: 최소 iOS 13 → **14.0**(전시 기기 14 Pro라 영향 없음). |
| 2026-10-06 | 0 | 음성 인식: `speech_to_text ^7.5.0` 유지하되 **`onDevice: true`를 쓰지 않는다**. 사유: iOS에서 미지원 기기일 때 에러 후에도 마이크가 살아남아 프로세스 수명 내내 재시작 불가(issue #673). 수정본은 7.6.0-beta.4에만 존재. 정식 출시 후 재검토. PRD §9 "기기 내 인식 우선"을 이 건에 한해 보류. |
| 2026-10-06 | 0 | Info.plist는 권한 4개(Camera/PhotoLibrary/Microphone/SpeechRecognition)만. **`NSAppTransportSecurity`/`NSAllowsLocalNetworking`은 넣지 않는다** — 무설정 상태로 WebView의 http://localhost:8080 로드 성공을 실측 확인. 플레이북 STEP 1 프롬프트에서 해당 줄 제외. |
