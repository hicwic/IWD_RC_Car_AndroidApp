import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../ble/ble_provider.dart';
import '../data/car_settings.dart';
import '../data/rc_protocol.dart';
import 'dart:typed_data';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

extension WheelDriveTypeLabel on WheelDriveType {
  String get label {
    switch (this) {
      case WheelDriveType.xcwDrive:
        return "Central Wheel Drive (XCWD)";
      case WheelDriveType.fiwDrive:
        return "Front In wheel drive (FIWD)";
      case WheelDriveType.riwDrive:
        return "Rear In wheel Drive (RIWD)";
      case WheelDriveType.aiwDrive:
        return "All In wheel drive (AIWD)";
    }
  }
}

extension DriveTrainTypeLabel on DriveTrainType {
  String get label {
    switch (this) {
      case DriveTrainType.pwm: return "PWM";
      case DriveTrainType.dshot: return "DShot";
      case DriveTrainType.bdshot: return "Bi-Directional DShot";
    }
  }
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  CarSettings settings = CarSettings();

  bool showFrontRearSlider = false;
  bool showFrontSlider = false;
  bool showRearSlider = false;  

  late TextEditingController _rcNameController;


  Widget _buildDiffControl(int value, {required bool enabled, required GestureTapCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: enabled ? Colors.green.shade600 : Colors.grey,
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: enabled
            ? Text(
                '${value.toInt()}',
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
    );
  }


  Widget _buildDrivetrainSchema() {
    bool centerSelectorEnabled = settings.wheelDriveType == WheelDriveType.aiwDrive;
    bool frontSelectorEnabled = settings.wheelDriveType == WheelDriveType.fiwDrive || settings.wheelDriveType == WheelDriveType.aiwDrive;
    bool rearSelectorEnabled = settings.wheelDriveType == WheelDriveType.riwDrive || settings.wheelDriveType == WheelDriveType.aiwDrive;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (settings.wheelDriveType == WheelDriveType.xcwDrive)
          Image.asset(
            'assets/images/car_chassis_outline_swd.png',
            width: 300,
            fit: BoxFit.contain,
          ),
        if (settings.wheelDriveType == WheelDriveType.fiwDrive)
          Image.asset(
            'assets/images/car_chassis_outline_fwd.png',
            width: 300,
            fit: BoxFit.contain,
          ),     
        if (settings.wheelDriveType == WheelDriveType.riwDrive)
          Image.asset(
            'assets/images/car_chassis_outline_rwd.png',
            width: 300,
            fit: BoxFit.contain,
          ),
        if (settings.wheelDriveType == WheelDriveType.aiwDrive)
          Image.asset(
            'assets/images/car_chassis_outline_awd.png',
            width: 300,
            fit: BoxFit.contain,
          ),                       

          // Position Diff values
          if (settings.wheelDriveType != WheelDriveType.xcwDrive)
          Positioned(
            top: 210,
            child: _buildDiffControl(
                      settings.frontRearRatioValue,
                      enabled: centerSelectorEnabled,
                      onTap: () => setState(() {
                        showFrontRearSlider = !showFrontRearSlider;
                        showFrontSlider = false;
                        showRearSlider = false;
                      }),
                    )
          ),
          Positioned(
            top: 90,
            child: _buildDiffControl(
                      settings.frontDiffValue,
                      enabled: frontSelectorEnabled,
                      onTap: () => setState(() {
                        showFrontSlider = !showFrontSlider;
                        showRearSlider = false;
                        showFrontRearSlider = false;
                      }),
                    )
          ),
          Positioned(
            bottom: 95,
            child: _buildDiffControl(
                      settings.rearDiffValue,
                      enabled: rearSelectorEnabled,
                      onTap: () => setState(() {
                        showRearSlider = !showRearSlider;
                        showFrontSlider = false;
                        showFrontRearSlider = false;
                      }),
                    )
          ),          
      ],
    );
  }

  Widget buildLabeledSlider({
    required String label,
    required double value,
    required ValueChanged<double>? onChanged,
    required double min,
    required double max,
    required int divisions,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toInt()} %',
          ),
        ),
        const SizedBox(width: 8),
        Text('${value.toInt()} %'),
      ],
    );
  }

  Widget buildLabeledSwitch({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        const Spacer(),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget buildLabeledDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(label),
        ),
        Expanded(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            onChanged: onChanged,
            items: items.map((item) {
              return DropdownMenuItem<T>(
                value: item,
                child: Text(labelBuilder(item)),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void updateFromBytes(List<int> data) {
    try {
      final newSettings = CarSettings.fromBytes(Uint8List.fromList(data));
      setState(() {
        settings = newSettings;
        _rcNameController.text = settings.rcName;
      });
    } catch (_) {
      // ignore or handle error
    }
  }

  @override
  void initState() {
    super.initState();

    _rcNameController = TextEditingController(text: settings.rcName);

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      ble.setScreen("settings");
      ble.onSettingsReceived = updateFromBytes;
      ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_SETTINGS_LOAD));
    });
  }

  @override
  void dispose() {
    _rcNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = ref.watch(bleConnectionNotifierProvider);
    final circle = connection.when(
      data: (state) => CircleAvatar(
        radius: 6,
        backgroundColor: state == BluetoothConnectionState.connected
            ? Colors.green
            : Colors.red,
      ),
      loading: () => const CircleAvatar(radius: 6, backgroundColor: Colors.grey),
      error: (_, __) => const CircleAvatar(radius: 6, backgroundColor: Colors.grey),
    );



    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            tooltip: "Load settings",
            icon: const Icon(Icons.download),
            onPressed: () {
              final ble = ref.read(bleProvider);
              ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_SETTINGS_LOAD));
            },
          ),
          IconButton(
            tooltip: "Save settings",
            icon: const Icon(Icons.upload),
            onPressed: () {
              final ble = ref.read(bleProvider);
              final data = settings.toBytes();
              ble.sendData(RCProtocol.buildDataMessage(RCProtocol.DATA_TYPE_SETTINGS, data));
            },
          ),
          IconButton(
            tooltip: "Reset settings",
            icon: const Icon(Icons.restart_alt),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Reset settings"),
                  content: const Text("Are you sure you want to reset all settings to defaults?"),
                  actions: [
                    TextButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text("Confirm"),
                      onPressed: () {
                        setState(() {
                          final ble = ref.read(bleProvider);
                          ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_SETTINGS_RESET));
                          settings = CarSettings();
                          ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_SETTINGS_LOAD));
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: circle
          ),
        ],

      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'RC Name',
                border: OutlineInputBorder(),
              ),
              controller: _rcNameController,
              onChanged: (value) {
                setState(() {
                  settings.rcName = value;
                });
              },
            ),

            const SizedBox(height: 4),

            const Text(
              'Need reboot to apply RC name',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 16),        
            const Text(
              'Motor Outputs:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),            
            DropdownButton<WheelDriveType>(
              value: settings.wheelDriveType,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    showFrontSlider = false;
                    showRearSlider = false;
                    showFrontRearSlider = false;      
                    settings.wheelDriveType = value;              
                  });
                }
              },
              isExpanded: true,
              items: WheelDriveType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Center(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  _buildDrivetrainSchema(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (showFrontRearSlider) ...[
              Row(
                children: [
                  const Text("Front/Rear Ratio"),
                ],
              ),
              Slider(
                value: settings.frontRearRatioValue.toDouble(),
                onChanged: (value) => setState(() => settings.frontRearRatioValue = value.toInt()),
                min: 0,
                max: 100,
                divisions: 100,
                label: settings.frontRearRatioValue.toString(),
              ),
            ],
            if (showFrontSlider) ...[
              const Text('Front Differential'),
              Slider(
                value: settings.frontDiffValue.toDouble(),
                onChanged: (value) => setState(() => settings.frontDiffValue = value.toInt()),
                min: 0,
                max: 100,
                divisions: 100,
                label: settings.frontDiffValue.toString(),
              ),
            ],
            if (showRearSlider) ...[
              const Text('Rear Differential'),
              Slider(
                value: settings.rearDiffValue.toDouble(),
                onChanged: (value) => setState(() => settings.rearDiffValue = value.toInt()),
                min: 0,
                max: 100,
                divisions: 100,
                label: settings.rearDiffValue.toString(),
              ),
            ],

            if (settings.wheelDriveType == WheelDriveType.xcwDrive)
              buildLabeledDropdown<DriveTrainType>(
                label: 'Central Output:',
                value: settings.centralDriveTrainType,
                items: DriveTrainType.values,
                labelBuilder: (type) => type.label,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => settings.centralDriveTrainType = value);
                  }
                },
              ),

            if (settings.wheelDriveType == WheelDriveType.fiwDrive || settings.wheelDriveType == WheelDriveType.aiwDrive)
              buildLabeledDropdown<DriveTrainType>(
                label: 'Front Output:',
                value: settings.frontDriveTrainType,
                items: DriveTrainType.values,
                labelBuilder: (type) => type.label,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => settings.frontDriveTrainType = value);
                  }
                },
              ),

            if (settings.wheelDriveType == WheelDriveType.riwDrive || settings.wheelDriveType == WheelDriveType.aiwDrive)
            buildLabeledDropdown<DriveTrainType>(
              label: 'Rear Output:',
              value: settings.rearDriveTrainType,
              items: DriveTrainType.values,
              labelBuilder: (type) => type.label,
              onChanged: (value) {
                if (value != null) {
                  setState(() => settings.rearDriveTrainType = value);
                }
              },
            ),

            const Divider(height: 32),
            const Text(
              'Inputs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            buildLabeledSlider(
              label: 'Throttle Deadzone:',
              value: settings.throttleDeadzone.toDouble(),
              onChanged: (value) => setState(() => settings.throttleDeadzone = value.toInt()),
              min: 0,
              max: 20,
              divisions: 20,
            ),

            buildLabeledSlider(
              label: 'Steering Deadzone:',
              value: settings.steeringDeadzone.toDouble(),
              onChanged: (value) => setState(() => settings.steeringDeadzone = value.toInt()),
              min: 0,
              max: 20,
              divisions: 20,
            ),

            buildLabeledSlider(
              label: 'Throttle Trim:',
              value: settings.throttleTrim.toDouble(),
              onChanged: (value) => setState(() => settings.throttleTrim = value.toInt()),
              min: -50,
              max: 50,
              divisions: 100,
            ),

            buildLabeledSlider(
              label: 'Steering Trim:',
              value: settings.steeringTrim.toDouble(),
              onChanged: (value) => setState(() => settings.steeringTrim = value.toInt()),
              min: -50,
              max: 50,
              divisions: 100,
            ),
            const Divider(height: 32),
            const Text(
              'Special Logic',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),            
            buildLabeledSwitch(
              label: 'Enable ramping',
              value: settings.rampingEnabled,
              onChanged: (v) => setState(() => settings.rampingEnabled = v),
            ),

            buildLabeledSwitch(
              label: 'Enable coasting',
              value: settings.coastingEnabled,
              onChanged: (v) => setState(() => settings.coastingEnabled = v),
            ),
            buildLabeledSlider(
              label: 'Coasting Factor (/s):',
              value: settings.coastingFactor.toDouble(),
              onChanged: settings.coastingEnabled
                  ? (value) => setState(() => settings.coastingFactor = value.toInt())
                  : null, // <- désactive le slider
              min: 0,
              max: 100,
              divisions: 100,
            ),
          ],
        ),
      ),
    );
  }
}
