import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_manager.dart';

final bleProvider = Provider<BleManager>((ref) => BleManager());
final bleConnectionStateProvider = StreamProvider<BluetoothConnectionState>((ref) {
  final ble = ref.watch(bleProvider);
  return ble.connectionStream;
});