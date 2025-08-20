import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'integrated_auth_service.dart';
import 'auth_service.dart';

/// Single Sign-On service supporting SAML 2.0 and OAuth2/OpenID Connect
class SsoService extends IntegratedAuthService {
  static final SsoService _instance = SsoService._internal();
  factory SsoService() => _instance;
  SsoService._internal() : super();

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  static const String _ssoConfigKey = 'sso_config';

  SsoConfig? _config;
  bool _isInitialized = false;
  final Map<String, SsoSession> _activeSessions = {};

  /// Configure SSO service with configuration
  Future<void> configureSso(SsoConfig config) async {
    try {
      _config = config;
      _isInitialized = true;

      // Save configuration
      await _saveConfig();

      _logger.i('SSO service initialized for provider: ${config.providerName}');
    } catch (e) {
      _logger.e('Failed to initialize SSO service: $e');
      rethrow;
    }
  }

  /// Initiate SAML 2.0 authentication
  Future<SamlAuthRequest> initiateSamlAuth({
    String? relayState,
    bool forceAuth = false,
  }) async {
    if (!_isInitialized || _config == null) {
      throw Exception('SSO service not initialized');
    }

    if (_config!.protocol != SsoProtocol.saml) {
      throw Exception('SAML not configured for this provider');
    }

    try {
      final requestId = _uuid.v4();
      final timestamp = DateTime.now().toUtc().toIso8601String();

      // Generate SAML AuthnRequest
      final authnRequest = _generateSamlAuthnRequest(
        requestId: requestId,
        timestamp: timestamp,
        forceAuth: forceAuth,
      );

      // Create SSO session
      final session = SsoSession(
        sessionId: requestId,
        providerId: _config!.providerId,
        protocol: SsoProtocol.saml,
        state: relayState,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      _activeSessions[requestId] = session;

      // Generate redirect URL
      final redirectUrl = _buildSamlRedirectUrl(authnRequest);

      _logger.i(
        'SAML authentication initiated for provider: ${_config!.providerName}',
      );

      return SamlAuthRequest(
        requestId: requestId,
        authnRequest: authnRequest,
        redirectUrl: redirectUrl,
        relayState: relayState,
      );
    } catch (e) {
      _logger.e('Failed to initiate SAML authentication: $e');
      rethrow;
    }
  }

  /// Process SAML response
  Future<SsoAuthResult> processSamlResponse(
    String samlResponse,
    String? relayState,
  ) async {
    if (!_isInitialized || _config == null) {
      throw Exception('SSO service not initialized');
    }

    try {
      _logger.i('Processing SAML response');

      // Decode and validate SAML response
      final decodedResponse = _decodeSamlResponse(samlResponse);
      final validationResult = _validateSamlResponse(decodedResponse);

      if (!validationResult.isValid) {
        return SsoAuthResult.error(
          'SAML response validation failed: ${validationResult.error}',
        );
      }

      // Extract user information
      final userInfo = _extractSamlUserInfo(decodedResponse);

      // Create or update user
      final user = await _createOrUpdateUserFromSso(userInfo);

      // Clean up session
      if (validationResult.inResponseTo != null) {
        _activeSessions.remove(validationResult.inResponseTo);
      }

      _logger.i('SAML authentication successful for user: ${user.email}');

      return SsoAuthResult.success(user, userInfo);
    } catch (e) {
      _logger.e('SAML response processing failed: $e');
      return SsoAuthResult.error('SAML authentication failed: $e');
    }
  }

  /// Initiate OAuth2/OpenID Connect authentication
  Future<OAuthAuthRequest> initiateOAuthAuth({
    List<String>? scopes,
    String? state,
  }) async {
    if (!_isInitialized || _config == null) {
      throw Exception('SSO service not initialized');
    }

    if (_config!.protocol != SsoProtocol.oauth2 &&
        _config!.protocol != SsoProtocol.oidc) {
      throw Exception('OAuth2/OIDC not configured for this provider');
    }

    try {
      final sessionId = _uuid.v4();
      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);
      final nonce = _generateNonce();

      // Create SSO session
      final session = SsoSession(
        sessionId: sessionId,
        providerId: _config!.providerId,
        protocol: _config!.protocol,
        state: state,
        codeVerifier: codeVerifier,
        nonce: nonce,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      );

      _activeSessions[sessionId] = session;

      // Build authorization URL
      final authUrl = _buildOAuthAuthUrl(
        state: sessionId,
        codeChallenge: codeChallenge,
        nonce: nonce,
        scopes: scopes ?? ['openid', 'profile', 'email'],
      );

      _logger.i(
        'OAuth2/OIDC authentication initiated for provider: ${_config!.providerName}',
      );

      return OAuthAuthRequest(
        sessionId: sessionId,
        authorizationUrl: authUrl,
        codeVerifier: codeVerifier,
        nonce: nonce,
        state: state,
      );
    } catch (e) {
      _logger.e('Failed to initiate OAuth2/OIDC authentication: $e');
      rethrow;
    }
  }

