import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/transaction.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  static const _kStorageKey = 'transactions_v1';

  final ValueNotifier<List<TransactionModel>> transactions = ValueNotifier([]);
  String? _lastSyncedUid;

  // load persisted data when service is created
  Future<void> _init() async {
    await _loadFromStorage();
  }

  // trigger init on singleton creation
  // ignore: prefer_constructors_over_static_methods
  static Future<void> initialize() => instance._init();

  List<TransactionModel> get all => transactions.value;

  void add(TransactionModel t) {
    transactions.value = [...transactions.value, t];
    _saveToStorage();
  }

  void update(String id, TransactionModel updated) {
    transactions.value = transactions.value
        .map((t) => t.id == id ? updated : t)
        .toList();
    _saveToStorage();
  }

  void delete(String id) {
    transactions.value = transactions.value.where((t) => t.id != id).toList();
    _saveToStorage();
  }

  double get totalIncome => transactions.value
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalExpense => transactions.value
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (s, t) => s + t.amount);

  double get balance => totalIncome - totalExpense;

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = transactions.value.map((t) => t.toJson()).toList();
      final encoded = jsonEncode(list);
      await prefs.setString(_kStorageKey, encoded);
    } catch (_) {
      // ignore write errors for now
    }
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final list = decoded
          .map(
            (e) =>
                TransactionModel.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      transactions.value = list;
    } catch (_) {
      // if parse error or other, ignore and keep empty list
    }
  }

  Future<void> syncFromFirestore(String uid) async {
    if (uid.isEmpty) return;
    if (_lastSyncedUid == uid) return;
    try {
      final qs = await FirebaseFirestore.instance
          .collection('transactions')
          .where('owner', isEqualTo: uid)
          .get();
      final list = qs.docs.map((d) {
        final data = d.data();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final typeStr = (data['type'] as String?) ?? 'expense';
        final dateField = data['date'];
        DateTime date;
        if (dateField is Timestamp) {
          date = dateField.toDate();
        } else if (dateField is String) {
          date = DateTime.parse(dateField);
        } else {
          date = DateTime.now();
        }
        final created = data['createdAt'] is Timestamp
            ? (data['createdAt'] as Timestamp).toDate()
            : (data['createdAt'] is String
                  ? DateTime.parse(data['createdAt'] as String)
                  : date);
        final updated = data['updatedAt'] is Timestamp
            ? (data['updatedAt'] as Timestamp).toDate()
            : (data['updatedAt'] is String
                  ? DateTime.parse(data['updatedAt'] as String)
                  : date);

        return TransactionModel(
          id: (data['id'] as String?) ?? d.id,
          amount: amount,
          type: typeStr == 'income'
              ? TransactionType.income
              : TransactionType.expense,
          title: (data['title'] as String?) ?? '',
          category: (data['category'] as String?) ?? '',
          note: (data['note'] as String?),
          date: date,
          createdAt: created,
          updatedAt: updated,
        );
      }).toList();
      transactions.value = list;
      await _saveToStorage();
      _lastSyncedUid = uid;
    } catch (_) {
      // ignore sync errors for now
    }
  }

  void clearLocalData() {
    transactions.value = [];
    _lastSyncedUid = null;
  }
}
