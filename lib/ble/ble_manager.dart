import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleManager {
  BluetoothDevice? device;
  BluetoothCharacteristic? screenChar;
  BluetoothCharacteristic? commandChar;

  void Function(List<int>)? onSettingsReceived;
  void Function(String)? onTelemetryReceived;
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

    final type = data[0];
    final payload = data.sublist(1);

    switch (type) {
      case 0x01: // MSG_TYPE_SETTINGS
        if (payload.length >= 7) {
          onSettingsReceived?.call(data); // on passe tout, y compris type
        }
        break;

      case 0x03: // MSG_TYPE_TELEMETRY (optionnel)
        if (onTelemetryReceived != null) {
          final message = String.fromCharCodes(payload);
          onTelemetryReceived!(message);
        }
        break;

      default:
        print("Trame inconnue, type: \$type");
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

  Future<void> sendCommand(String cmd) async {
    if (commandChar == null) return;
    try {
      await commandChar!.write(cmd.codeUnits);
      print("Commande envoyée : $cmd");
    } catch (e) {
      print("Erreur sendCommand: $e");
    }
  }

  Future<void> sendSettings(List<int> data) async {
    if (commandChar == null) return;
    try {
      await commandChar!.write(data);
      print("Trame settings envoyée (${data.length} octets)");
    } catch (e) {
      print("Erreur sendSettings: $e");
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
    _connectionController.add(BluetoothConnectionState.disconnected);
    _shouldReconnect = false;
  }

}
