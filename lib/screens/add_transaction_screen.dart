import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../services/database_service.dart';
import '../data/categories.dart';

class AddTransactionScreen extends StatefulWidget {
  static const routeName = '/add';
  final TransactionModel? editing;

  const AddTransactionScreen({super.key, this.editing});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // no explicit Form validation; using auto-save and simple inputs
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = kDefaultCategories.first;
  DateTime _date = DateTime.now();

  bool _dirty = false; // tracked changes

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _category = e.category;
      _date = e.date;
    }

    // mark dirty when fields change
    _titleCtrl.addListener(() => _dirty = true);
    _amountCtrl.addListener(() => _dirty = true);
    _noteCtrl.addListener(() => _dirty = true);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _autoSaveIfNeeded() async {
    // Only save if user made changes and at least amount > 0 or title/note not empty
    final amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    final hasContent =
        amount > 0 ||
        _titleCtrl.text.trim().isNotEmpty ||
        _noteCtrl.text.trim().isNotEmpty;
    if (!_dirty && widget.editing == null) return;
    if (!hasContent) return;

    final id = widget.editing?.id ?? DateTime.now().toIso8601String();
    final now = DateTime.now();
    final tx = TransactionModel(
      id: id,
      amount: amount,
      type: _type,
      title: _titleCtrl.text.isEmpty ? _category : _titleCtrl.text,
      category: _category,
      note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      date: _date,
      createdAt: widget.editing?.createdAt ?? now,
      updatedAt: now,
    );

    final db = DatabaseService.instance;
    if (widget.editing == null) {
      db.add(tx);
    } else {
      db.update(id, tx);
    }
  }

  Future<bool> _onWillPop() async {
    await _autoSaveIfNeeded();
    // allow pop
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat.yMMMMd('vi_VN').format(_date);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TH5 - Nhóm G1C4'),
              const SizedBox(height: 2),
              Text(
                widget.editing == null ? 'Thêm chi tiêu' : 'Sửa chi tiêu',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Tiêu đề (ví dụ: Mua cafe)',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Amount
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Số tiền',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: 'VNĐ',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<TransactionType>(
                          value: _type,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: TransactionType.income,
                              child: Text('Thu'),
                            ),
                            DropdownMenuItem(
                              value: TransactionType.expense,
                              child: Text('Chi'),
                            ),
                          ],
                          onChanged: (v) => setState(
                            () => _type = v ?? TransactionType.expense,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _category,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: kDefaultCategories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => _category = v ?? kDefaultCategories.first,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Note
                  TextField(
                    controller: _noteCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ghi chú (tuỳ chọn)',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ngày: $dateText',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: _pickDate,
                        child: const Text('Chọn'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tự động lưu khi bạn quay lại',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
