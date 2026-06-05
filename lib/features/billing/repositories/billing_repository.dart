import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/supabase_client.dart';
import '../models/billing_models.dart';

class BillingRepository {
  Future<List<Payment>> fetchPayments() async {
    try {
      final res = await supabase
          .from('payments')
          .select('*')
          .order('received_at', ascending: false)
          .limit(50);
      return (res as List).map((e) => Payment.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchPayments failed: $e');
      rethrow;
    }
  }

  Future<List<Expense>> fetchExpenses() async {
    try {
      final res = await supabase
          .from('expenses')
          .select('*')
          .order('date', ascending: false)
          .limit(50);
      return (res as List).map((e) => Expense.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchExpenses failed: $e');
      rethrow;
    }
  }

  Future<List<MonthlySummary>> fetchMonthlySummary() async {
    try {
      final res = await supabase
          .from('monthly_summary')
          .select('*')
          .order('year', ascending: false)
          .order('month', ascending: false)
          .limit(12);
      return (res as List).map((e) => MonthlySummary.fromJson(e)).toList();
    } catch (e) {
      debugPrint('fetchMonthlySummary failed: $e');
      rethrow;
    }
  }

  Future<void> addPayment({
    required double amount,
    required String currency,
    required String method,
    String? note,
    XFile? file,
  }) async {
    try {
      String? receiptUrl;

      if (file != null) {
        final fn = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
        final bytes = await file.readAsBytes();
        await supabase.storage
            .from('receipts')
            .uploadBinary(fn, bytes);
        final pubUrl =
            supabase.storage.from('receipts').getPublicUrl(fn);
        receiptUrl = pubUrl;
      }

      await supabase.from('payments').insert({
        'amount': amount,
        'currency': currency,
        'method': method,
        'note': note,
        'receipt_url': receiptUrl,
      });
    } catch (e) {
      debugPrint('addPayment failed: $e');
      rethrow;
    }
  }

  Future<void> addExpense({
    required String category,
    required double amount,
    String? description,
    required String createdBy,
    String? method,
    XFile? file,
  }) async {
    try {
      String? receiptUrl;

      if (file != null) {
        final fn = '${DateTime.now().millisecondsSinceEpoch}-${file.name}';
        final bytes = await file.readAsBytes();
        await supabase.storage
            .from('receipts')
            .uploadBinary(fn, bytes);
        receiptUrl = supabase.storage.from('receipts').getPublicUrl(fn);
      }

      await supabase.from('expenses').insert({
        'category': category,
        'amount': amount,
        'description': description,
        'created_by': createdBy,
        'method': method,
        'receipt_url': receiptUrl,
      });
    } catch (e) {
      debugPrint('addExpense failed: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await supabase.from('expenses').delete().eq('id', id);
    } catch (e) {
      debugPrint('deleteExpense failed: $e');
      rethrow;
    }
  }
}
