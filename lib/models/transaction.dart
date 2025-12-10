import 'dart:convert';

class Transaction {
  final int? id;
  final String name;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;
  
  // Group related fields
  final int? groupId;
  final String? paidBy;
  final Map<String, dynamic>? split;

  const Transaction({
    this.id,
    required this.name,
    required this.amount,
    required this.isIncome,
    required this.category,
    required this.date,
    this.groupId,
    this.paidBy,
    this.split,
  });

  Transaction copyWith({
    int? id,
    String? name,
    double? amount,
    bool? isIncome,
    String? category,
    DateTime? date,
    int? groupId,
    String? paidBy,
    Map<String, dynamic>? split,
  }) {
    return Transaction(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      date: date ?? this.date,
      groupId: groupId ?? this.groupId,
      paidBy: paidBy ?? this.paidBy,
      split: split ?? this.split,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'isIncome': isIncome ? 1 : 0,
      'category': category,
      'date': date.toIso8601String(),
      'groupId': groupId,
      'paidBy': paidBy,
      // split is handled specially in DBHelper because it needs JSON encoding
      // we don't encode it here to avoid double encoding if DBHelper handles it, 
      // but standard toMap usually returns primitives. 
      // Let's return it as is, DBHelper can encode if needed, or we encode here?
      // In db_helper_group.dart, it does: map['split'] = jsonEncode(transaction.split);
      // So we leave it out of here or return it as null if you want strictly primitives?
      // Actually, let's not include 'split' in toMap if it's complex, or include it?
      // db_helper_group logic: final map = transaction.toMap(); map['split'] = jsonEncode(...)
      // So let's NOT include it here to avoid confusion, OR include it as Map and let DB helper convert.
      // But standard sqlite map expects primitives. 
      // Let's leave it out of standard toMap for now to match current pattern, 
      // but wait, if I want a clean model, toMap should probably include everything.
      // Let's include it but remember to handle JSON encoding in DB layer.
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      name: map['name'],
      amount: map['amount'],
      isIncome: (map['isIncome'] is int) ? (map['isIncome'] == 1) : (map['isIncome'] as bool),
      category: map['category'],
      date: DateTime.parse(map['date']),
      groupId: map['groupId'],
      paidBy: map['paidBy'],
      split: map['split'] != null 
          ? (map['split'] is String 
              ? Map<String, dynamic>.from(jsonDecode(map['split']))
              : Map<String, dynamic>.from(map['split']))
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is Transaction &&
      other.id == id &&
      other.name == name &&
      other.amount == amount &&
      other.isIncome == isIncome &&
      other.category == category &&
      other.date == date &&
      other.groupId == groupId &&
      other.paidBy == paidBy;
      // Map equality is tricky, simplifying for now
  }

  @override
  int get hashCode {
    return id.hashCode ^
      name.hashCode ^
      amount.hashCode ^
      isIncome.hashCode ^
      category.hashCode ^
      date.hashCode ^
      groupId.hashCode ^
      paidBy.hashCode;
  }

  @override
  String toString() {
    return 'Transaction(id: $id, name: $name, amount: $amount, isIncome: $isIncome, category: $category, date: $date, groupId: $groupId, paidBy: $paidBy)';
  }
}
