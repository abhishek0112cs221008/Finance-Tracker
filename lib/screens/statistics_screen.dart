import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/transaction_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final transactions = Provider.of<TransactionProvider>(context).transactions;
    double totalIncome = transactions
        .where((t) => t.isIncome)
        .fold(0, (sum, t) => sum + t.amount);
    double totalExpense = transactions
        .where((t) => !t.isIncome)
        .fold(0, (sum, t) => sum + t.amount);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? CupertinoColors.activeBlue : CupertinoColors.systemBlue;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? CupertinoColors.systemGrey3 : CupertinoColors.systemGrey;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text('Statistics', style: TextStyle(color: textColor)),
        backgroundColor: isDarkMode ? const Color(0xFF1C1C1E) : CupertinoColors.white,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCard(totalIncome, totalExpense, cardColor, textColor, subtitleColor),
              const SizedBox(height: 20),
              _buildPieChart(totalIncome, totalExpense, cardColor, textColor, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  // Financial Overview Card with a modern, clean look
  Widget _buildStatsCard(double income, double expenses, Color cardColor, Color textColor, Color subtitleColor) {
    double balance = income - expenses;
    final balanceColor = balance >= 0 ? CupertinoColors.activeGreen : CupertinoColors.systemRed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Financial Overview',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryTile("Income", income, CupertinoColors.activeGreen, subtitleColor),
              _buildSummaryTile("Expenses", expenses, CupertinoColors.systemRed, subtitleColor),
              _buildSummaryTile("Balance", balance, balanceColor, subtitleColor),
            ],
          ),
        ],
      ),
    );
  }

  // Reusable Summary Tile with clean fonts and colors
  Widget _buildSummaryTile(String label, double amount, Color amountColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "₹${amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: amountColor,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // Pie Chart with dynamic colors and modern design
  Widget _buildPieChart(double income, double expenses, Color cardColor, Color textColor, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Spending Breakdown',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                borderData: FlBorderData(show: false),
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                sections: _buildPieChartSections(income, expenses, primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendIndicator(CupertinoColors.activeGreen, "Income", textColor),
              const SizedBox(width: 20),
              _legendIndicator(CupertinoColors.systemRed, "Expenses", textColor),
            ],
          ),
        ],
      ),
    );
  }

  // Pie Chart Data Sections with clear, modern visuals
  List<PieChartSectionData> _buildPieChartSections(double income, double expenses, Color primaryColor) {
    if (income == 0 && expenses == 0) {
      return [
        PieChartSectionData(
          value: 1,
          title: "No Data",
          color: CupertinoColors.systemGrey3,
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    return [
      if (income > 0)
        PieChartSectionData(
          value: income,
          title: "₹${income.toStringAsFixed(0)}",
          color: CupertinoColors.activeGreen,
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      if (expenses > 0)
        PieChartSectionData(
          value: expenses,
          title: "₹${expenses.toStringAsFixed(0)}",
          color: CupertinoColors.systemRed,
          radius: 70,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
    ];
  }

  // Legend Indicator with modern styling
  Widget _legendIndicator(Color color, String text, Color textColor) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}