  /// Process OAuth2 authorization code
  Future<SsoAuthResult> processOAuthCallback(String code, String state) async {
    if (!_isInitialized || _config == null) {
      throw Exception('SSO service not initialized');
    }

    try {
      _logger.i('Processing OAuth2 callback');

      // Find session
      final session = _activeSessions[state];
      if (session == null) {
        return SsoAuthResult.error('Invalid or expired OAuth2 session');
      }

      // Exchange code for tokens
      final tokenResponse = await _exchangeCodeForTokens(code, session);
      if (tokenResponse == null) {
        return SsoAuthResult.error(
          'Failed to exchange authorization code for tokens',
        );
      }

      // Validate ID token if present (OIDC)
      SsoUserInfo? userInfo;
      if (tokenResponse.idToken != null) {
        userInfo = _validateAndExtractIdToken(
          tokenResponse.idToken!,
          session.nonce,
        );
      }

      // Get user info from userinfo endpoint if needed
      userInfo ??= await _getUserInfoFromEndpoint(tokenResponse.accessToken);

      if (userInfo == null) {
        return SsoAuthResult.error('Failed to retrieve user information');
      }

      // Create or update user
      final user = await _createOrUpdateUserFromSso(userInfo);

      // Clean up session
      _activeSessions.remove(state);

      _logger.i(
        'OAuth2/OIDC authentication successful for user: ${user.email}',
      );

      return SsoAuthResult.success(user, userInfo);
    } catch (e) {
      _logger.e('OAuth2 callback processing failed: $e');
      return SsoAuthResult.error('OAuth2 authentication failed: $e');
    }
  }

  /// Get SSO configuration
  SsoConfig? get config => _config;

  /// Check if SSO is configured
  bool get isConfigured => _isInitialized && _config != null;

  /// Get active sessions count
  int get activeSessionsCount => _activeSessions.length;

  /// Clean up expired sessions
  void cleanupExpiredSessions() {
    final now = DateTime.now();
    _activeSessions.removeWhere(
      (key, session) => now.isAfter(session.expiresAt),
    );
  }

  // Private methods

  String _generateSamlAuthnRequest({
    required String requestId,
    required String timestamp,
    required bool forceAuth,
  }) {
    // In a real implementation, this would generate a proper SAML AuthnRequest XML
    // For demo purposes, we'll create a simplified structure
    final authnRequest =
        '''
<?xml version="1.0" encoding="UTF-8"?>
<samlp:AuthnRequest
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    ID="$requestId"
    Version="2.0"
    IssueInstant="$timestamp"
    Destination="${_config!.ssoUrl}"
    AssertionConsumerServiceURL="${_config!.callbackUrl}"
    ForceAuthn="$forceAuth">
    <saml:Issuer>${_config!.entityId}</saml:Issuer>
</samlp:AuthnRequest>
''';

    // Base64 encode the request
    return base64Encode(utf8.encode(authnRequest));
  }

