import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

/// 토큰을 [ThemeData] 로 묶는다.
///
/// 라이트 전용 (PRD 부록 D). 화면·위젯은 색과 치수를 직접 쓰지 않고 토큰이나
/// 이 테마를 통해 받는다 (CLAUDE.md 규칙 9).
abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.bgBrand,
      onPrimary: AppColors.textOnBrand,
      primaryContainer: AppColors.bgBrandSubtle,
      onPrimaryContainer: AppColors.textPrimary,
      secondary: AppColors.sage600,
      onSecondary: AppColors.textOnBrand,
      surface: AppColors.bgSurface,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.bgSurface,
      surfaceContainerLow: AppColors.bgCanvas,
      surfaceContainer: AppColors.bgSurfaceMuted,
      error: AppColors.statusError,
      onError: AppColors.neutral0,
      errorContainer: AppColors.bgErrorSubtle,
      onErrorContainer: AppColors.textError,
      outline: AppColors.borderDefault,
      outlineVariant: AppColors.neutral150,
      inverseSurface: AppColors.bgInverse,
      onInverseSurface: AppColors.textOnInverse,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bgCanvas,
      fontFamily: AppTextStyles.fontFamily,
      fontFamilyFallback: AppTextStyles.fontFamilyFallback,

      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        displayMedium: AppTextStyles.titleL,
        titleLarge: AppTextStyles.titleM,
        titleMedium: AppTextStyles.titleS,
        titleSmall: AppTextStyles.header,
        bodyLarge: AppTextStyles.bodyL,
        bodyMedium: AppTextStyles.bodyM,
        bodySmall: AppTextStyles.bodyS,
        labelLarge: AppTextStyles.labelM,
        labelMedium: AppTextStyles.labelS,
        labelSmall: AppTextStyles.caption,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bgCanvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTextStyles.header,
        iconTheme: const IconThemeData(color: AppColors.iconPrimary, size: 22),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.borderDefault,
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: AppColors.iconPrimary),

      // 버튼은 전부 완전 둥근 모서리 (radius/full — 시안의 Button / Chip).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bgBrand,
          foregroundColor: AppColors.textOnBrand,
          disabledBackgroundColor: AppColors.bgDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTextStyles.labelM,
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size.fromHeight(52),
          textStyle: AppTextStyles.labelM,
          side: const BorderSide(color: AppColors.borderDefault),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textLink,
          textStyle: AppTextStyles.labelM,
          shape: const StadiumBorder(),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgSurface,
        hintStyle: AppTextStyles.bodyM.copyWith(color: AppColors.textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x16,
          vertical: AppSpacing.x12,
        ),
        border: _inputBorder(AppColors.borderDefault),
        enabledBorder: _inputBorder(AppColors.borderDefault),
        focusedBorder: _inputBorder(AppColors.bgBrand),
        errorBorder: _inputBorder(AppColors.borderError),
        focusedErrorBorder: _inputBorder(AppColors.borderError),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.bgSurface,
        surfaceTintColor: Colors.transparent,
        scrimColor: AppColors.bgOverlay,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bgInverse,
        contentTextStyle: AppTextStyles.bodyS.copyWith(
          color: AppColors.textOnInverse,
        ),
        actionTextColor: AppColors.sage200,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 15,
          height: 22 / 15,
          color: AppColors.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 13,
          height: 18 / 13,
          color: AppColors.textSecondary,
        ),
        iconColor: AppColors.iconSecondary,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.neutral0
              : AppColors.neutral0,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.bgBrand
              : AppColors.bgDisabled,
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.bgBrand,
        linearTrackColor: AppColors.bgSurfaceMuted,
      ),

      splashFactory: InkSparkle.splashFactory,
    );
  }

  static OutlineInputBorder _inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color),
      );
}
