import 'package:logger/logger.dart';
import 'integrated_auth_service.dart';
import 'auth_service.dart';

/// LDAP/Active Directory integration service for hospital identity systems
class LdapService extends IntegratedAuthService {
  static LdapService? _instance;
  factory LdapService() => _instance ??= LdapService._internal();
  LdapService._internal() : super();

  final Logger _logger = Logger();

  // LDAP Configuration
  LdapConfig? _config;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;

  /// Configure LDAP service with configuration
  @override
  Future<bool> configureLdap(LdapConfig config, AuthenticationMode mode) async {
    try {
      _config = config;

      // Test LDAP connection
      final connectionTest = await _testConnection();
      if (!connectionTest) {
        throw Exception('Failed to connect to LDAP server');
      }

      _isInitialized = true;
      _logger.i('LDAP service initialized successfully');
      return true;
    } catch (e) {
      _logger.e('Failed to initialize LDAP service: $e');
      return false;
    }
  }

  /// Authenticate user against LDAP/Active Directory
  Future<LdapAuthResult> authenticateUser(
    String username,
    String password,
  ) async {
    if (!_isInitialized || _config == null) {
      return LdapAuthResult.error('LDAP service not initialized');
    }

    try {
      _logger.i('Attempting LDAP authentication for user: $username');

      // In a real implementation, this would use an LDAP library like dart_ldap
      // For demo purposes, we'll simulate LDAP authentication
      final authResult = await _performLdapAuth(username, password);

      if (authResult.success) {
        // Get user details from LDAP
        final userDetails = await _getUserDetails(username);
        if (userDetails != null) {
          // Map LDAP groups to application roles
          final mappedRoles = _mapLdapGroupsToRoles(userDetails.groups);

          final user = User(
            id: userDetails.distinguishedName,
            name: userDetails.displayName,
            email: userDetails.email,
            role: mappedRoles.isNotEmpty ? mappedRoles.first : UserRole.patient,
            phoneNumber: userDetails.phoneNumber,
            createdAt: DateTime.now(),
            lastLoginAt: DateTime.now(),
            isActive: userDetails.isActive,
          );

          _logger.i('LDAP authentication successful for user: $username');
          return LdapAuthResult.success(user, userDetails);
        }
      }

      _logger.w('LDAP authentication failed for user: $username');
      return LdapAuthResult.error('Authentication failed');
    } catch (e) {
      _logger.e('LDAP authentication error: $e');
      return LdapAuthResult.error('Authentication error: $e');
    }
  }

  /// Synchronize users from LDAP/Active Directory
  Future<LdapSyncResult> synchronizeUsers() async {
    if (!_isInitialized || _config == null) {
      return LdapSyncResult.error('LDAP service not initialized');
    }

    try {
      _logger.i('Starting LDAP user synchronization');

      final users = await _getAllUsers();
      final syncResults = <String, bool>{};
      int successCount = 0;
      int errorCount = 0;

      for (final ldapUser in users) {
        try {
          // Check if user already exists
          final existingUser = await getUserByEmailProtected(ldapUser.email);

          final mappedRoles = _mapLdapGroupsToRoles(ldapUser.groups);
          final user = User(
            id: existingUser?.id ?? ldapUser.distinguishedName,
            name: ldapUser.displayName,
            email: ldapUser.email,
            role: mappedRoles.isNotEmpty ? mappedRoles.first : UserRole.patient,
            phoneNumber: ldapUser.phoneNumber,
            createdAt: existingUser?.createdAt ?? DateTime.now(),
            lastLoginAt: existingUser?.lastLoginAt ?? DateTime.now(),
            isActive: ldapUser.isActive,
          );

          if (existingUser != null) {
            // Update existing user
            await updateUserProtected(user);
          } else {
            // Create new user
            await storeUserProtected(user, 'ldap_managed');
          }

          syncResults[ldapUser.email] = true;
          successCount++;
        } catch (e) {
          _logger.e('Failed to sync user ${ldapUser.email}: $e');
          syncResults[ldapUser.email] = false;
          errorCount++;
        }
      }

      _lastSyncTime = DateTime.now();
      _logger.i(
        'LDAP synchronization completed: $successCount success, $errorCount errors',
      );

      return LdapSyncResult.success(syncResults, successCount, errorCount);
    } catch (e) {
      _logger.e('LDAP synchronization failed: $e');
      return LdapSyncResult.error('Synchronization failed: $e');
    }
  }

