import 'dart:typed_data';
import 'package:rc_car_deck/data/rc_protocol.dart';

import '../utils/tlv_utils.dart'; // Assure-toi que TLVReader est bien accessible

class TelemetryData {
  final double targetSpeed;
  final double currentSpeed;
  final double? central;
  final double? rearLeft;
  final double? rearRight;
  final double? frontLeft;
  final double? frontRight;  
  final bool reverse;
  final bool readyForReverse;
  final bool ramping;
  final bool coasting;

  const TelemetryData({
    required this.targetSpeed,
    required this.currentSpeed,
    this.central,
    this.rearLeft,
    this.rearRight,
    this.frontLeft,
    this.frontRight,    
    required this.reverse,
    required this.readyForReverse,
    required this.ramping,
    required this.coasting,
  });

  static const TelemetryData empty = TelemetryData(
    targetSpeed: 0,
    currentSpeed: 0,
    central: null,
    rearLeft: null,
    rearRight: null,
    frontLeft: null,
    frontRight: null,    
    reverse: false,
    readyForReverse: false,
    ramping: false,
    coasting: false,
  );

  factory TelemetryData.fromBytes(List<int> raw) {
    final data = Uint8List.fromList(raw);
    final reader = TLVReader(data);

    if (!reader.isValid(RCProtocol.MSG_TYPE_DATA, RCProtocol.DATA_TYPE_TELEMETRY_MOTION)) {
      throw FormatException("Invalid telemetry message");
    }

    final fields = <int, Uint8List>{};

    while (!reader.done) {
      final entry = reader.next();
      if (entry == null) break;
      fields[entry.id] = entry.value;
    }

    double? readFloatOptional(int id) =>
        fields.containsKey(id) ? TLVReader.readFloat(fields[id]!) : null;

    double readFloat(int id, [double def = 0.0]) =>
        fields.containsKey(id) ? TLVReader.readFloat(fields[id]!) : def;

    double readDouble(int id, [double def = 0.0]) =>
        fields.containsKey(id) ? TLVReader.readDouble(fields[id]!) : def;

    bool readBool(int id) =>
        fields.containsKey(id) ? TLVReader.readBool(fields[id]!) : false;

    return TelemetryData(
      targetSpeed: readFloat(0x01),
      currentSpeed: readFloat(0x02),
      rearLeft: readFloatOptional(0x03),
      rearRight: readFloatOptional(0x04),
      frontLeft: readFloatOptional(0x09),
      frontRight: readFloatOptional(0x0A),   
      central: readFloatOptional(0x0B),     
      reverse: readBool(0x05),
      readyForReverse: readBool(0x06),
      ramping: readBool(0x07),
      coasting: readBool(0x08),
    );
  }
}
