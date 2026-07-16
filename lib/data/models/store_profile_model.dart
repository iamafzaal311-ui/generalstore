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
    String name = map['storeName'] ?? 'HASNAIN TRADERS';
    if (name.isEmpty) name = 'HASNAIN TRADERS';
    // Automatically correct spelling based on user feedback
    if (name.toUpperCase().contains('HUSSNAIN')) {
      name = name.replaceAll(
        RegExp('HUSSNAIN', caseSensitive: false),
        'HASNAIN',
      );
    }

    String p = map['phone'] ?? '';
    if (p.isEmpty) p = '0307-4217267';

    String a = map['address'] ?? '';
    if (a.isEmpty) a = 'Ghosia Market Sikandar Chowk Pakkpattan';

    String t = map['tagline'] ?? '';
    if (t.isEmpty) t = 'Ali Abbas';

    return StoreProfileModel(
      storeName: name,
      phone: p,
      address: a,
      tagline: t,
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
      return StoreProfileModel(
        storeName: 'HASNAIN TRADERS',
        phone: '0307-4217267',
        address: 'Ghosia Market Sikandar Chowk Pakkpattan',
        tagline: 'Ali Abbas',
      );
    }
    return StoreProfileModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
