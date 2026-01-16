// lib/models/transaction.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { deposit, payment, refund }

class WalletTransaction {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String description;
  final DateTime createdAt;
  final String? bookingId;

  WalletTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
    this.bookingId,
  });

  factory WalletTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      amount: (data['amount'] as num).toDouble(),
      type: _parseType(data['type']),
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      bookingId: data['bookingId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'type': type.name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'bookingId': bookingId,
    };
  }

  static TransactionType _parseType(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.name == type,
      orElse: () => TransactionType.payment,
    );
  }
}
