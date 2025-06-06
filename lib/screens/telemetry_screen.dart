import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_provider.dart';
import '../data/rc_protocol.dart';
import '../data/car_settings.dart';
import '../data/telemetryMotionData.dart';
import '../data/telemetryInputsData.dart';
import '../data/telemetryOutputsData.dart';
import '../widgets/telemetry_graph.dart';

class TelemetryScreen extends ConsumerStatefulWidget {
  const TelemetryScreen({super.key});

  @override
  ConsumerState<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends ConsumerState<TelemetryScreen> {
  TelemetryData telemetryData = TelemetryData.empty;

  final Stopwatch stopwatch = Stopwatch();

  final List<TelemetrySeries> speedSeries = [
    TelemetrySeries('Target', Colors.orange, invalidValue: -128),
    TelemetrySeries('Current', Colors.blue, invalidValue: -128),
    TelemetrySeries('Rear Left', Colors.red, invalidValue: -128),
    TelemetrySeries('Rear Right', Colors.green, invalidValue: -128),
    TelemetrySeries('Front Left', Colors.yellow, invalidValue: -128),
    TelemetrySeries('Front Right', Colors.deepPurple, invalidValue: -128),
  ];

  final List<TelemetrySeries> _inputSeries = [
    TelemetrySeries('CH1', Colors.red),
    TelemetrySeries('CH2', Colors.green),
    TelemetrySeries('CH3', Colors.blue),
    TelemetrySeries('CH4', Colors.orange),
  ];

  final List<TelemetrySeries> _outputSeries = [
    TelemetrySeries('RearL', Colors.red),
    TelemetrySeries('RearR', Colors.green),
    TelemetrySeries('FrontL', Colors.blue),
    TelemetrySeries('FrontR', Colors.orange),
    TelemetrySeries('Central', Colors.purple),
  ];

  StreamSubscription<List<int>>? _bleSubscription;
  StreamSubscription<bool>? _connectionSub;

  bool telemetryPaused = true;

  Timer? timer;

  double graphDuration = 10;
  final List<double> durationOptions = [10, 30, 60, 300];

  bool isConnected = true;

  @override
  void initState() {
    super.initState();

    stopwatch.start();

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      final connection = ref.watch(bleConnectionNotifierProvider);
      final isConnected = connection.value == BluetoothConnectionState.connected;
      if (isConnected) {
        ble.setScreen("telemetry");
        ble.onTelemetryReceived = _onDataReceived;
      }
    });

