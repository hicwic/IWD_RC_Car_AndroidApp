import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_provider.dart';

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  bool overrideControl = false;
  int pwmSteering = 1500;
  int pwmThrottle = 1500;
  Timer? _pwmTimer;

  double joystickX = 0;
  double joystickY = 0;

  @override
  void initState() {
    super.initState();

    // Simule les valeurs PWM radio
    _pwmTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        pwmSteering = 1500 + Random().nextInt(200) - 100;
        pwmThrottle = 1500 + Random().nextInt(200) - 100;
      });
    });
  }

  @override
  void dispose() {
    _pwmTimer?.cancel();
    super.dispose();
  }

  void _onJoystickMove(StickDragDetails details) {
    if (!overrideControl) return;

    setState(() {
      joystickX = details.x;
      joystickY = details.y;
    });

    // Ici tu peux envoyer les données vers l'ESP32 si besoin
    // Ex : sendToESP32(x: details.x, y: details.y);
  }

  @override
  Widget build(BuildContext context) {
    final bleConnectionState = ref.watch(bleConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: bleConnectionState.when(
              data: (state) {
                final isConnected = state == BluetoothConnectionState.connected;
                return CircleAvatar(
                  radius: 6,
                  backgroundColor: isConnected ? Colors.green : Colors.red,
                );
              },
              loading: () => const CircleAvatar(radius: 6, backgroundColor: Colors.orange),
              error: (_, __) => const CircleAvatar(radius: 6, backgroundColor: Colors.grey),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Encart PWM
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Radio Input (PWM)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Steering: $pwmSteering µs'),
                      Text('Throttle: $pwmThrottle µs'),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Case à cocher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Override control'),
                    ],
                  ),
                  subtitle: const Text('Bypass RC input with joystick'),
                  value: overrideControl,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => overrideControl = val);
                    }
                  },
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  'Throttle: ${(joystickY * 100).toInt()}',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Steering: ${(joystickX * 100).toInt()}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Joystick
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Joystick(
                  mode: JoystickMode.all,
                  listener: _onJoystickMove,
                  base: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  stick: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // Overlay si non activé
                if (!overrideControl)
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white70, size: 40),
                    ),
                  ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
