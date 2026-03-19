import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/database_service.dart';

enum StatisticsRange { weekly, monthly }

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

Map<String, double> _aggregateByMonth(List<TransactionModel> transactions) {
  final rawTotals = <DateTime, double>{};
  for (final transaction in transactions) {
    final key = DateTime(transaction.date.year, transaction.date.month);
    rawTotals.update(
      key,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  final sortedKeys = rawTotals.keys.toList()..sort();
  final visibleKeys = sortedKeys.length > 6
      ? sortedKeys.sublist(sortedKeys.length - 6)
      : sortedKeys;

  final formatter = DateFormat('MM/yyyy');
  return {
    for (final key in visibleKeys) formatter.format(key): rawTotals[key] ?? 0,
  };
}

Map<String, double> _aggregateByWeek(List<TransactionModel> transactions) {
  final rawTotals = <DateTime, double>{};
  for (final transaction in transactions) {
    final date = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    rawTotals.update(
      startOfWeek,
      (value) => value + transaction.amount,
      ifAbsent: () => transaction.amount,
    );
  }

  final sortedKeys = rawTotals.keys.toList()..sort();
  final visibleKeys = sortedKeys.length > 8
      ? sortedKeys.sublist(sortedKeys.length - 8)
      : sortedKeys;

  return {
    for (final key in visibleKeys)
      'T${_weekOfMonth(key)}\n${DateFormat('dd/MM').format(key)}':
          rawTotals[key] ?? 0,
  };
}

int _weekOfMonth(DateTime date) {
  final firstDay = DateTime(date.year, date.month, 1);
  return ((date.day + firstDay.weekday - 2) ~/ 7) + 1;
}