  /// Check if user exists in LDAP
  Future<bool> userExists(String username) async {
    if (!_isInitialized || _config == null) return false;

    try {
      final userDetails = await _getUserDetails(username);
      return userDetails != null;
    } catch (e) {
      _logger.e('Error checking user existence: $e');
      return false;
    }
  }

  /// Get user groups from LDAP
  Future<List<String>> getUserGroups(String username) async {
    if (!_isInitialized || _config == null) return [];

    try {
      final userDetails = await _getUserDetails(username);
      return userDetails?.groups ?? [];
    } catch (e) {
      _logger.e('Error getting user groups: $e');
      return [];
    }
  }

  /// Test LDAP connection
  Future<bool> testConnection() async {
    if (!_isInitialized || _config == null) return false;
    return await _testConnection();
  }

  /// Get synchronization status
  LdapSyncStatus getSyncStatus() {
    return LdapSyncStatus(
      isInitialized: _isInitialized,
      lastSyncTime: _lastSyncTime,
      serverUrl: _config?.serverUrl,
      baseDn: _config?.baseDn,
    );
  }

  // Private methods

  Future<bool> _testConnection() async {
    try {
      if (_config == null) return false;

      // In a real implementation, this would test the actual LDAP connection
      // For demo purposes, we'll simulate a connection test
      await Future.delayed(const Duration(milliseconds: 500));

      // Simulate connection success/failure based on server URL
      if (_config!.serverUrl.contains('localhost') ||
          _config!.serverUrl.contains('demo')) {
        return true;
      }

      // For real LDAP servers, we would attempt to bind
      return true;
    } catch (e) {
      _logger.e('LDAP connection test failed: $e');
      return false;
    }
  }

  Future<LdapAuthResult> _performLdapAuth(
    String username,
    String password,
  ) async {
    // In a real implementation, this would use LDAP bind operation
    // For demo purposes, we'll simulate authentication
    await Future.delayed(const Duration(milliseconds: 300));

    // Demo users that would exist in LDAP
    final demoUsers = {
      'jdoe': 'password123',
      'msmith': 'password123',
      'admin': 'admin123',
      'doctor1': 'doctor123',
    };

    if (demoUsers.containsKey(username) && demoUsers[username] == password) {
      return LdapAuthResult.success(null, null);
    }

    return LdapAuthResult.error('Invalid credentials');
  }

  Future<LdapUserDetails?> _getUserDetails(String username) async {
    // In a real implementation, this would query LDAP for user details
    // For demo purposes, we'll return mock data
    await Future.delayed(const Duration(milliseconds: 200));

    final demoUserDetails = {
      'jdoe': LdapUserDetails(
        distinguishedName: 'CN=John Doe,OU=Users,DC=hospital,DC=com',
        displayName: 'John Doe',
        email: 'john.doe@hospital.com',
        phoneNumber: '+1-555-0101',
        groups: [
          'CN=Doctors,OU=Groups,DC=hospital,DC=com',
          'CN=Staff,OU=Groups,DC=hospital,DC=com',
        ],
        isActive: true,
        department: 'Emergency Medicine',
        title: 'Emergency Physician',
      ),
      'msmith': LdapUserDetails(
        distinguishedName: 'CN=Mary Smith,OU=Users,DC=hospital,DC=com',
        displayName: 'Mary Smith',
        email: 'mary.smith@hospital.com',
        phoneNumber: '+1-555-0102',
        groups: [
          'CN=Nurses,OU=Groups,DC=hospital,DC=com',
          'CN=Staff,OU=Groups,DC=hospital,DC=com',
        ],
        isActive: true,
        department: 'Emergency Medicine',
        title: 'Registered Nurse',
      ),
      'admin': LdapUserDetails(
        distinguishedName: 'CN=Admin User,OU=Admins,DC=hospital,DC=com',
        displayName: 'Admin User',
        email: 'admin@hospital.com',
        phoneNumber: '+1-555-0103',
        groups: [
          'CN=Administrators,OU=Groups,DC=hospital,DC=com',
          'CN=IT Staff,OU=Groups,DC=hospital,DC=com',
        ],
        isActive: true,
        department: 'IT',
        title: 'System Administrator',
      ),
      'doctor1': LdapUserDetails(
        distinguishedName: 'CN=Dr. Wilson,OU=Users,DC=hospital,DC=com',
        displayName: 'Dr. Sarah Wilson',
        email: 'sarah.wilson@hospital.com',
        phoneNumber: '+1-555-0104',
        groups: [
          'CN=Doctors,OU=Groups,DC=hospital,DC=com',
          'CN=Senior Staff,OU=Groups,DC=hospital,DC=com',
        ],
        isActive: true,
        department: 'Cardiology',
        title: 'Cardiologist',
      ),
    };

    return demoUserDetails[username];
  }

