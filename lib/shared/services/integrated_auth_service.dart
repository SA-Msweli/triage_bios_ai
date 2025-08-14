import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'ldap_service.dart';

/// Enhanced authentication service with LDAP/Active Directory integration
class IntegratedAuthService extends AuthService {
  IntegratedAuthService() : super.forSubclass();

  final Logger _logger = Logger();
  final LdapService _ldapService = LdapService();

  static const String _ldapConfigKey = 'ldap_config';
  static const String _authModeKey = 'auth_mode';

  AuthenticationMode _authMode = AuthenticationMode.local;
  LdapConfig? _ldapConfig;
  bool _ldapFallbackEnabled = true;

  /// Initialize integrated authentication service
  @override
  Future<void> initialize() async {
    try {
      // Initialize base auth service
      await super.initialize();

      // Load LDAP configuration
      await _loadLdapConfig();

      // Initialize LDAP service if configured
      if (_ldapConfig != null && _authMode != AuthenticationMode.local) {
        try {
          await _ldapService.configureLdap(_ldapConfig!, _authMode);
          _logger.i('LDAP integration initialized successfully');
        } catch (e) {
          _logger.e(
            'LDAP initialization failed, falling back to local auth: $e',
          );
          if (_ldapFallbackEnabled) {
            _authMode = AuthenticationMode.local;
          } else {
            rethrow;
          }
        }
      }

      _logger.i(
        'Integrated auth service initialized with mode: ${_authMode.name}',
      );
    } catch (e) {
      _logger.e('Failed to initialize integrated auth service: $e');
      rethrow;
    }
  }

