/// User session model for tracking active sessions
class UserSession {
  final String sessionId;
  final String userId;
  final String deviceId;
  final String ipAddress;
  final DateTime createdAt;
  final DateTime lastAccessAt;
  final DateTime expiresAt;
  final bool isActive;

  UserSession({
    required this.sessionId,
    required this.userId,
    required this.deviceId,
    required this.ipAddress,
    required this.createdAt,
    required this.lastAccessAt,
    required this.expiresAt,
    required this.isActive,
  });

  UserSession copyWith({
    String? sessionId,
    String? userId,
    String? deviceId,
    String? ipAddress,
    DateTime? createdAt,
    DateTime? lastAccessAt,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return UserSession(
      sessionId: sessionId ?? this.sessionId,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      ipAddress: ipAddress ?? this.ipAddress,
      createdAt: createdAt ?? this.createdAt,
      lastAccessAt: lastAccessAt ?? this.lastAccessAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
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

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      sessionId: json['sessionId'] as String,
      userId: json['userId'] as String,
      deviceId: json['deviceId'] as String,
      ipAddress: json['ipAddress'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessAt: DateTime.parse(json['lastAccessAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      isActive: json['isActive'] as bool,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get deviceType {
    if (deviceId.toLowerCase().contains('mobile') || 
        deviceId.toLowerCase().contains('android') || 
        deviceId.toLowerCase().contains('ios')) {
      return 'Mobile';
    } else if (deviceId.toLowerCase().contains('web') || 
               deviceId.toLowerCase().contains('browser')) {
      return 'Web';
    } else if (deviceId.toLowerCase().contains('desktop')) {
      return 'Desktop';
    }
    return 'Unknown';
  }

  Duration get sessionDuration => lastAccessAt.difference(createdAt);
  
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());
}