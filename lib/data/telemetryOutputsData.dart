import 'dart:typed_data';
import 'package:rc_car_deck/data/rc_protocol.dart';

import '../utils/tlv_utils.dart';

class TelemetryOutputsData {
  final List<int?> motors; // [rearL, rearR, frontL, frontR, central]

  const TelemetryOutputsData({required this.motors});

  static const TelemetryOutputsData empty = TelemetryOutputsData(motors: [0, 0, 0, 0, 0]);

  factory TelemetryOutputsData.fromBytes(List<int> raw) {
    final data = Uint8List.fromList(raw);
    final reader = TLVReader(data);

    if (!reader.isValid(RCProtocol.MSG_TYPE_DATA, RCProtocol.DATA_TYPE_TELEMETRY_OUTPUTS)) {
      throw FormatException("Invalid outputs telemetry message");
    }

    final values = List<int?>.filled(5, null);

    while (!reader.done) {
      final entry = reader.next();
      if (entry == null) break;

      final id = entry.id;
      if (id >= 0x01 && id <= 0x05) {
        final index = id - 0x01;
        values[index] = TLVReader.readUint16(entry.value);
      }
    }

    return TelemetryOutputsData(motors: values);
  }
}
