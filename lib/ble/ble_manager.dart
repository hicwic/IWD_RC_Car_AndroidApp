import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/rc_protocol.dart';


class BleManager {
  final void Function(BluetoothConnectionState)? onConnectionUpdate;
  BleManager({this.onConnectionUpdate});

  BluetoothDevice? device;
  BluetoothCharacteristic? screenChar;
  BluetoothCharacteristic? commandChar;

  void Function(List<int>)? onSettingsReceived;
  void Function(List<int>)? onTelemetryReceived;
  void Function()? onDisconnected;
  void Function()? onConnected;  

  String currentScreen = "home"; // valeur par défaut

  late StreamSubscription<BluetoothConnectionState> _connSub;
  bool _shouldReconnect = true;


  final _connectionController = StreamController<BluetoothConnectionState>.broadcast();

  Stream<BluetoothConnectionState>? get connectionStateStream {
    return device?.connectionState;
  }

  Stream<BluetoothConnectionState> get connectionStream => _connectionController.stream;


  Future<void> setupCharacteristics() async {
    final services = await device!.discoverServices();
    for (final s in services) {
      for (final c in s.characteristics) {
        print("UUID détecté : ${c.uuid}");
        if (c.uuid.toString().toLowerCase().contains("33333333")) screenChar = c;
        if (c.uuid.toString().toLowerCase().contains("34343434")) commandChar = c;
      }
    }

    if (commandChar != null) {
      await commandChar!.setNotifyValue(true);
      commandChar!.onValueReceived.listen(_handleCommandData);
    }
  }

  void _handleCommandData(List<int> data) {
    if (data.isEmpty) return;
    if (data[0] != RCProtocol.MSG_TYPE_DATA) return;

    final type = data[1];
    final payload = data.sublist(1);

    switch (type) {
      case RCProtocol.DATA_TYPE_SETTINGS:
        print("Trame settings reçu");
        if (onSettingsReceived != null) {
          onSettingsReceived?.call(data);
        }
        break;

      case RCProtocol.DATA_TYPE_TELEMETRY:
        print("Trame telemetry reçu");
        if (onTelemetryReceived != null) {
          onTelemetryReceived?.call(data);
        }
        break;

      default:
        print("Trame inconnue, type: $type");
    }
  }

  Future<void> setScreen(String name) async {
    if (screenChar == null) return;
    try {
      await screenChar!.write(name.codeUnits);
      currentScreen = name;
      print("Écran envoyé : $name");
    } catch (e) {
      print("Erreur setScreen: $e");
    }
  }

  // Future<void> sendCommand(String cmd) async {
  //   if (commandChar == null) return;
  //   try {
  //     await commandChar!.write(cmd.codeUnits);
  //     print("Commande envoyée : $cmd");
  //   } catch (e) {
  //     print("Erreur sendCommand: $e");
  //   }
  // }

  Future<void> sendData(List<int> data) async {
    if (commandChar == null) return;
    try {
      await commandChar!.write(data);
      print("Trame settings envoyée (${data.length} octets)");
    } catch (e) {
      print("Erreur sendData: $e");
    }
  }

  Stream<List<int>>? telemetryStream() {
    return screenChar?.onValueReceived;
  }

  Future<bool> isConnected() async {
    return device != null && await device!.isConnected;
  }

  void startConnectionMonitor() {
    if (device == null) return;
    _shouldReconnect = true;

    _connSub = device!.connectionState.listen((state) async {
      _connectionController.add(state);
      onConnectionUpdate?.call(state);
      if (state == BluetoothConnectionState.disconnected) {
        print("⚠️ ESP déconnecté");
        if (_shouldReconnect) {
          await _attemptReconnect();
        } else {
          onDisconnected?.call();
        }
      }
    });
  }

  Future<void> _attemptReconnect() async {
    for (int i = 0; i < 5; i++) {
      print("Tentative de reconnexion... ($i)");
      try {
        await device!.connect(autoConnect: true);
        if (await device!.isConnected) {
          print("✅ Reconnecté !");
          onConnectionUpdate?.call(BluetoothConnectionState.connected);
          await setupCharacteristics();
          await setScreen(currentScreen); // ou autre écran actif
          return;
        }
      } catch (_) {
        await Future.delayed(Duration(seconds: 2));
      }
    } 

    print("❌ Impossible de se reconnecter.");
    _shouldReconnect = false;
    onDisconnected?.call(); 
  }

  void stopMonitoring() {
    _connSub.cancel();
    onConnectionUpdate?.call(BluetoothConnectionState.disconnected);
    _shouldReconnect = false;
  }

}
