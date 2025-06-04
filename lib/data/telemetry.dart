import 'dart:typed_data';
import 'package:rc_car_deck/data/rc_protocol.dart';

import '../utils/tlv_utils.dart'; // Assure-toi que TLVReader est bien accessible

class TelemetryData {
  final double targetSpeed;
  final double currentSpeed;
  final double rearLeft;
  final double rearRight;
  final bool reverse;
  final bool readyForReverse;
  final bool ramping;
  final bool coasting;

  const TelemetryData({
    required this.targetSpeed,
    required this.currentSpeed,
    required this.rearLeft,
    required this.rearRight,
    required this.reverse,
    required this.readyForReverse,
    required this.ramping,
    required this.coasting,
  });

  static const TelemetryData empty = TelemetryData(
    targetSpeed: 0,
    currentSpeed: 0,
    rearLeft: 0,
    rearRight: 0,
    reverse: false,
    readyForReverse: false,
    ramping: false,
    coasting: false,
  );

  factory TelemetryData.fromBytes(List<int> raw) {
    final data = Uint8List.fromList(raw);
    final reader = TLVReader(data);

    if (!reader.isValid(RCProtocol.MSG_TYPE_DATA, RCProtocol.DATA_TYPE_TELEMETRY)) {
      throw FormatException("Invalid telemetry message");
    }

    final fields = <int, Uint8List>{};

    while (!reader.done) {
      final entry = reader.next();
      if (entry == null) break;
      fields[entry.id] = entry.value;
    }

    double readDouble(int id, [double def = 0.0]) =>
        fields.containsKey(id) ? TLVReader.readDouble(fields[id]!) : def;

    bool readBool(int id) =>
        fields.containsKey(id) ? TLVReader.readBool(fields[id]!) : false;

    return TelemetryData(
      targetSpeed: readDouble(0x01),
      currentSpeed: readDouble(0x02),
      rearLeft: readDouble(0x03),
      rearRight: readDouble(0x04),
      reverse: readBool(0x05),
      readyForReverse: readBool(0x06),
      ramping: readBool(0x07),
      coasting: readBool(0x08),
    );
  }
}