    _updateOutputSeriesLabels();
  }

  @override
  void dispose() {
    _bleSubscription?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  void _updateOutputSeriesLabels() {
    final settings = ref.read(carSettingsProvider);
    _outputSeries.clear();

    switch (settings.wheelDriveType) {
      case WheelDriveType.xcwDrive:
        _outputSeries.add(TelemetrySeries('Central (${_driveModeLabel(settings.centralDriveTrainType)})', Colors.purple));
        break;

      case WheelDriveType.fiwDrive:
        _outputSeries.add(TelemetrySeries('Front L (${_driveModeLabel(settings.frontDriveTrainType)})', Colors.blue));
        _outputSeries.add(TelemetrySeries('Front R (${_driveModeLabel(settings.frontDriveTrainType)})', Colors.orange));
        break;

      case WheelDriveType.riwDrive:
        _outputSeries.add(TelemetrySeries('Rear L (${_driveModeLabel(settings.rearDriveTrainType)})', Colors.red));
        _outputSeries.add(TelemetrySeries('Rear R (${_driveModeLabel(settings.rearDriveTrainType)})', Colors.green));
        break;

      case WheelDriveType.aiwDrive:
        _outputSeries.add(TelemetrySeries('Front L (${_driveModeLabel(settings.frontDriveTrainType)})', Colors.blue));
        _outputSeries.add(TelemetrySeries('Front R (${_driveModeLabel(settings.frontDriveTrainType)})', Colors.orange));
        _outputSeries.add(TelemetrySeries('Rear L (${_driveModeLabel(settings.rearDriveTrainType)})', Colors.red));
        _outputSeries.add(TelemetrySeries('Rear R (${_driveModeLabel(settings.rearDriveTrainType)})', Colors.green));
        break;
    }
  }

  String _driveModeLabel(DriveTrainType type) {
    switch (type) {
      case DriveTrainType.pwm: return 'PWM';
      case DriveTrainType.dshot: return 'DShot';
      case DriveTrainType.bdshot: return 'BiDShot';
    }
  }


  void _onDataReceived(List<int> raw) {
    try {
      if (raw.length >= 2) {
        final msgType = raw[0];
        final dataType = raw[1];

        final currentTime = stopwatch.elapsedMilliseconds / 1000.0;

        if (msgType == RCProtocol.MSG_TYPE_DATA && dataType == RCProtocol.DATA_TYPE_TELEMETRY_MOTION) {
          telemetryData = TelemetryData.fromBytes(raw);

          setState(() {
            speedSeries[0].add(FlSpot(currentTime, telemetryData.targetSpeed), graphDuration);
            speedSeries[1].add(FlSpot(currentTime, telemetryData.currentSpeed), graphDuration);
            if (telemetryData.rearLeft != null) {
              speedSeries[2].add(FlSpot(currentTime, telemetryData.rearLeft!), graphDuration);
            }
            if (telemetryData.rearRight != null) {
              speedSeries[3].add(FlSpot(currentTime, telemetryData.rearRight!), graphDuration);
            }
            if (telemetryData.frontLeft != null) {
              speedSeries[4].add(FlSpot(currentTime, telemetryData.frontLeft!), graphDuration);
            }
            if (telemetryData.frontRight != null) {
              speedSeries[5].add(FlSpot(currentTime, telemetryData.frontRight!), graphDuration);
            }
          });
        } else if (msgType == RCProtocol.MSG_TYPE_DATA && dataType == RCProtocol.DATA_TYPE_TELEMETRY_INPUTS) {
          final inputs = TelemetryInputsData.fromBytes(raw);
          setState(() {
            for (int i = 0; i < inputs.channels.length; i++) {
              _inputSeries[i].add(FlSpot(currentTime, inputs.channels[i].toDouble()), graphDuration);
            }
          });
        } else if (msgType == RCProtocol.MSG_TYPE_DATA && dataType == RCProtocol.DATA_TYPE_TELEMETRY_OUTPUTS) {
          final outputs = TelemetryOutputsData.fromBytes(raw);
          setState(() {
            for (int i = 0; i < outputs.motors.length; i++) {
              final value = outputs.motors[i];
              if (value != null) {
                _outputSeries[i].add(FlSpot(currentTime, value.toDouble()), graphDuration);
              }
            }
          });
        }
      }
    } catch (_) {
      // ignore malformed data
    }
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
        title: const Text('Telemetry'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: circle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Graph Window:'),
                DropdownButton<double>(
                  value: graphDuration,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        graphDuration = value;
                      });
                    }
                  },
                  items: durationOptions.map((sec) {
                    String label = sec < 60 ? '${sec.toInt()}s' : '${(sec ~/ 60)}min';
                    return DropdownMenuItem(value: sec, child: Text(label));
                  }).toList(),
                ),
                IconButton(
                  icon: Icon(
                    telemetryPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.blueAccent,
                  ),
                  tooltip: telemetryPaused ? 'Reprendre la télémétrie' : 'Pause',
                  onPressed: () {
                    final ble = ref.read(bleProvider);
                    telemetryPaused
                        ? ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_TELEMETRY_RESUME))
                        : ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_TELEMETRY_PAUSE));

                    setState(() {
                      telemetryPaused = !telemetryPaused;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TelemetryGraph(
              title: 'Speed Telemetry',
              minY: -110,
              maxY: 110,
              graphDuration: graphDuration,
              seriesList: speedSeries,
            ),
            const SizedBox(height: 8),
            TelemetryGraph(
              title: 'Inputs (PWM µs)',
              minY: 1000,
              maxY: 2000,
              graphDuration: graphDuration,
              seriesList: _inputSeries,
            ),
            const SizedBox(height: 8),
            TelemetryGraph(
              title: 'Motor Outputs',
              minY: 0,
              maxY: 2100,
              graphDuration: graphDuration,
              seriesList: _outputSeries,
            ),
            const SizedBox(height: 8),
            const Text('System Status', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _statusChip('Reverse', telemetryData.reverse),
                _statusChip('ReadyForReverse', telemetryData.readyForReverse),
                _statusChip('Ramping', telemetryData.ramping),
                _statusChip('Coasting', telemetryData.coasting),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool value) {
    return Chip(
      label: Text(label),
      backgroundColor: value ? Colors.green.shade300 : Colors.grey.shade400,
    );
  }
}