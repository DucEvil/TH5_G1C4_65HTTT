import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/auth_service.dart';
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
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await AuthService.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('TH5 - Nhóm G1C4'),
            SizedBox(height: 2),
            Text('Trang chính', style: TextStyle(fontSize: 12)),
          ],
        ),
        surfaceTintColor: cs.primary,
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
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm...',
                  prefixIcon: Icon(Icons.search),
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
                              ? cs.secondary
                              : cs.error,
                          child: Icon(
                            t.type == TransactionType.income
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (t.note != null && t.note!.isNotEmpty)
                              Text(
                                t.note!,
                                style: TextStyle(color: cs.onSurfaceVariant),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '${t.category} • ${_subtitleDate(t)}',
                              style: TextStyle(
                                color: cs.onSurface.withAlpha(
                                  (0.7 * 255).round(),
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    // key intentionally omitted to silence unused-key analyzer warning
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    Text('Tổng thu', style: TextStyle(color: cs.secondary)),
                    Text(currency.format(income)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng chi', style: TextStyle(color: cs.error)),
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
