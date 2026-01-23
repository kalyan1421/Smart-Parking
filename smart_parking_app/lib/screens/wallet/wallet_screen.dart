// lib/screens/wallet/wallet_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_parking_app/config/app_config.dart';
import 'package:smart_parking_app/providers/auth_provider.dart';
import 'package:smart_parking_app/providers/wallet_provider.dart';
import 'package:smart_parking_app/models/transaction.dart';
import 'package:intl/intl.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<UpiTransactionResponse>? _transaction;

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
    PaymentMethod _selectedMethod = PaymentMethod.upi;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Money'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: AppConfig.currencySymbol,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _paymentOption(
                        'UPI', 
                        Icons.qr_code, 
                        _selectedMethod == PaymentMethod.upi,
                        () => setState(() => _selectedMethod = PaymentMethod.upi),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _paymentOption(
                        'Card', 
                        Icons.credit_card, 
                        _selectedMethod == PaymentMethod.card,
                        () => setState(() => _selectedMethod = PaymentMethod.card),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final amount = double.tryParse(_amountController.text);
                  if (amount != null && amount > 0) {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                    
                    if (_selectedMethod == PaymentMethod.upi) {
                      Navigator.pop(context); // Close the add money dialog
                      _initiateUpiPayment(authProvider.currentUser!.id, amount);
                    } else {
                      // Handle card payment simulation
                      Navigator.pop(context); // Close the add money dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Simulating Card payment...')),
                      );
                      await Future.delayed(const Duration(seconds: 2));

                      final success = await walletProvider.addMoney(
                        authProvider.currentUser!.id,
                        amount,
                        method: _selectedMethod,
                      );
                      
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Money added successfully via ${_selectedMethod.name}')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add money: ${walletProvider.error}')),
                        );
                      }
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _initiateUpiPayment(String userId, double amount) async {
    try {
      // Get installed UPI apps using flutter_upi_india
      final List<ApplicationMeta> installedUpiApps = await UpiPay.getInstalledUpiApplications();

      if (installedUpiApps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No UPI apps found. Please install a UPI app to proceed.')),
        );
        return;
      }

      ApplicationMeta? selectedUpiApp = await showModalBottomSheet<ApplicationMeta>(
        context: context,
        builder: (BuildContext context) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Choose UPI App',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: installedUpiApps.length,
                  itemBuilder: (context, index) {
                    final app = installedUpiApps[index];
                    return ListTile(
                      leading: app.iconImage(32),
                      title: Text(app.upiApplication.getAppName()),
                      onTap: () => Navigator.pop(context, app),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );

      if (selectedUpiApp == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI payment cancelled by user.')),
        );
        return;
      }

      final response = await UpiPay.initiateTransaction(
        amount: amount.toStringAsFixed(2),
        app: selectedUpiApp.upiApplication,
        receiverName: 'QuickPark Wallet',
        receiverUpiAddress: 'quickpark@upi', // Replace with actual UPI ID
        transactionRef: 'QPWLT${DateTime.now().millisecondsSinceEpoch}',
        transactionNote: 'Add money to QuickPark wallet',
      );
      
      // Handle transaction response
      String message = '';
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      if (response.status == UpiTransactionStatus.success) {
        message = 'UPI payment successful!';
        await walletProvider.addMoney(userId, amount, method: PaymentMethod.upi);
      } else if (response.status == UpiTransactionStatus.submitted) {
        message = 'UPI payment submitted (pending verification).';
      } else if (response.status == UpiTransactionStatus.failure) {
        message = 'UPI payment failed.';
      } else {
        message = 'UPI payment status: ${response.status}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('UPI payment error: $e')),
      );
    }
  }
  
  Widget _paymentOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? Colors.blue.withOpacity(0.1) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
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
        title: const Text('My Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWalletData,
          ),
        ],
      ),
      body: walletProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          const Text(
                            'Available Balance',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppConfig.currencySymbol} ${walletProvider.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    onPressed: _addMoney,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Money'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: walletProvider.transactions.isEmpty
                        ? const Center(
                            child: Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            itemCount: walletProvider.transactions.length,
                            itemBuilder: (context, index) {
                              final transaction = walletProvider.transactions[index];
                              final isDeposit = transaction.type == TransactionType.deposit;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
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