  Future<List<LdapUserDetails>> _getAllUsers() async {
    // In a real implementation, this would query all users from LDAP
    // For demo purposes, we'll return mock data
    await Future.delayed(const Duration(seconds: 1));

    return [
      LdapUserDetails(
        distinguishedName: 'CN=John Doe,OU=Users,DC=hospital,DC=com',
        displayName: 'John Doe',
        email: 'john.doe@hospital.com',
        phoneNumber: '+1-555-0101',
        groups: ['CN=Doctors,OU=Groups,DC=hospital,DC=com'],
        isActive: true,
        department: 'Emergency Medicine',
        title: 'Emergency Physician',
      ),
      LdapUserDetails(
        distinguishedName: 'CN=Mary Smith,OU=Users,DC=hospital,DC=com',
        displayName: 'Mary Smith',
        email: 'mary.smith@hospital.com',
        phoneNumber: '+1-555-0102',
        groups: ['CN=Nurses,OU=Groups,DC=hospital,DC=com'],
        isActive: true,
        department: 'Emergency Medicine',
        title: 'Registered Nurse',
      ),
    ];
  }

  List<UserRole> _mapLdapGroupsToRoles(List<String> groups) {
    final roles = <UserRole>[];

    for (final group in groups) {
      final groupName = group.toLowerCase();

      if (groupName.contains('administrators') || groupName.contains('admin')) {
        roles.add(UserRole.admin);
      } else if (groupName.contains('doctors') ||
          groupName.contains('physicians')) {
        roles.add(UserRole.healthcareProvider);
      } else if (groupName.contains('nurses') || groupName.contains('staff')) {
        roles.add(UserRole.healthcareProvider);
      } else if (groupName.contains('caregivers')) {
        roles.add(UserRole.caregiver);
      }
    }

    // Default to patient if no specific role found
    if (roles.isEmpty) {
      roles.add(UserRole.patient);
    }

    return roles;
  }
}

/// LDAP configuration model
class LdapConfig {
  final String serverUrl;
  final int port;
  final String baseDn;
  final String bindDn;
  final String bindPassword;
  final String userSearchBase;
  final String userSearchFilter;
  final String groupSearchBase;
  final String groupSearchFilter;
  final bool useSSL;
  final bool useStartTLS;
  final Duration connectionTimeout;
  final Map<String, UserRole> groupRoleMapping;

  LdapConfig({
    required this.serverUrl,
    this.port = 389,
    required this.baseDn,
    required this.bindDn,
    required this.bindPassword,
    required this.userSearchBase,
    this.userSearchFilter = '(sAMAccountName={username})',
    required this.groupSearchBase,
    this.groupSearchFilter = '(member={userDn})',
    this.useSSL = false,
    this.useStartTLS = true,
    this.connectionTimeout = const Duration(seconds: 30),
    this.groupRoleMapping = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'serverUrl': serverUrl,
      'port': port,
      'baseDn': baseDn,
      'bindDn': bindDn,
      'userSearchBase': userSearchBase,
      'userSearchFilter': userSearchFilter,
      'groupSearchBase': groupSearchBase,
      'groupSearchFilter': groupSearchFilter,
      'useSSL': useSSL,
      'useStartTLS': useStartTLS,
      'connectionTimeout': connectionTimeout.inSeconds,
      'groupRoleMapping': groupRoleMapping.map((k, v) => MapEntry(k, v.name)),
    };
  }

