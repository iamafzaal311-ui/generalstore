// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PaymentModelAdapter extends TypeAdapter<PaymentModel> {
  @override
  final int typeId = 9;

  @override
  PaymentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PaymentModel()
      ..paymentId = fields[0] as String
      ..personId = fields[1] as String
      ..isCustomer = fields[2] as bool
      ..amount = fields[3] as double
      ..timestamp = fields[4] as DateTime
      ..description = fields[5] as String?
      ..isDirty = fields[6] as bool
      ..lastUpdated = fields[7] as DateTime
      ..isDeleted = fields[8] as bool;
  }

  @override
  void write(BinaryWriter writer, PaymentModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.paymentId)
      ..writeByte(1)
      ..write(obj.personId)
      ..writeByte(2)
      ..write(obj.isCustomer)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.isDirty)
      ..writeByte(7)
      ..write(obj.lastUpdated)
      ..writeByte(8)
      ..write(obj.isDeleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
