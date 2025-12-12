import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/statement_provider.dart';

class PersonSummaryScreen extends StatelessWidget {
  const PersonSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
     return Scaffold(
       appBar: AppBar(title: const Text("Person Summary")),
       body: Consumer<StatementProvider>(
          builder: (context, provider, _) {
             // Group by Person
             Map<String, double> totals = {};
             for (var t in provider.transactions) {
                totals[t.personName] = (totals[t.personName] ?? 0) + (t.type == 'DEBIT' ? -t.amount : t.amount);
             }
             
             final sortedKeys = totals.keys.toList()..sort((a,b) => totals[a]!.compareTo(totals[b]!));
             
             return ListView.builder(
               itemCount: sortedKeys.length,
               itemBuilder: (context, index) {
                  final person = sortedKeys[index];
                  final amount = totals[person]!;
                  final isNegative = amount < 0;
                  
                  return ListTile(
                    leading: CircleAvatar(child: Text(person[0].toUpperCase())),
                    title: Text(person),
                    trailing: Text(
                       "₹${amount.abs().toStringAsFixed(2)}",
                       style: TextStyle(
                          color: isNegative ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                       ),
                    ),
                  );
               },
             );
          }
       ),
     );
  }
}
