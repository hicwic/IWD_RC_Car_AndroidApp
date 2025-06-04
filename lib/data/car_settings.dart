import 'dart:typed_data';
import 'rc_protocol.dart';
import '../utils/tlv_utils.dart';

enum WheelDriveType {
  xcwDrive,
  fiwDrive,
  riwDrive,
  aiwDrive,
}

enum DriveTrainType {
  pwm,
  dshot,
  bdshot,
}

class CarSettings {
  String rcName;

  WheelDriveType wheelDriveType;
  bool rampingEnabled;
  bool coastingEnabled;

  DriveTrainType centralDriveTrainType;
  int frontDiffValue;
  DriveTrainType frontDriveTrainType;
  int rearDiffValue;
  DriveTrainType rearDriveTrainType;
  int frontRearRatioValue;

  int coastingFactor;

  int throttleDeadzone;
  int steeringDeadzone;
  int steeringTrim;
  int throttleTrim;

  bool steeringInverted;
  bool throttleInverted;

  CarSettings({
    this.rcName = "MyRC",
    this.wheelDriveType = WheelDriveType.xcwDrive,
    this.rampingEnabled = true,
    this.coastingEnabled = true,
    this.centralDriveTrainType = DriveTrainType.pwm,
    this.frontDiffValue = 50,
    this.frontDriveTrainType = DriveTrainType.pwm,
    this.rearDiffValue = 50,
    this.rearDriveTrainType = DriveTrainType.pwm,
    this.frontRearRatioValue = 50,
    this.throttleDeadzone = 10,
    this.steeringDeadzone = 0,
    this.steeringTrim = 0,
    this.throttleTrim = 0,
    this.steeringInverted = false,
    this.throttleInverted = false,
    this.coastingFactor = 50,
  });

  Uint8List toBytes() {
    final writer = TLVWriter();

    writer.addString(0x01, rcName);
    writer.addUint8(0x02, wheelDriveType.index);
    writer.addBool(0x03, rampingEnabled);
    writer.addBool(0x04, coastingEnabled);

    writer.addUint8(0x05, centralDriveTrainType.index);
    writer.addUint8(0x06, frontDiffValue);
    writer.addUint8(0x07, frontDriveTrainType.index);
    writer.addUint8(0x08, rearDiffValue);
    writer.addUint8(0x09, rearDriveTrainType.index);
    writer.addUint8(0x0A, frontRearRatioValue);

    writer.addUint8(0x0B, throttleDeadzone);
    writer.addUint8(0x0C, steeringDeadzone);
    writer.addInt8(0x0D, steeringTrim); // int8 natif
    writer.addInt8(0x0E, throttleTrim); // int8 natif

    writer.addBool(0x0F, steeringInverted);
    writer.addBool(0x10, throttleInverted);

    writer.addUint8(0x11, coastingFactor);

    return writer.toBytes();
  }

  factory CarSettings.fromBytes(Uint8List data) {
    final reader = TLVReader(data);
    if (!reader.isValid(RCProtocol.MSG_TYPE_DATA, RCProtocol.DATA_TYPE_SETTINGS)) {
      throw FormatException("Invalid message header");
    }

    final fields = <int, Uint8List>{};

    while (!reader.done) {
      final entry = reader.next();
      if (entry == null) break;
      fields[entry.id] = entry.value;
    }

    int readUint8(int id, [int def = 0]) => fields[id]?.first ?? def;
    int readInt8(int id, [int def = 0]) =>
        fields.containsKey(id) ? TLVReader.readInt8(fields[id]!) : def;
    bool readBool(int id) => readUint8(id) != 0;
    String readString(int id) =>
        fields.containsKey(id) ? TLVReader.readString(fields[id]!) : '';
    int readInt32(int id, [int def = 0]) =>
        fields.containsKey(id) ? TLVReader.readInt32(fields[id]!) : def;
    int readInt64(int id, [int def = 0]) =>
        fields.containsKey(id) ? TLVReader.readInt64(fields[id]!) : def;
    double readDouble(int id, [double def = 0.0]) =>
        fields.containsKey(id) ? TLVReader.readDouble(fields[id]!) : def;

    return CarSettings(
      rcName: readString(0x01),
      wheelDriveType: WheelDriveType.values[readUint8(0x02)],
      rampingEnabled: readBool(0x03),
      coastingEnabled: readBool(0x04),

      centralDriveTrainType: DriveTrainType.values[readUint8(0x05)],
      frontDiffValue: readUint8(0x06),
      frontDriveTrainType: DriveTrainType.values[readUint8(0x07)],
      rearDiffValue: readUint8(0x08),
      rearDriveTrainType: DriveTrainType.values[readUint8(0x09)],
      frontRearRatioValue: readUint8(0x0A),

      throttleDeadzone: readUint8(0x0B),
      steeringDeadzone: readUint8(0x0C),
      steeringTrim: readInt8(0x0D),
      throttleTrim: readInt8(0x0E),

      steeringInverted: readBool(0x0F),
      throttleInverted: readBool(0x10),

      coastingFactor: readUint8(0x11),
    );
  }

}
