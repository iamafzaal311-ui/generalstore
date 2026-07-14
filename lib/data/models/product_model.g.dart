// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 5;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel()
      ..productId = fields[0] as String
      ..name = fields[1] as String
      ..sku = fields[2] as String?
      ..barcode = fields[3] as String?
      ..categoryId = fields[4] as String?
      ..brandId = fields[5] as String?
      ..supplierId = fields[6] as String?
      ..purchasePrice = fields[7] as double
      ..wholesalePrice = fields[8] as double
      ..retailPrice = fields[9] as double
      ..minimumPrice = fields[10] as double
      ..stock = fields[11] as double
      ..unit = fields[12] as String
      ..openingStock = fields[13] as double
      ..minimumStock = fields[14] as double
      ..maximumStock = fields[15] as double
      ..expiryDate = fields[16] as DateTime?
      ..imagePath = fields[17] as String?
      ..description = fields[18] as String?
      ..isDirty = fields[19] as bool
      ..lastUpdated = fields[20] as DateTime
      ..isDeleted = fields[21] as bool
      ..cartons = fields[22] as double?
      ..piecesPerCarton = fields[23] as double?
      ..cartonPrice = fields[24] as double?;
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(25)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.sku)
      ..writeByte(3)
      ..write(obj.barcode)
      ..writeByte(4)
      ..write(obj.categoryId)
      ..writeByte(5)
      ..write(obj.brandId)
      ..writeByte(6)
      ..write(obj.supplierId)
      ..writeByte(7)
      ..write(obj.purchasePrice)
      ..writeByte(8)
      ..write(obj.wholesalePrice)
      ..writeByte(9)
      ..write(obj.retailPrice)
      ..writeByte(10)
      ..write(obj.minimumPrice)
      ..writeByte(11)
      ..write(obj.stock)
      ..writeByte(12)
      ..write(obj.unit)
      ..writeByte(13)
      ..write(obj.openingStock)
      ..writeByte(14)
      ..write(obj.minimumStock)
      ..writeByte(15)
      ..write(obj.maximumStock)
      ..writeByte(16)
      ..write(obj.expiryDate)
      ..writeByte(17)
      ..write(obj.imagePath)
      ..writeByte(18)
      ..write(obj.description)
      ..writeByte(19)
      ..write(obj.isDirty)
      ..writeByte(20)
      ..write(obj.lastUpdated)
      ..writeByte(21)
      ..write(obj.isDeleted)
      ..writeByte(22)
      ..write(obj.cartons)
      ..writeByte(23)
      ..write(obj.piecesPerCarton)
      ..writeByte(24)
      ..write(obj.cartonPrice);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
