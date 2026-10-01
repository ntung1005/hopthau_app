// Giao diện theo UI kit Coinpay (Figma community): xanh royal làm màu chính, nền trắng,
// nút bo tròn cao 56, ô nhập nền xám nhạt, card bo 16, bottom nav có nút giữa nổi.
// ponytail: token lấy từ ảnh chụp kit, chưa đọc được file Figma. Khi kết nối Figma,
// chỉnh giá trị trong [AppColors] / [AppRadius] cho khớp chính xác, không phải sửa màn hình.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF304FFE);
  static const primarySoft = Color(0xFFE8ECFF);
  static const accent = Color(0xFFFFB800);
  static const text = Color(0xFF1B1D28);
  static const muted = Color(0xFF6B7280);
  static const surface = Color(0xFFFFFFFF);
  static const field = Color(0xFFF4F5F7);
  static const border = Color(0xFFE6E8EC);
  static const success = Color(0xFF16A34A);
  static const error = Color(0xFFDC2626);
}

class AppRadius {
  AppRadius._();

  static const button = 28.0;
  static const card = 16.0;
  static const field = 12.0;
  static const sheet = 24.0;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySoft,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.accent,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.border,
    outlineVariant: AppColors.border,
    error: AppColors.error,
  );
  const buttonSize = Size.fromHeight(56);
  const buttonShape = StadiumBorder();
  const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
          headlineSmall: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
          titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          titleMedium: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
        )
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: buttonSize, shape: buttonShape, textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: buttonSize,
        shape: buttonShape,
        textStyle: buttonText,
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.primary, textStyle: buttonText),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.primary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.primary,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    ),
    checkboxTheme: CheckboxThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.text,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.field)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: AppColors.surface, surfaceTintColor: Colors.transparent),
  );
}

/// Icon trong vòng tròn nền xanh nhạt, dùng ở đầu dòng danh sách (kiểu danh sách giao dịch của Coinpay).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.primary, size: size * 0.5),
      );
}

/// Hình minh hoạ đầu màn hình (onboarding, đăng nhập, gửi thành công): icon lớn trên các vòng tròn đồng tâm.
/// ponytail: thay bằng ảnh minh hoạ line-art của kit khi xuất được asset từ Figma.
class Illustration extends StatelessWidget {
  const Illustration(this.icon, {super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 200,
        child: Stack(alignment: Alignment.center, children: [
          for (final (size, alpha) in const [(200.0, 0.35), (150.0, 0.6), (104.0, 1.0)])
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft.withValues(alpha: alpha),
              ),
            ),
          Icon(icon, size: 52, color: AppColors.primary),
        ]),
      );
}

/// "Tên nhà thầu ✓  ★ 4.7" (✓ khi đã xác minh). Sao và dấu tích là icon: font web không có các glyph này.
class ContractorLine extends StatelessWidget {
  const ContractorLine(this.contractor, {super.key, this.style});

  final Map<String, dynamic> contractor;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final rating = contractor['rating'];
    final s = style ?? const TextStyle(color: AppColors.muted, fontSize: 13);
    return Text.rich(TextSpan(style: s, children: [
      TextSpan(text: '${contractor['name']}'),
      if (contractor['status'] == 'verified')
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(left: 4),
            child: Tooltip(message: 'Đã xác minh', child: Icon(Icons.verified_rounded, size: 16, color: AppColors.primary)),
          ),
        ),
      if (rating != null) ...[
        const TextSpan(text: '  '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(Icons.star_rounded, size: (s.fontSize ?? 14) + 2, color: AppColors.accent),
        ),
        TextSpan(text: ' $rating'),
      ],
    ]));
  }
}
