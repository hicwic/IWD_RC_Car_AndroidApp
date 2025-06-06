import 'dart:typed_data';
import 'package:rc_car_deck/data/rc_protocol.dart';

import '../utils/tlv_utils.dart';

class TelemetryInputsData {
  final List<int> channels;

  const TelemetryInputsData({required this.channels});

  static const TelemetryInputsData empty = TelemetryInputsData(channels: [1500, 1500, 1500, 1500]);

  factory TelemetryInputsData.fromBytes(List<int> raw) {
    final data = Uint8List.fromList(raw);
    final reader = TLVReader(data);

    if (!reader.isValid(RCProtocol.MSG_TYPE_DATA, RCProtocol.DATA_TYPE_TELEMETRY_INPUTS)) {
      throw FormatException("Invalid inputs telemetry message");
    }

    final values = List.filled(4, 1500);

    while (!reader.done) {
      final entry = reader.next();
      if (entry == null) break;

      final id = entry.id;
      if (id >= 0x10 && id <= 0x13) {
        final index = id - 0x10;
        final bytes = entry.value;
        if (bytes.length == 2) {
          values[index] = bytes[0] | (bytes[1] << 8);
        }
      }
    }

    return TelemetryInputsData(channels: values);
  }
}