  factory LdapConfig.fromJson(Map<String, dynamic> json) {
    return LdapConfig(
      serverUrl: json['serverUrl'] as String,
      port: json['port'] as int? ?? 389,
      baseDn: json['baseDn'] as String,
      bindDn: json['bindDn'] as String,
      bindPassword: json['bindPassword'] as String,
      userSearchBase: json['userSearchBase'] as String,
      userSearchFilter:
          json['userSearchFilter'] as String? ?? '(sAMAccountName={username})',
      groupSearchBase: json['groupSearchBase'] as String,
      groupSearchFilter:
          json['groupSearchFilter'] as String? ?? '(member={userDn})',
      useSSL: json['useSSL'] as bool? ?? false,
      useStartTLS: json['useStartTLS'] as bool? ?? true,
      connectionTimeout: Duration(
        seconds: json['connectionTimeout'] as int? ?? 30,
      ),
      groupRoleMapping:
          (json['groupRoleMapping'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              UserRole.values.firstWhere((role) => role.name == v),
            ),
          ) ??
          {},
    );
  }
}

/// LDAP user details model
class LdapUserDetails {
  final String distinguishedName;
  final String displayName;
  final String email;
  final String? phoneNumber;
  final List<String> groups;
  final bool isActive;
  final String? department;
  final String? title;
  final Map<String, dynamic> additionalAttributes;

  LdapUserDetails({
    required this.distinguishedName,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    required this.groups,
    required this.isActive,
    this.department,
    this.title,
    this.additionalAttributes = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'distinguishedName': distinguishedName,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'groups': groups,
      'isActive': isActive,
      'department': department,
      'title': title,
      'additionalAttributes': additionalAttributes,
    };
  }

  factory LdapUserDetails.fromJson(Map<String, dynamic> json) {
    return LdapUserDetails(
      distinguishedName: json['distinguishedName'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      groups: List<String>.from(json['groups'] as List),
      isActive: json['isActive'] as bool,
      department: json['department'] as String?,
      title: json['title'] as String?,
      additionalAttributes:
          json['additionalAttributes'] as Map<String, dynamic>? ?? {},
    );
  }
}

/// LDAP authentication result
class LdapAuthResult {
  final bool success;
  final User? user;
  final LdapUserDetails? ldapUser;
  final String? error;

  LdapAuthResult._({
    required this.success,
    this.user,
    this.ldapUser,
    this.error,
  });

  factory LdapAuthResult.success(User? user, LdapUserDetails? ldapUser) {
    return LdapAuthResult._(success: true, user: user, ldapUser: ldapUser);
  }

  factory LdapAuthResult.error(String error) {
    return LdapAuthResult._(success: false, error: error);
  }
}

/// LDAP synchronization result
class LdapSyncResult {
  final bool success;
  final Map<String, bool>? userResults;
  final int? successCount;
  final int? errorCount;
  final String? error;

  LdapSyncResult._({
    required this.success,
    this.userResults,
    this.successCount,
    this.errorCount,
    this.error,
  });

  factory LdapSyncResult.success(
    Map<String, bool> userResults,
    int successCount,
    int errorCount,
  ) {
    return LdapSyncResult._(
      success: true,
      userResults: userResults,
      successCount: successCount,
      errorCount: errorCount,
    );
  }

  factory LdapSyncResult.error(String error) {
    return LdapSyncResult._(success: false, error: error);
  }
}

/// LDAP synchronization status
class LdapSyncStatus {
  final bool isInitialized;
  final DateTime? lastSyncTime;
  final String? serverUrl;
  final String? baseDn;

  LdapSyncStatus({
    required this.isInitialized,
    this.lastSyncTime,
    this.serverUrl,
    this.baseDn,
  });

  Map<String, dynamic> toJson() {
    return {
      'isInitialized': isInitialized,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'serverUrl': serverUrl,
      'baseDn': baseDn,
    };
  }
}
