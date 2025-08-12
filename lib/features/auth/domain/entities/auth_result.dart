import '../../../../shared/services/auth_service.dart';

class AuthResult {
  final bool success;
  final User? user;
  final TokenPair? tokens;
  final String? error;
  final bool requiresMFA;
  final MFAChallenge? mfaChallenge;

  const AuthResult({
    required this.success,
    this.user,
    this.tokens,
    this.error,
    this.requiresMFA = false,
    this.mfaChallenge,
  });

  factory AuthResult.success(User user, TokenPair tokens) {
    return AuthResult(success: true, user: user, tokens: tokens);
  }

  factory AuthResult.requiresMFA(MFAChallenge challenge) {
    return AuthResult(
      success: false,
      requiresMFA: true,
      mfaChallenge: challenge,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(success: false, error: error);
  }
}

class TokenPair {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['accessToken'],
      refreshToken: json['refreshToken'],
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class MFAChallenge {
  final String challengeId;
  final MFAMethod method;
  final String? destination; // Phone number or email for SMS/Email OTP
  final DateTime expiresAt;

  const MFAChallenge({
    required this.challengeId,
    required this.method,
    this.destination,
    required this.expiresAt,
  });

  factory MFAChallenge.fromJson(Map<String, dynamic> json) {
    return MFAChallenge(
      challengeId: json['challengeId'],
      method: MFAMethod.values.firstWhere(
        (m) => m.toString().split('.').last == json['method'],
      ),
      destination: json['destination'],
      expiresAt: DateTime.parse(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'challengeId': challengeId,
      'method': method.toString().split('.').last,
      'destination': destination,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

enum MFAMethod { sms, email, totp, biometric, hardwareKey }

class UserSession {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastAccessAt;
  final DateTime expiresAt;
  final bool isActive;

  const UserSession({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.ipAddress,
    required this.createdAt,
    required this.lastAccessAt,
    required this.expiresAt,
    required this.isActive,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'],
      userId: json['userId'],
      deviceId: json['deviceId'],
      ipAddress: json['ipAddress'],
      createdAt: DateTime.parse(json['createdAt']),
      lastAccessAt: DateTime.parse(json['lastAccessAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      isActive: json['isActive'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'userId': userId,
      'deviceId': deviceId,
      'ipAddress': ipAddress,
      'createdAt': createdAt.toIso8601String(),
      'lastAccessAt': lastAccessAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}
