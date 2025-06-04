import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ble/ble_provider.dart'; // ton provider
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with RouteAware {
  BluetoothDevice? connectedDevice;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyConnected();

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      ble.setScreen("home");
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // Revient depuis un autre écran
    _notifyScreenIsHome();
  }

  @override
  void didPush() {
    // Arrivée initiale
    _notifyScreenIsHome();
  }

  void _notifyScreenIsHome() {
    final ble = ref.read(bleProvider);
    ble.setScreen("home");
  }

  Future<void> _disconnect() async {
    final ble = ref.read(bleProvider);
    try {
      ble.stopMonitoring();
      await ble.device?.disconnect();
      setState(() => connectedDevice = null); 
    } catch (e) {
      debugPrint("Erreur lors de la déconnexion : $e");
    }
  }

  Future<void> _checkIfAlreadyConnected() async {
    final ble = ref.read(bleProvider);
    final isConnected = await ble.isConnected();
    if (isConnected) {
      setState(() => connectedDevice = ble.device);
    }

    // Écoute des changements d'état Bluetooth
    ble.onDisconnected = () {
      if (mounted) {
        setState(() => connectedDevice = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connexion Bluetooth perdue")),
        );
      }
    };
  }
  

  Future<void> _showDevicePicker() async {
    setState(() => isScanning = true); // ← début du scan

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses.values.any((status) => status.isDenied)) {
      setState(() => isScanning = false);
      return;
    }

    List<ScanResult> results = [];

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    await Future.delayed(const Duration(seconds: 5));
    results = await FlutterBluePlus.scanResults.first;
    await FlutterBluePlus.stopScan();

    setState(() => isScanning = false); // ← fin du scan

    if (!mounted) return;

    final selected = await showDialog<ScanResult>(
      context: context,
      builder: (context) {
        final filteredResults = results
  //          .where((r) => r.device.platformName.startsWith('RC_CAR'))
            .toList();

        return AlertDialog(
          title: const Text('Select your RC Car Controller'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.builder(
                itemCount: filteredResults.length,
                itemBuilder: (context, index) {
                  final device = filteredResults[index].device;
                  final name = device.platformName.isNotEmpty ? device.platformName : device.remoteId.toString();
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(device.remoteId.toString()),
                    trailing: const Icon(Icons.bluetooth),
                    onTap: () => Navigator.pop(context, filteredResults[index]),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );

    if (selected != null) {
      final ble = ref.read(bleProvider);
      ble.device = selected.device;
      await ble.device!.connect(autoConnect: false);
      ble.startConnectionMonitor();
      await ble.setupCharacteristics();
      setState(() => connectedDevice = ble.device);
    }
  }


  @override
  Widget build(BuildContext context) {
    final name = connectedDevice?.platformName.isNotEmpty == true
        ? connectedDevice!.platformName
        : connectedDevice?.remoteId.toString() ?? "Unknown";

    return Stack(
      children: [
        // 👇 Toute ton UI normale dans un Scaffold
        Scaffold(
          appBar: AppBar(title: const Text('RC Car Control')),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showDevicePicker,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bluetooth,
                            size: 32,
                            color: connectedDevice != null ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  connectedDevice != null ? name : 'Tap to connect to ESP32',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                Text(
                                  connectedDevice != null ? 'Connected' : 'Not connected',
                                  style: TextStyle(
                                    color: connectedDevice != null ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (connectedDevice != null)
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: _disconnect,
                              tooltip: "Déconnecter",
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _showDevicePicker,
                              tooltip: "Rechercher",
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _navButton(context, 'Control', '/control', Icons.gamepad),
                const SizedBox(height: 16),
                _navButton(context, 'Telemetry', '/telemetry', Icons.bar_chart),
                const SizedBox(height: 16),
                _navButton(context, 'Settings', '/settings', Icons.settings),
              ],
            ),
          ),
        ),

        // 👇 Overlay par-dessus tout, AppBar incluse
        if (isScanning)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _navButton(BuildContext context, String label, String route, IconData icon) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
        onPressed: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
