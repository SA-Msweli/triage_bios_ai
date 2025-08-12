import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../features/auth/domain/entities/patient_consent.dart';
import '../models/token_pair.dart';

/// Authentication and user management service
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Protected constructor for subclasses
  AuthService.forSubclass();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const String _currentUserKey = 'current_user';
  static const String _usersKey = 'users_database';
  static const String _tokensKey = 'auth_tokens';
  static const String _consentsKey = 'patient_consents';

  User? currentUserInternal;
  TokenPair? _currentTokens;
  final Map<String, List<PatientConsent>> _patientConsents = {};
  final List<UserSession> _activeSessions = [];

  /// Get current authenticated user
  User? get currentUser => currentUserInternal;

  /// Check if user is authenticated
  bool get isAuthenticated =>
      currentUserInternal != null &&
      (_currentTokens == null || !_currentTokens!.isExpired);

  /// Get current tokens
  TokenPair? get currentTokens => _currentTokens;

  /// Initialize auth service and restore session
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);

      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        currentUserInternal = User.fromJson(userData);
        _logger.i('Restored user session: ${currentUserInternal!.name}');
      }

      // Load tokens and consents
      await _loadStoredData();
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
      currentUserInternal = user;
      await _saveCurrentUser();

      _logger.i(
        'User registered successfully: ${user.name} (${user.role.name})',
      );
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

      currentUserInternal = updatedUser;
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

      currentUserInternal = guestUser;
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
      currentUserInternal = null;
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
    if (currentUserInternal == null) {
      return AuthResult.error('No user logged in');
    }

    try {
      final updatedUser = currentUserInternal!.copyWith(
        name: name ?? currentUserInternal!.name,
        phoneNumber: phoneNumber ?? currentUserInternal!.phoneNumber,
        dateOfBirth: dateOfBirth ?? currentUserInternal!.dateOfBirth,
        emergencyContact:
            emergencyContact ?? currentUserInternal!.emergencyContact,
        medicalId: medicalId ?? currentUserInternal!.medicalId,
      );

      await _updateUser(updatedUser);
      currentUserInternal = updatedUser;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      if (currentUserInternal != null) {
        await prefs.setString(
          _currentUserKey,
          json.encode(currentUserInternal!.toJson()),
        );
      } else {
        await prefs.remove(_currentUserKey);
      }
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
        'role': UserRole.healthcareProvider,
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

  // Enhanced Authentication Methods

  /// Enhanced login with JWT tokens
  Future<AuthResult> loginWithTokens({
    required String email,
    required String password,
    String? deviceId,
  }) async {
    try {
      final result = await login(email: email, password: password);
      if (!result.success || result.user == null) {
        return result;
      }

      // Generate JWT tokens
      final tokens = await _generateTokens(result.user!);
      _currentTokens = tokens;

      // Create session
      if (deviceId != null) {
        await _createSession(result.user!.id, deviceId);
      }

      // Store tokens
      await _storeTokens(tokens);

      return result;
    } catch (e) {
      _logger.e('Enhanced login failed: $e');
      return AuthResult.error('Login failed: $e');
    }
  }

  /// Refresh authentication tokens
  Future<TokenPair?> refreshTokens() async {
    if (_currentTokens == null || currentUserInternal == null) return null;

    try {
      // In a real app, you'd validate the refresh token with the server
      if (_currentTokens!.isExpired) {
        await logout();
        return null;
      }

      // Generate new tokens
      final newTokens = await _generateTokens(currentUserInternal!);
      _currentTokens = newTokens;

      // Store new tokens
      await _storeTokens(newTokens);

      return newTokens;
    } catch (e) {
      _logger.e('Token refresh failed: $e');
      await logout();
      return null;
    }
  }

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    if (currentUserInternal == null || !isAuthenticated) return false;

    switch (currentUserInternal!.role) {
      case UserRole.admin:
        return true; // Admin has all permissions
      case UserRole.healthcareProvider:
        return [
          'read_assigned_patient_data',
          'write_assessments',
          'manage_queue',
          'view_analytics',
          'create_assessment',
          'update_assessment',
        ].contains(permission);
      case UserRole.caregiver:
        return [
          'read_assigned_patient_data',
          'view_queue',
        ].contains(permission);
      case UserRole.patient:
        return [
          'read_own_data',
          'manage_consent',
          'view_triage',
          'grant_consent',
          'revoke_consent',
        ].contains(permission);
    }
  }

  /// Check if user has specific role
  bool hasRole(String roleName) {
    if (currentUserInternal == null || !isAuthenticated) return false;
    return currentUserInternal!.role.name == roleName;
  }

  // Patient Consent Management

  /// Grant patient consent to a provider
  Future<PatientConsent> grantPatientConsent(
    String patientId,
    String providerId,
    List<String> dataScopes,
    DateTime? expiresAt,
  ) async {
    final consent = PatientConsent(
      consentId: _uuid.v4(),
      patientId: patientId,
      providerId: providerId,
      consentType: 'treatment',
      dataScopes: dataScopes,
      grantedAt: DateTime.now(),
      expiresAt: expiresAt,
      isActive: true,
      blockchainTxId: 'tx_${Random().nextInt(1000000)}',
      consentDetails: {
        'grantedBy': currentUserInternal?.id,
        'reason': 'Patient consent for treatment',
        'ipAddress': '192.168.1.1', // Mock IP
      },
    );

    _patientConsents.putIfAbsent(patientId, () => []).add(consent);
    await _storeConsents();

    _logger.i('Patient consent granted: $patientId -> $providerId');
    return consent;
  }

  /// Check if provider has patient consent
  bool hasPatientConsent(
    String providerId,
    String patientId,
    String dataScope,
  ) {
    final consents = _patientConsents[patientId] ?? [];
    return consents.any(
      (consent) =>
          consent.providerId == providerId &&
          consent.isActive &&
          !consent.isExpired &&
          consent.hasDataScope(dataScope),
    );
  }

  /// Get all consents for a patient
  List<PatientConsent> getPatientConsents(String patientId) {
    return _patientConsents[patientId] ?? [];
  }

  /// Revoke patient consent
  Future<void> revokePatientConsent(String patientId, String consentId) async {
    final consents = _patientConsents[patientId] ?? [];
    consents.removeWhere((consent) => consent.consentId == consentId);
    await _storeConsents();

    _logger.i('Patient consent revoked: $consentId');
  }

  /// Check if provider can access patient data
  bool canAccessPatientData(String providerId, String patientId) {
    // If current user is the patient themselves, always allow
    if (currentUserInternal?.id == patientId) return true;

    // Check if provider has consent for any data scope
    final consents = _patientConsents[patientId] ?? [];
    return consents.any(
      (consent) =>
          consent.providerId == providerId &&
          consent.isActive &&
          !consent.isExpired,
    );
  }

  // Private helper methods

  /// Generate JWT tokens
  Future<TokenPair> _generateTokens(User user) async {
    final accessToken = _generateJWT(user, const Duration(minutes: 15));
    final refreshToken = _generateJWT(user, const Duration(days: 7));

    return TokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(const Duration(minutes: 15)),
    );
  }

  /// Generate JWT token
  String _generateJWT(User user, Duration expiry) {
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'sub': user.id,
      'email': user.email,
      'role': user.role.name,
      'name': user.name,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'exp': DateTime.now().add(expiry).millisecondsSinceEpoch ~/ 1000,
      'jti': _uuid.v4(),
    };

    final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
    final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
    final signature = _generateSignature('$encodedHeader.$encodedPayload');

    return '$encodedHeader.$encodedPayload.$signature';
  }

  /// Generate JWT signature
  String _generateSignature(String data) {
    final key = utf8.encode('triage-bios-ai-secret-key');
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return base64Url.encode(digest.bytes);
  }

  /// Create user session
  Future<void> _createSession(String userId, String deviceId) async {
    final session = UserSession(
      sessionId: _uuid.v4(),
      userId: userId,
      deviceId: deviceId,
      ipAddress: '192.168.1.1', // Mock IP
      createdAt: DateTime.now(),
      lastAccessAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 8)),
      isActive: true,
    );

    _activeSessions.add(session);
  }

  /// Store tokens in preferences
  Future<void> _storeTokens(TokenPair tokens) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokensKey, json.encode(tokens.toJson()));
    } catch (e) {
      _logger.e('Failed to store tokens: $e');
    }
  }

  /// Store consents in preferences
  Future<void> _storeConsents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final consentsJson = <String, dynamic>{};

      _patientConsents.forEach((patientId, consents) {
        consentsJson[patientId] = consents.map((c) => c.toJson()).toList();
      });

      await prefs.setString(_consentsKey, json.encode(consentsJson));
    } catch (e) {
      _logger.e('Failed to store consents: $e');
    }
  }

  /// Load stored tokens and consents
  Future<void> _loadStoredData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load tokens
      final tokensJson = prefs.getString(_tokensKey);
      if (tokensJson != null) {
        _currentTokens = TokenPair.fromJson(json.decode(tokensJson));

        // Check if tokens are expired
        if (_currentTokens!.isExpired) {
          _currentTokens = null;
          await prefs.remove(_tokensKey);
        }
      }

      // Load consents
      final consentsJson = prefs.getString(_consentsKey);
      if (consentsJson != null) {
        final consentsData = json.decode(consentsJson) as Map<String, dynamic>;
        consentsData.forEach((patientId, consentsList) {
          _patientConsents[patientId] = (consentsList as List)
              .map((c) => PatientConsent.fromJson(c))
              .toList();
        });
      }
    } catch (e) {
      _logger.e('Failed to load stored data: $e');
    }
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
      case UserRole.healthcareProvider:
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
enum UserRole { patient, caregiver, healthcareProvider, admin }

/// Authentication result
class AuthResult {
  final bool success;
  final User? user;
  final String? error;

  AuthResult._({required this.success, this.user, this.error});

  factory AuthResult.success(User user) {
    return AuthResult._(success: true, user: user);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(success: false, error: error);
  }
}