  String _buildSamlRedirectUrl(String authnRequest) {
    final params = {
      'SAMLRequest': authnRequest,
      'RelayState': _config!.entityId,
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '${_config!.ssoUrl}?$queryString';
  }

  Map<String, dynamic> _decodeSamlResponse(String samlResponse) {
    // In a real implementation, this would properly decode and parse SAML XML
    // For demo purposes, we'll simulate a decoded response
    try {
      final decoded = utf8.decode(base64Decode(samlResponse));
      return {
        'response': decoded,
        'attributes': {
          'email': 'user@hospital.com',
          'firstName': 'John',
          'lastName': 'Doe',
          'groups': ['Doctors', 'Staff'],
        },
        'nameId': 'user@hospital.com',
        'sessionIndex': _uuid.v4(),
      };
    } catch (e) {
      throw Exception('Invalid SAML response format');
    }
  }

  SamlValidationResult _validateSamlResponse(Map<String, dynamic> response) {
    // In a real implementation, this would validate signatures, timestamps, etc.
    // For demo purposes, we'll perform basic validation
    try {
      if (!response.containsKey('attributes') ||
          !response.containsKey('nameId')) {
        return SamlValidationResult(false, 'Missing required SAML attributes');
      }

      return SamlValidationResult(true, null, inResponseTo: _uuid.v4());
    } catch (e) {
      return SamlValidationResult(false, 'SAML validation error: $e');
    }
  }

  SsoUserInfo _extractSamlUserInfo(Map<String, dynamic> response) {
    final attributes = response['attributes'] as Map<String, dynamic>;

    return SsoUserInfo(
      id: response['nameId'] as String,
      email: attributes['email'] as String,
      firstName: attributes['firstName'] as String?,
      lastName: attributes['lastName'] as String?,
      displayName: '${attributes['firstName']} ${attributes['lastName']}',
      groups: List<String>.from(attributes['groups'] as List? ?? []),
      provider: _config!.providerId,
      rawAttributes: attributes,
    );
  }

  String _buildOAuthAuthUrl({
    required String state,
    required String codeChallenge,
    required String nonce,
    required List<String> scopes,
  }) {
    final params = {
      'response_type': 'code',
      'client_id': _config!.clientId!,
      'redirect_uri': _config!.callbackUrl,
      'scope': scopes.join(' '),
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'nonce': nonce,
    };

    final queryString = params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    return '${_config!.ssoUrl}?$queryString';
  }

  Future<OAuthTokenResponse?> _exchangeCodeForTokens(
    String code,
    SsoSession session,
  ) async {
    // In a real implementation, this would make an HTTP POST to the token endpoint
    // For demo purposes, we'll simulate a token response
    await Future.delayed(const Duration(milliseconds: 500));

    return OAuthTokenResponse(
      accessToken: 'demo_access_token_${_uuid.v4()}',
      refreshToken: 'demo_refresh_token_${_uuid.v4()}',
      idToken: _generateDemoIdToken(session.nonce),
      tokenType: 'Bearer',
      expiresIn: 3600,
    );
  }

  String _generateDemoIdToken(String? nonce) {
    final header = {'alg': 'RS256', 'typ': 'JWT'};
    final payload = {
      'iss': _config!.providerId,
      'sub': 'user123',
      'aud': _config!.clientId,
      'exp':
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
          1000,
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'nonce': nonce,
      'email': 'user@hospital.com',
      'given_name': 'John',
      'family_name': 'Doe',
      'groups': ['Doctors', 'Staff'],
    };

    final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
    final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
    final signature = 'demo_signature';

    return '$encodedHeader.$encodedPayload.$signature';
  }

  SsoUserInfo? _validateAndExtractIdToken(
    String idToken,
    String? expectedNonce,
  ) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;

      final payload =
          json.decode(utf8.decode(base64Url.decode(parts[1])))
              as Map<String, dynamic>;

      // Validate nonce if provided
      if (expectedNonce != null && payload['nonce'] != expectedNonce) {
        throw Exception('Invalid nonce in ID token');
      }

      return SsoUserInfo(
        id: payload['sub'] as String,
        email: payload['email'] as String,
        firstName: payload['given_name'] as String?,
        lastName: payload['family_name'] as String?,
        displayName: '${payload['given_name']} ${payload['family_name']}',
        groups: List<String>.from(payload['groups'] as List? ?? []),
        provider: _config!.providerId,
        rawAttributes: payload,
      );
    } catch (e) {
      _logger.e('Failed to validate ID token: $e');
      return null;
    }
  }

  Future<SsoUserInfo?> _getUserInfoFromEndpoint(String accessToken) async {
    // In a real implementation, this would make an HTTP GET to the userinfo endpoint
    // For demo purposes, we'll simulate user info
    await Future.delayed(const Duration(milliseconds: 300));

    return SsoUserInfo(
      id: 'user123',
      email: 'user@hospital.com',
      firstName: 'John',
      lastName: 'Doe',
      displayName: 'John Doe',
      groups: ['Doctors', 'Staff'],
      provider: _config!.providerId,
      rawAttributes: {
        'sub': 'user123',
        'email': 'user@hospital.com',
        'given_name': 'John',
        'family_name': 'Doe',
      },
    );
  }

  Future<User> _createOrUpdateUserFromSso(SsoUserInfo userInfo) async {
    try {
      // Check if user already exists
      final existingUser = await getUserByEmailProtected(userInfo.email);

      // Map SSO groups to application roles
      final mappedRoles = _mapSsoGroupsToRoles(userInfo.groups);
      final primaryRole = mappedRoles.isNotEmpty
          ? mappedRoles.first
          : UserRole.patient;

      final user = User(
        id: existingUser?.id ?? userInfo.id,
        name: userInfo.displayName,
        email: userInfo.email,
        role: primaryRole,
        createdAt: existingUser?.createdAt ?? DateTime.now(),
        lastLoginAt: DateTime.now(),
        isActive: true,
      );

      if (existingUser != null) {
        // Update existing user
        await updateUserProtected(user);
        _logger.i('Updated existing user from SSO: ${user.email}');
      } else {
        // Create new user
        await storeUserProtected(user, 'sso_managed');
        _logger.i('Created new user from SSO: ${user.email}');
      }

      return user;
    } catch (e) {
      _logger.e('Failed to create/update user from SSO: $e');
      rethrow;
    }
  }

  List<UserRole> _mapSsoGroupsToRoles(List<String> groups) {
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

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateNonce() {
    return _uuid.v4();
  }

  Future<void> _saveConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_config != null) {
        await prefs.setString(_ssoConfigKey, json.encode(_config!.toJson()));
      }
    } catch (e) {
      _logger.e('Failed to save SSO configuration: $e');
    }
  }
}

