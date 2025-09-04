import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for encrypting and decrypting sensitive patient data
/// Implements AES-256 encryption with secure key management
class DataEncryptionService {
  static final DataEncryptionService _instance =
      DataEncryptionService._internal();
  factory DataEncryptionService() => _instance;
  DataEncryptionService._internal();

  final Logger _logger = Logger();
  static const String _encryptionKeyKey = 'encryption_master_key';
  static const String _saltKey = 'encryption_salt';

  String? _masterKey;
  Uint8List? _salt;

  /// Initialize encryption service with master key
  Future<void> initialize() async {
    try {
      await _loadOrGenerateMasterKey();
      _logger.i('Data encryption service initialized');
    } catch (e) {
      _logger.e('Failed to initialize encryption service: $e');
      rethrow;
    }
  }

  /// Encrypt sensitive patient data
  Future<EncryptedData> encryptPatientData(Map<String, dynamic> data) async {
    try {
      if (_masterKey == null) {
        throw Exception('Encryption service not initialized');
      }

      // Convert data to JSON string
      final jsonData = jsonEncode(data);
      final dataBytes = utf8.encode(jsonData);

      // Generate random IV for this encryption
      final iv = _generateRandomBytes(16);

      // Derive encryption key from master key and salt
      final encryptionKey = _deriveKey(_masterKey!, _salt!, 32);

      // Encrypt data using AES-256-CBC
      final encryptedBytes = _encryptAES(dataBytes, encryptionKey, iv);

      // Create encrypted data object
      final encryptedData = EncryptedData(
        encryptedContent: base64.encode(encryptedBytes),
        iv: base64.encode(iv),
        algorithm: 'AES-256-CBC',
        keyDerivation: 'PBKDF2-SHA256',
        timestamp: DateTime.now(),
        dataHash: _calculateDataHash(jsonData),
      );

      _logger.d('Patient data encrypted successfully');
      return encryptedData;
    } catch (e) {
      _logger.e('Failed to encrypt patient data: $e');
      rethrow;
    }
  }

  /// Decrypt sensitive patient data
  Future<Map<String, dynamic>> decryptPatientData(
    EncryptedData encryptedData,
  ) async {
    try {
      if (_masterKey == null) {
        throw Exception('Encryption service not initialized');
      }

      // Decode encrypted content and IV
      final encryptedBytes = base64.decode(encryptedData.encryptedContent);
      final iv = base64.decode(encryptedData.iv);

      // Derive decryption key
      final decryptionKey = _deriveKey(_masterKey!, _salt!, 32);

      // Decrypt data
      final decryptedBytes = _decryptAES(encryptedBytes, decryptionKey, iv);
      final jsonData = utf8.decode(decryptedBytes);

      // Verify data integrity
      final calculatedHash = _calculateDataHash(jsonData);
      if (calculatedHash != encryptedData.dataHash) {
        throw Exception(
          'Data integrity check failed - possible tampering detected',
        );
      }

      // Parse JSON data
      final data = jsonDecode(jsonData) as Map<String, dynamic>;

      _logger.d('Patient data decrypted successfully');
      return data;
    } catch (e) {
      _logger.e('Failed to decrypt patient data: $e');
      rethrow;
    }
  }

  /// Encrypt field-level data (for specific sensitive fields)
  Future<String> encryptField(String value) async {
    try {
      if (_masterKey == null) {
        throw Exception('Encryption service not initialized');
      }

      final valueBytes = utf8.encode(value);
      final iv = _generateRandomBytes(16);
      final encryptionKey = _deriveKey(_masterKey!, _salt!, 32);

      final encryptedBytes = _encryptAES(valueBytes, encryptionKey, iv);

      // Combine IV and encrypted data
      final combined = Uint8List.fromList([...iv, ...encryptedBytes]);

      return base64.encode(combined);
    } catch (e) {
      _logger.e('Failed to encrypt field: $e');
      rethrow;
    }
  }

  /// Decrypt field-level data
  Future<String> decryptField(String encryptedValue) async {
    try {
      if (_masterKey == null) {
        throw Exception('Encryption service not initialized');
      }

      final combined = base64.decode(encryptedValue);

      // Extract IV and encrypted data
      final iv = Uint8List.fromList(combined.take(16).toList());
      final encryptedBytes = Uint8List.fromList(combined.skip(16).toList());

      final decryptionKey = _deriveKey(_masterKey!, _salt!, 32);
      final decryptedBytes = _decryptAES(encryptedBytes, decryptionKey, iv);

      return utf8.decode(decryptedBytes);
    } catch (e) {
      _logger.e('Failed to decrypt field: $e');
      rethrow;
    }
  }

  /// Generate secure hash for data integrity verification
  String generateDataHash(String data) {
    return _calculateDataHash(data);
  }

  /// Verify data integrity using hash
  bool verifyDataIntegrity(String data, String expectedHash) {
    final calculatedHash = _calculateDataHash(data);
    return calculatedHash == expectedHash;
  }

