// lib/screens/wallet/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/wallet_provider.dart';
import 'package:smart_parking_app/models/transaction.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser != null) {
      await Provider.of<WalletProvider>(context, listen: false)
          .loadWalletData(authProvider.currentUser!.id);
    }
  }

  Future<void> _addMoney() async {
    final TextEditingController _amountController = TextEditingController();
    String _selectedMethod = 'UPI';
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Add Money'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: AppConfig.currencySymbol,
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 16),
                Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _paymentOption(
                        'UPI', 
                        Icons.qr_code, 
                        _selectedMethod == 'UPI',
                        () => setState(() => _selectedMethod = 'UPI'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _paymentOption(
                        'Card', 
                        Icons.credit_card, 
                        _selectedMethod == 'Card',
                        () => setState(() => _selectedMethod = 'Card'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_amountController.text);
                  if (amount != null && amount > 0) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                    
                    Navigator.pop(context);
                    
                    // Simulate payment delay
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Processing $_selectedMethod payment...')),
                    );
                    await Future.delayed(Duration(seconds: 2));
                    
                    final success = await walletProvider.addMoney(
                      authProvider.currentUser!.id,
                      amount,
                    );
                    
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Money added successfully via $_selectedMethod')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add money: ${walletProvider.error}')),
                      );
                    }
                  }
                },
                child: Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _paymentOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('My Wallet'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: walletProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Theme.of(context).primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Text(
                            'Available Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${AppConfig.currencySymbol} ${walletProvider.balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _addMoney,
                    icon: Icon(Icons.add),
                    label: Text('Add Money'),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)),
                  ),
                  SizedBox(height: 40),
                  Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Expanded(
                    child: walletProvider.transactions.isEmpty
                        ? Center(
                            child: Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: walletProvider.transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = walletProvider.transactions[index];
                              final isDeposit = transaction.type == TransactionType.deposit;
                              
                              return Card(
                                margin: EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isDeposit ? Colors.green[100] : Colors.red[100],
                                    child: Icon(
                                      isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                      color: isDeposit ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  title: Text(transaction.description),
                                  subtitle: Text(
                                    DateFormat('MMM d, y • h:mm a').format(transaction.createdAt),
                                  ),
                                  trailing: Text(
                                    '${isDeposit ? '+' : '-'}${AppConfig.currencySymbol}${transaction.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: isDeposit ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
