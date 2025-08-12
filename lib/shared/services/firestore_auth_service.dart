import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import '../../features/auth/domain/entities/patient_consent.dart';

class FirestoreAuthService extends AuthService {
  FirestoreAuthService() : super.forSubclass();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final FirebaseService _firebaseService = FirebaseService();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  firebase_auth.FirebaseAuth get _firebaseAuth => _firebaseService.auth;

  // Collection names
  static const String _usersCollection = 'users';
  static const String _consentsCollection = 'patient_consents';
  static const String _auditLogsCollection = 'audit_logs';
  // Collection names for future use
  // static const String _emergencyAccessCollection = 'emergency_access';
  // static const String _verifiedProvidersCollection = 'verified_providers';

  @override
  Future<void> initialize() async {
    try {
      // Initialize Firebase first
      if (!_firebaseService.isInitialized) {
        await _firebaseService.initialize();
      }

      // Check if user is already authenticated
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        // Load user data from Firestore
        await _loadUserFromFirestore(firebaseUser.uid);
      }

      _logger.i('FirestoreAuthService initialized successfully');
    } catch (e) {
      _logger.e('FirestoreAuthService initialization failed: $e');
      // Fall back to local storage
      await super.initialize();
    }
  }

  @override
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
      // Create Firebase user
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.error('Failed to create Firebase user');
      }

      // Create user document in Firestore
      final user = User(
        id: credential.user!.uid,
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

      await _firestore
          .collection(_usersCollection)
          .doc(user.id)
          .set(user.toJson());

      // Set as current user
      currentUserInternal = user;

      _logger.i(
        'User registered in Firestore: ${user.name} (${user.role.name})',
      );
      return AuthResult.success(user);
    } catch (e) {
      _logger.e('Firestore registration failed: $e');
      // Fall back to local registration
      return await super.register(
        name: name,
        email: email,
        password: password,
        role: role,
        phoneNumber: phoneNumber,
        dateOfBirth: dateOfBirth,
        emergencyContact: emergencyContact,
        medicalId: medicalId,
      );
    }
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      // Authenticate with Firebase
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.error('Firebase authentication failed');
      }

      // Load user data from Firestore
      await _loadUserFromFirestore(credential.user!.uid);

      if (currentUserInternal == null) {
        return AuthResult.error('User data not found in Firestore');
      }

      // Update last login time
      await _updateLastLogin(currentUserInternal!.id);

      _logger.i('User logged in via Firestore: ${currentUserInternal!.name}');
      return AuthResult.success(currentUserInternal!);
    } catch (e) {
      _logger.e('Firestore login failed: $e');
      // Fall back to local login
      return await super.login(email: email, password: password);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _firebaseAuth.signOut();
      currentUserInternal = null;
      _logger.i('User logged out from Firebase');
    } catch (e) {
      _logger.e('Firebase logout failed: $e');
      // Fall back to local logout
      await super.logout();
    }
  }

  /// Grant patient consent and store in Firestore
  @override
  Future<PatientConsent> grantPatientConsent(
    String patientId,
    String providerId,
    List<String> dataScopes,
    DateTime? expiresAt,
  ) async {
    try {
      final consent = PatientConsent(
        consentId: _uuid.v4(),
        patientId: patientId,
        providerId: providerId,
        consentType: 'treatment',
        dataScopes: dataScopes,
        grantedAt: DateTime.now(),
        expiresAt: expiresAt,
        isActive: true,
        blockchainTxId: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        consentDetails: {
          'grantedBy': currentUserInternal?.id,
          'reason': 'Patient consent for treatment',
          'ipAddress': '192.168.1.1', // In production, get real IP
        },
      );

      // Store in Firestore
      await _firestore
          .collection(_consentsCollection)
          .doc(consent.consentId)
          .set(consent.toJson());

      _logger.i('Patient consent stored in Firestore: ${consent.consentId}');
      return consent;
    } catch (e) {
      _logger.e('Failed to store consent in Firestore: $e');
      // Fall back to local storage
      return await super.grantPatientConsent(
        patientId,
        providerId,
        dataScopes,
        expiresAt,
      );
    }
  }

  /// Get patient consents from Firestore
  @override
  List<PatientConsent> getPatientConsents(String patientId) {
    // For real-time data, we should use streams, but for now return cached data
    // In production, implement proper Firestore queries
    return super.getPatientConsents(patientId);
  }

  /// Get patient consents from Firestore (async version)
  Future<List<PatientConsent>> getPatientConsentsFromFirestore(
    String patientId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_consentsCollection)
          .where('patientId', isEqualTo: patientId)
          .where('isActive', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => PatientConsent.fromJson(doc.data()))
          .toList();
    } catch (e) {
      _logger.e('Failed to get consents from Firestore: $e');
      return [];
    }
  }

  /// Revoke patient consent in Firestore
  @override
  Future<void> revokePatientConsent(String patientId, String consentId) async {
    try {
      await _firestore.collection(_consentsCollection).doc(consentId).update({
        'isActive': false,
        'revokedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('Patient consent revoked in Firestore: $consentId');
    } catch (e) {
      _logger.e('Failed to revoke consent in Firestore: $e');
      // Fall back to local revocation
      await super.revokePatientConsent(patientId, consentId);
    }
  }

  /// Store audit log in Firestore
  Future<void> storeAuditLogInFirestore({
    required String category,
    required String eventType,
    required String userId,
    required String ipAddress,
    String? resourceId,
    String? patientId,
    bool success = true,
    String? errorMessage,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final auditLog = {
        'id': _uuid.v4(),
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
        'eventType': eventType,
        'userId': userId,
        'resourceId': resourceId,
        'ipAddress': ipAddress,
        'patientId': patientId,
        'success': success,
        'errorMessage': errorMessage,
        'additionalData': additionalData ?? {},
      };

      await _firestore.collection(_auditLogsCollection).add(auditLog);
      _logger.i('Audit log stored in Firestore: $eventType');
    } catch (e) {
      _logger.e('Failed to store audit log in Firestore: $e');
    }
  }

  /// Get audit logs from Firestore
  Future<List<Map<String, dynamic>>> getAuditLogsFromFirestore({
    String? userId,
    String? patientId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore.collection(_auditLogsCollection);

      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      if (patientId != null) {
        query = query.where('patientId', isEqualTo: patientId);
      }
      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final querySnapshot = await query.get();
      return querySnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      _logger.e('Failed to get audit logs from Firestore: $e');
      return [];
    }
  }

  // Private helper methods

  Future<void> _loadUserFromFirestore(String userId) async {
    try {
      final doc = await _firestore
          .collection(_usersCollection)
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        currentUserInternal = User.fromJson(doc.data()!);
        _logger.i('User loaded from Firestore: ${currentUserInternal!.name}');
      }
    } catch (e) {
      _logger.e('Failed to load user from Firestore: $e');
    }
  }

  Future<void> _updateLastLogin(String userId) async {
    try {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('Failed to update last login in Firestore: $e');
    }
  }

  /// Create demo users in Firestore
  Future<void> createDemoUsersInFirestore() async {
    try {
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
        // Check if user already exists
        final existingUser = await _firestore
            .collection(_usersCollection)
            .where('email', isEqualTo: userData['email'])
            .get();

        if (existingUser.docs.isEmpty) {
          // Create Firebase user
          try {
            final credential = await _firebaseAuth
                .createUserWithEmailAndPassword(
                  email: userData['email'] as String,
                  password: 'demo123',
                );

            if (credential.user != null) {
              // Create user document
              final user = User(
                id: credential.user!.uid,
                name: userData['name'] as String,
                email: userData['email'] as String,
                role: userData['role'] as UserRole,
                phoneNumber: userData['phoneNumber'] as String?,
                dateOfBirth: userData['dateOfBirth'] as DateTime?,
                emergencyContact: userData['emergencyContact'] as String?,
                medicalId: userData['medicalId'] as String?,
                createdAt: DateTime.now(),
                lastLoginAt: DateTime.now(),
                isActive: true,
              );

              await _firestore
                  .collection(_usersCollection)
                  .doc(user.id)
                  .set(user.toJson());
              _logger.i('Demo user created in Firestore: ${user.email}');
            }
          } catch (e) {
            _logger.w(
              'Demo user already exists or creation failed: ${userData['email']} - $e',
            );
          }
        }
      }

      _logger.i('Demo users setup completed in Firestore');
    } catch (e) {
      _logger.e('Failed to create demo users in Firestore: $e');
    }
  }
}
