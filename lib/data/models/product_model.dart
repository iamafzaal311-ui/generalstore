import 'package:hive/hive.dart';

part 'product_model.g.dart';

@HiveType(typeId: 5)
class ProductModel extends HiveObject {
  @HiveField(0)
  late String productId; // Uuid string

  @HiveField(1)
  late String name;

  @HiveField(2)
  String? sku;

  @HiveField(3)
  String? barcode;

  @HiveField(4)
  String? categoryId;

  @HiveField(5)
  String? brandId;

  @HiveField(6)
  String? supplierId;

  @HiveField(7)
  late double purchasePrice;

  @HiveField(8)
  late double wholesalePrice;

  @HiveField(9)
  late double retailPrice;

  @HiveField(10)
  late double minimumPrice;

  @HiveField(11)
  late double stock;

  @HiveField(12)
  late String unit; // 'kg', 'pcs', 'pack', 'liter', etc.

  @HiveField(13)
  late double openingStock;

  @HiveField(14)
  late double minimumStock;

  @HiveField(15)
  late double maximumStock;

  @HiveField(16)
  DateTime? expiryDate;

  @HiveField(17)
  String? imagePath; // Local file path or Firestore Storage URL

  @HiveField(18)
  String? description;

  @HiveField(19)
  late bool isDirty;

  @HiveField(20)
  late DateTime lastUpdated;

  @HiveField(21)
  late bool isDeleted;

  // New fields for Carton support
  @HiveField(22)
  double? cartons;

  @HiveField(23)
  double? piecesPerCarton;

  @HiveField(24)
  double? cartonPrice;
}
