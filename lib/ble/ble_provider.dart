import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_manager.dart';

class BleConnectionNotifier extends StateNotifier<AsyncValue<BluetoothConnectionState>> {
  BleConnectionNotifier() : super(const AsyncLoading());

  void set(BluetoothConnectionState newState) {
    state = AsyncValue.data(newState);
  }

  void setLoading() {
    state = const AsyncLoading();
  }

  void setError(Object error, StackTrace stack) {
    state = AsyncValue.error(error, stack);
  }
}

final bleConnectionNotifierProvider =
    StateNotifierProvider<BleConnectionNotifier, AsyncValue<BluetoothConnectionState>>(
        (ref) => BleConnectionNotifier());

final bleProvider = Provider<BleManager>((ref) {
  final notifier = ref.read(bleConnectionNotifierProvider.notifier);
  return BleManager(onConnectionUpdate: notifier.set);
});
