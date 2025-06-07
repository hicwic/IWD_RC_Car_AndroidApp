import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';

import '../ble/ble_provider.dart';
import '../data/rc_protocol.dart';
import '../widgets/telemetry_graph.dart';
import '../data/telemetryMotionData.dart';
import '../data/telemetryInputsData.dart';
import '../data/telemetryOutputsData.dart';
import '../utils/tlv_utils.dart';

enum GraphType {
  speed,
  inputs,
  outputs,
}

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  bool overrideControl = false;

  GraphType selectedGraph = GraphType.speed;

  double time = 0;
  final Stopwatch stopwatch = Stopwatch()..start();

  final List<TelemetrySeries> speedSeries = [
    TelemetrySeries('Target', Colors.orange, invalidValue: 999),
    TelemetrySeries('Current', Colors.blue, invalidValue: 999),
    TelemetrySeries('Rear Left', Colors.red, invalidValue: 999),
    TelemetrySeries('Rear Right', Colors.green, invalidValue: 999),
    TelemetrySeries('Front Left', Colors.yellow, invalidValue: 999),
    TelemetrySeries('Front Right', Colors.deepPurple, invalidValue: 999),
  ];

  final List<TelemetrySeries> inputSeries = [
    TelemetrySeries('CH1', Colors.red),
    TelemetrySeries('CH2', Colors.green),
    TelemetrySeries('CH3', Colors.blue),
    TelemetrySeries('CH4', Colors.orange),
  ];

  final List<TelemetrySeries> outputSeries = [
    TelemetrySeries('RearL', Colors.red),
    TelemetrySeries('RearR', Colors.green),
    TelemetrySeries('FrontL', Colors.blue),
    TelemetrySeries('FrontR', Colors.orange),
    TelemetrySeries('Central', Colors.purple),
    TelemetrySeries('Servo (PWM)', Colors.pink),    
  ];

  @override
  void initState() {
    super.initState();

    final ble = ref.read(bleProvider);
    ble.onTelemetryReceived = _onDataReceived;

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      ble.setScreen("control");
    });

  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onDataReceived(List<int> raw) {
    try {
      if (raw.length >= 2) {
        final msgType = raw[0];
        final dataType = raw[1];

        final currentTime = stopwatch.elapsedMilliseconds / 1000.0;
        double graphDuration = 10;

        if (msgType == RCProtocol.MSG_TYPE_DATA && dataType == RCProtocol.DATA_TYPE_TELEMETRY_MOTION) {
          final telemetryData = TelemetryData.fromBytes(raw);

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
              inputSeries[i].add(FlSpot(currentTime, inputs.channels[i].toDouble()), graphDuration);
            }
          });
        } else if (msgType == RCProtocol.MSG_TYPE_DATA && dataType == RCProtocol.DATA_TYPE_TELEMETRY_OUTPUTS) {
          final outputs = TelemetryOutputsData.fromBytes(raw);
          setState(() {
            for (int i = 0; i < outputs.outputs.length; i++) {
              final value = outputs.outputs[i];
              if (value != null) {
                outputSeries[i].add(FlSpot(currentTime, value.toDouble()), graphDuration);
              }
            }
          });
        }
      }
    } catch (e) {
      // ignore malformed data
    }
  }

  void _sendGraphTypeToEsp(GraphType type) {
    final ble = ref.read(bleProvider);
    int cmd;

    switch (type) {
      case GraphType.speed:
        cmd = RCProtocol.CMD_TELEMETRY_SEND_MOTION;
        break;
      case GraphType.inputs:
        cmd = RCProtocol.CMD_TELEMETRY_SEND_INPUTS;
        break;
      case GraphType.outputs:
        cmd = RCProtocol.CMD_TELEMETRY_SEND_OUTPUTS;
        break;
    }

    ble.sendData(RCProtocol.buildCommandMessage(cmd));
  }

  void _onJoystickMove(StickDragDetails details) {
    if (!overrideControl) return;

    int mapToPWM(double val) => (1500 + val * 500).clamp(1000, 2000).toInt();

    final writer = TLVWriter()
      ..addUint16(0x01, mapToPWM(details.x)) // CH1
      ..addUint16(0x02, mapToPWM(-details.y)); // CH2

    final ble = ref.read(bleProvider);
    ble.sendData(RCProtocol.buildDataMessage(RCProtocol.DATA_TYPE_CONTROL, writer.toBytes()));
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

    final graph = TelemetryGraph(
      title: selectedGraph == GraphType.speed
          ? 'Speed Telemetry'
          : selectedGraph == GraphType.inputs
              ? 'Inputs (PWM µs)'
              : 'Motor Outputs',
      minY: selectedGraph == GraphType.speed ? -110 : selectedGraph == GraphType.inputs ? 1000 : 0,
      maxY: selectedGraph == GraphType.speed ? 110 : selectedGraph == GraphType.inputs ? 2000 : 2100,
      graphDuration: 10,
      seriesList: selectedGraph == GraphType.speed
          ? speedSeries
          : selectedGraph == GraphType.inputs
              ? inputSeries
              : outputSeries,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Control'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: circle
          ),
        ],
      ),
      body: Column(
        children: [
          // Override toggle
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
                      final ble = ref.read(bleProvider);
                      overrideControl
                          ? ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_CONTROL_OVERRIDE))
                          : ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_CONTROL_RELEASE));
                    }
                  },
                ),
              ),
            ),
          ),

          // Graph selector + display
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Graph type:'),
                const SizedBox(width: 12),
                DropdownButton<GraphType>(
                  value: selectedGraph,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedGraph = value);
                      _sendGraphTypeToEsp(value);
                    }
                  },
                  items: GraphType.values.map((type) {
                    final label = switch (type) {
                      GraphType.speed => 'Speed',
                      GraphType.inputs => 'Inputs',
                      GraphType.outputs => 'Outputs',
                    };
                    return DropdownMenuItem(value: type, child: Text(label));
                  }).toList(),
                ),
                              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: graph,
          ),



          const Spacer(),

          Padding(
            padding: const EdgeInsets.only(bottom: 50),
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
