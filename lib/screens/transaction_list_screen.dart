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
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử giao dịch')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
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
                      children: const [
                        Icon(
                          Icons.note_alt_outlined,
                          size: 96,
                          color: Colors.black12,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Không có giao dịch phù hợp với bộ lọc',
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
                              ? '${t.category} • ${_subtitleDate(t)}'
                              : '${t.category} • ${t.note} • ${_subtitleDate(t)}',
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
