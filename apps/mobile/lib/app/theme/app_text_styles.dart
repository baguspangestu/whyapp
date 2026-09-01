import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const titleLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static const titleMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static const bodyLarge = TextStyle(fontSize: 16);

  static const bodyMedium = TextStyle(fontSize: 14);

  static const bodySmall = TextStyle(fontSize: 12);
}
