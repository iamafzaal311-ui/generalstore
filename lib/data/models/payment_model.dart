import 'package:hive/hive.dart';

part 'payment_model.g.dart';

@HiveType(typeId: 9)
class PaymentModel extends HiveObject {
  @HiveField(0)
  late String paymentId;

  @HiveField(1)
  late String personId; // Customer or Supplier ID

  @HiveField(2)
  late bool isCustomer; // True if customer payment, False if supplier payment

  @HiveField(3)
  late double amount;

  @HiveField(4)
  late DateTime timestamp;

  @HiveField(5)
  String? description;

  @HiveField(6)
  late bool isDirty;

  @HiveField(7)
  late DateTime lastUpdated;

  @HiveField(8)
  late bool isDeleted;
}
