import 'package:cloud_firestore/cloud_firestore.dart';

class StoreProfileModel {
  final String storeName;
  final String phone;
  final String address;
  final String tagline;

  StoreProfileModel({
    required this.storeName,
    this.phone = '',
    this.address = '',
    this.tagline = '',
  });

  factory StoreProfileModel.fromMap(Map<String, dynamic> map) {
    return StoreProfileModel(
      storeName: map['storeName'] ?? 'General Store',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      tagline: map['tagline'] ?? '',
    );
  }

  factory StoreProfileModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return StoreProfileModel(storeName: 'General Store');
    }
    return StoreProfileModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
