// MTA2_CONTRACT: STATIC_PRIVILEGED_API_KEY_IN_APP = ZERO
// Session tokens are stored in FlutterSecureStorage — never in logs or plain prefs.

class CustomerSession {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String userId;
  final String displayName;

  const CustomerSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.displayName,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  /// True when the access token will expire within [threshold].
  bool expiresWithin(Duration threshold) =>
      expiresAt.difference(DateTime.now().toUtc()) <= threshold;

  CustomerSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    String? userId,
    String? displayName,
  }) =>
      CustomerSession(
        accessToken: accessToken ?? this.accessToken,
        refreshToken: refreshToken ?? this.refreshToken,
        expiresAt: expiresAt ?? this.expiresAt,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'user_id': userId,
        'display_name': displayName,
      };

  factory CustomerSession.fromJson(Map<String, dynamic> json) =>
      CustomerSession(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String,
      );
}
