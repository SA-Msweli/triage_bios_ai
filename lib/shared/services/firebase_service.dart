import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart'; // For Color
import 'package:logger/logger.dart';

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

  // --- Color Conversion Helper Methods ---
  String _colorToHexString(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0')}'; // ARGB format, e.g., #FFAABBCC
  }

  Color _hexStringToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 7) buffer.write('ff'); // Add alpha if only RGB like #RRGGBB
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // --- Hospital Dashboard Data Methods ---

  /// Seeds mock hospital dashboard data into Firestore.
  /// Clears existing patient queue before seeding new data.
  Future<void> seedHospitalDashboardData({
    required Map<String, dynamic> hospitalStats,
    required List<Map<String, dynamic>> patientQueue,
  }) async {
    if (!isInitialized) throw Exception('Firebase not initialized. Call initialize() first.');
    _logger.i('Seeding hospital dashboard data to Firestore...');

    try {
      // Seed Hospital Stats
      await firestore
          .collection('hospital_config')
          .doc('current_stats')
          .set(hospitalStats);
      _logger.d('Hospital stats seeded.');

      // Seed Patient Queue
      final WriteBatch batch = firestore.batch();
      final patientQueueCollection = firestore.collection('patient_queue');

      // Clear existing patient queue before seeding
      final existingPatients = await patientQueueCollection.get();
      for (final doc in existingPatients.docs) {
        batch.delete(doc.reference);
      }
      _logger.d('Cleared existing patient queue.');

      for (final patientData in patientQueue) {
        final Map<String, dynamic> dataToWrite = Map.from(patientData);
        if (dataToWrite['color'] is Color) {
          dataToWrite['color'] = _colorToHexString(dataToWrite['color'] as Color);
        }
        // If patientData has an 'id' field, use it, otherwise let Firestore generate one
        // This is useful if your mock data has predefined IDs.
        final docRef = dataToWrite.containsKey('id') && dataToWrite['id'] != null
            ? patientQueueCollection.doc(dataToWrite['id'] as String)
            : patientQueueCollection.doc();
        dataToWrite.remove('id'); // Remove id from data if it was only for doc ID
        batch.set(docRef, dataToWrite);
      }
      await batch.commit();
      _logger.d('Patient queue seeded with ${patientQueue.length} items.');
      _logger.i('Hospital dashboard data seeding completed successfully.');
    } catch (e) {
      _logger.e('Error seeding hospital dashboard data: $e');
      rethrow;
    }
  }

  /// Fetches hospital statistics from Firestore.
  Future<Map<String, dynamic>?> getHospitalStats() async {
    if (!isInitialized) throw Exception('Firebase not initialized. Call initialize() first.');
    _logger.i('Fetching hospital stats from Firestore...');
    try {
      final docSnapshot = await firestore
          .collection('hospital_config')
          .doc('current_stats')
          .get();
      if (docSnapshot.exists) {
        _logger.d('Hospital stats fetched successfully.');
        return docSnapshot.data();
      } else {
        _logger.w('Hospital stats document (hospital_config/current_stats) not found.');
        return null;
      }
    } catch (e) {
      _logger.e('Error fetching hospital stats: $e');
      rethrow;
    }
  }

  /// Fetches the patient queue from Firestore.
  /// Converts color hex strings back to Color objects.
  Future<List<Map<String, dynamic>>> getPatientQueue() async {
    if (!isInitialized) throw Exception('Firebase not initialized. Call initialize() first.');
    _logger.i('Fetching patient queue from Firestore...');
    try {
      final querySnapshot = await firestore.collection('patient_queue').orderBy('aiScore', descending: true).get(); // Example: order by AI score
      final patientList = querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Convert color string back to Color object
        if (data.containsKey('color') && data['color'] is String) {
          data['color'] = _hexStringToColor(data['color'] as String);
        }
        // Add document ID to the data map, useful for keys or updates
        data['id'] = doc.id; 
        return data;
      }).toList();
      _logger.d('Patient queue fetched with ${patientList.length} items.');
      return patientList;
    } catch (e) {
      _logger.e('Error fetching patient queue: $e');
      rethrow;
    }
  }
}
