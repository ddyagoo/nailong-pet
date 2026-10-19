import 'package:flutter/material.dart';

/// 奶油暖黄 palette. Everything in the app pulls colours from here so the
/// pet（视频抠出来的黄）和界面是同一套色。
abstract final class Palette {
  static const cream = Color(0xFFFFF7E9);
  static const creamDeep = Color(0xFFFFE8C8);
  static const peach = Color(0xFFFFD6AF);
  static const yellow = Color(0xFFF5B93F);
  static const yellowDeep = Color(0xFFE0992B);
  static const orange = Color(0xFFF08A3C);
  static const brown = Color(0xFF3E2A1C);
  static const brownSoft = Color(0xFF8A6A50);
  static const card = Color(0xFFFFFCF5);
  static const leaf = Color(0xFF7FA96B);
  static const red = Color(0xFFD9694E);
  static const line = Color(0xFFE8D5BC);
}

abstract final class T {
  static const display = TextStyle(
      fontFamily: 'ZCOOL', fontSize: 24, height: 1.25, color: Palette.brown);
  static const title = TextStyle(
      fontFamily: 'ZCOOL', fontSize: 19, height: 1.3, color: Palette.brown);
  static const label = TextStyle(
      fontFamily: 'ZCOOL', fontSize: 15, height: 1.3, color: Palette.brown);
  static const body = TextStyle(
      fontFamily: 'ZCOOL', fontSize: 14, height: 1.5, color: Palette.brown);
  static const bodyStrong = TextStyle(
      fontFamily: 'ZCOOL',
      fontSize: 14,
      height: 1.5,
      color: Palette.brown,
      fontWeight: FontWeight.w600);
  static const caption = TextStyle(
      fontFamily: 'ZCOOL', fontSize: 12, height: 1.45, color: Palette.brownSoft);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'ZCOOL',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.yellow,
      primary: Palette.orange,
      surface: Palette.card,
    ),
    scaffoldBackgroundColor: Palette.cream,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          fontFamily: 'ZCOOL',
          bodyColor: Palette.brown,
          displayColor: Palette.brown,
        )
        .apply(fontFamilyFallback: const ['ZCOOL']),
    splashFactory: InkSparkle.splashFactory,
  );
}
