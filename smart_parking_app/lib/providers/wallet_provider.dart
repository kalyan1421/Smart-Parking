// lib/providers/wallet_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/database/database_service.dart';
import '../models/transaction.dart';

class WalletProvider with ChangeNotifier {
  double _balance = 0.0;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  double get balance => _balance;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadWalletData(String userId) async {
    _setLoading(true);
    try {
      // Listen to user document for balance updates
      final userDoc = await DatabaseService.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _balance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
      }

      // Load transactions
      final querySnapshot = await DatabaseService.collection('transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      _transactions = querySnapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc))
          .toList();
      
      _error = null;
    } catch (e) {
      _error = 'Failed to load wallet data: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> addMoney(String userId, double amount) async {
    _setLoading(true);
    try {
      await DatabaseService.runTransaction((transaction) async {
        // Update user balance
        transaction.update(
          DatabaseService.collection('users').doc(userId),
          {'walletBalance': FieldValue.increment(amount)},
        );

        // Add transaction record
        final transactionRef = DatabaseService.collection('transactions').doc();
        final newTransaction = WalletTransaction(
          id: transactionRef.id,
          userId: userId,
          amount: amount,
          type: TransactionType.deposit,
          description: 'Added money to wallet',
          createdAt: DateTime.now(),
        );
        
        transaction.set(transactionRef, newTransaction.toMap());
      });

      // Refresh data
      await loadWalletData(userId);
      return true;
    } catch (e) {
      _error = 'Failed to add money: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> payForBooking(String userId, double amount, String bookingId) async {
    if (_balance < amount) {
      _error = 'Insufficient balance';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      await DatabaseService.runTransaction((transaction) async {
        // Deduct from balance
        transaction.update(
          DatabaseService.collection('users').doc(userId),
          {'walletBalance': FieldValue.increment(-amount)},
        );

        // Add transaction record
        final transactionRef = DatabaseService.collection('transactions').doc();
        final newTransaction = WalletTransaction(
          id: transactionRef.id,
          userId: userId,
          amount: amount,
          type: TransactionType.payment,
          description: 'Payment for parking booking',
          createdAt: DateTime.now(),
          bookingId: bookingId,
        );
        
        transaction.set(transactionRef, newTransaction.toMap());
      });

      // Refresh data
      await loadWalletData(userId);
      return true;
    } catch (e) {
      _error = 'Payment failed: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
