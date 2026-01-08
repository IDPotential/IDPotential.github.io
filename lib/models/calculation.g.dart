// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calculation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalculationAdapter extends TypeAdapter<Calculation> {
  @override
  final int typeId = 0;

  @override
  Calculation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Calculation(
      id: fields[0] as int?,
      name: fields[1] as String,
      birthDate: fields[2] as String,
      gender: fields[3] as String,
      numbers: (fields[4] as List).cast<int>(),
      createdAt: fields[5] as DateTime,
      group: fields[6] as String?,
      notes: fields[7] as String?,
      decryption: fields[8] as int,
      firebaseId: fields[9] as String?,
      telegram: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Calculation obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.birthDate)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.numbers)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.group)
      ..writeByte(7)
      ..write(obj.notes)
      ..writeByte(8)
      ..write(obj.decryption)
      ..writeByte(9)
      ..write(obj.firebaseId)
      ..writeByte(10)
      ..write(obj.telegram);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
