import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';

String _subtitleDate(TransactionModel t) {
  final created = DateFormat.yMMMd('vi_VN').format(t.createdAt);
  final updated = DateFormat.yMMMd('vi_VN').format(t.updatedAt);
  if (t.updatedAt.difference(t.createdAt).inSeconds == 0) return created;
  return '$created (Sửa: $updated)';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  String searchQuery = '';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

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
            Text('Trang chính', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<List<TransactionModel>>(
              valueListenable: db.transactions,
              builder: (context, txs, _) {
                return _BalanceCard(
                  balance: db.balance,
                  income: db.totalIncome,
                  expense: db.totalExpense,
                  currency: currency,
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Giao dịch gần đây',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) =>
                    setState(() => searchQuery = v.trim().toLowerCase()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ValueListenableBuilder<List<TransactionModel>>(
                valueListenable: db.transactions,
                builder: (context, txs, _) {
                  var recent = List.of(txs.reversed).take(6).toList();
                  if (searchQuery.isNotEmpty) {
                    recent = recent
                        .where(
                          (t) => t.title.toLowerCase().contains(searchQuery),
                        )
                        .toList();
                  }
                  if (recent.isEmpty) {
                    return const Center(child: Text('Không có giao dịch'));
                  }
                  return ListView.separated(
                    itemCount: recent.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final t = recent[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.type == TransactionType.income
                              ? Colors.green
                              : Colors.red,
                          child: Icon(
                            t.type == TransactionType.income
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(t.title),
                        subtitle: Text(
                          '${t.category}${t.note != null && t.note!.isNotEmpty ? ' • ${t.note}' : ''} • ${_subtitleDate(t)}',
                        ),
                        trailing: Text(
                          (t.type == TransactionType.income ? '+ ' : '- ') +
                              currency.format(t.amount),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(editing: t),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  final NumberFormat currency;

  const _BalanceCard({
    required this.balance,
    required this.income,
    required this.expense,
    required this.currency,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Số dư hiện tại', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              currency.format(balance),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tổng thu',
                      style: TextStyle(color: Colors.green),
                    ),
                    Text(currency.format(income)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tổng chi', style: TextStyle(color: Colors.red)),
                    Text(currency.format(expense)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
