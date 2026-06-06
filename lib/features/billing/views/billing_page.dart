import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';

class BillingPage extends ConsumerStatefulWidget {
  const BillingPage({super.key});

  @override
  ConsumerState<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends ConsumerState<BillingPage> {
  String _tab = 'overview';

  // Date filter
  late String _dateFrom;
  late String _dateTo;

  bool _showCustomRange = false;

  // Add expense
  bool _addExpenseOpen = false;
  String _expCategory = 'supplies';
  String _expMethod = 'cash';
  final _expAmount = TextEditingController();
  final _expDesc = TextEditingController();
  XFile? _expFile;

  // Add payment
  bool _addPaymentOpen = false;
  final _payAmount = TextEditingController();
  String _payCurrency = 'THB';
  String _payMethod = 'cash';
  final _payNote = TextEditingController();
  XFile? _payFile;

  // Pagination
  int _payLimit = 20;
  int _expLimit = 20;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = now.toIso8601String().substring(0, 10);
    _dateFrom =
        now.subtract(const Duration(days: 30)).toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    _expAmount.dispose();
    _expDesc.dispose();
    _payAmount.dispose();
    _payNote.dispose();
    super.dispose();
  }

  List<Payment> _filterPayments(List<Payment> payments) {
    return payments.where((p) {
      if (_dateFrom.isNotEmpty && p.receivedAt.compareTo(_dateFrom) < 0) {
        return false;
      }
      if (_dateTo.isNotEmpty &&
          p.receivedAt.compareTo('${_dateTo}T23:59:59') > 0) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    return expenses.where((e) {
      if (_dateFrom.isNotEmpty && e.date.compareTo(_dateFrom) < 0) return false;
      if (_dateTo.isNotEmpty && e.date.compareTo(_dateTo) > 0) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final paymentsAsync = ref.watch(paymentsProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final summariesAsync = ref.watch(monthlySummaryProvider);

    // Show loading indicator while core data is still loading
    if (paymentsAsync.isLoading || expensesAsync.isLoading || summariesAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgMain,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final payments = paymentsAsync.valueOrNull ?? [];
    final expenses = expensesAsync.valueOrNull ?? [];
    final summaries = summariesAsync.valueOrNull ?? [];

    final filtered = _filterPayments(payments);
    final filteredExp = _filterExpenses(expenses);
    double totalIncome = filtered.fold<double>(0, (s, p) => s + p.amount);
    if (totalIncome == 0 && summaries.isNotEmpty) {
      final now = DateTime.now();
      final currentMonth = summaries.cast<MonthlySummary?>().firstWhere(
          (s) => s!.month == now.month && s.year == now.year,
          orElse: () => null);
      if (currentMonth != null) {
        totalIncome = currentMonth.income;
      }
    }
    final totalExpenses =
        filteredExp.fold<double>(0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpenses;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paymentsProvider);
            ref.invalidate(expensesProvider);
            ref.invalidate(monthlySummaryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Title
              Text('billing'.tr(), style: AppTextStyles.displaySm),
            const SizedBox(height: 16),

            // Summary cards
            Row(
              children: [
                _SummaryCard(
                  icon: Icons.trending_up_rounded,
                  initialValue: totalIncome,
                  label: 'incomeTHB'.tr(),
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  icon: Icons.trending_down_rounded,
                  initialValue: totalExpenses,
                  label: 'expensesTHB'.tr(),
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                _SummaryCard(
                  icon: Icons.attach_money_rounded,
                  initialValue: net,
                  label: 'netTHB'.tr(),
                  color: net >= 0 ? AppColors.success : AppColors.danger,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date range
            _buildDateFilter(),
            const SizedBox(height: 12),

            // Tabs
            Row(
              children: [
                _TabBtn(
                    label: 'overview'.tr(),
                    active: _tab == 'overview',
                    onTap: () => setState(() => _tab = 'overview')),
                const SizedBox(width: 8),
                _TabBtn(
                    label: 'income'.tr(),
                    active: _tab == 'income',
                    onTap: () => setState(() => _tab = 'income')),
                const SizedBox(width: 8),
                _TabBtn(
                    label: 'expenses'.tr(),
                    active: _tab == 'expenses',
                    onTap: () => setState(() => _tab = 'expenses')),
              ],
            ),
            const SizedBox(height: 16),

            if (_tab == 'overview') _buildOverview(summaries),
            if (_tab == 'income') _buildIncome(filtered),
            if (_tab == 'expenses') _buildExpenses(filteredExp),
          ],
          ),
        ),
    );
  }

  Widget _buildDateFilter() {
    final isCustom = _isCustomRange();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _presetBtn(label: '7d', days: 7),
              const SizedBox(width: 8),
              _presetBtn(label: '30d', days: 30),
              const SizedBox(width: 8),
              _presetBtn(label: '90d', days: 90),
              const SizedBox(width: 8),
              _presetBtn(label: 'all'.tr(), days: 0),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showCustomRange = !_showCustomRange),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCustom || _showCustomRange
                          ? AppColors.primary
                          : AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Center(
                      child: Text('custom'.tr(),
                          style: AppTextStyles.bodyBoldSm.copyWith(
                              color: isCustom || _showCustomRange
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showCustomRange) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    initialValue: _dateFrom,
                    onChanged: (v) => setState(() => _dateFrom = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—',
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textMuted)),
                ),
                Expanded(
                  child: _DateField(
                    initialValue: _dateTo,
                    onChanged: (v) => setState(() => _dateTo = v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _isCustomRange() {
    for (final days in [7, 30, 90]) {
      final presetFrom = DateTime.now()
          .subtract(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);
      final presetTo = DateTime.now().toIso8601String().substring(0, 10);
      if (_dateFrom == presetFrom && _dateTo == presetTo) return false;
    }
    if (_dateFrom.isEmpty && _dateTo.isEmpty) return false;
    return true;
  }

  Widget _presetBtn({required String label, required int days}) {
    final presetFrom = days > 0
        ? DateTime.now()
            .subtract(Duration(days: days))
            .toIso8601String()
            .substring(0, 10)
        : '';
    final presetTo = days > 0
        ? DateTime.now().toIso8601String().substring(0, 10)
        : '';
    final isActive = _dateFrom == presetFrom && _dateTo == presetTo;

    return GestureDetector(
      onTap: () => setState(() {
        _dateFrom = presetFrom;
        _dateTo = presetTo;
        _showCustomRange = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(label,
            style: AppTextStyles.bodyBoldSm
                .copyWith(color: isActive ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildOverview(List<MonthlySummary> summaries) {
    if (summaries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('noMonthlyData'.tr(),
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('monthlySummary'.tr(), style: AppTextStyles.bodyBoldSm),
        const SizedBox(height: 8),
        ...summaries.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Text('${s.month}/${s.year}',
                      style: AppTextStyles.bodySemiBoldSm),
                  const Spacer(),
                  Text('+${s.income.toStringAsFixed(0)}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.success)),
                  const SizedBox(width: 16),
                  Text('-${s.expenses.toStringAsFixed(0)}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.danger)),
                  const SizedBox(width: 16),
                  Text('= ${s.profit.toStringAsFixed(0)}',
                      style: AppTextStyles.bodyBoldSm.copyWith(
                          color: s.profit >= 0
                              ? AppColors.success
                              : AppColors.danger)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildIncome(List<Payment> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () =>
              setState(() => _addPaymentOpen = !_addPaymentOpen),
          icon: const Icon(Icons.add_rounded),
          label: Text('recordPayment'.tr()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary),
        ),
        if (_addPaymentOpen) ...[
          const SizedBox(height: 12),
          _buildPaymentForm(),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('noPaymentsRecorded'.tr(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textMuted)),
            ),
          )
        else ...[
          ...filtered.take(_payLimit).map((p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_up_rounded,
                          color: AppColors.success, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${p.amount.toStringAsFixed(0)} ${p.currency}',
                              style: AppTextStyles.bodySemiBoldSm),
                          Text(
                            '${_shortDate(p.receivedAt)}${p.method != null ? ' | ${p.method}' : ''}',
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (p.receiptUrl != null && p.receiptUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(p.receiptUrl!),
                            mode: LaunchMode.externalApplication),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text('receipt'.tr(),
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ],
                ),
              )),
          if (filtered.length > _payLimit)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _payLimit += 20),
                child: Text('loadMore'.tr(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.primary)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPaymentForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _payAmount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'amount'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: _payCurrency),
                  onChanged: (v) => _payCurrency = v,
                  decoration: InputDecoration(hintText: 'currency'.tr()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _payMethod,
            items: [
              DropdownMenuItem(value: 'cash', child: Text('cash'.tr())),
              DropdownMenuItem(value: 'transfer', child: Text('transfer'.tr())),
              DropdownMenuItem(value: 'promptpay', child: Text('promptpay'.tr())),
            ],
            onChanged: (v) => setState(() => _payMethod = v ?? 'cash'),
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _payNote,
            decoration: InputDecoration(hintText: 'note'.tr()),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
              );
              if (result != null && result.files.isNotEmpty) {
                final pf = result.files.first;
                if (pf.size > AppConstants.maxFileSize) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('fileTooLarge'.tr())),
                    );
                  }
                  return;
                }
                if (pf.path != null) {
                  setState(() => _payFile = XFile(pf.path!));
                } else if (pf.bytes != null) {
                  setState(() => _payFile = XFile.fromData(pf.bytes!, name: pf.name));
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    _payFile != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                    size: 18,
                    color: _payFile != null ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _payFile != null
                          ? _payFile!.name
                          : 'receipt'.tr(),
                      style: AppTextStyles.bodySm.copyWith(
                        color: _payFile != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_payFile != null)
                    GestureDetector(
                      onTap: () => setState(() => _payFile = null),
                      child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _addPaymentOpen = false;
                    _payAmount.clear();
                    _payNote.clear();
                    _payFile = null;
                  }),
                  child: Text('cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleAddPayment,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                  child: Text('save'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpenses(List<Expense> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: () =>
              setState(() => _addExpenseOpen = !_addExpenseOpen),
          icon: const Icon(Icons.add_rounded),
          label: Text('addExpense'.tr()),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary),
        ),
        if (_addExpenseOpen) ...[
          const SizedBox(height: 12),
          _buildExpenseForm(),
        ],
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('noExpensesRecorded'.tr(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textMuted)),
            ),
          )
        else ...[
          ...filtered.take(_expLimit).map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.trending_down_rounded,
                          color: AppColors.danger, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${e.amount.toStringAsFixed(0)} THB — ${e.category}',
                              style: AppTextStyles.bodySemiBoldSm),
                          Text(
                            '${_shortDate(e.date)}${e.method != null ? ' | ${e.method}' : ''}${e.description != null ? ' | ${e.description}' : ''}',
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    if (e.receiptUrl != null && e.receiptUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse(e.receiptUrl!),
                            mode: LaunchMode.externalApplication),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                          ),
                          child: Text('receipt'.tr(),
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    IconButton(
                      onPressed: () => _handleDeleteExpense(e),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                    ),
                  ],
                ),
              )),
          if (filtered.length > _expLimit)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _expLimit += 20),
                child: Text('loadMore'.tr(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.primary)),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildExpenseForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _expCategory,
                  items: [
                    DropdownMenuItem(value: 'supplies', child: Text('supplies'.tr())),
                    DropdownMenuItem(value: 'rent', child: Text('rent'.tr())),
                    DropdownMenuItem(value: 'salary', child: Text('salary'.tr())),
                    DropdownMenuItem(value: 'utilities', child: Text('utilities'.tr())),
                    DropdownMenuItem(value: 'other', child: Text('other'.tr())),
                  ],
                  onChanged: (v) =>
                      setState(() => _expCategory = v ?? 'supplies'),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _expAmount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'amountTHB'.tr()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _expMethod,
            items: [
              DropdownMenuItem(value: 'cash', child: Text('cash'.tr())),
              DropdownMenuItem(value: 'transfer', child: Text('transfer'.tr())),
              DropdownMenuItem(value: 'promptpay', child: Text('promptpay'.tr())),
            ],
            onChanged: (v) => setState(() => _expMethod = v ?? 'cash'),
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _expDesc,
            decoration:
                InputDecoration(hintText: 'descriptionOptional'.tr()),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
              );
              if (result != null && result.files.isNotEmpty) {
                final pf = result.files.first;
                if (pf.size > AppConstants.maxFileSize) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('fileTooLarge'.tr())),
                    );
                  }
                  return;
                }
                if (pf.path != null) {
                  setState(() => _expFile = XFile(pf.path!));
                } else if (pf.bytes != null) {
                  setState(() => _expFile = XFile.fromData(pf.bytes!, name: pf.name));
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    _expFile != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                    size: 18,
                    color: _expFile != null ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _expFile != null
                          ? _expFile!.name
                          : 'receiptOptional'.tr(),
                      style: AppTextStyles.bodySm.copyWith(
                        color: _expFile != null ? AppColors.textPrimary : AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_expFile != null)
                    GestureDetector(
                      onTap: () => setState(() => _expFile = null),
                      child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _addExpenseOpen = false),
                  child: Text('cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleAddExpense,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success),
                  child: Text('save'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddPayment() async {
    final amount = double.tryParse(_payAmount.text) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('amountMustBePositive'.tr())),
        );
      }
      return;
    }
    if (_payCurrency.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('currencyRequired'.tr())),
        );
      }
      return;
    }
    final repo = ref.read(billingRepositoryProvider);
    await repo.addPayment(
      amount: amount,
      currency: _payCurrency,
      method: _payMethod,
      note: _payNote.text.isEmpty ? null : _payNote.text,
      file: _payFile,
    );
    ref.invalidate(paymentsProvider);
    setState(() {
      _addPaymentOpen = false;
      _payAmount.clear();
      _payNote.clear();
      _payFile = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('paymentRecorded'.tr())));
    }
  }

  Future<void> _handleAddExpense() async {
    final expAmount = double.tryParse(_expAmount.text) ?? 0;
    if (expAmount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('amountMustBePositive'.tr())),
        );
      }
      return;
    }
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final repo = ref.read(billingRepositoryProvider);
    await repo.addExpense(
      category: _expCategory,
      amount: expAmount,
      description: _expDesc.text.isEmpty ? null : _expDesc.text,
      createdBy: user.id,
      method: _expMethod,
      file: _expFile,
    );
    ref.invalidate(expensesProvider);
    setState(() {
      _addExpenseOpen = false;
      _expAmount.clear();
      _expDesc.clear();
      _expFile = null;
      _expMethod = 'cash';
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('expenseAdded'.tr())));
    }
  }

  Future<void> _handleDeleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirmDelete'.tr()),
        content: Text(
            '${expense.amount.toStringAsFixed(0)} THB — ${expense.category}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: Text('delete'.tr(),
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(billingRepositoryProvider);
    await repo.deleteExpense(expense.id);
    ref.invalidate(expensesProvider);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('expenseDeleted'.tr())));
    }
  }

  String _shortDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.initialValue,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final double initialValue;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(initialValue.toStringAsFixed(0),
                style: AppTextStyles.bodyBoldBase.copyWith(color: color)),
            Text(label,
                style: AppTextStyles.bodyXs
                    .copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn(
      {required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: active ? null : Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(label,
                style: AppTextStyles.bodyBoldSm.copyWith(
                    color: active ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.initialValue, required this.onChanged});
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final initial =
            initialValue.isNotEmpty ? DateTime.tryParse(initialValue) : DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked.toIso8601String().substring(0, 10));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(
          initialValue.isEmpty ? '—' : initialValue,
          style: AppTextStyles.bodySm.copyWith(color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
