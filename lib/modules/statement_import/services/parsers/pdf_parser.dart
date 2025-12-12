import 'dart:io';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/imported_transaction.dart';
import '../file_parser_factory.dart';

class PdfParser implements FileParser {
  @override
  Future<List<ImportedTransaction>> parse(File file) async {
    print("DEBUG: Pt A - Starting parse for ${file.path}");
    try {
        // Load the PDF document
        print("DEBUG: Pt B - Reading bytes...");
        final List<int> bytes = file.readAsBytesSync();
        print("DEBUG: Pt C - Bytes read: ${bytes.length}. Creating PdfDocument...");
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        print("DEBUG: Pt D - PdfDocument created. Extracting text...");
        String text = PdfTextExtractor(document).extractText();
        document.dispose();
        print("DEBUG: Pt E - Text extracted. Length: ${text.length}");

        print("DEBUG: Extracted text length: ${text.length}");
        if (text.isNotEmpty) {
           print("DEBUG: First 500 chars: ${text.substring(0, text.length > 500 ? 500 : text.length)}");
        } else {
           print("DEBUG: Text extraction returned empty string. Possible scanned PDF or encryption.");
        }

        // ... Rest of parsing ...
        
        List<ImportedTransaction> transactions = [];
        
        // Split by lines
        final lines = text.split('\n');
    
    // PhonePe Statement Regex Patterns (Relaxed)
    // Date: Dec 02, 2025 or 12 Nov, 2025
    final dateRegex = RegExp(r'(\d{1,2}|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s\d{1,2},?\s\d{4}', caseSensitive: false);
    // Amount: ₹1,000 or 1,000.00 (allow missing symbol)
    final amountRegex = RegExp(r'[₹Rs\.]{0,3}\s?([\d,]+(\.\d{2})?)');
    // Transaction Lines
    final paidToRegex = RegExp(r'(Paid to|Transfer to)\s+(.+)', caseSensitive: false);
    final receivedFromRegex = RegExp(r'(Received from|Transfer from)\s+(.+)', caseSensitive: false);

    print("Parsed Text Length: ${text.length}"); // Debug
    
    // Iterate through lines to find transaction blocks
    for (int i = 0; i < lines.length; i++) {
       String line = lines[i].trim();
       if (line.isEmpty) continue;
       
       if (dateRegex.hasMatch(line)) {
          try {
             // Found a date start line!
             final dateMatch = dateRegex.firstMatch(line)!;
             // Try flexible parsing for date
             String dateStr = dateMatch.group(0)!;
             // Normalize date string for parsing if needed, but lets assume DateFormat matching
             // We'll try a few patterns
             DateTime date;
             try {
                date = DateFormat('MMM dd, yyyy').parse(dateStr);
             } catch (_) {
                 try {
                    date = DateFormat('dd MMM, yyyy').parse(dateStr);
                 } catch (e) {
                    date = DateTime.now(); // Fallback
                 }
             }
             
             String personName = "Unknown";
             String type = "DEBIT";
             double amount = 0.0;
             bool foundDetails = false;

             // Look ahead 5 lines for context
             for (int j = 0; j <= 5 && (i + j) < lines.length; j++) {
                String seekLine = lines[i+j].trim();
                
                // Check Name / Type
                if (paidToRegex.hasMatch(seekLine)) {
                   personName = paidToRegex.firstMatch(seekLine)!.group(2)!.trim();
                   type = 'DEBIT';
                } else if (receivedFromRegex.hasMatch(seekLine)) {
                   personName = receivedFromRegex.firstMatch(seekLine)!.group(2)!.trim();
                   type = 'CREDIT';
                }
                
                // Check Amount (ensure it's a valid number and looks like an amount)
                if (amountRegex.hasMatch(seekLine) && !seekLine.contains("Transaction ID")) {
                    // Avoid matching IDs as amounts
                    final match = amountRegex.firstMatch(seekLine)!;
                    String rawAmount = match.group(1)!.replaceAll(',', '');
                     try {
                        double parsed = double.parse(rawAmount);
                        if (parsed > 0 && amount == 0.0) { // Take first valid amount
                           amount = parsed;
                           foundDetails = true;
                        }
                     } catch (_) {}
                }
             }

             if (foundDetails && amount > 0) {
                 transactions.add(ImportedTransaction(
                     date: date,
                     personName: personName,
                     upiId: "", // UTR extraction could be added here if needed
                     amount: amount,
                     type: type,
                     sourceBank: "PhonePe",
                     category: "Uncategorized",
                 ));
             }
          } catch (e) {
             print("Error parsing PhonePe block at line $i: $e");
          }
       }
    }
    
    // Returning empty list for now as strict implementing requires known format.
    // In a real app, I'd ask user for "Bank Format".
    // For this task, I'll return dummy data if parsing fails to demonstrate UI.
    return transactions;
    } catch (e) {
       print("CRITICAL: Error in PdfParser: $e");
       return [];
    }
  }
}
