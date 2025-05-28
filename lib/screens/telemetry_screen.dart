import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:rc_car_deck/ble/ble_manager.dart';
import '../ble/ble_provider.dart';

class TelemetryScreen extends ConsumerStatefulWidget {
  const TelemetryScreen({super.key});

  @override
  ConsumerState<TelemetryScreen> createState() => _TelemetryScreenState();
}

class _TelemetryScreenState extends ConsumerState<TelemetryScreen> {
  final List<FlSpot> targetData = [];
  final List<FlSpot> currentData = [];
  final List<FlSpot> leftData = [];
  final List<FlSpot> rightData = [];

  StreamSubscription<List<int>>? _bleSubscription;
  StreamSubscription<bool>? _connectionSub;

  bool telemetryPaused = true;

  double time = 0;
  Timer? timer;
  final Random rng = Random();

  double graphDuration = 10;
  final List<double> durationOptions = [10, 30, 60, 300];

  bool reverse = false;
  bool readyForReverse = true;
  bool ramping = true;
  bool coasting = false;

  bool isConnected = true;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      final ble = ref.read(bleProvider);
      final connectionState = ref.watch(bleConnectionStateProvider);
      final isConnected = connectionState.value == BluetoothConnectionState.connected;      
      if (isConnected) {
        ble.setScreen("telemetry");

        final char = ble.commandChar;
        if (char != null) {
          char.setNotifyValue(true);
          _bleSubscription = char.lastValueStream.listen(_onDataReceived);
        }
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
    final str = String.fromCharCodes(raw);
    final fields = Map.fromEntries(
      str.split(',').map((e) => e.split(':')).where((e) => e.length == 2).map((e) => MapEntry(e[0], e[1])),
    );

    final t = double.tryParse(fields['ts'] ?? '') ?? 0;
    final c = double.tryParse(fields['cs'] ?? '') ?? 0;
    final l = double.tryParse(fields['rl'] ?? '') ?? 0;
    final r = double.tryParse(fields['rr'] ?? '') ?? 0;

    final rev = fields['rev'] == '1';
    final ready = fields['revOK'] == '1';
    final ramp = fields['ramp'] == '1';
    final coast = fields['coast'] == '1';

    setState(() {
      time += 0.2;
      _addPoint(targetData, FlSpot(time, t));
      _addPoint(currentData, FlSpot(time, c));
      _addPoint(leftData, FlSpot(time, l));
      _addPoint(rightData, FlSpot(time, r));

      reverse = rev;
      readyForReverse = ready;
      ramping = ramp;
      coasting = coast;
    });
  }

  void _addPoint(List<FlSpot> list, FlSpot point) {
    list.add(point);
    list.removeWhere((p) => time - p.x > graphDuration);
  }

  @override
  Widget build(BuildContext context) {
    final bleConnectionState = ref.watch(bleConnectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetry'),
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
                    final command = telemetryPaused ? "resumetelemetry" : "pausetelemetry";
                    ble.sendCommand(command);

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
                    _line(leftData, Colors.red),
                    _line(rightData, Colors.green),
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
                _statusChip('Reverse', reverse),
                _statusChip('ReadyForReverse', readyForReverse),
                _statusChip('Ramping', ramping),
                _statusChip('Coasting', coasting),
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
    leftData.removeWhere((p) => time - p.x > graphDuration);
    rightData.removeWhere((p) => time - p.x > graphDuration);
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
