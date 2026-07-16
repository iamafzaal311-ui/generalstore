import 'package:hive/hive.dart';

part 'sale_model.g.dart';

@HiveType(typeId: 6)
class SaleModel extends HiveObject {
  @HiveField(0)
  late String saleId; // UUID string

  @HiveField(1)
  late String invoiceNumber;

  @HiveField(2)
  late String cashierId;

  @HiveField(3)
  String? customerId;

  @HiveField(4)
  late double subtotal;

  @HiveField(5)
  late double discount;

  @HiveField(6)
  late double total;

  @HiveField(7)
  late double paidAmount;

  @HiveField(8)
  late double changeAmount;

  @HiveField(9)
  late String paymentMethod; // 'Cash', 'Card', 'Mobile Payment', 'Credit (Khata)'

  @HiveField(10)
  late DateTime timestamp;

  @HiveField(11)
  late String itemsJson; // JSON representation of items sold

  @HiveField(12)
  late bool isDirty;

  @HiveField(13)
  late DateTime lastUpdated;

  @HiveField(14)
  late bool isDeleted;
}
