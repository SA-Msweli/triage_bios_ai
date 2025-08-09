import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Authentication and user management service
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  
  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users_database';
  
  User? _currentUser;

  /// Get current authenticated user
  User? get currentUser => _currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => _currentUser != null;

  /// Initialize auth service and restore session
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(userData);
        _logger.i('Restored user session: ${_currentUser!.name}');
      }
    } catch (e) {
      _logger.e('Failed to initialize auth service: $e');
    }
  }

  /// Register a new user
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? emergencyContact,
    String? medicalId,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _getUserByEmail(email);
      if (existingUser != null) {
        return AuthResult.error('User with this email already exists');
      }

      // Create new user
      final user = User(
        id: _uuid.v4(),
        name: name,
        email: email,
        role: role,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        emergencyContact: emergencyContact,
        medicalId: medicalId,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );

      // Store user in local database
      await _storeUser(user, password);
      
      // Set as current user
      _currentUser = user;
      await _saveCurrentUser();

      _logger.i('User registered successfully: ${user.name} (${user.role.name})');
      return AuthResult.success(user);

    } catch (e) {
      _logger.e('Registration failed: $e');
      return AuthResult.error('Registration failed: $e');
    }
  }

  /// Login user
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _getUserByEmail(email);
      if (user == null) {
        return AuthResult.error('User not found');
      }

      // In a real app, you'd verify the password hash
      // For demo purposes, we'll accept any password for existing users
      
      // Update last login
      final updatedUser = user.copyWith(lastLoginAt: DateTime.now());
      await _updateUser(updatedUser);
      
      _currentUser = updatedUser;
      await _saveCurrentUser();

      _logger.i('User logged in: ${user.name} (${user.role.name})');
      return AuthResult.success(updatedUser);

    } catch (e) {
      _logger.e('Login failed: $e');
      return AuthResult.error('Login failed: $e');
    }
  }

  /// Login as guest (for demo purposes)
  Future<AuthResult> loginAsGuest() async {
    try {
      final guestUser = User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Guest User',
        email: 'guest@demo.com',
        role: UserRole.patient,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
        isGuest: true,
      );

      _currentUser = guestUser;
      await _saveCurrentUser();

      _logger.i('Guest login successful');
      return AuthResult.success(guestUser);

    } catch (e) {
      _logger.e('Guest login failed: $e');
      return AuthResult.error('Guest login failed: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    try {
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);
      _logger.i('User logged out');
    } catch (e) {
      _logger.e('Logout failed: $e');
    }
  }

  /// Update user profile
  Future<AuthResult> updateProfile({
    String? name,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? emergencyContact,
    String? medicalId,
  }) async {
    if (_currentUser == null) {
      return AuthResult.error('No user logged in');
    }

    try {
      final updatedUser = _currentUser!.copyWith(
        name: name ?? _currentUser!.name,
        phoneNumber: phoneNumber ?? _currentUser!.phoneNumber,
        dateOfBirth: dateOfBirth ?? _currentUser!.dateOfBirth,
        emergencyContact: emergencyContact ?? _currentUser!.emergencyContact,
        medicalId: medicalId ?? _currentUser!.medicalId,
      );

      await _updateUser(updatedUser);
      _currentUser = updatedUser;
      await _saveCurrentUser();

      _logger.i('Profile updated for user: ${updatedUser.name}');
      return AuthResult.success(updatedUser);

    } catch (e) {
      _logger.e('Profile update failed: $e');
      return AuthResult.error('Profile update failed: $e');
    }
  }

  /// Get user by email
  Future<User?> _getUserByEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);
      
      if (usersJson == null) return null;

      final usersData = jsonDecode(usersJson) as Map<String, dynamic>;
      final userData = usersData[email] as Map<String, dynamic>?;
      
      if (userData == null) return null;

      return User.fromJson(userData['user'] as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Failed to get user by email: $e');
      return null;
    }
  }

  /// Store user in local database
  Future<void> _storeUser(User user, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '{}';
      final usersData = jsonDecode(usersJson) as Map<String, dynamic>;

      usersData[user.email] = {
        'user': user.toJson(),
        'password_hash': password, // In real app, this would be hashed
        'created_at': DateTime.now().toIso8601String(),
      };

      await prefs.setString(_usersKey, jsonEncode(usersData));
    } catch (e) {
      _logger.e('Failed to store user: $e');
      rethrow;
    }
  }

  /// Update user in local database
  Future<void> _updateUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey) ?? '{}';
      final usersData = jsonDecode(usersJson) as Map<String, dynamic>;

      if (usersData.containsKey(user.email)) {
        usersData[user.email]['user'] = user.toJson();
        await prefs.setString(_usersKey, jsonEncode(usersData));
      }
    } catch (e) {
      _logger.e('Failed to update user: $e');
      rethrow;
    }
  }

  /// Save current user to preferences
  Future<void> _saveCurrentUser() async {
    if (_currentUser == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      _logger.e('Failed to save current user: $e');
    }
  }

  /// Create demo users for testing
  Future<void> createDemoUsers() async {
    final demoUsers = [
      {
        'name': 'John Patient',
        'email': 'patient@demo.com',
        'role': UserRole.patient,
        'phoneNumber': '+1-555-0101',
        'dateOfBirth': DateTime(1985, 6, 15),
        'emergencyContact': 'Jane Patient: +1-555-0102',
        'medicalId': 'MRN-123456',
      },
      {
        'name': 'Mary Caregiver',
        'email': 'caregiver@demo.com',
        'role': UserRole.caregiver,
        'phoneNumber': '+1-555-0201',
        'emergencyContact': 'Emergency Services: 911',
      },
      {
        'name': 'Dr. Sarah Wilson',
        'email': 'doctor@demo.com',
        'role': UserRole.healthcare_provider,
        'phoneNumber': '+1-555-0301',
      },
      {
        'name': 'Admin User',
        'email': 'admin@demo.com',
        'role': UserRole.admin,
        'phoneNumber': '+1-555-0401',
      },
    ];

    for (final userData in demoUsers) {
      await register(
        name: userData['name'] as String,
        email: userData['email'] as String,
        password: 'demo123',
        role: userData['role'] as UserRole,
        phoneNumber: userData['phoneNumber'] as String?,
        dateOfBirth: userData['dateOfBirth'] as DateTime?,
        emergencyContact: userData['emergencyContact'] as String?,
        medicalId: userData['medicalId'] as String?,
      );
    }

    _logger.i('Demo users created successfully');
  }
}

