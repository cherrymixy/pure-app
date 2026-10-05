# 디자인 토큰

Figma 파일 `xp0RmyE9WwsNFAF5kE88OX` → **Design System** 페이지(`70:1520`)에서 읽어 옮긴 값.
추측한 값은 없다. 바뀌면 Figma를 다시 읽어 이 문서와 `lib/theme/`을 함께 고친다.

| Figma 노드 | 파일 |
|---|---|
| `F / Color` `458:4287` | `lib/theme/app_colors.dart` |
| `F / Typography` `458:4812` | `lib/theme/app_text_styles.dart` |
| `F / Spacing & Radius` `458:4878` | `lib/theme/app_spacing.dart` |
| `F / Effect` `458:4947` | `lib/theme/app_effects.dart` |
| — | `lib/theme/app_theme.dart` (ThemeData 조립) |

---

## 색

브랜드는 **세이지(회청록)** `#789ba2`다. 파랑은 "재생 중" 표시 한 군데에만 쓴다.

> PRD §11에는 "홈 배경의 블루 라디얼 글로우, 블루 원형 마이크"로 적혀 있으나,
> Figma의 `bg/brand-glow`는 `sage/200 #a9c2c7`이다. 화면 SSOT는 Figma이므로 세이지를 따른다.

### Primitives

| Figma | Dart | 값 |
|---|---|---|
| `neutral/0` | `AppColors.neutral0` | `#FFFFFF` |
| `neutral/50` | `neutral50` | `#F6F7F7` |
| `neutral/100` | `neutral100` | `#F2F2F2` |
| `neutral/150` | `neutral150` | `#E9EDED` |
| `neutral/200` | `neutral200` | `#D8DCDD` |
| `neutral/300` | `neutral300` | `#C3CBCC` |
| `neutral/400` | `neutral400` | `#A0ABAD` |
| `neutral/500` | `neutral500` | `#8A9698` |
| `neutral/600` | `neutral600` | `#5F6B6D` |
| `neutral/700` | `neutral700` | `#3D4A4D` |
| `neutral/800` | `neutral800` | `#2C3335` |
| `neutral/850` | `neutral850` | `#232829` |
| `neutral/900` | `neutral900` | `#1A1E1F` |
| `neutral/950` | `neutral950` | `#0F1213` |
| `neutral/1000` | `neutral1000` | `#000000` |
| `sage/50` | `sage50` | `#E8F0F1` |
| `sage/100` | `sage100` | `#D3E2E4` |
| `sage/200` | `sage200` | `#A9C2C7` |
| `sage/300` | `sage300` | `#8FB3B9` |
| `sage/400` | `sage400` | `#789BA2` |
| `sage/500` | `sage500` | `#5F8189` |
| `sage/600` | `sage600` | `#4A666C` |
| `sage/700` | `sage700` | `#33474B` |
| `sage/800` | `sage800` | `#1E2A2C` |
| `sage/900` | `sage900` | `#142023` |
| `red/50` | `red50` | `#FDECEC` |
| `red/400` | `red400` | `#FF6B6E` |
| `red/500` | `red500` | `#E5484D` |
| `red/900` | `red900` | `#3A1517` |
| `blue/300` | `blue300` | `#7FA8FA` |
| `blue/500` | `blue500` | `#3B79F6` |
| `green/400` | `green400` | `#4CC38A` |
| `green/500` | `green500` | `#2FA36B` |
| `alpha/black-06` | `alphaBlack06` | `#0000000F` |
| `alpha/black-35` | `alphaBlack35` | `#00000059` |
| `alpha/black-55` | `alphaBlack55` | `#0000008C` |
| `alpha/white-08` | `alphaWhite08` | `#FFFFFF14` |

### Semantic

