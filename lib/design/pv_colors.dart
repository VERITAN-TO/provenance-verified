import 'package:flutter/material.dart';

class PvColors {
  // Surfaces — carbon base per brand system
  static const Color background = Color(0xFF030506);
  static const Color surface = Color(0xFF10222B);
  static const Color surfaceElevated = Color(0xFF18303C);
  static const Color border = Color(0xFF1E3340);
  static const Color onBackground = Color(0xFFF0F2F3);
  static const Color onSurface = Color(0xFFD8DBDD);
  static const Color muted = Color(0xFF6B7880);

  // Brand identity
  static const Color cyan = Color(0xFF20DDF2);       // Protocol Cyan — active verification
  static const Color silver = Color(0xFFB7C0C6);     // Authority Silver — machined silver

  // Certification tiers — canonical from brand system
  static const Color tier1 = Color(0xFF48545E);      // graphite
  static const Color tier2 = Color(0xFFAD7045);      // bronze
  static const Color tier3 = Color(0xFFB7C0C6);      // silver
  static const Color tier4 = Color(0xFFD5A63D);      // gold — certified / highest authority only

  // State colors — canonical from brand system
  static const Color success = Color(0xFF35D69D);    // approve
  static const Color warning = Color(0xFFF0B33A);    // pending
  static const Color error = Color(0xFFFF4D4F);      // failed
  static const Color revoked = Color(0xFFD9363E);    // revoked
  static const Color exception = Color(0xFFFFB02E);  // exception

  // Prohibition / limitation
  static const Color prohibited = Color(0xFFFF4D4F);
  static const Color limitation = Color(0xFFFFB02E);

  PvColors._();
}