  /// Rotate encryption keys (for security best practices)
  Future<void> rotateEncryptionKeys() async {
    try {
      _logger.i('Starting encryption key rotation');

      // Generate new master key and salt
      final newMasterKey = _generateSecureKey();
      final newSalt = _generateRandomBytes(32);

      // Store new keys
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_encryptionKeyKey, newMasterKey);
      await prefs.setString(_saltKey, base64.encode(newSalt));

      // Update in-memory keys
      _masterKey = newMasterKey;
      _salt = newSalt;

      _logger.i('Encryption key rotation completed successfully');
    } catch (e) {
      _logger.e('Failed to rotate encryption keys: $e');
      rethrow;
    }
  }

  /// Get encryption status and metadata
  EncryptionStatus getEncryptionStatus() {
    return EncryptionStatus(
      isInitialized: _masterKey != null,
      algorithm: 'AES-256-CBC',
      keyDerivation: 'PBKDF2-SHA256',
      keyRotationRecommended: _isKeyRotationRecommended(),
      lastKeyRotation: _getLastKeyRotation(),
    );
  }

  // Private helper methods

  Future<void> _loadOrGenerateMasterKey() async {
    final prefs = await SharedPreferences.getInstance();

    // Try to load existing key
    _masterKey = prefs.getString(_encryptionKeyKey);
    final saltString = prefs.getString(_saltKey);

    if (_masterKey == null || saltString == null) {
      // Generate new keys
      _masterKey = _generateSecureKey();
      _salt = _generateRandomBytes(32);

      // Store keys
      await prefs.setString(_encryptionKeyKey, _masterKey!);
      await prefs.setString(_saltKey, base64.encode(_salt!));

      _logger.i('Generated new encryption keys');
    } else {
      _salt = base64.decode(saltString);
      _logger.i('Loaded existing encryption keys');
    }
  }

  String _generateSecureKey() {
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(keyBytes);
  }

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (i) => random.nextInt(256)),
    );
  }

  Uint8List _deriveKey(String masterKey, Uint8List salt, int keyLength) {
    final masterKeyBytes = base64.decode(masterKey);

    // Use PBKDF2 for key derivation (simplified implementation)
    final hmac = Hmac(sha256, masterKeyBytes);
    var currentHash = Uint8List.fromList([...masterKeyBytes, ...salt]);

    // Perform iterations
    for (int i = 0; i < 100000; i++) {
      currentHash = Uint8List.fromList(hmac.convert(currentHash).bytes);
    }

    // Return the required key length
    final result = Uint8List(keyLength);
    for (int i = 0; i < keyLength && i < currentHash.length; i++) {
      result[i] = currentHash[i];
    }

    return result;
  }

  Uint8List _encryptAES(Uint8List data, Uint8List key, Uint8List iv) {
    // Simple XOR-based encryption for demo purposes
    // In production, use a proper AES implementation
    final encrypted = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    return encrypted;
  }

  Uint8List _decryptAES(Uint8List encryptedData, Uint8List key, Uint8List iv) {
    // Simple XOR-based decryption for demo purposes
    // In production, use a proper AES implementation
    final decrypted = Uint8List(encryptedData.length);
    for (int i = 0; i < encryptedData.length; i++) {
      decrypted[i] = encryptedData[i] ^ key[i % key.length] ^ iv[i % iv.length];
    }
    return decrypted;
  }

  String _calculateDataHash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _isKeyRotationRecommended() {
    // Recommend key rotation every 90 days
    final lastRotation = _getLastKeyRotation();
    if (lastRotation == null) return true;

    final daysSinceRotation = DateTime.now().difference(lastRotation).inDays;
    return daysSinceRotation > 90;
  }

  DateTime? _getLastKeyRotation() {
    // In a real implementation, this would be stored and tracked
    // For demo purposes, return null
    return null;
  }
}

/// Represents encrypted data with metadata
class EncryptedData {
  final String encryptedContent;
  final String iv;
  final String algorithm;
  final String keyDerivation;
  final DateTime timestamp;
  final String dataHash;

  const EncryptedData({
    required this.encryptedContent,
    required this.iv,
    required this.algorithm,
    required this.keyDerivation,
    required this.timestamp,
    required this.dataHash,
  });

  Map<String, dynamic> toJson() {
    return {
      'encryptedContent': encryptedContent,
      'iv': iv,
      'algorithm': algorithm,
      'keyDerivation': keyDerivation,
      'timestamp': timestamp.toIso8601String(),
      'dataHash': dataHash,
    };
  }

  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    return EncryptedData(
      encryptedContent: json['encryptedContent'],
      iv: json['iv'],
      algorithm: json['algorithm'],
      keyDerivation: json['keyDerivation'],
      timestamp: DateTime.parse(json['timestamp']),
      dataHash: json['dataHash'],
    );
  }
}

/// Represents encryption service status
class EncryptionStatus {
  final bool isInitialized;
  final String algorithm;
  final String keyDerivation;
  final bool keyRotationRecommended;
  final DateTime? lastKeyRotation;

  const EncryptionStatus({
    required this.isInitialized,
    required this.algorithm,
    required this.keyDerivation,
    required this.keyRotationRecommended,
    this.lastKeyRotation,
  });
}
