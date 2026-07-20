import 'package:cloud_firestore/cloud_firestore.dart';

class StoreProfileModel {
  final String storeName;
  final String phone;
  final String address;
  final String tagline;
  final bool isActive;
  final String? logoUrl;
  final String? deactivationReason;
  final DateTime? deactivatedAt;
  final String? headerColor;
  final String? headerTextColor;

  StoreProfileModel({
    required this.storeName,
    this.phone = '',
    this.address = '',
    this.tagline = '',
    this.isActive = true,
    this.logoUrl,
    this.deactivationReason,
    this.deactivatedAt,
    this.headerColor,
    this.headerTextColor,
  });

  factory StoreProfileModel.fromMap(Map<String, dynamic> map) {
    final String name = (map['storeName'] as String? ?? '').trim();
    final String p = (map['phone'] as String? ?? '').trim();
    final String a = (map['address'] as String? ?? '').trim();
    final String t = (map['tagline'] as String? ?? '').trim();

    DateTime? deactivatedAt;
    if (map['deactivatedAt'] != null) {
      try {
        if (map['deactivatedAt'] is String) {
          deactivatedAt = DateTime.parse(map['deactivatedAt'] as String);
        } else if (map['deactivatedAt'] is Timestamp) {
          deactivatedAt = (map['deactivatedAt'] as Timestamp).toDate();
        }
      } catch (_) {}
    }

    return StoreProfileModel(
      storeName: name,
      phone: p,
      address: a,
      tagline: t,
      isActive: map['isActive'] as bool? ?? true,
      logoUrl: map['logoUrl'] as String?,
      deactivationReason: map['deactivationReason'] as String?,
      deactivatedAt: deactivatedAt,
      headerColor: map['headerColor'] as String?,
      headerTextColor: map['headerTextColor'] as String?,
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
      if (deactivationReason != null) 'deactivationReason': deactivationReason,
      if (deactivatedAt != null)
        'deactivatedAt': deactivatedAt!.toUtc().toIso8601String(),
      if (headerColor != null) 'headerColor': headerColor,
      if (headerTextColor != null) 'headerTextColor': headerTextColor,
    };
  }

  factory StoreProfileModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists || doc.data() == null) {
      return StoreProfileModel(storeName: '');
    }
    return StoreProfileModel.fromMap(doc.data() as Map<String, dynamic>);
  }
}
