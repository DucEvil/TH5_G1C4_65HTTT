import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/calendar_service.dart';
import '../services/cloudinary_service.dart';

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
  TimeOfDay _time = TimeOfDay.fromDateTime(DateTime.now());
  bool _dirty = false;
  File? _imageFile;
  File? _pickedFile;
  Uint8List? _handwritingBytes;
  final TextEditingController _presetCtrl = TextEditingController();
  final SignatureController _signatureCtrl = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

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
      _time = TimeOfDay.fromDateTime(e.date);
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
    _presetCtrl.dispose();
    _signatureCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: source);
    if (x == null) return;
    setState(() {
      _imageFile = File(x.path);
      _dirty = true;
    });
  }

  Future<void> _showImageSourcePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Chụp ảnh bằng camera'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAnyFile() async {
    final r = await FilePicker.platform.pickFiles(withData: false);
    if (r == null || r.files.isEmpty || r.files.first.path == null) return;
    setState(() {
      _pickedFile = File(r.files.first.path!);
      _dirty = true;
    });
  }

  Future<void> _captureHandwriting() async {
    final result = await showDialog<Uint8List>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chữ viết tay'),
          content: SizedBox(
            width: 320,
            height: 220,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Signature(
                      controller: _signatureCtrl,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _signatureCtrl.clear(),
                      child: const Text('Xóa nét'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final bytes = await _signatureCtrl.toPngBytes();
                        if (!mounted) return;
                        nav.pop(bytes);
                      },
                      child: const Text('Lưu'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    _signatureCtrl.clear();
    if (result == null) return;
    setState(() {
      _handwritingBytes = result;
      _dirty = true;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Chọn giờ',
      cancelText: 'Hủy',
      confirmText: 'Áp dụng',
    );
    if (t == null) return;
    if (!mounted) return;
    setState(() {
      _date = d;
      _time = t;
      _dirty = true;
    });
  }

  Future<bool> _ensureCloudinaryPresetIfNeeded() async {
    final cloud = CloudinaryService.instance;
    await cloud.initialize();
    if (cloud.isConfigured) return true;
    if (!mounted) return false;

    _presetCtrl.clear();
    final preset = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Thiếu Cloudinary preset'),
          content: TextField(
            controller: _presetCtrl,
            decoration: const InputDecoration(
              labelText: 'Upload preset (unsigned)',
              hintText: 'Ví dụ: todoapp_unsigned',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, _presetCtrl.text),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    final value = (preset ?? '').trim();
    if (value.isEmpty) return false;
    await cloud.setUploadPreset(value);
    return true;
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

    final shouldUpload =
        _imageFile != null || _pickedFile != null || _handwritingBytes != null;
    if (shouldUpload) {
      final configured = await _ensureCloudinaryPresetIfNeeded();
      if (!configured) {
        return;
      }
    }

    final cloud = CloudinaryService.instance;
    String? imagePath = widget.editing?.imagePath;
    String? filePath = widget.editing?.filePath;
    String? handwritingPath = widget.editing?.handwritingPath;

    try {
      if (_imageFile != null) {
        imagePath = await cloud.uploadImagePath(_imageFile!);
      }
      if (_pickedFile != null) {
        filePath = await cloud.uploadFilePath(_pickedFile!);
      }
      if (_handwritingBytes != null) {
        handwritingPath = await cloud.uploadHandwritingPath(_handwritingBytes!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi upload Cloudinary: $e')));
      }
      return;
    }

    final selectedDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    final tx = TransactionModel(
      id: id,
      amount: amountVal,
      type: _type,
      title: titleText.isEmpty ? _category : titleText,
      category: _category,
      note: noteText.isEmpty ? null : noteText,
      date: selectedDateTime,
      createdAt: widget.editing?.createdAt ?? now,
      updatedAt: now,
      imagePath: imagePath,
      filePath: filePath,
      handwritingPath: handwritingPath,
    );

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
        'imagePath': tx.imagePath,
        'filePath': tx.filePath,
        'handwritingPath': tx.handwritingPath,
        'owner': ownerId,
        'calendarEventId': null,
        'calendarSynced': false,
      });

      // Try to insert event into Google Calendar (best-effort)
      try {
        final start = tx.date;
        final end = start.add(const Duration(hours: 1));
        final eventId = await CalendarService.instance.insertEvent(
          title: tx.title,
          start: start,
          end: end,
          description: tx.note,
        );
        await docRef.update({
          'calendarSynced': true,
          'calendarEventId': eventId.isEmpty ? null : eventId,
        });
      } catch (e) {
        final errorText = e.toString();
        final friendly =
            errorText.contains('Google Calendar API has not been used')
            ? 'Google Calendar API chưa được bật cho project. Hãy vào Google Cloud Console > APIs & Services > Library > bật Google Calendar API, rồi thử lại sau vài phút.'
            : 'Không đồng bộ được Calendar: $e';
        await docRef.update({
          'calendarSynced': false,
          'calendarError': e.toString(),
        });
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendly)));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã lưu')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e')));
      }
    }
  }

  Future<bool> _onWillPop() async {
    await _autoSaveIfNeeded();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final dateText = DateFormat(
      'dd/MM/yyyy HH:mm',
      'vi_VN',
    ).format(selectedDateTime);

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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showImageSourcePicker,
                          icon: const Icon(Icons.image),
                          label: Text(
                            _imageFile == null ? 'Ảnh/Camera' : 'Đã chọn ảnh',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickAnyFile,
                          icon: const Icon(Icons.attach_file),
                          label: Text(
                            _pickedFile == null ? 'Tệp' : 'Đã chọn tệp',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _captureHandwriting,
                          icon: const Icon(Icons.draw),
                          label: Text(
                            _handwritingBytes == null
                                ? 'Chữ viết tay'
                                : 'Đã ký tay',
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
                          'Ngày giờ: $dateText',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _pickDate,
                              child: const Text('Chọn ngày giờ'),
                            ),
                          ],
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
      ),
    );
  }
}