| Figma | Dart | 가리키는 값 |
|---|---|---|
| `bg/canvas` | `bgCanvas` | `neutral/100` |
| `bg/surface` | `bgSurface` | `neutral/0` |
| `bg/surface-raised` | `bgSurfaceRaised` | `neutral/0` |
| `bg/surface-muted` | `bgSurfaceMuted` | `neutral/150` |
| `bg/brand` | `bgBrand` | `sage/400` |
| `bg/brand-subtle` | `bgBrandSubtle` | `sage/50` |
| `bg/brand-glow` | `bgBrandGlow` | `sage/200` |
| `bg/inverse` | `bgInverse` | `neutral/900` |
| `bg/disabled` | `bgDisabled` | `neutral/200` |
| `bg/error-subtle` | `bgErrorSubtle` | `red/50` |
| `bg/overlay` | `bgOverlay` | `alpha/black-35` |
| `text/primary` | `textPrimary` | `neutral/900` |
| `text/secondary` | `textSecondary` | `neutral/500` |
| `text/tertiary` | `textTertiary` | `neutral/400` |
| `text/brand` | `textBrand` | `sage/400` |
| `text/link` | `textLink` | `neutral/700` |
| `text/on-brand` | `textOnBrand` | `neutral/0` |
| `text/on-inverse` | `textOnInverse` | `neutral/0` |
| `text/disabled` | `textDisabled` | `neutral/500` |
| `text/error` | `textError` | `red/500` |
| `icon/primary` | `iconPrimary` | `neutral/900` |
| `icon/secondary` | `iconSecondary` | `neutral/500` |
| `icon/brand` | `iconBrand` | `sage/400` |
| `icon/on-brand` | `iconOnBrand` | `neutral/0` |
| `icon/on-inverse` | `iconOnInverse` | `neutral/0` |
| `border/default` | `borderDefault` | `neutral/200` |
| `border/strong` | `borderStrong` | `neutral/900` |
| `border/error` | `borderError` | `red/500` |
| `status/live` | `statusLive` | `blue/500` |
| `status/success` | `statusSuccess` | `green/500` |
| `status/error` | `statusError` | `red/500` |
| `effect/shadow` | `effectShadow` | `alpha/black-06` |

---

## 타이포

패밀리는 **Google Sans Flex**. 폰트 파일 연결은 STEP 21에서 한다.

| Figma | Dart | 크기/행간 | 굵기 |
|---|---|---|---|
| `PURE/Display` | `display` | 30 / 38 | 400 |
| `PURE/Title/L` | `titleL` | 30 / 38 | 500 |
| `PURE/Title/M` | `titleM` | 22 / 29 | 500 |
| `PURE/Title/S` | `titleS` | 18 / 24 | 500 |
| `PURE/Header` | `header` | 16 / 22 | 500 |
| `PURE/Body/L` | `bodyL` | 16 / 22 | 400 |
| `PURE/Body/L Strong` | `bodyLStrong` | 16 / 22 | 500 |
| `PURE/Body/M` | `bodyM` | 15 / 22 | 400 |
| `PURE/Body/S` | `bodyS` | 13 / 18 | 400 |
| `PURE/Label/M` | `labelM` | 14 / 20 | 500 |
| `PURE/Label/S` | `labelS` | 13 / 18 | 500 |
| `PURE/Caption` | `caption` | 11 / 14 | 400 |

자간은 전부 0이다.

---

## 간격

**4px 그리드.** 시안 설명: *화면 좌우 여백 24, 카드 내부 16~20, 요소 간격 8/12/16.*

| Figma | Dart | 값 |
|---|---|---|
| `space/4` | `AppSpacing.x4` | 4 |
| `space/8` | `x8` | 8 |
| `space/12` | `x12` | 12 |
| `space/16` | `x16` | 16 |
| `space/20` | `x20` | 20 |
| `space/24` | `x24` | 24 |
| `space/32` | `x32` | 32 |
| `space/40` | `x40` | 40 |
| `space/48` | `x48` | 48 |

편의 상수: `screenGutter = 24`, `cardPadding = 16`.

---

## 라운드

시안이 각 값의 쓰임새를 적어 두었다.

| Figma | Dart | 값 | 쓰는 곳 |
|---|---|---|---|
| `radius/xs` | `AppRadius.xs` | 8 | Small tag |
| `radius/sm` | `sm` | 12 | Thumbnail |
| `radius/md` | `md` | 16 | Input / Card(S) |
| `radius/lg` | `lg` | 20 | Card / Bubble |
| `radius/xl` | `xl` | 28 | Sheet / Robot card |
| `radius/full` | `full` | 999 | Button / Chip |

---

## 효과

| Figma | Dart | 값 |
|---|---|---|
| `PURE/Shadow/Card` | `AppEffects.shadowCard` | drop `#0000000F` offset (0, 4) blur 16 |
| `PURE/Shadow/Float` | `shadowFloat` | drop `#0000001F` offset (0, 8) blur 28 |
| `PURE/Blur/Overlay` | `overlayBlur` | background blur 50 |
| — | `brandGlow()` | `bg/brand-glow` 라디얼 그라디언트 |

홈 글로우의 **위치와 크기는 STEP 23**에서 홈 화면 시안을 보고 맞춘다. 여기서는 색과
번지는 방식만 정의했다.

---

## 아직 안 정한 것

| 항목 | 언제 |
|---|---|
| 폰트 파일 임베드 (Google Sans Flex) | STEP 21 |
| 아이콘 SVG 추출 (`ICON 원본` `407:82771`) | STEP 21 |
| 홈 글로우의 위치·크기 | STEP 23 |
