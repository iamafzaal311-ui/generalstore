import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  late String userId; // UUID string

  @HiveField(1)
  late String username;

  @HiveField(2)
  late String fullName;

  @HiveField(3)
  late String passwordHash;

  @HiveField(4)
  late String salt;

  @HiveField(5)
  late String role; // 'Super Admin', 'Manager', 'Cashier', 'Inventory Manager', 'Accountant'

  @HiveField(6)
  late bool isActive;

  @HiveField(7)
  late bool isDirty;

  @HiveField(8)
  late DateTime lastUpdated;
}
