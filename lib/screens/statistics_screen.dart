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
      appBar: AppBar(title: const Text('Thống kê')),
      body: ValueListenableBuilder<List<TransactionModel>>(
        valueListenable: db.transactions,
        builder: (context, transactions, _) {
          final expenses = transactions
              .where((t) => t.type == TransactionType.expense)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          if (expenses.isEmpty) {
            return const _EmptyStatisticsState();
          }

          final categoryTotals = _aggregateByCategory(expenses);
          final periodTotals = _selectedRange == StatisticsRange.weekly
              ? _aggregateByWeek(expenses)
              : _aggregateByMonth(expenses);
          final totalExpense = expenses.fold<double>(
            0,
            (sum, item) => sum + item.amount,
          );
          final topCategory = categoryTotals.entries.reduce(
            (current, next) => current.value >= next.value ? current : next,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _OverviewCard(
                totalExpense: totalExpense,
                totalTransactions: expenses.length,
                topCategory: topCategory.key,
                topCategoryAmount: topCategory.value,
                currency: currency,
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Chi tiêu theo danh mục',
                subtitle: 'Tỷ trọng từng nhóm chi trong toàn bộ giao dịch.',
                child: _CategoryChart(
                  totals: categoryTotals,
                  currency: currency,
                  colors: _chartColors,
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Chi tiêu theo thời gian',
                subtitle: 'So sánh xu hướng chi tiêu theo tuần hoặc theo tháng.',
                action: SegmentedButton<StatisticsRange>(
                  segments: const [
                    ButtonSegment<StatisticsRange>(
                      value: StatisticsRange.weekly,
                      label: Text('Tuần'),
                      icon: Icon(Icons.view_week_outlined),
                    ),
                    ButtonSegment<StatisticsRange>(
                      value: StatisticsRange.monthly,
                      label: Text('Tháng'),
                      icon: Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                  selected: {_selectedRange},
                  onSelectionChanged: (selection) {
                    setState(() => _selectedRange = selection.first);
                  },
                ),
                child: _TimeChart(
                  totals: periodTotals,
                  currency: currency,
                  selectedRange: _selectedRange,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalExpense,
    required this.totalTransactions,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.currency,
  });

  final double totalExpense;
  final int totalTransactions;
  final String topCategory;
  final double topCategoryAmount;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Báo cáo chi tiêu',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currency.format(totalExpense),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricChip(
                label: 'Số giao dịch',
                value: '$totalTransactions',
              ),
              _MetricChip(
                label: 'Chi nhiều nhất',
                value: topCategory,
              ),
              _MetricChip(
                label: 'Mức cao nhất',
                value: currency.format(topCategoryAmount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                  '${percentage.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(width: 12),
                Text(
                  currency.format(item.value),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TimeChart extends StatelessWidget {
  const _TimeChart({
    required this.totals,
    required this.currency,
    required this.selectedRange,
  });

  final Map<String, double> totals;
  final NumberFormat currency;
  final StatisticsRange selectedRange;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList();
    final maxValue = entries.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: maxValue == 0 ? 10 : maxValue * 1.2,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxValue == 0 ? 2 : maxValue / 4,
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 54,
                    interval: maxValue == 0 ? 2 : maxValue / 4,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          _compactCurrency(value),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          entries[index].key,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
