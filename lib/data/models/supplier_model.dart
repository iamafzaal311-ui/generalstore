import 'package:hive/hive.dart';

part 'supplier_model.g.dart';

@HiveType(typeId: 3)
class SupplierModel extends HiveObject {
  @HiveField(0)
  late String supplierId; // UUID string

  @HiveField(1)
  late String name;
  
  @HiveField(2)
  String? contactName;
  
  @HiveField(3)
  String? phone;
  
  @HiveField(4)
  String? email;
  
  @HiveField(5)
  String? address;
  
  @HiveField(6)
  late double balance; // Amount we owe supplier

  @HiveField(7)
  late bool isDirty;

  @HiveField(8)
  late DateTime lastUpdated;

  @HiveField(9)
  late bool isDeleted;
}
