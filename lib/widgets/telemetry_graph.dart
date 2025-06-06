import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TelemetrySeries {
  final String label;
  final Color color;
  final double? invalidValue;
  final List<FlSpot> data = [];
  bool enabled;

  TelemetrySeries(
    this.label,
    this.color, {
    this.invalidValue,
    this.enabled = true,
  });

  void add(FlSpot point, double maxDuration) {
    if (invalidValue != null && point.y == invalidValue) return;
    data.add(point);
    data.removeWhere((p) => point.x - p.x > maxDuration);
  }

  bool get hasValidData {
    if (data.isEmpty) return false;
    if (invalidValue == null) return true;
    return data.any((p) => p.y != invalidValue);
  }

  List<FlSpot> get safeData => data.isEmpty
      ? [const FlSpot(0, 0)]
      : data.where((p) => invalidValue == null || p.y != invalidValue).toList();

}

class TelemetryGraph extends StatefulWidget {
  final String title;
  final double minY;
  final double maxY;
  final double graphDuration;
  final List<TelemetrySeries> seriesList;

  const TelemetryGraph({
    super.key,
    required this.title,
    required this.minY,
    required this.maxY,
    required this.graphDuration,
    required this.seriesList,
  });

  @override
  State<TelemetryGraph> createState() => _TelemetryGraphState();
}

class _TelemetryGraphState extends State<TelemetryGraph> {
  
  ({double minX, double maxX}) computeGraphWindow(List<FlSpot> data, double graphDuration) {
    if (data.isEmpty) {
      return (minX: 0, maxX: graphDuration);
    }

    final minX = data.first.x;
    final maxX = minX + graphDuration;

    return (minX: minX, maxX: maxX);
  }

  @override
  Widget build(BuildContext context) {

    final allPoints = widget.seriesList.expand((s) => s.safeData).toList();
    final window = computeGraphWindow(allPoints, widget.graphDuration);

    final minX = window.minX;
    final maxX = window.maxX;

    final visibleSeries = widget.seriesList
        .where((s) => s.enabled && s.hasValidData)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: widget.minY,
              maxY: widget.maxY,
              lineBarsData: visibleSeries.map(_line).toList(),
              lineTouchData: LineTouchData(enabled: true),
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() == 110 || value.toInt() == -110) {
                        return const SizedBox.shrink();
                      }
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    },
                  ),
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
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: widget.seriesList
            .where((s) => s.hasValidData)
            .map(_legendSelector)
            .toList(),
        ),
      ],
    );
  }

  LineChartBarData _line(TelemetrySeries s) {
    return LineChartBarData(
      spots: s.safeData,
      isCurved: true,
      preventCurveOverShooting: true,
      color: s.color,
      dotData: FlDotData(show: false),
      barWidth: 2,
    );
  }

  Widget _legendSelector(TelemetrySeries s) {
    final isDisabled = !s.hasValidData;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () {
              setState(() {
                s.enabled = !s.enabled;
              });
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            s.enabled && !isDisabled
                ? Icons.circle
                : Icons.radio_button_unchecked,
            size: 14,
            color: isDisabled ? Colors.grey : s.color,
          ),
          const SizedBox(width: 4),
          Text(
            s.label,
            style: TextStyle(
              color: isDisabled
                  ? Colors.grey
                  : (s.enabled ? Colors.black : Colors.grey.shade700),
              fontWeight: s.enabled ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
