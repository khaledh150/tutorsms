import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/billing_models.dart';
import '../repositories/billing_repository.dart';

final billingRepositoryProvider = Provider((ref) => BillingRepository());

final paymentsProvider = FutureProvider<List<Payment>>((ref) {
  final repo = ref.read(billingRepositoryProvider);
  return repo.fetchPayments();
});

final expensesProvider = FutureProvider<List<Expense>>((ref) {
  final repo = ref.read(billingRepositoryProvider);
  return repo.fetchExpenses();
});

final monthlySummaryProvider = FutureProvider<List<MonthlySummary>>((ref) {
  final repo = ref.read(billingRepositoryProvider);
  return repo.fetchMonthlySummary();
});
