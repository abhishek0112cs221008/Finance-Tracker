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
import '../l10n/app_localizations.dart';

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

    // Group transactions by date for that "Chat Day Header" feel
    // (Optional, but simple list first)

    // Let's re-do the grouping for `reverse: true` ListView.
    // Input: sortedTransactions (Newest First).
    // If reverse: true, index 0 is at bottom (Newest).
    // So we iterate Newest -> Oldest.
    // Date Header should appear AFTER the last message of that day (visually above).
    // In `reverse: true` list, "Above" means "Next index".

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedTransactions.length,
      reverse: true, // Chat style
      itemBuilder: (context, index) {
        final transaction = sortedTransactions[index];
        final isLast = index == sortedTransactions.length - 1;
        final isFirst = index == 0; // Visually bottom-most

        // Logic for Date Header (Show if Next item (older) is different day)
        // Since we are scrolling up (reverse), we look ahead to `index + 1`.
        // If `index + 1` is different day or default (end of list), we show header for `current`.
        
        bool showHeader = false;
        if (index == sortedTransactions.length - 1) {
            showHeader = true; // Top most item (Oldest) always gets header
        } else {
            final nextTransaction = sortedTransactions[index + 1];
            if (!_isSameDay(transaction.date, nextTransaction.date)) {
                showHeader = true;
            }
        }

        return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                if (showHeader) _buildDateHeader(transaction.date), // Visually Top
                _buildTransactionBubble(transaction),
            ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          DateFormat('MMMM d, y').format(date), // e.g. October 24, 2025
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionBubble(Transaction transaction) {
      final isMe = transaction.paidBy == 'You';
      
      // Premium Bubble Colors
      final bubbleColor = isMe
          ? Theme.of(context).colorScheme.primary.withOpacity(0.9) // Emerald
          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5); // Glassy

      final textColor = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
      final subTextColor = isMe ? Colors.white.withOpacity(0.7) : Theme.of(context).colorScheme.onSurfaceVariant;

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12), // More padding for premium feel
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
              bottomRight: isMe ? Radius.zero : const Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Stack(
            children: [
               Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        transaction.paidBy ?? 'Unknown',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 60.0, bottom: 4.0),
                     child: Text(
                      transaction.name,
                      style: TextStyle(
                        fontSize: 16,
                        color: textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    "₹${transaction.amount.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 15, // Slightly larger
                      fontWeight: FontWeight.bold,
                      color: textColor.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
               Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  DateFormat('h:mm a').format(transaction.date),
                  style: TextStyle(
                    fontSize: 10,
                    color: subTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildBottomInputBar() {
      // Glassmorphic Input Bar
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8), // Glass base
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
            boxShadow: [
                 BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                 ),
            ]
          ),
          child: SafeArea(
            top: false,
            child: Row(
                children: [
                    Container(
                        decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            shape: BoxShape.circle,
                        ),
                        child: IconButton(
                            icon: const Icon(Icons.add),
                             onPressed: () {}, // Attachment
                             color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: GestureDetector(
                            onTap: _navigateToAddGroupTransaction,
                            child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    AppLocalizations.of(context)!.addExpense,
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 16,
                                    ),
                                ),
                            ),
                        ),
                    ),
                    const SizedBox(width: 8),
                    FloatingActionButton(
                        onPressed: _navigateToAddGroupTransaction,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        elevation: 4,
                        shape: const CircleBorder(),
                        child: const Icon(Icons.arrow_forward_rounded),
                    ),
                ],
            ),
          ),
      );
  }


}