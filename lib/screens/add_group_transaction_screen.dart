import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/group.dart';
import '../models/transaction.dart';

class AddGroupTransactionScreen extends StatefulWidget {
  final Group group;

  const AddGroupTransactionScreen({super.key, required this.group});

  @override
  State<AddGroupTransactionScreen> createState() =>
      _AddGroupTransactionScreenState();
}

class _AddGroupTransactionScreenState extends State<AddGroupTransactionScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _amountFocusNode = FocusNode();

  String _paidBy = '';
  String _selectedCategory = 'Food';
  final Map<String, bool> _splitMembers = {};
  bool _isSaving = false;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'name': 'Transport', 'icon': Icons.directions_car, 'color': Colors.blue},
    {'name': 'Shopping', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {'name': 'Entertainment', 'icon': Icons.movie, 'color': Colors.purple},
    {'name': 'Utilities', 'icon': Icons.lightbulb, 'color': Colors.yellow},
    {'name': 'Rent', 'icon': Icons.home, 'color': Colors.green},
    {'name': 'Travel', 'icon': Icons.flight, 'color': Colors.teal},
    {'name': 'Others', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  @override
  void initState() {
    super.initState();
    _paidBy = widget.group.members.first;
    for (var member in widget.group.members) {
      _splitMembers[member] = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _nameFocusNode.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getCategoryData(String categoryName) {
    return _categories.firstWhere(
      (cat) => cat['name'] == categoryName,
      orElse: () => _categories.last,
    );
  }

  Future<void> _saveTransaction() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (name.isEmpty) {
      _showErrorSnackBar('Please enter an expense name');
      _nameFocusNode.requestFocus();
      return;
    }

    if (amountText.isEmpty || amount == null || amount <= 0) {
      _showErrorSnackBar('Please enter a valid amount');
      _amountFocusNode.requestFocus();
      return;
    }

    final membersToSplit = _splitMembers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (membersToSplit.isEmpty) {
      _showErrorSnackBar('Please select at least one person to split with');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final perPersonAmount = amount / membersToSplit.length;
      final splitMap = {for (var member in membersToSplit) member: perPersonAmount};

      final newTransaction = Transaction(
        name: name,
        amount: amount,
        isIncome: false,
        category: _selectedCategory,
        date: DateTime.now(),
        groupId: widget.group.id,
        paidBy: _paidBy,
        split: splitMap,
      );

      await context.read<TransactionProvider>().addTransaction(newTransaction);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showErrorSnackBar('Failed to save expense: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveTransaction,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmountCard(),
            const SizedBox(height: 16),
            _buildDetailsCard(),
            const SizedBox(height: 16),
            _buildSplitSection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Enter Amount'),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
                prefixText: '₹',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.description,
                prefixIcon: const Icon(Icons.description_outlined),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.category,
                prefixIcon: const Icon(Icons.category_outlined),
                border: const OutlineInputBorder(),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat['name'],
                  child: Row(
                    children: [
                      Icon(cat['icon'], size: 20, color: cat['color']),
                      const SizedBox(width: 12),
                      Text(cat['name']),
                    ],
                  ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? CupertinoColors.activeBlue.withOpacity(0.1)
                            : CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: CupertinoColors.activeBlue, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? CupertinoColors.activeBlue.withOpacity(0.2)
                                  : CupertinoColors.systemGrey4,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                member.isNotEmpty ? member[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isSelected 
                                      ? CupertinoColors.activeBlue
                                      : CupertinoColors.systemGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              member,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected 
                                    ? FontWeight.w600 
                                    : FontWeight.w500,
                                color: isSelected 
                                    ? CupertinoColors.activeBlue
                                    : CupertinoColors.label,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: CupertinoColors.activeBlue,
                              size: 20,
                            ),
                        ],
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