import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

enum StatisticsRange { weekly, monthly }

class _ExpensePoint {
  final DateTime date;
  final double amount;

  const _ExpensePoint({required this.date, required this.amount});
}

class StatisticsScreen extends StatefulWidget {
  static const routeName = '/statistics';

  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatisticsRange _selectedRange = StatisticsRange.monthly;

  static const List<Color> _chartColors = [
    Color(0xFF0F766E),
    Color(0xFF2563EB),
    Color(0xFFF97316),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFF65A30D),
    Color(0xFFE11D48),
  ];

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('TH5 - Nhóm G1C4'),
            SizedBox(height: 2),
            Text('Thống kê', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<List<TransactionModel>>(
          valueListenable: db.transactions,
          builder: (context, txs, _) {
            if (txs.isEmpty) return const _EmptyStatisticsState();
            final totals = _aggregateByCategory(txs);
            final expenseSeries = _aggregateExpenseByDay(
              txs,
              range: _selectedRange,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Biểu đồ theo danh mục',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _CategoryChart(
                  totals: totals,
                  currency: currency,
                  colors: _chartColors,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Xu hướng chi tiêu',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    SegmentedButton<StatisticsRange>(
                      segments: const [
                        ButtonSegment(
                          value: StatisticsRange.weekly,
                          label: Text('7 ngày'),
                        ),
                        ButtonSegment(
                          value: StatisticsRange.monthly,
                          label: Text('30 ngày'),
                        ),
                      ],
                      selected: {_selectedRange},
                      onSelectionChanged: (selection) {
                        setState(() => _selectedRange = selection.first);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ExpenseTrendChart(points: expenseSeries, currency: currency),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChart extends StatelessWidget {
  const _CategoryChart({
    required this.totals,
    required this.currency,
    required this.colors,
  });

  final Map<String, double> totals;
  final NumberFormat currency;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final total = totals.values.fold<double>(0, (s, v) => s + v);
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 48,
              sectionsSpace: 4,
              pieTouchData: PieTouchData(enabled: false),
              sections: List.generate(entries.length, (index) {
                final e = entries[index];
                final pct = total == 0 ? 0.0 : e.value / total * 100;
                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: e.value,
                  radius: 60,
                  title: '${pct.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[entries.indexOf(e) % colors.length],
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  currency.format(e.value),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseTrendChart extends StatelessWidget {
  const _ExpenseTrendChart({required this.points, required this.currency});

  final List<_ExpensePoint> points;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxY = points
        .map((e) => e.amount)
        .fold<double>(0, (prev, e) => e > prev ? e : prev);
    final safeMaxY = maxY <= 0 ? 1000.0 : (maxY * 1.2);
    final interval = points.length <= 10 ? 1 : (points.length / 6).ceil();

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: safeMaxY,
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: true),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final idx = spot.x.toInt();
                  final point = points[idx];
                  final date = DateFormat('dd/MM/yyyy').format(point.date);
                  return LineTooltipItem(
                    '$date\n${currency.format(point.amount)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: interval.toDouble(),
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('dd/MM').format(points[idx].date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: safeMaxY / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _compactCurrency(value),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              barWidth: 3,
              color: const Color(0xFF0F766E),
              dotData: const FlDotData(show: false),
              spots: List.generate(points.length, (index) {
                return FlSpot(index.toDouble(), points[index].amount);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

String _compactCurrency(double value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(0)}K';
  }
  return value.toStringAsFixed(0);
}

class _EmptyStatisticsState extends StatelessWidget {
  const _EmptyStatisticsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insert_chart_outlined, size: 84, color: Colors.black12),
            SizedBox(height: 14),
            Text(
              'Chưa có dữ liệu chi tiêu để thống kê.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Hãy thêm vài giao dịch chi tiêu để biểu đồ bắt đầu hiển thị.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

Map<String, double> _aggregateByCategory(List<TransactionModel> transactions) {
  final totals = <String, double>{};
  for (final transaction in transactions) {
    totals.update(
      transaction.category,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }
  return totals;
}

List<_ExpensePoint> _aggregateExpenseByDay(
  List<TransactionModel> transactions, {
  required StatisticsRange range,
}) {
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day);
  final days = range == StatisticsRange.weekly ? 7 : 30;
  final start = end.subtract(Duration(days: days - 1));

  final totals = <DateTime, double>{};
  for (int i = 0; i < days; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    totals[d] = 0;
  }

  for (final transaction in transactions) {
    if (transaction.type != TransactionType.expense) continue;
    final d = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    if (d.isBefore(start) || d.isAfter(end)) continue;
    totals[d] = (totals[d] ?? 0) + transaction.amount;
  }

  final keys = totals.keys.toList()..sort();
  return keys
      .map((d) => _ExpensePoint(date: d, amount: totals[d] ?? 0))
      .toList();
}
