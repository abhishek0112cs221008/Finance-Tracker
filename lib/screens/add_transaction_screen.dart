import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  _AddTransactionScreenState createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food';
  bool _isIncome = false;
  final TextEditingController _customCategoryController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _addTransaction() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text);
    if (name.isEmpty || amount == null || amount <= 0) {
      _showErrorDialog("Please enter valid transaction details.");
      return;
    }

    final category = _selectedCategory == 'Others'
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    if (_selectedCategory == 'Others' && category.isEmpty) {
      _showErrorDialog("Please enter a custom category name.");
      return;
    }

    final transaction = Transaction(
      name: name,
      amount: amount,
      isIncome: _isIncome,
      category: category,
      date: DateTime.now(),
    );

    Provider.of<TransactionProvider>(context, listen: false)
        .addTransaction(transaction);
    Navigator.pop(context);
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invalid Input"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1C1C1E) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF2C2C2E) : Colors.grey[100]!;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.white54 : Colors.black54;
    final switchTrackColor = isDarkMode
        ? MaterialStateProperty.all(const Color(0xFF3A3A3C))
        : null;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          "Add Transaction",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              "Transaction Name",
              _nameController,
              Icons.edit_note,
              cardColor,
              textColor,
              hintColor,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "Amount",
              _amountController,
              Icons.attach_money,
              cardColor,
              textColor,
              hintColor,
              isNumber: true,
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(cardColor, textColor, hintColor),
            if (_selectedCategory == 'Others')
              _buildCustomCategoryField(
                  cardColor, textColor, hintColor),
            const SizedBox(height: 16),
            _buildSwitchTile(textColor, switchTrackColor),
            const SizedBox(height: 32),
            _buildAddButton(textColor, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      String label,
      TextEditingController controller,
      IconData icon,
      Color fillColor,
      Color textColor,
      Color hintColor,
      {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
          : null,
      style: TextStyle(fontSize: 16, color: textColor),
      cursorColor: Theme.of(context).colorScheme.primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor, fontSize: 16),
        prefixIcon: Icon(icon, color: hintColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: fillColor,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }

  Widget _buildCategoryDropdown(
      Color fillColor, Color textColor, Color hintColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        style: TextStyle(color: textColor, fontSize: 16),
        dropdownColor: fillColor,
        icon: Icon(Icons.arrow_drop_down, color: hintColor),
        decoration: InputDecoration(
          labelText: "Category",
          labelStyle: TextStyle(color: hintColor, fontSize: 16),
          border: InputBorder.none,
          isDense: true,
        ),
        items: ['Food', 'Transport', 'Shopping', 'Entertainment', 'Others']
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
            .toList(),
        onChanged: (value) => setState(() => _selectedCategory = value!),
      ),
    );
  }

  Widget _buildCustomCategoryField(
      Color fillColor, Color textColor, Color hintColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: _buildTextField(
        "Custom Category Name",
        _customCategoryController,
        Icons.category,
        fillColor,
        textColor,
        hintColor,
      ),
    );
  }

  Widget _buildSwitchTile(
      Color textColor, MaterialStateProperty<Color?>? trackColor) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Is Income?",
              style: TextStyle(
                fontSize: 16,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Switch.adaptive(
              value: _isIncome,
              activeColor: Colors.greenAccent,
              inactiveThumbColor: Colors.redAccent,
              trackColor: trackColor,
              onChanged: (value) => setState(() => _isIncome = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(Color textColor, bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _addTransaction,
        style: ElevatedButton.styleFrom(
          foregroundColor: isDarkMode ? Colors.black : Colors.white,
          backgroundColor: isDarkMode ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          "Add Transaction",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: isDarkMode ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}