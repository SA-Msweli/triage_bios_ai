class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final List<Role> roles;
  final String? hospitalId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final UserPreferences preferences;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.roles,
    this.hospitalId,
    required this.createdAt,
    this.lastLoginAt,
    required this.isActive,
    required this.preferences,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      roles: (json['roles'] as List).map((r) => Role.fromJson(r)).toList(),
      hospitalId: json['hospitalId'],
      createdAt: DateTime.parse(json['createdAt']),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'])
          : null,
      isActive: json['isActive'],
      preferences: UserPreferences.fromJson(json['preferences']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'roles': roles.map((r) => r.toJson()).toList(),
      'hospitalId': hospitalId,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'preferences': preferences.toJson(),
    };
  }

  bool hasRole(String roleName) {
    return roles.any((role) => role.name == roleName);
  }

  bool hasPermission(String permission) {
    return roles.any(
      (role) => role.permissions.any((p) => p.name == permission),
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? firstName,
    String? lastName,
    List<Role>? roles,
    String? hospitalId,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    UserPreferences? preferences,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      roles: roles ?? this.roles,
      hospitalId: hospitalId ?? this.hospitalId,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      preferences: preferences ?? this.preferences,
    );
  }
}

class Role {
  final String id;
  final String name;
  final String description;
  final List<Permission> permissions;
  final int hierarchyLevel;
  final bool isSystemRole;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    required this.permissions,
    required this.hierarchyLevel,
    required this.isSystemRole,
  });

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      permissions: (json['permissions'] as List)
          .map((p) => Permission.fromJson(p))
          .toList(),
      hierarchyLevel: json['hierarchyLevel'],
      isSystemRole: json['isSystemRole'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'permissions': permissions.map((p) => p.toJson()).toList(),
      'hierarchyLevel': hierarchyLevel,
      'isSystemRole': isSystemRole,
    };
  }
}

class Permission {
  final String id;
  final String name;
  final String resource;
  final String action;
  final Map<String, dynamic> conditions;
  final List<String> requiredRelationships;

  const Permission({
    required this.id,
    required this.name,
    required this.resource,
    required this.action,
    required this.conditions,
    required this.requiredRelationships,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      id: json['id'],
      name: json['name'],
      resource: json['resource'],
      action: json['action'],
      conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
      requiredRelationships: List<String>.from(
        json['requiredRelationships'] ?? [],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'resource': resource,
      'action': action,
      'conditions': conditions,
      'requiredRelationships': requiredRelationships,
    };
  }
}

class UserPreferences {
  final String language;
  final bool enableNotifications;
  final bool enableBiometrics;
  final Map<String, dynamic> dashboardSettings;

  const UserPreferences({
    required this.language,
    required this.enableNotifications,
    required this.enableBiometrics,
    required this.dashboardSettings,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      language: json['language'] ?? 'en',
      enableNotifications: json['enableNotifications'] ?? true,
      enableBiometrics: json['enableBiometrics'] ?? false,
      dashboardSettings: Map<String, dynamic>.from(
        json['dashboardSettings'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'enableNotifications': enableNotifications,
      'enableBiometrics': enableBiometrics,
      'dashboardSettings': dashboardSettings,
    };
  }
}
