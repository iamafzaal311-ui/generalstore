// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleModelAdapter extends TypeAdapter<SaleModel> {
  @override
  final int typeId = 6;

  @override
  SaleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleModel()
      ..saleId = fields[0] as String
      ..invoiceNumber = fields[1] as String
      ..cashierId = fields[2] as String
      ..customerId = fields[3] as String?
      ..subtotal = fields[4] as double
      ..discount = fields[5] as double
      ..total = fields[6] as double
      ..paidAmount = fields[7] as double
      ..changeAmount = fields[8] as double
      ..paymentMethod = fields[9] as String
      ..timestamp = fields[10] as DateTime
      ..itemsJson = fields[11] as String
      ..isDirty = fields[12] as bool
      ..lastUpdated = fields[13] as DateTime
      ..isDeleted = fields[14] as bool;
  }

  @override
  void write(BinaryWriter writer, SaleModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.saleId)
      ..writeByte(1)
      ..write(obj.invoiceNumber)
      ..writeByte(2)
      ..write(obj.cashierId)
      ..writeByte(3)
      ..write(obj.customerId)
      ..writeByte(4)
      ..write(obj.subtotal)
      ..writeByte(5)
      ..write(obj.discount)
      ..writeByte(6)
      ..write(obj.total)
      ..writeByte(7)
      ..write(obj.paidAmount)
      ..writeByte(8)
      ..write(obj.changeAmount)
      ..writeByte(9)
      ..write(obj.paymentMethod)
      ..writeByte(10)
      ..write(obj.timestamp)
      ..writeByte(11)
      ..write(obj.itemsJson)
      ..writeByte(12)
      ..write(obj.isDirty)
      ..writeByte(13)
      ..write(obj.lastUpdated)
      ..writeByte(14)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
