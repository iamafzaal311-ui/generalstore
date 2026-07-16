import 'package:cloud_firestore/cloud_firestore.dart';

class StoreProfileModel {
  final String storeName;
  final String phone;
  final String address;
  final String tagline;
  final bool isActive;
  final String? logoUrl;

  StoreProfileModel({
    required this.storeName,
    this.phone = '',
    this.address = '',
    this.tagline = '',
    this.isActive = true,
    this.logoUrl,
  });

  factory StoreProfileModel.fromMap(Map<String, dynamic> map) {
    String name = map['storeName'] ?? 'General Store';
    // Automatically correct spelling based on user feedback
    if (name.toUpperCase().contains('HUSSNAIN')) {
      name = name.replaceAll(RegExp('HUSSNAIN', caseSensitive: false), 'HASNAIN');
    }

    return StoreProfileModel(
      storeName: name,
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      tagline: map['tagline'] ?? '',
      isActive: map['isActive'] ?? true,
      logoUrl: map['logoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeName': storeName,
      'phone': phone,
      'address': address,
      'tagline': tagline,
      'isActive': isActive,
      'logoUrl': logoUrl,
    };
  }

  factory StoreProfileModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return StoreProfileModel(storeName: 'General Store');
    }
    return StoreProfileModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
