import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction.dart';
import '../services/auth_service.dart';
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
  // _formKey removed (unused)
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  TransactionType _type = TransactionType.expense;
  String _category = kDefaultCategories.first;
  DateTime _date = DateTime.now();
  bool _isSaving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _titleCtrl.text = e.title ?? '';
      _amountCtrl.text = e.amount.toString();
      _noteCtrl.text = e.note ?? '';
      _type = e.type;
      _category = e.category;
      _date = e.date;
    }
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
    final amountVal =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
    final titleText = _titleCtrl.text.trim();
    final noteText = _noteCtrl.text.trim();
    final hasContent =
        amountVal > 0 || titleText.isNotEmpty || noteText.isNotEmpty;
    if (!_dirty) return;
    if (!hasContent) return;

    final id =
        widget.editing?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();

    final tx = TransactionModel(
      id: id,
      amount: amountVal,
      type: _type,
      title: titleText.isEmpty ? _category : titleText,
      category: _category,
      note: noteText.isEmpty ? null : noteText,
      date: _date,
      createdAt: widget.editing?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _isSaving = true);
    final db = DatabaseService.instance;
    try {
      if (widget.editing == null) {
        db.add(tx);
      } else {
        db.update(id, tx);
      }

      // Cloud sync
      final ownerId = AuthService.instance.currentUid;
      final docRef = FirebaseFirestore.instance
          .collection('transactions')
          .doc(id);
      await docRef.set({
        'id': tx.id,
        'amount': tx.amount,
        'type': tx.type == TransactionType.income ? 'income' : 'expense',
        'title': tx.title,
        'category': tx.category,
        'note': tx.note,
        'date': Timestamp.fromDate(tx.date),
        'createdAt': Timestamp.fromDate(tx.createdAt),
        'updatedAt': Timestamp.fromDate(tx.updatedAt),
        'owner': ownerId,
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _onWillPop() async {
    await _autoSaveIfNeeded();
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
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        hintText: 'ví dụ: Mua cafe',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 8),
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
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
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
                    TextField(
                      controller: _noteCtrl,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ghi chú (tuỳ chọn)',
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    await _autoSaveIfNeeded();
                                    if (mounted) Navigator.pop(context, true);
                                  },
                            icon: const Icon(Icons.save),
                            label: Text(
                              _isSaving
                                  ? 'Đang lưu...'
                                  : (widget.editing == null
                                        ? 'Thêm'
                                        : 'Cập nhật'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
