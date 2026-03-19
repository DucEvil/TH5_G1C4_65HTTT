import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

enum ChartGranularity { day, month, year }

class ExpenseChart extends StatefulWidget {
  final List<TransactionModel> transactions;
  const ExpenseChart({super.key, required this.transactions});

  @override
  State<ExpenseChart> createState() => _ExpenseChartState();
}

class _ExpenseChartState extends State<ExpenseChart> {
  ChartGranularity _granularity = ChartGranularity.day;

  void _setGranularity(ChartGranularity g) => setState(() => _granularity = g);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currency = NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '₫');
    final series = _buildSeries(widget.transactions, _granularity);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Biểu đồ chi tiêu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ToggleButtons(
                  isSelected: [
                    _granularity == ChartGranularity.day,
                    _granularity == ChartGranularity.month,
                    _granularity == ChartGranularity.year,
                  ],
                  onPressed: (i) => _setGranularity(ChartGranularity.values[i]),
                  children: const [Text('Ngày'), Text('Tháng'), Text('Năm')],
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: series.spots.isEmpty
                  ? Center(
                      child: Text(
                        'Không có dữ liệu',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: series.intervalY,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 60,
                              getTitlesWidget: (v, meta) {
                                return Text(currency.format(v));
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= series.labels.length)
                                  return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    series.labels[idx],
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        minX: 0,
                        maxX: (series.spots.length - 1).toDouble(),
                        minY: 0,
                        maxY: series.maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: series.spots,
                            isCurved: true,
                            color: theme.colorScheme.primary,
                            barWidth: 2,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  theme.colorScheme.primary.withOpacity(0.2),
                                  theme.colorScheme.primary.withOpacity(0.0),
                                ],
                              ),
                            ),
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  _Series _buildSeries(List<TransactionModel> txs, ChartGranularity g) {
    // Aggregate expenses only (type == expense). We show sums per bucket.
    final now = DateTime.now();
    if (g == ChartGranularity.day) {
      // last 14 days
      final Map<DateTime, double> map = {};
      for (int i = 13; i >= 0; i--) {
        final d = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: i));
        map[d] = 0.0;
      }
      for (var t in txs) {
        if (t.type != TransactionType.expense) continue;
        final d = DateTime(t.date.year, t.date.month, t.date.day);
        if (map.containsKey(d)) map[d] = (map[d] ?? 0) + t.amount;
      }
      final labels = map.keys
          .map((d) => DateFormat.Md('vi_VN').format(d))
          .toList();
      final spots = <FlSpot>[];
      double maxY = 0;
      for (int i = 0; i < labels.length; i++) {
        final y = map.values.elementAt(i);
        if (y > maxY) maxY = y;
        spots.add(FlSpot(i.toDouble(), y));
      }
      final interval = _niceInterval(maxY);
      return _Series(
        spots: spots,
        labels: labels,
        maxY: (maxY == 0 ? 1 : _roundUp(maxY)),
        intervalY: interval,
      );
    } else if (g == ChartGranularity.month) {
      // last 12 months
      final Map<String, double> map = {};
      for (int i = 11; i >= 0; i--) {
        final dt = DateTime(now.year, now.month - i, 1);
        final key = '${dt.year}-${dt.month}';
        map[key] = 0.0;
      }
      for (var t in txs) {
        if (t.type != TransactionType.expense) continue;
        final key = '${t.date.year}-${t.date.month}';
        if (map.containsKey(key)) map[key] = (map[key] ?? 0) + t.amount;
      }
      final labels = map.keys.map((k) {
        final parts = k.split('-');
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return DateFormat.MMM('vi_VN').format(DateTime(y, m));
      }).toList();
      final spots = <FlSpot>[];
      double maxY = 0;
      for (int i = 0; i < labels.length; i++) {
        final y = map.values.elementAt(i);
        if (y > maxY) maxY = y;
        spots.add(FlSpot(i.toDouble(), y));
      }
      final interval = _niceInterval(maxY);
      return _Series(
        spots: spots,
        labels: labels,
        maxY: (maxY == 0 ? 1 : _roundUp(maxY)),
        intervalY: interval,
      );
    } else {
      // yearly - last 5 years
      final Map<int, double> map = {};
      for (int i = 4; i >= 0; i--) {
        final y = now.year - i;
        map[y] = 0.0;
      }
      for (var t in txs) {
        if (t.type != TransactionType.expense) continue;
        if (map.containsKey(t.date.year))
          map[t.date.year] = (map[t.date.year] ?? 0) + t.amount;
      }
      final labels = map.keys.map((y) => y.toString()).toList();
      final spots = <FlSpot>[];
      double maxY = 0;
      for (int i = 0; i < labels.length; i++) {
        final y = map.values.elementAt(i);
        if (y > maxY) maxY = y;
        spots.add(FlSpot(i.toDouble(), y));
      }
      final interval = _niceInterval(maxY);
      return _Series(
        spots: spots,
        labels: labels,
        maxY: (maxY == 0 ? 1 : _roundUp(maxY)),
        intervalY: interval,
      );
    }
  }

  double _niceInterval(double maxY) {
    if (maxY <= 10) return 2;
    final pow = (maxY / 5).ceilToDouble();
    return pow;
  }

  double _roundUp(double v) {
    if (v <= 0) return 1;
    final magnitude = math.pow(10, v.toInt().toString().length - 1).toDouble();
    return ((v / magnitude).ceilToDouble()) * magnitude;
  }
}

class _Series {
  final List<FlSpot> spots;
  final List<String> labels;
  final double maxY;
  final double intervalY;
  _Series({
    required this.spots,
    required this.labels,
    required this.maxY,
    required this.intervalY,
  });
}
