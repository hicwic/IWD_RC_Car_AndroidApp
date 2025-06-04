import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../ble/ble_provider.dart';
import '../data/rc_protocol.dart';
import '../data/telemetry.dart';

class TelemetryScreen extends ConsumerStatefulWidget {
  const TelemetryScreen({super.key});

  @override
  ConsumerState<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends ConsumerState<TelemetryScreen> {
  TelemetryData telemetryData = TelemetryData.empty;
  final List<FlSpot> targetData = [];
  final List<FlSpot> currentData = [];
  final List<FlSpot> rearLeftData = [];
  final List<FlSpot> rearRightData = [];
  final List<FlSpot> frontLeftData = [];
  final List<FlSpot> frontRightData = [];

  StreamSubscription<List<int>>? _bleSubscription;
  StreamSubscription<bool>? _connectionSub;

  bool telemetryPaused = true;

  double time = 0;
  Timer? timer;
  final Random rng = Random();

  double graphDuration = 10;
  final List<double> durationOptions = [10, 30, 60, 300];

  bool isConnected = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      final connection = ref.watch(bleConnectionNotifierProvider);
      final isConnected = connection.value == BluetoothConnectionState.connected;      
      if (isConnected) {
        ble.setScreen("telemetry");
        ble.onTelemetryReceived = _onDataReceived;
      }
    });
  }


  @override
  void dispose() {
    _bleSubscription?.cancel();
    _connectionSub?.cancel();
    super.dispose();
  }

  void _onDataReceived(List<int> raw) {
    telemetryData = TelemetryData.fromBytes(raw);

    setState(() {
      time += 0.2;
      _addPoint(targetData, FlSpot(time, telemetryData.targetSpeed));
      _addPoint(currentData, FlSpot(time, telemetryData.currentSpeed));
      _addPoint(rearLeftData, FlSpot(time, telemetryData.rearLeft));
      _addPoint(rearRightData, FlSpot(time, telemetryData.rearRight));
      _addPoint(frontLeftData, FlSpot(time, telemetryData.rearLeft));
      _addPoint(frontRightData, FlSpot(time, telemetryData.rearRight));      
    });
  }

  void _addPoint(List<FlSpot> list, FlSpot point) {
    list.add(point);
    list.removeWhere((p) => time - p.x > graphDuration);
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
            child: circle
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
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
                        _filterOldPoints();
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
                    telemetryPaused ? ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_TELEMETRY_RESUME)) : ble.sendData(RCProtocol.buildCommandMessage(RCProtocol.CMD_TELEMETRY_PAUSE)) ;

                    setState(() {
                      telemetryPaused = !telemetryPaused;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Speed Telemetry', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legend('Target', Colors.orange),
                _legend('Current', Colors.blue),
                _legend('Left', Colors.red),
                _legend('Right', Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: -110,
                  maxY: 110,
                  lineBarsData: [
                    _line(targetData, Colors.orange),
                    _line(currentData, Colors.blue),
                    _line(rearLeftData, Colors.red),
                    _line(rearRightData, Colors.green),
                    _line(frontLeftData, Colors.yellow),
                    _line(frontRightData, Colors.deepPurple),                    
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.bar.color == Colors.orange ? 'Target' : spot.bar.color == Colors.blue ? 'Current' : spot.bar.color == Colors.red ? 'Left' : 'Right'}: ${spot.y.toInt()}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
            const SizedBox(height: 16),
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

  void _filterOldPoints() {
    targetData.removeWhere((p) => time - p.x > graphDuration);
    currentData.removeWhere((p) => time - p.x > graphDuration);
    rearLeftData.removeWhere((p) => time - p.x > graphDuration);
    rearRightData.removeWhere((p) => time - p.x > graphDuration);
    frontLeftData.removeWhere((p) => time - p.x > graphDuration);
    frontRightData.removeWhere((p) => time - p.x > graphDuration);    
  }

  LineChartBarData _line(List<FlSpot> data, Color color) {
    final safeData = data.isEmpty ? [const FlSpot(0, 0)] : data;

    return LineChartBarData(
      spots: safeData,
      isCurved: true,
      color: color,
      dotData: FlDotData(show: false),
      barWidth: 2,
    );
  }

  Widget _legend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _statusChip(String label, bool value) {
    return Chip(
      label: Text(label),
      backgroundColor: value ? Colors.green.shade300 : Colors.grey.shade400,
    );
  }
}
