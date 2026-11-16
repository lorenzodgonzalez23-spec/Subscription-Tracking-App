import 'package:flutter/material.dart';

abstract final class AppColors {
  static const canvas = Color(0xFF0A0A0C);
  static const surface = Color(0xFF141418);
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const red = Color(0xFFFF453A);
  static const purple = Color(0xFFBF5AF2);
  static const amber = Color(0xFFFF9F0A);
  static const muted = Color(0xFF8E8E93);
  static const categories = <String, Color>{
    'Entertainment': blue,
    'Productivity & AI': purple,
    'Utilities': amber,
    'Gaming': red,
    'Health & Fitness': green,
    'Cloud Storage': Color(0xFF64D2FF),
    'Education': Color(0xFFFFD60A),
    'Other': muted,
  };
}
