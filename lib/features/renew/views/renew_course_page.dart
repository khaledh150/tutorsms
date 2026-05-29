import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../repositories/renewal_repository.dart';

const _lineGreen = Color(0xFF06C755);

class RenewCoursePage extends StatefulWidget {
  const RenewCoursePage({
    super.key,
    required this.studentId,
    required this.courseId,
    required this.token,
  });

  final String studentId;
  final String courseId;
  final String token;

  @override
  State<RenewCoursePage> createState() => _RenewCoursePageState();
}

class _RenewCoursePageState extends State<RenewCoursePage> {
  final _repo = RenewalRepository();

  bool _loading = true;
  String? _error;
  RenewalData? _data;

  String _step = 'packages'; // packages | payment | upload | done
  Map<String, dynamic>? _selectedPkg;
  XFile? _slipFile;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tokenRow = await _repo.validateRenewalToken(
          widget.token, widget.studentId, widget.courseId);

      // H8 — Check token expiration upfront
      final expiresAt = DateTime.tryParse(
          (tokenRow['expires_at'] as String?) ?? '');
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        setState(() {
          _error = 'renewTokenExpired'.tr();
          _loading = false;
        });
        return;
      }
      if (tokenRow['used_at'] != null) {
        setState(() {
          _error = 'renewTokenUsed'.tr();
          _loading = false;
        });
        return;
      }

      final data = await _repo.fetchRenewalData(
          tokenRow, widget.studentId, widget.courseId);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'renewTokenInvalid'.tr();
        _loading = false;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (_slipFile == null || _data == null || _selectedPkg == null) return;
    setState(() => _uploading = true);
    try {
      await _repo.submitRenewalSlip(
        schoolId: _data!.schoolId,
        studentId: _data!.studentId,
        courseId: _data!.courseId,
        courseName: _data!.courseName,
        selectedHours: (_selectedPkg!['hours'] as num).toInt(),
        selectedPrice: (_selectedPkg!['price'] as num).toInt(),
        file: _slipFile!,
        token: widget.token,
      );
      setState(() => _step = 'done');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(
          child: CircularProgressIndicator(color: _lineGreen),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😔', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 16),
                Text(_error!,
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;
    final remaining = data.remaining;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  // Header card
                  _buildHeader(data, remaining),
                  const SizedBox(height: 16),

                  if (_step == 'packages') _buildPackages(data),
                  if (_step == 'payment') _buildPayment(data),
                  if (_step == 'upload') _buildUpload(),
                  if (_step == 'done') _buildDone(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(RenewalData data, int remaining) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(data.studentName,
              style: AppTextStyles.bodyBoldBase,
              textAlign: TextAlign.center),
          Text(data.courseName,
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: remaining <= 0
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFFEF3C7),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              remaining <= 0
                  ? 'renewHoursUsedUp'.tr()
                  : 'renewHoursLeft'.tr(namedArgs: {
                      'count': '$remaining',
                    }),
              style: AppTextStyles.bodySm.copyWith(
                  color: remaining <= 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFD97706),
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
              'renewUsedOfTotal'.tr(namedArgs: {
                'used': '${data.usedHours}',
                'total': '${data.purchasedHours}',
              }),
              style: AppTextStyles.bodyXs
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildPackages(RenewalData data) {
    return Column(
      children: [
        Text('renewSelectPackage'.tr(),
            style: AppTextStyles.bodySemiBoldBase
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ...data.packages.map((pkg) {
          final hours = (pkg['hours'] as num).toInt();
          final price = (pkg['price'] as num).toInt();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              elevation: 2,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedPkg = pkg;
                    _step = data.qrUrl != null ? 'payment' : 'upload';
                  });
                },
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLg),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text('renewPackageHours'.tr(
                              namedArgs: {'count': '$hours'}),
                          style: AppTextStyles.bodyBoldBase),
                      Text('฿${_formatNumber(price)}',
                          style: AppTextStyles.bodyBoldBase
                              .copyWith(color: _lineGreen)),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPayment(RenewalData data) {
    final price = (_selectedPkg!['price'] as num).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text('renewScanAndPay'.tr(),
              style: AppTextStyles.bodySemiBoldBase
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('฿${_formatNumber(price)}',
              style: AppTextStyles.displayLg
                  .copyWith(color: _lineGreen)),
          const SizedBox(height: 16),
          if (data.qrUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Image.network(
                data.qrUrl!,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _lineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 240,
                  height: 240,
                  child: Center(
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('renewAfterPaymentNext'.tr(),
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _step = 'packages'),
                  style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('renewBack'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      setState(() => _step = 'upload'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lineGreen,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('renewNext'.tr(),
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

  Widget _buildUpload() {
    final hours = (_selectedPkg!['hours'] as num).toInt();
    final price = (_selectedPkg!['price'] as num).toInt();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text('renewUploadSlip'.tr(),
              style: AppTextStyles.bodySemiBoldBase
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('renewPackageSummary'.tr(namedArgs: {
                'hours': '$hours',
                'price': _formatNumber(price),
              }),
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final picker = ImagePicker();
              final file = await picker.pickImage(
                  source: ImageSource.gallery, maxWidth: 1200);
              if (file != null) setState(() => _slipFile = file);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.border,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: _slipFile != null
                  ? Column(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: _lineGreen, size: 40),
                        const SizedBox(height: 8),
                        Text(_slipFile!.name,
                            style: AppTextStyles.bodySm
                                .copyWith(color: _lineGreen)),
                      ],
                    )
                  : Column(
                      children: [
                        const Text('📸',
                            style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text('renewTapToSelectFile'.tr(),
                            style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.textMuted)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _step =
                      _data?.qrUrl != null ? 'payment' : 'packages'),
                  style: OutlinedButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('renewBack'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _slipFile == null || _uploading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lineGreen,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                      _uploading
                          ? 'renewSubmitting'.tr()
                          : 'renewSubmitSlip'.tr(),
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

  Widget _buildDone() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          const Text('✅', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text('renewThankYou'.tr(),
              style: AppTextStyles.bodyBoldBase),
          const SizedBox(height: 8),
          Text('renewVerifyMessage'.tr(),
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