/// User model
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phoneNumber;
  final DateTime? dateOfBirth;
  final String? emergencyContact;
  final String? medicalId;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;
  final bool isGuest;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.dateOfBirth,
    this.emergencyContact,
    this.medicalId,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isActive,
    this.isGuest = false,
  });

  User copyWith({
    String? name,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? emergencyContact,
    String? medicalId,
    DateTime? lastLoginAt,
    bool? isActive,
  }) {
    return User(
      id: id,
      name: name ?? this.name,
      email: email,
      role: role,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      medicalId: medicalId ?? this.medicalId,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isGuest: isGuest,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'phoneNumber': phoneNumber,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'emergencyContact': emergencyContact,
      'medicalId': medicalId,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt.toIso8601String(),
      'isActive': isActive,
      'isGuest': isGuest,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.values.firstWhere((r) => r.name == json['role']),
      phoneNumber: json['phoneNumber'] as String?,
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      emergencyContact: json['emergencyContact'] as String?,
      medicalId: json['medicalId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastLoginAt: DateTime.parse(json['lastLoginAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  String get displayRole {
    switch (role) {
      case UserRole.patient:
        return 'Patient';
      case UserRole.caregiver:
        return 'Family/Caregiver';
      case UserRole.healthcare_provider:
        return 'Healthcare Provider';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month || 
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age;
  }
}

/// User roles
enum UserRole {
  patient,
  caregiver,
  healthcare_provider,
  admin,
}

/// Authentication result
class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult._({
    required this.success,
    this.user,
    this.error,
  });

  factory AuthResult.success(User user) {
    return AuthResult._(success: true, user: user);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(success: false, error: error);
  }
}