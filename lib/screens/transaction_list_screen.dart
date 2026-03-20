import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/transaction.dart';
import 'add_transaction_screen.dart';
import 'package:intl/intl.dart';
import '../data/categories.dart';

class TransactionListScreen extends StatefulWidget {
  static const routeName = '/transactions';
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionType? _filterType;
  String? _filterCategory;
  DateTimeRange? _filterDateRange;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _subtitleDate(TransactionModel t) {
    final created = DateFormat.yMMMd('vi_VN').format(t.createdAt);
    final updated = DateFormat.yMMMd('vi_VN').format(t.updatedAt);
    if (t.updatedAt.difference(t.createdAt).inSeconds == 0) return created;
    return '$created (Sửa: $updated)';
  }

  bool _isInDateRange(DateTime date, DateTimeRange range) {
    final target = DateTime(date.year, date.month, date.day);
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    return !target.isBefore(start) && !target.isAfter(end);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange =
        _filterDateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
      locale: const Locale('vi', 'VN'),
      helpText: 'Lọc theo khoảng ngày',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
    );

    if (range != null) {
      setState(() => _filterDateRange = range);
    }
  }

  String _dateRangeLabel() {
    if (_filterDateRange == null) return 'Mọi ngày';
    final f = DateFormat('dd/MM/yyyy');
    return '${f.format(_filterDateRange!.start)} - ${f.format(_filterDateRange!.end)}';
  }

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
            Text('Danh sách giao dịch', style: TextStyle(fontSize: 12)),
          ],
        ),
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
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (q) =>
                  setState(() => _searchQuery = q.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TransactionType?>(
                    value: _filterType,
                    decoration: const InputDecoration(
                      labelText: 'Phân loại',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tất cả')),
                      DropdownMenuItem(
                        value: TransactionType.income,
                        child: Text('Thu'),
                      ),
                      DropdownMenuItem(
                        value: TransactionType.expense,
                        child: Text('Chi'),
                      ),
                    ],
                    onChanged: (value) => setState(() => _filterType = value),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _filterCategory,
                    decoration: const InputDecoration(
                      labelText: 'Loại chi tiêu',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tất cả'),
                      ),
                      ...kDefaultCategories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(category),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _filterCategory = value),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateRangeLabel()),
                  ),
                ),
                const SizedBox(width: 10),
                if (_filterDateRange != null ||
                    _filterType != null ||
                    _filterCategory != null ||
                    _searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterDateRange = null;
                        _filterType = null;
                        _filterCategory = null;
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                    child: const Text('Xóa lọc'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: db.transactions,
              builder: (context, List<TransactionModel> txs, _) {
                final sorted = List<TransactionModel>.from(txs)
                  ..sort((a, b) => b.date.compareTo(a.date));

                final list = sorted.where((t) {
                  if (_filterType != null && t.type != _filterType) {
                    return false;
                  }
                  if (_filterCategory != null &&
                      t.category != _filterCategory) {
                    return false;
                  }
                  if (_filterDateRange != null &&
                      !_isInDateRange(t.date, _filterDateRange!)) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final title = t.title.toLowerCase();
                    final note = (t.note ?? '').toLowerCase();
                    final category = t.category.toLowerCase();
                    final matchesSearch =
                        title.contains(_searchQuery) ||
                        note.contains(_searchQuery) ||
                        category.contains(_searchQuery);
                    if (!matchesSearch) return false;
                  }
                  return true;
                }).toList();

                if (list.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 96,
                          color: cs.onSurface.withAlpha((0.12 * 255).round()),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Bạn chưa có ghi chú nào, hãy tạo mới nhé!',
                          style: TextStyle(color: cs.onSurfaceVariant),
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
                        color: cs.error,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 16),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: cs.error,
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
                              'Bạn có chắc chắn muốn xóa giao dịch này không?',
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
                        if (ok == true) {
                          try {
                            await db.deleteTransaction(t);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Xóa thất bại: $e')),
                              );
                            }
                            return false;
                          }
                        }
                        return ok == true;
                      },
                      child: ListTile(
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
