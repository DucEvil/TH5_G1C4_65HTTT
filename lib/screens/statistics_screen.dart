import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/expense_chart.dart';

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
    final cs = Theme.of(context).colorScheme;
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
        child: ValueListenableBuilder(
          valueListenable: db.transactions,
          builder: (context, List<TransactionModel> txs, _) {
            if (txs.isEmpty) {
              return const Center(child: Text('Không có dữ liệu'));
            }

            // Chart + aggregation
            final Map<String, double> byCategory = {};
            for (var t in txs) {
              byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
            }
            final items = byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(width: 12),
                  Flexible(child: action!),
                ],
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
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
    final total = totals.values.fold<double>(0, (sum, amount) => sum + amount);
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 52,
              sectionsSpace: 3,
              pieTouchData: PieTouchData(enabled: false),
              sections: List.generate(entries.length, (index) {
                final item = entries[index];
                final percentage = total == 0 ? 0.0 : item.value / total * 100;

                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: item.value,
                  radius: 72,
                  title: '${percentage.toStringAsFixed(0)}%',
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
        const SizedBox(height: 16),
        ...List.generate(entries.length, (index) {
          final item = entries[index];
          final percentage = total == 0 ? 0.0 : item.value / total * 100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[index % colors.length],
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  'Tổng thu: ${currency.format(db.totalIncome)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tổng chi: ${currency.format(db.totalExpense)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 12),
                // Chart showing recent spending
                ExpenseChart(transactions: txs),
                const SizedBox(height: 12),
                Text(
                  'Chi tiêu theo danh mục',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return ListTile(
                        title: Text(e.key),
                        trailing: Text(
                          currency.format(e.value),
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: cs.onSurface),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(entries.length, (index) {
                final item = entries[index];

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: item.value,
                      width: selectedRange == StatisticsRange.weekly ? 22 : 18,
                      borderRadius: BorderRadius.circular(8),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF0EA5E9)],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...entries.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  currency.format(item.value),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
