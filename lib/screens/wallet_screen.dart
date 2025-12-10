import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction.dart';
import '../database/db_helper.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  List<Transaction> _transactions = [];
  Map<String, List<Transaction>> _groupedTransactions = {};
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = "All";
  String _selectedSort = "Newest First";

  // New state for grouping
  String _selectedGroup = "By Category";
  final Map<String, dynamic> _groupingOptions = {
    "By Category": 'category',
    "By Date": 'date',
  };

  // The correct way to use a GlobalKey for RefreshIndicator
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to show the indicator on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshIndicatorKey.currentState?.show();
    });
  }

  // Refactored to group transactions after loading
  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    final transactions = await DBHelper.getTransactions();
    setState(() {
      _transactions = transactions;
      _groupTransactionsAndApplyFilters();
      _isLoading = false;
    });
  }

  void _groupTransactionsAndApplyFilters() {
    List<Transaction> tempTransactions = _transactions.where((t) {
      final matchesFilter = (_selectedFilter == "All") ||
          (t.isIncome && _selectedFilter == "Income") ||
          (!t.isIncome && _selectedFilter == "Expense");
      final matchesSearch = t.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    // Apply sorting before grouping
    if (_selectedSort == "Amount: High to Low") {
      tempTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_selectedSort == "Amount: Low to High") {
      tempTransactions.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      tempTransactions.sort((a, b) => b.date.compareTo(a.date));
    }

    _groupedTransactions = _groupTransactions(tempTransactions);
  }

  // New function to handle transaction grouping
  Map<String, List<Transaction>> _groupTransactions(List<Transaction> transactions) {
    final Map<String, List<Transaction>> grouped = {};
    if (_selectedGroup == "By Category") {
      for (var transaction in transactions) {
        if (!grouped.containsKey(transaction.category)) {
          grouped[transaction.category] = [];
        }
        grouped[transaction.category]!.add(transaction);
      }
    } else if (_selectedGroup == "By Date") {
      final formatter = DateFormat('MMMM yyyy');
      for (var transaction in transactions) {
        final monthKey = formatter.format(transaction.date);
        if (!grouped.containsKey(monthKey)) {
          grouped[monthKey] = [];
        }
        grouped[monthKey]!.add(transaction);
      }
    }
    return grouped;
  }

  void _filterTransactions(String query) {
    setState(() {
      _searchQuery = query;
      _groupTransactionsAndApplyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _groupTransactionsAndApplyFilters();
    });
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.poppinsRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Transaction Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, font: font)),
              pw.SizedBox(height: 16),
              ..._transactions.map((t) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(t.name, style: pw.TextStyle(fontSize: 14, font: font)),
                          pw.Text(DateFormat.yMMMd().format(t.date),
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
                        ],
                      ),
                      pw.Text(
                        '₹${t.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          color: t.isIncome ? PdfColors.green500 : PdfColors.red500,
                          font: font,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: CupertinoSearchTextField(
        onChanged: _filterTransactions,
        placeholder: 'Search Transactions...',
        style: TextStyle(color: CupertinoDynamicColor.resolve(CupertinoColors.label, context)),
        backgroundColor: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context),
        prefixIcon: const Icon(CupertinoIcons.search, size: 20),
        suffixIcon: const Icon(CupertinoIcons.xmark_circle_fill, size: 20),
      ),
    );
  }

  Widget _buildFilterAndSortOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(
                'Filter: $_selectedFilter',
                style: const TextStyle(fontSize: 14),
              ),
              onPressed: () => _showFilterSheet(context),
            ),
          ),
          Container(
            height: 24,
            width: 1,
            color: CupertinoColors.systemGrey4,
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Expanded(
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              child: Text(
                'Sort: $_selectedSort',
                style: const TextStyle(fontSize: 14),
              ),
              onPressed: () => _showSortSheet(context),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.only(left: 8),
            onPressed: _generatePdf,
            child: const Icon(CupertinoIcons.share, size: 24),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Filter by Type"),
        actions: [
          for (var filter in ["All", "Income", "Expense"])
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _selectedFilter = filter);
                _applyFilters();
                Navigator.pop(context);
              },
              child: Text(filter, style: TextStyle(
                fontWeight: _selectedFilter == filter ? FontWeight.bold : FontWeight.normal
              )),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: const Text("Sort Transactions"),
        actions: [
          for (var sort in ["Newest First", "Amount: High to Low", "Amount: Low to High"])
            CupertinoActionSheetAction(
              onPressed: () {
                setState(() => _selectedSort = sort);
                _applyFilters();
                Navigator.pop(context);
              },
              child: Text(sort, style: TextStyle(
                fontWeight: _selectedSort == sort ? FontWeight.bold : FontWeight.normal
              )),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          isDefaultAction: true,
          child: const Text("Cancel"),
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Center(
        child: Text(
          "No transactions found.",
          style: TextStyle(
            color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
            fontSize: 16,
          ),
        ),
      );
    }

    if (_groupedTransactions.isEmpty) {
      return Center(
        child: Text(
          "No results found for your search.",
          style: TextStyle(
            color: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey, context),
            fontSize: 16,
          ),
        ),
      );
    }

    final sortedKeys = _groupedTransactions.keys.toList();
    if (_selectedGroup == "By Date") {
        sortedKeys.sort((a, b) {
            final dateA = DateFormat('MMMM yyyy').parse(a);
            final dateB = DateFormat('MMMM yyyy').parse(b);
            return dateB.compareTo(dateA);
        });
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(), // Ensures the list can always be pulled down
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      itemCount: _groupedTransactions.length,
      itemBuilder: (context, index) {
        final groupKey = sortedKeys[index];
        final transactionsInGroup = _groupedTransactions[groupKey]!;
        final groupTotal = transactionsInGroup.fold(0.0, (sum, t) => sum + (t.isIncome ? t.amount : -t.amount));

        return CupertinoListSection.insetGrouped(
          header: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  groupKey,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
                Text(
                  "₹${groupTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: groupTotal >= 0 ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                  ),
                ),
              ],
            ),
          ),
          children: transactionsInGroup.map((t) {
            return CupertinoListTile(
              title: Text(t.name),
              subtitle: Text(DateFormat.yMMMd().format(t.date)),
              trailing: Text(
                "₹${t.amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: t.isIncome ? CupertinoColors.activeGreen : CupertinoColors.systemRed,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isDarkMode ? CupertinoColors.black : CupertinoColors.systemGroupedBackground;

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: const CupertinoNavigationBar(
        middle: Text("Wallet"),
        backgroundColor: CupertinoColors.systemBackground,
        border: null,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            _buildFilterAndSortOptions(),
            const SizedBox(height: 8),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: _selectedGroup,
              thumbColor: CupertinoDynamicColor.resolve(CupertinoColors.systemGrey5, context),
              children: _groupingOptions.keys.map((key) {
                return MapEntry(
                  key,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(key),
                  ),
                );
              }).cast<MapEntry<String, Widget>>()
                  .fold(<String, Widget>{}, (map, entry) {
                    map[entry.key] = entry.value;
                    return map;
                  }),
              onValueChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedGroup = newValue;
                    _groupTransactionsAndApplyFilters();
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: RefreshIndicator(
                key: _refreshIndicatorKey,
                color: CupertinoDynamicColor.resolve(CupertinoColors.activeBlue, context),
                onRefresh: _loadTransactions,
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _buildTransactionList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Added CupertinoListTile for a true iOS look
class CupertinoListTile extends StatelessWidget {
  const CupertinoListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.all(14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : CupertinoColors.label,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      color: isDarkMode ? CupertinoColors.systemGrey2 : CupertinoColors.systemGrey,
                      fontSize: 12,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}