enum TransactionType { income, expense }

class TransactionModel {
  final String id;
  final double amount;
  final TransactionType type;
  final String title;
  final String category;
  final String? note;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imagePath;
  final String? filePath;
  final String? handwritingPath;
  final String? calendarEventId;
  final bool? calendarSynced;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.title,
    required this.category,
    this.note,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.imagePath,
    this.filePath,
    this.handwritingPath,
    this.calendarEventId,
    this.calendarSynced,
  });

  TransactionModel copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? title,
    String? category,
    String? note,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? imagePath,
    String? filePath,
    String? handwritingPath,
    String? calendarEventId,
    bool? calendarSynced,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      title: title ?? this.title,
      category: category ?? this.category,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      filePath: filePath ?? this.filePath,
      handwritingPath: handwritingPath ?? this.handwritingPath,
      calendarEventId: calendarEventId ?? this.calendarEventId,
      calendarSynced: calendarSynced ?? this.calendarSynced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'title': title,
      'category': category,
      'note': note,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'imagePath': imagePath,
      'filePath': filePath,
      'handwritingPath': handwritingPath,
      'calendarEventId': calendarEventId,
      'calendarSynced': calendarSynced ?? false,
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: (json['type'] as String) == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      title: (json['title'] as String?) ?? '',
      category: json['category'] as String,
      note: json['note'] as String?,
      date: DateTime.parse(json['date'] as String),
      createdAt: json['createdAt'] == null
          ? DateTime.parse(json['date'] as String)
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? DateTime.parse(json['date'] as String)
          : DateTime.parse(json['updatedAt'] as String),
      imagePath: (json['imagePath'] ?? json['imageUrl']) as String?,
      filePath: (json['filePath'] ?? json['fileUrl']) as String?,
      handwritingPath:
          (json['handwritingPath'] ?? json['handwritingUrl']) as String?,
      calendarEventId: json['calendarEventId'] as String?,
      calendarSynced: json['calendarSynced'] as bool?,
    );
  }
}
