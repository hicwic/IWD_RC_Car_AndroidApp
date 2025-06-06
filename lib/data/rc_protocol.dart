import 'dart:typed_data';

class RCProtocol {
  // == MSG TYPE ==
  static const int MSG_TYPE_COMMAND = 0xF0;
  static const int MSG_TYPE_DATA    = 0xFA;

  // == DATA TYPE ==
  static const int DATA_TYPE_SETTINGS               = 0x01;
  static const int DATA_TYPE_CONTROL                = 0x02;
  static const int DATA_TYPE_TELEMETRY_MOTION       = 0x03;
  static const int DATA_TYPE_TELEMETRY_INPUTS       = 0x04;
  static const int DATA_TYPE_TELEMETRY_OUTPUTS      = 0x05;

  // == CMD TYPE ==
  static const int CMD_TELEMETRY_PAUSE          = 0x02;
  static const int CMD_TELEMETRY_RESUME         = 0x03;
  static const int CMD_TELEMETRY_SEND_MOTION    = 0x08;    
  static const int CMD_TELEMETRY_SEND_INPUTS    = 0x09;
  static const int CMD_TELEMETRY_SEND_OUTPUTS   = 0x0F;
  static const int CMD_TELEMETRY_SEND_ALL       = 0x10;

  static const int CMD_SETTINGS_LOAD      = 0x04;
  static const int CMD_SETTINGS_RESET     = 0x05;

  static const int CMD_CONTROL_OVERRIDE   = 0x06;
  static const int CMD_CONTROL_RELEASE    = 0x07;

  // == BUILDERS ==

  /// Builds a command message: [type=F0, cmd, ...optionalPayload]
  static Uint8List buildCommandMessage(int cmd, [List<int> payload = const []]) =>
      Uint8List.fromList([MSG_TYPE_COMMAND, cmd, ...payload]);

  /// Builds a data message: [type=FA, dataType, ...payload]
  static Uint8List buildDataMessage(int type, List<int> payload) =>
      Uint8List.fromList([MSG_TYPE_DATA, type, ...payload]);
}
