import 'package:hive/hive.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 8)
class ExpenseModel extends HiveObject {
  @HiveField(0)
  late String expenseId; // UUID string

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String category; // 'Rent', 'Salaries', 'Utilities', 'Stationery', 'Other'

  @HiveField(3)
  late double amount;

  @HiveField(4)
  String? description;

  @HiveField(5)
  late DateTime timestamp;

  @HiveField(6)
  late bool isDirty;

  @HiveField(7)
  late DateTime lastUpdated;

  @HiveField(8)
  late bool isDeleted;
}
