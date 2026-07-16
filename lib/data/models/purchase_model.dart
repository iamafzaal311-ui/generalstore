import 'package:hive/hive.dart';

part 'purchase_model.g.dart';

@HiveType(typeId: 7)
class PurchaseModel extends HiveObject {
  @HiveField(0)
  late String purchaseId; // UUID string

  @HiveField(1)
  late String invoiceNumber;

  @HiveField(2)
  late String supplierId;

  @HiveField(3)
  late double totalAmount;

  @HiveField(4)
  late double paidAmount;

  @HiveField(5)
  late DateTime timestamp;

  @HiveField(6)
  late String itemsJson; // JSON representation of purchased items

  @HiveField(7)
  late bool isDirty;

  @HiveField(8)
  late DateTime lastUpdated;

  @HiveField(9)
  late bool isDeleted;
}
