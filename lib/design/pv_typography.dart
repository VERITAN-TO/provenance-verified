import 'package:flutter/material.dart';

class PvTypography {
  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle body = TextStyle(fontSize: 15);
  static const TextStyle bodySmall = TextStyle(fontSize: 13);
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.8,
  );
  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
  );

  PvTypography._();
}
