import 'package:hive/hive.dart';

part 'brand_model.g.dart';

@HiveType(typeId: 2)
class BrandModel extends HiveObject {
  @HiveField(0)
  late String brandId; // UUID string

  @HiveField(1)
  late String name;
  
  @HiveField(2)
  String? description;

  @HiveField(3)
  late bool isDirty;

  @HiveField(4)
  late DateTime lastUpdated;

  @HiveField(5)
  late bool isDeleted;
}