  /// Enhanced login with LDAP integration
  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      switch (_authMode) {
        case AuthenticationMode.ldapOnly:
          return await _loginWithLdap(email, password);

        case AuthenticationMode.ldapWithFallback:
          // Try LDAP first, fallback to local if it fails
          final ldapResult = await _loginWithLdap(email, password);
          if (ldapResult.success) {
            return ldapResult;
          }
          _logger.w('LDAP login failed, falling back to local authentication');
          return await super.login(email: email, password: password);

        case AuthenticationMode.local:
          return await super.login(email: email, password: password);
      }
    } catch (e) {
      _logger.e('Integrated login failed: $e');

      // Fallback to local authentication if LDAP fails and fallback is enabled
      if (_authMode != AuthenticationMode.local && _ldapFallbackEnabled) {
        _logger.i('Attempting local authentication fallback');
        return await super.login(email: email, password: password);
      }

      return AuthResult.error('Authentication failed: $e');
    }
  }

  /// Login with LDAP authentication
  Future<AuthResult> _loginWithLdap(String email, String password) async {
    try {
      // Extract username from email (assuming email format)
      final username = email.contains('@') ? email.split('@')[0] : email;

      final ldapResult = await _ldapService.authenticateUser(
        username,
        password,
      );

      if (ldapResult.success && ldapResult.ldapUser != null) {
        // Create or update local user from LDAP data
        final user = await _createOrUpdateUserFromLdap(ldapResult.ldapUser!);

        // Set as current user
        currentUserInternal = user;
        await saveCurrentUserProtected();

        // Log successful LDAP authentication
        await _logAuthEvent('ldap_login_success', user.id, {
          'username': username,
          'email': email,
        });

        _logger.i('LDAP authentication successful for user: $email');
        return AuthResult.success(user);
      } else {
        await _logAuthEvent('ldap_login_failed', email, {
          'username': username,
          'error': ldapResult.error,
        });

        return AuthResult.error(
          ldapResult.error ?? 'LDAP authentication failed',
        );
      }
    } catch (e) {
      _logger.e('LDAP login error: $e');
      await _logAuthEvent('ldap_login_error', email, {'error': e.toString()});
      return AuthResult.error('LDAP authentication error: $e');
    }
  }

  /// Create or update user from LDAP data
  Future<User> _createOrUpdateUserFromLdap(LdapUserDetails ldapUser) async {
    try {
      // Check if user already exists
      final existingUser = await getUserByEmailProtected(ldapUser.email);

      // Map LDAP groups to application roles
      final mappedRoles = _mapLdapGroupsToRoles(ldapUser.groups);
      final primaryRole = mappedRoles.isNotEmpty
          ? mappedRoles.first
          : UserRole.patient;

      final user = User(
        id: existingUser?.id ?? ldapUser.distinguishedName,
        name: ldapUser.displayName,
        email: ldapUser.email,
        role: primaryRole,
        phoneNumber: ldapUser.phoneNumber,
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: ldapUser.isActive,
      );

      if (existingUser != null) {
        // Update existing user
        await updateUserProtected(user);
        _logger.i('Updated existing user from LDAP: ${user.email}');
      } else {
        // Create new user
        await storeUserProtected(user, 'ldap_managed');
        _logger.i('Created new user from LDAP: ${user.email}');
      }

      return user;
    } catch (e) {
      _logger.e('Failed to create/update user from LDAP: $e');
      rethrow;
    }
  }

  /// Configure LDAP settings
  Future<bool> configureLdap(LdapConfig config, AuthenticationMode mode) async {
    try {
      _ldapConfig = config;
      _authMode = mode;

      // Test LDAP connection
      await _ldapService.configureLdap(config, mode);
      final connectionTest = await _ldapService.testConnection();

      if (!connectionTest) {
        throw Exception('LDAP connection test failed');
      }

      // Save configuration
      await _saveLdapConfig();

      _logger.i('LDAP configuration saved successfully');
      return true;
    } catch (e) {
      _logger.e('LDAP configuration failed: $e');
      return false;
    }
  }

  /// Synchronize users from LDAP
  Future<LdapSyncResult> synchronizeUsersFromLdap() async {
    if (_authMode == AuthenticationMode.local) {
      return LdapSyncResult.error('LDAP not configured');
    }

    try {
      _logger.i('Starting LDAP user synchronization');

      final syncResult = await _ldapService.synchronizeUsers();

      if (syncResult.success) {
        await _logAuthEvent('ldap_sync_success', 'system', {
          'successCount': syncResult.successCount,
          'errorCount': syncResult.errorCount,
        });
      } else {
        await _logAuthEvent('ldap_sync_failed', 'system', {
          'error': syncResult.error,
        });
      }

      return syncResult;
    } catch (e) {
      _logger.e('LDAP synchronization error: $e');
      return LdapSyncResult.error('Synchronization error: $e');
    }
  }

  /// Get authentication mode
  AuthenticationMode get authenticationMode => _authMode;

  /// Get LDAP configuration (without sensitive data)
  LdapConfig? get ldapConfig {
    if (_ldapConfig == null) return null;

    // Return config without sensitive information
    return LdapConfig(
      serverUrl: _ldapConfig!.serverUrl,
      port: _ldapConfig!.port,
      baseDn: _ldapConfig!.baseDn,
      bindDn: _ldapConfig!.bindDn,
      bindPassword: '***', // Hide password
      userSearchBase: _ldapConfig!.userSearchBase,
      userSearchFilter: _ldapConfig!.userSearchFilter,
      groupSearchBase: _ldapConfig!.groupSearchBase,
      groupSearchFilter: _ldapConfig!.groupSearchFilter,
      useSSL: _ldapConfig!.useSSL,
      useStartTLS: _ldapConfig!.useStartTLS,
      connectionTimeout: _ldapConfig!.connectionTimeout,
      groupRoleMapping: _ldapConfig!.groupRoleMapping,
    );
  }

  /// Get LDAP sync status
  LdapSyncStatus getLdapSyncStatus() {
    return _ldapService.getSyncStatus();
  }

  /// Test LDAP connection
  Future<bool> testLdapConnection() async {
    if (_authMode == AuthenticationMode.local) return false;
    return await _ldapService.testConnection();
  }

  /// Enable/disable LDAP fallback
  void setLdapFallback(bool enabled) {
    _ldapFallbackEnabled = enabled;
    _logger.i('LDAP fallback ${enabled ? 'enabled' : 'disabled'}');
  }

  // Private methods

  Future<void> _loadLdapConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load authentication mode
      final authModeString = prefs.getString(_authModeKey);
      if (authModeString != null) {
        _authMode = AuthenticationMode.values.firstWhere(
          (mode) => mode.name == authModeString,
          orElse: () => AuthenticationMode.local,
        );
      }

      // Load LDAP configuration
      final configJson = prefs.getString(_ldapConfigKey);
      if (configJson != null) {
        final configData = jsonDecode(configJson) as Map<String, dynamic>;
        _ldapConfig = LdapConfig.fromJson(configData);
      }

      _logger.i('Loaded LDAP configuration: mode=${_authMode.name}');
    } catch (e) {
      _logger.e('Failed to load LDAP configuration: $e');
      _authMode = AuthenticationMode.local;
    }
  }

  Future<void> _saveLdapConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save authentication mode
      await prefs.setString(_authModeKey, _authMode.name);

      // Save LDAP configuration
      if (_ldapConfig != null) {
        await prefs.setString(
          _ldapConfigKey,
          jsonEncode(_ldapConfig!.toJson()),
        );
      }

      _logger.i('Saved LDAP configuration');
    } catch (e) {
      _logger.e('Failed to save LDAP configuration: $e');
    }
  }

  List<UserRole> _mapLdapGroupsToRoles(List<String> groups) {
    final roles = <UserRole>[];

    // Use configured group mappings if available
    if (_ldapConfig?.groupRoleMapping.isNotEmpty == true) {
      for (final group in groups) {
        final role = _ldapConfig!.groupRoleMapping[group];
        if (role != null && !roles.contains(role)) {
          roles.add(role);
        }
      }
    }

    // Fallback to default mapping
    if (roles.isEmpty) {
      for (final group in groups) {
        final groupName = group.toLowerCase();

        if (groupName.contains('administrators') ||
            groupName.contains('admin')) {
          roles.add(UserRole.admin);
        } else if (groupName.contains('doctors') ||
            groupName.contains('physicians')) {
          roles.add(UserRole.healthcareProvider);
        } else if (groupName.contains('nurses') ||
            groupName.contains('staff')) {
          roles.add(UserRole.healthcareProvider);
        } else if (groupName.contains('caregivers')) {
          roles.add(UserRole.caregiver);
        }
      }
    }

    // Default to patient if no specific role found
    if (roles.isEmpty) {
      roles.add(UserRole.patient);
    }

    return roles;
  }

  Future<void> _logAuthEvent(
    String eventType,
    String userId,
    Map<String, dynamic> details,
  ) async {
    try {
      // In a real implementation, this would log to an audit system
      _logger.i('Auth event: $eventType for user: $userId, details: $details');
    } catch (e) {
      _logger.e('Failed to log auth event: $e');
    }
  }
}

/// Authentication modes
enum AuthenticationMode {
  local, // Local authentication only
  ldapOnly, // LDAP authentication only
  ldapWithFallback, // LDAP with local fallback
}

/// LDAP integration status
class LdapIntegrationStatus {
  final AuthenticationMode mode;
  final bool isConnected;
  final DateTime? lastSyncTime;
  final String? serverUrl;
  final String? error;

  LdapIntegrationStatus({
    required this.mode,
    required this.isConnected,
    this.lastSyncTime,
    this.serverUrl,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.name,
      'isConnected': isConnected,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
      'serverUrl': serverUrl,
      'error': error,
    };
  }
}
