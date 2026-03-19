import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import '../widgets/expense_chart.dart';

class StatisticsScreen extends StatelessWidget {
  static const routeName = '/statistics';
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder(
          valueListenable: db.transactions,
          builder: (context, List<TransactionModel> txs, _) {
            if (txs.isEmpty)
              return const Center(child: Text('Không có dữ liệu'));

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
                Text(
                  'Tổng thu: ${currency.format(db.totalIncome)}',
                  style: const TextStyle(color: Colors.green),
                ),
                Text(
                  'Tổng chi: ${currency.format(db.totalExpense)}',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 12),
                // Chart showing recent spending
                ExpenseChart(transactions: txs),
                const SizedBox(height: 12),
                const Text(
                  'Chi tiêu theo danh mục',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                        trailing: Text(currency.format(e.value)),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
