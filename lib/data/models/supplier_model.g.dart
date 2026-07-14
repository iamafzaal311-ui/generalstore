// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SupplierModelAdapter extends TypeAdapter<SupplierModel> {
  @override
  final int typeId = 3;

  @override
  SupplierModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SupplierModel()
      ..supplierId = fields[0] as String
      ..name = fields[1] as String
      ..contactName = fields[2] as String?
      ..phone = fields[3] as String?
      ..email = fields[4] as String?
      ..address = fields[5] as String?
      ..balance = fields[6] as double
      ..isDirty = fields[7] as bool
      ..lastUpdated = fields[8] as DateTime
      ..isDeleted = fields[9] as bool;
  }

  @override
  void write(BinaryWriter writer, SupplierModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.supplierId)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.contactName)
      ..writeByte(3)
      ..write(obj.phone)
      ..writeByte(4)
      ..write(obj.email)
      ..writeByte(5)
      ..write(obj.address)
      ..writeByte(6)
      ..write(obj.balance)
      ..writeByte(7)
      ..write(obj.isDirty)
      ..writeByte(8)
      ..write(obj.lastUpdated)
      ..writeByte(9)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
