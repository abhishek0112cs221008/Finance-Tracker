import 'package:flutter/material.dart';
import 'package:project_track_your_finance/screens/groups_screen.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';
import 'analytics_card.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    // M3 ColorScheme
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar.large(
            title: Text(
              'Finance Tracker',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
            backgroundColor: colorScheme.surface,
            scrolledUnderElevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GroupsScreen()),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Consumer<TransactionProvider>(
              builder: (context, transactionProvider, child) {
                final transactions = transactionProvider.transactions
                    .where((t) => _selectedCategory == 'All' || t.category == _selectedCategory)
                    .toList();

                final double totalIncome = transactions.where((t) => t.isIncome).fold(0, (sum, t) => sum + t.amount);
                final double totalExpenses = transactions.where((t) => !t.isIncome).fold(0, (sum, t) => sum + t.amount);
                final double balance = totalIncome - totalExpenses;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Analytics Card
                      ExpenseTrackerCard(
                        totalIncome: totalIncome,
                        totalExpenses: totalExpenses,
                        balance: balance,
                      ),
                      const SizedBox(height: 24),
                      
                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Transactions',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            onPressed: _showFilterOptions,
                            icon: const Icon(Icons.filter_list_rounded, size: 18),
                            label: const Text('Filter'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Transaction List
          Consumer<TransactionProvider>(
            builder: (context, transactionProvider, child) {
              final transactions = transactionProvider.transactions
                  .where((t) => _selectedCategory == 'All' || t.category == _selectedCategory)
                  .toList();
              
              if (transactions.isEmpty) {
                 return SliverFillRemaining(
                   hasScrollBody: false,
                   child: Center(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Icon(Icons.receipt_long_rounded, size: 64, color: colorScheme.outline),
                         const SizedBox(height: 16),
                         Text(
                           "No transactions found",
                           style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
                         ),
                       ],
                     ),
                   ),
                 );
              }

              // Sort by date (newest first)
              transactions.sort((a, b) => b.date.compareTo(a.date));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionTile(transaction, context)
                        .animate(delay: (50 * index).ms) // Staggered animation
                        .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                        .slideX(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
                  },
                  childCount: transactions.length,
                ),
              );
            },
          ),
          // Add some bottom padding for the FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(Transaction transaction, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? Colors.green : Colors.red;
    final icon = isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final iconBg = isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1);

    return Dismissible(
      key: Key(transaction.id.toString()),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outline_rounded, color: colorScheme.onErrorContainer),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Transaction"),
            content: const Text("Are you sure you want to delete this transaction?"),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("Delete")),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        // Implement delete in provider if not already there
         Provider.of<TransactionProvider>(context, listen: false).deleteTransaction(transaction.id!);
      },
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: isIncome ? Colors.green : Colors.red),
        ),
        title: Text(
          transaction.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${transaction.category} • ${DateFormat('dd MMM').format(transaction.date)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}₹${transaction.amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        onTap: () => _showUpdateTransactionSheet(context, transaction),
      ),
    );
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                 title: Text('Filter by Category', style: Theme.of(context).textTheme.titleLarge),
              ),
              ...['All', 'Food', 'Transport', 'Shopping', 'Bills', 'Other'].map(
                (category) => RadioListTile<String>(
                  title: Text(category),
                  value: category,
                  groupValue: _selectedCategory,
                  onChanged: (value) {
                    setState(() => _selectedCategory = value!);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUpdateTransactionSheet(BuildContext context, Transaction transaction) {
    // Navigate to update screen or show modal
    // For simplicity, reusing the logic but with M3 BottomSheet
     TextEditingController nameController = TextEditingController(text: transaction.name);
     TextEditingController amountController = TextEditingController(text: transaction.amount.toString());
     // ... logic can be similar to AddTransactionScreen but populated
     // For now, let's just use a simple sheet for demo
     showModalBottomSheet(
       context: context,
       isScrollControlled: true,
       showDragHandle: true,
       builder: (ctx) => Padding(
         padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
             const SizedBox(height: 12),
             TextField(controller: amountController, decoration: const InputDecoration(labelText: 'Amount', border: OutlineInputBorder()), keyboardType: TextInputType.number),
             const SizedBox(height: 24),
              FilledButton(
               onPressed: () {
                 final updated = transaction.copyWith(
                   name: nameController.text,
                   amount: double.parse(amountController.text),
                 );
                 Provider.of<TransactionProvider>(context, listen: false).updateTransaction(updated);
                 Navigator.pop(context);
               },
               child: const Text('Update Transaction'),
             ),
             const SizedBox(height: 24),
           ],
         ),
       ),
     );
  }
}
