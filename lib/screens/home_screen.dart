import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_track_your_finance/screens/add_transaction_screen.dart';
import 'home.dart'; // TransactionsScreen
import 'statistics_screen.dart';
import 'groups_screen.dart';
import 'wallet_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const TransactionsScreen(),
    const StatisticsScreen(),
    const GroupsScreen(),
    const WalletPage(),
    const SettingsScreen(),
  ];

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colorScheme.surface,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            const TransactionsScreen(),
            const StatisticsScreen(), // Restored Stats
            const GroupsScreen(),
            const WalletPage(),
            // Settings moved to Home Screen Header
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
             Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddTransactionScreen()),
              );
          },
          backgroundColor: colorScheme.primary,
          elevation: 4,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   _buildTabItem(0, Icons.home_rounded, 'Home'),
                   _buildTabItem(1, Icons.pie_chart_rounded, 'Stats'),
                   _buildTabItem(2, Icons.group_work_rounded, 'Groups'),
                   _buildTabItem(3, Icons.account_balance_wallet_rounded, 'Wallet'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
             Icon(
               icon,
               color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
               size: 24,
             ),
             if (isSelected) ...[
               const SizedBox(width: 8),
               Text(
                 label,
                 style: TextStyle(
                   color: colorScheme.primary,
                   fontSize: 14,
                   fontWeight: FontWeight.w600,
                 ),
               ),
             ],
          ],
        ),
      ),
    );
  }
}
