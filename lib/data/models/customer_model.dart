import 'package:hive/hive.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 4)
class CustomerModel extends HiveObject {
  @HiveField(0)
  late String customerId; // UUID string

  @HiveField(1)
  late String name;
  
  @HiveField(2)
  String? phone;
  
  @HiveField(3)
  String? email;
  
  @HiveField(4)
  String? address;
  
  @HiveField(5)
  late double balance; // Amount customer owes us (Khata)

  @HiveField(6)
  late bool isDirty;

  @HiveField(7)
  late DateTime lastUpdated;

  @HiveField(8)
  late bool isDeleted;
}
