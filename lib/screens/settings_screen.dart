import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  double frontRearRatioValue = 50;
  double frontDiffValue = 50;
  double rearDiffValue = 50;

  bool showFrontRearSlider = false;
  bool showFrontSlider = false;
  bool showRearSlider = false;

  double throttleDeadzone = 5;
  double steeringDeadzone = 5;
  double steeringTrim = 0;

  bool rampingEnabled = false;
  bool coastingEnabled = true;

  bool frontMotorsEnabled = false;
  bool rearMotorsEnabled = true;

  void updateFromBytes(List<int> data) {
    if (data.length < 8 || data[0] != 0x01) return;

    final flags = data[1];

    setState(() {
      rampingEnabled = (flags & 0x01) != 0;
      coastingEnabled = (flags & 0x02) != 0;
      frontMotorsEnabled = (flags & 0x04) != 0;
      rearMotorsEnabled = (flags & 0x08) != 0;

      frontDiffValue = data[2].toDouble();
      rearDiffValue = data[3].toDouble();
      frontRearRatioValue = data[4].toDouble();
      throttleDeadzone = data[5].toDouble();
      steeringDeadzone = data[6].toDouble();
      steeringTrim = data[7].toDouble() - 50;
    });
  }

  List<int> _encodeSettings() {
    int flags = 0;
    if (rampingEnabled) flags |= 0x01;
    if (coastingEnabled) flags |= 0x02;
    if (frontMotorsEnabled) flags |= 0x04;
    if (rearMotorsEnabled) flags |= 0x08;

    return [
      0x01,
      flags,
      frontDiffValue.toInt(),
      rearDiffValue.toInt(),
      frontRearRatioValue.toInt(),
      throttleDeadzone.toInt(),
      steeringDeadzone.toInt(),
      (steeringTrim + 50).toInt(),
    ];
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final ble = ref.read(bleProvider);
      ble.setScreen("settings");
      ble.onSettingsReceived = updateFromBytes;
      ble.sendCommand("loadSettings");
    });
  }

  @override
  Widget build(BuildContext context) {
    final frontRearRatioEnabled = frontMotorsEnabled && rearMotorsEnabled;
    final bleConnectionState = ref.watch(bleConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final ble = ref.read(bleProvider);
                    ble.sendCommand("loadSettings");
                  },
                  icon: const Icon(Icons.download),
                  label: const Text("Load"),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final ble = ref.read(bleProvider);
                    final data = _encodeSettings();
                    ble.sendSettings(data);
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text("Save"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -20,
                  child: Text(
                    'Front',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Image.asset(
                  'assets/images/car_schema.png',
                  width: 300,
                  fit: BoxFit.contain,
                ),
                Positioned(
                  top: 130,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      showFrontRearSlider = !showFrontRearSlider;
                      showFrontSlider = false;
                      showRearSlider = false;
                    }),
                    child: Container(
                      width: 60,
                      height: 30,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: frontRearRatioEnabled
                          ? Text(
                              '${frontRearRatioValue.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.block,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 45,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      showFrontSlider = !showFrontSlider;
                      showRearSlider = false;
                      showFrontRearSlider = false;
                    }),
                    child: Container(
                      width: 60,
                      height: 30,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: frontMotorsEnabled
                          ? Text(
                              '${frontDiffValue.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.block,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 45,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      showRearSlider = !showRearSlider;
                      showFrontSlider = false;
                      showFrontRearSlider = false;
                    }),
                    child: Container(
                      width: 60,
                      height: 30,
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: rearMotorsEnabled
                          ? Text(
                              '${rearDiffValue.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.block,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (showFrontRearSlider) ...[
              Row(
                children: [
                  const Text("Front/Rear Ratio"),
                ],
              ),
              Slider(
                value: frontRearRatioValue,
                onChanged: frontRearRatioEnabled ? (value) => setState(() => frontRearRatioValue = value) : null,
                min: 0,
                max: 100,
                divisions: 100,
                label: frontRearRatioEnabled ? frontRearRatioValue.toInt().toString() : 'none',
              ),
            ],
            if (showFrontSlider) ...[
              Row(
                children: [
                  const Text("Enabled"),
                  Checkbox(
                    value: frontMotorsEnabled,
                    onChanged: (value) => setState(() => frontMotorsEnabled = value!),
                  ),
                ],
              ),
              const Text('Front Differential'),
              Slider(
                value: frontDiffValue,
                onChanged: frontMotorsEnabled ? (value) => setState(() => frontDiffValue = value) : null,
                min: 0,
                max: 100,
                divisions: 100,
                label: frontMotorsEnabled ? frontDiffValue.toInt().toString() : 'none',
              ),
            ],
            if (showRearSlider) ...[
              Row(
                children: [
                  const Text("Enabled"),
                  Checkbox(
                    value: rearMotorsEnabled,
                    onChanged: (value) => setState(() => rearMotorsEnabled = value!),
                  ),
                ],
              ),
              const Text('Rear Differential'),
              Slider(
                value: rearDiffValue,
                onChanged: rearMotorsEnabled ? (value) => setState(() => rearDiffValue = value) : null,
                min: 0,
                max: 100,
                divisions: 100,
                label: rearMotorsEnabled ? rearDiffValue.toInt().toString() : 'none',
              ),
            ],
            const Text(
              'Steering Trim',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                const Text('Trim:'),
                Expanded(
                  child: Slider(
                    value: steeringTrim,
                    onChanged: (value) => setState(() => steeringTrim = value),
                    min: -50,
                    max: 50,
                    divisions: 100,
                    label: '${steeringTrim.toInt()} %'
                  ),
                ),
                SizedBox(width: 8),
                Text('${steeringTrim.toInt()} %'),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Deadzones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Throttle:'),
                Expanded(
                  child: Slider(
                    value: throttleDeadzone,
                    onChanged: (value) => setState(() => throttleDeadzone = value),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: '${throttleDeadzone.toInt()} %',
                  ),
                ),
                SizedBox(width: 8),
                Text('${throttleDeadzone.toInt()} %'),
              ],
            ),
            Row(
              children: [
                const Text('Steering:'),
                Expanded(
                  child: Slider(
                    value: steeringDeadzone,
                    onChanged: (value) => setState(() => steeringDeadzone = value),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    label: '${steeringDeadzone.toInt()} %',
                  ),
                ),
                SizedBox(width: 8),
                Text('${steeringDeadzone.toInt()} %'),
              ],
            ),
            const Divider(height: 32),
            SwitchListTile(
              title: const Text('Enable ramping'),
              value: rampingEnabled,
              onChanged: (value) => setState(() => rampingEnabled = value),
            ),
            SwitchListTile(
              title: const Text('Enable coasting'),
              value: coastingEnabled,
              onChanged: (value) => setState(() => coastingEnabled = value),
            ),
          ],
        ),
      ),
    );
  }
}
