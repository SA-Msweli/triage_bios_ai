import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Firestore model for hospital data
class HospitalFirestore extends Equatable {
  final String id;
  final String name;
  final HospitalAddress address;
  final HospitalLocation location;
  final HospitalContact contact;
  final int traumaLevel;
  final List<String> specializations;
  final List<String> certifications;
  final HospitalOperatingHours operatingHours;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  const HospitalFirestore({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.contact,
    required this.traumaLevel,
    required this.specializations,
    required this.certifications,
    required this.operatingHours,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  /// Create from Firestore document
  factory HospitalFirestore.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data()!;
    return HospitalFirestore(
      id: snapshot.id,
      name: data['name'] as String,
      address: HospitalAddress.fromMap(data['address'] as Map<String, dynamic>),
      location: HospitalLocation.fromMap(
        data['location'] as Map<String, dynamic>,
      ),
      contact: HospitalContact.fromMap(data['contact'] as Map<String, dynamic>),
      traumaLevel: data['traumaLevel'] as int,
      specializations: List<String>.from(data['specializations'] as List),
      certifications: List<String>.from(data['certifications'] as List),
      operatingHours: HospitalOperatingHours.fromMap(
        data['operatingHours'] as Map<String, dynamic>,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isActive: data['isActive'] as bool,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address.toMap(),
      'location': location.toMap(),
      'contact': contact.toMap(),
      'traumaLevel': traumaLevel,
      'specializations': specializations,
      'certifications': certifications,
      'operatingHours': operatingHours.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
    };
  }

  HospitalFirestore copyWith({
    String? id,
    String? name,
    HospitalAddress? address,
    HospitalLocation? location,
    HospitalContact? contact,
    int? traumaLevel,
    List<String>? specializations,
    List<String>? certifications,
    HospitalOperatingHours? operatingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return HospitalFirestore(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      location: location ?? this.location,
      contact: contact ?? this.contact,
      traumaLevel: traumaLevel ?? this.traumaLevel,
      specializations: specializations ?? this.specializations,
      certifications: certifications ?? this.certifications,
      operatingHours: operatingHours ?? this.operatingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object> get props => [
    id,
    name,
    address,
    location,
    contact,
    traumaLevel,
    specializations,
    certifications,
    operatingHours,
    createdAt,
    updatedAt,
    isActive,
  ];
}

class HospitalAddress extends Equatable {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  const HospitalAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.country,
  });

  factory HospitalAddress.fromMap(Map<String, dynamic> map) {
    return HospitalAddress(
      street: map['street'] as String,
      city: map['city'] as String,
      state: map['state'] as String,
      zipCode: map['zipCode'] as String,
      country: map['country'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }

  @override
  List<Object> get props => [street, city, state, zipCode, country];
}

class HospitalLocation extends Equatable {
  final double latitude;
  final double longitude;

  const HospitalLocation({required this.latitude, required this.longitude});

  factory HospitalLocation.fromMap(Map<String, dynamic> map) {
    return HospitalLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'latitude': latitude, 'longitude': longitude};
  }

  @override
  List<Object> get props => [latitude, longitude];
}

class HospitalContact extends Equatable {
  final String phone;
  final String email;
  final String? website;

  const HospitalContact({
    required this.phone,
    required this.email,
    this.website,
  });

  factory HospitalContact.fromMap(Map<String, dynamic> map) {
    return HospitalContact(
      phone: map['phone'] as String,
      email: map['email'] as String,
      website: map['website'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'email': email,
      if (website != null) 'website': website,
    };
  }

  @override
  List<Object?> get props => [phone, email, website];
}

class HospitalOperatingHours extends Equatable {
  final String emergency;
  final String general;

  const HospitalOperatingHours({
    required this.emergency,
    required this.general,
  });

  factory HospitalOperatingHours.fromMap(Map<String, dynamic> map) {
    return HospitalOperatingHours(
      emergency: map['emergency'] as String,
      general: map['general'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'emergency': emergency, 'general': general};
  }

  @override
  List<Object> get props => [emergency, general];
}
