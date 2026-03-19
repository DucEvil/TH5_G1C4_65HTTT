import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';

class TransactionListScreen extends StatefulWidget {
  static const routeName = '/transactions';
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  TransactionType? _filterType;
  String _searchQuery = '';

  String _subtitleDate(TransactionModel t) {
    final created = DateFormat.yMMMd('vi_VN').format(t.createdAt);
    final updated = DateFormat.yMMMd('vi_VN').format(t.updatedAt);
    if (t.updatedAt.difference(t.createdAt).inSeconds == 0) return created;
    return '$created (Sửa: $updated)';
  }

  @override
  Widget build(BuildContext context) {
    final db = DatabaseService.instance;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách giao dịch'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (s) {
              setState(() {
                if (s == 'All') _filterType = null;
                if (s == 'Thu') _filterType = TransactionType.income;
                if (s == 'Chi') _filterType = TransactionType.expense;
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'All', child: Text('Tất cả')),
              PopupMenuItem(value: 'Thu', child: Text('Thu')),
              PopupMenuItem(value: 'Chi', child: Text('Chi')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
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
              onChanged: (q) =>
                  setState(() => _searchQuery = q.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: db.transactions,
              builder: (context, List<TransactionModel> txs, _) {
                final base = _filterType == null
                    ? txs
                    : txs.where((t) => t.type == _filterType).toList();
                final list = _searchQuery.isEmpty
                    ? base
                    : base
                          .where(
                            (t) => t.title.toLowerCase().contains(_searchQuery),
                          )
                          .toList();
                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 96,
                          color: Colors.black12,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Bạn chưa có ghi chú nào, hãy tạo mới nhé!',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = list[index];
                    return Dismissible(
                      key: Key(t.id),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Xác nhận'),
                            content: const Text(
                              'Bạn có chắc chắn muốn xóa chi tiêu này không?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Hủy'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('OK'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) db.delete(t.id);
                        return ok == true;
                      },
                      child: ListTile(
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
                        title: Text(t.title.isEmpty ? t.category : t.title),
                        subtitle: Text(
                          t.note == null || t.note!.isEmpty
                              ? _subtitleDate(t)
                              : '${t.note} • ${_subtitleDate(t)}',
                        ),
                        trailing: Text(
                          (t.type == TransactionType.income ? '+ ' : '- ') +
                              currency.format(t.amount),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTransactionScreen(editing: t),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
