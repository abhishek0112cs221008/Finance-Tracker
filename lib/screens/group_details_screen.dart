import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/group_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/group.dart';
import '../models/transaction.dart'; // Use standard transaction model
import 'add_group_transaction_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen>
    with TickerProviderStateMixin {
  List<Transaction> _groupTransactions = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;
  String? _error;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  Future<void> _loadGroupData() async {
    if (!_isLoading) {
      setState(() => _isRefreshing = true);
    } else {
      setState(() => _isLoading = true);
    }

    setState(() => _error = null);

    try {
      // Add slight delay for better UX
      await Future.delayed(const Duration(milliseconds: 300));

      final transactions = await context.read<GroupProvider>().getGroupTransactions(widget.group.id!);

      if (mounted) {
        setState(() {
          _groupTransactions = transactions;
          _calculateBalances();
          _isLoading = false;
          _isRefreshing = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _error = 'Failed to load group data. Please try again.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load group data: $e')),
        );
      }
    }
  }

  void _calculateBalances() {
    final Map<String, double> balances = {};

    // Initialize all members with 0 balance
    for (var member in widget.group.members) {
      if (member.trim().isNotEmpty) {
        balances[member.trim()] = 0.0;
      }
    }

    for (var transaction in _groupTransactions) {
      try {
        if (transaction.split != null &&
            transaction.paidBy != null &&
            transaction.paidBy!.trim().isNotEmpty) {
          final paidBy = transaction.paidBy!.trim();

          // Add amount paid by the member
          balances[paidBy] = (balances[paidBy] ?? 0) + transaction.amount;

          // Subtract what each member owes
          transaction.split!.forEach((member, owedAmount) {
            final memberKey = member.trim();
            if (memberKey.isNotEmpty && owedAmount > 0) {
              balances[memberKey] = (balances[memberKey] ?? 0) - owedAmount;
            }
          });
        }
      } catch (e) {
        debugPrint('Error calculating balance for transaction ${transaction.id}: $e');
      }
    }

    _balances = balances;
  }

  Future<void> _navigateToAddGroupTransaction() async {
    HapticFeedback.lightImpact();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddGroupTransactionScreen(group: widget.group),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      await _loadGroupData();
    }
  }

  void _confirmDeleteTransaction(Transaction transaction) {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteTransactionTitle),
        content: Text(
            AppLocalizations.of(context)!.deleteTransactionMessage(transaction.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () => _deleteTransaction(transaction),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    Navigator.of(context).pop();

    try {
      await context.read<TransactionProvider>().deleteTransaction(transaction.id!);

      if (mounted) {
        await _loadGroupData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.transactionDeletedSuccessfully)),
        );
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete transaction')),
        );
      }
    }
  }

  Future<void> _pullToRefresh() async {
    HapticFeedback.lightImpact();
    await _loadGroupData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar.large(
              title: Text(widget.group.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _navigateToAddGroupTransaction,
                ),
              ],
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverFillRemaining(
                child: Center(child: Text(_error!)),
              )
            else
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),
                  _buildBalanceSummary(),
                  const SizedBox(height: 24),
                  if (_groupTransactions.isEmpty)
                    _buildEmptyState()
                  else
                    _buildTransactionList(),
                  const SizedBox(height: 80),
                ]),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddGroupTransaction,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            "No transactions yet",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary() {
    final balancesToDisplay = _balances.entries
        .where((e) => e.value.abs() > 0.01)
        .toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.monetization_on,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    "Group Balance",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (balancesToDisplay.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.allSettled,
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: Colors.green),
                      ),
                    ],
                  ),
                )
              else
                ...balancesToDisplay.asMap().entries.map((entry) {
                  final index = entry.key;
                  final mapEntry = entry.value;
                  final member = mapEntry.key;
                  final balance = mapEntry.value;
                  final isOwed = balance > 0;
                  final formattedAmount = "₹${balance.abs().toStringAsFixed(2)}";

                  return Column(
                    children: [
                      if (index > 0) Divider(color: Theme.of(context).dividerColor),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isOwed
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          child: Text(
                            member.isNotEmpty ? member[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: isOwed ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(member),
                        subtitle: Text(
                          isOwed
                              ? "is owed $formattedAmount"
                              : "owes $formattedAmount",
                          style: TextStyle(
                            color: isOwed ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          formattedAmount,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isOwed ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  )
                  .animate(delay: (50 * index).ms)
                  .fadeIn()
                  .slideX();
                }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    final sortedTransactions = List<Transaction>.from(_groupTransactions)
      ..sort((a, b) => b.date.compareTo(a.date));
                  ),
                ),
              );
            }),
            if (sortedTransactions.isNotEmpty) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CupertinoColors.systemGrey5,
                  CupertinoColors.systemGrey6,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              CupertinoIcons.money_dollar_circle,
              size: 60,
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "No expenses yet",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Start splitting expenses with your group by adding your first transaction. Track who pays what and settle up easily.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.secondaryLabel,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          CupertinoButton.filled(
            onPressed: _navigateToAddGroupTransaction,
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.add, size: 20),
                SizedBox(width: 8),
                Text(
                  "Add First Expense",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}