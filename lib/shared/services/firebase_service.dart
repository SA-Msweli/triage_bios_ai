import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:logger/logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final Logger _logger = Logger();
  FirebaseFirestore? _firestore;
  firebase_auth.FirebaseAuth? _firebaseAuth;

  /// Initialize Firebase (called from main.dart)
  Future<void> initialize() async {
    try {
      // Firebase is already initialized in main.dart
      // This method just sets up the service instances

      _firestore = FirebaseFirestore.instance;
      _firebaseAuth = firebase_auth.FirebaseAuth.instance;

      // Configure Firestore settings
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _logger.i('Firebase initialized successfully');
    } catch (e) {
      _logger.e('Firebase initialization failed: $e');
      rethrow;
    }
  }

  /// Get Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firestore!;
  }

  /// Get Firebase Auth instance
  firebase_auth.FirebaseAuth get auth {
    if (_firebaseAuth == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firebaseAuth!;
  }

  /// Check if Firebase is initialized
  bool get isInitialized => _firestore != null && _firebaseAuth != null;
}