/// SSO configuration model
class SsoConfig {
  final String providerId;
  final String providerName;
  final SsoProtocol protocol;
  final String ssoUrl;
  final String callbackUrl;
  final String entityId;
  final String? clientId;
  final String? clientSecret;
  final String? tokenUrl;
  final String? userInfoUrl;
  final Map<String, String> additionalParams;

  SsoConfig({
    required this.providerId,
    required this.providerName,
    required this.protocol,
    required this.ssoUrl,
    required this.callbackUrl,
    required this.entityId,
    this.clientId,
    this.clientSecret,
    this.tokenUrl,
    this.userInfoUrl,
    this.additionalParams = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'providerId': providerId,
      'providerName': providerName,
      'protocol': protocol.name,
      'ssoUrl': ssoUrl,
      'callbackUrl': callbackUrl,
      'entityId': entityId,
      'clientId': clientId,
      'clientSecret': clientSecret,
      'tokenUrl': tokenUrl,
      'userInfoUrl': userInfoUrl,
      'additionalParams': additionalParams,
    };
  }

  factory SsoConfig.fromJson(Map<String, dynamic> json) {
    return SsoConfig(
      providerId: json['providerId'] as String,
      providerName: json['providerName'] as String,
      protocol: SsoProtocol.values.firstWhere(
        (p) => p.name == json['protocol'],
      ),
      ssoUrl: json['ssoUrl'] as String,
      callbackUrl: json['callbackUrl'] as String,
      entityId: json['entityId'] as String,
      clientId: json['clientId'] as String?,
      clientSecret: json['clientSecret'] as String?,
      tokenUrl: json['tokenUrl'] as String?,
      userInfoUrl: json['userInfoUrl'] as String?,
      additionalParams: Map<String, String>.from(
        json['additionalParams'] as Map? ?? {},
      ),
    );
  }
}

/// SSO protocols
enum SsoProtocol { saml, oauth2, oidc }

/// SSO session model
class SsoSession {
  final String sessionId;
  final String providerId;
  final SsoProtocol protocol;
  final String? state;
  final String? codeVerifier;
  final String? nonce;
  final DateTime createdAt;
  final DateTime expiresAt;

  SsoSession({
    required this.sessionId,
    required this.providerId,
    required this.protocol,
    this.state,
    this.codeVerifier,
    this.nonce,
    required this.createdAt,
    required this.expiresAt,
  });
}

/// SSO user information
class SsoUserInfo {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String displayName;
  final List<String> groups;
  final String provider;
  final Map<String, dynamic> rawAttributes;

  SsoUserInfo({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    required this.displayName,
    required this.groups,
    required this.provider,
    required this.rawAttributes,
  });
}

/// SSO authentication result
class SsoAuthResult {
  final bool success;
  final User? user;
  final SsoUserInfo? userInfo;
  final String? error;

  SsoAuthResult._({
    required this.success,
    this.user,
    this.userInfo,
    this.error,
  });

  factory SsoAuthResult.success(User user, SsoUserInfo userInfo) {
    return SsoAuthResult._(success: true, user: user, userInfo: userInfo);
  }

  factory SsoAuthResult.error(String error) {
    return SsoAuthResult._(success: false, error: error);
  }
}

/// SAML authentication request
class SamlAuthRequest {
  final String requestId;
  final String authnRequest;
  final String redirectUrl;
  final String? relayState;

  SamlAuthRequest({
    required this.requestId,
    required this.authnRequest,
    required this.redirectUrl,
    this.relayState,
  });
}

/// OAuth authentication request
class OAuthAuthRequest {
  final String sessionId;
  final String authorizationUrl;
  final String codeVerifier;
  final String nonce;
  final String? state;

  OAuthAuthRequest({
    required this.sessionId,
    required this.authorizationUrl,
    required this.codeVerifier,
    required this.nonce,
    this.state,
  });
}

/// OAuth token response
class OAuthTokenResponse {
  final String accessToken;
  final String? refreshToken;
  final String? idToken;
  final String tokenType;
  final int expiresIn;

  OAuthTokenResponse({
    required this.accessToken,
    this.refreshToken,
    this.idToken,
    required this.tokenType,
    required this.expiresIn,
  });
}

/// SAML validation result
class SamlValidationResult {
  final bool isValid;
  final String? error;
  final String? inResponseTo;

  SamlValidationResult(this.isValid, this.error, {this.inResponseTo});
}
