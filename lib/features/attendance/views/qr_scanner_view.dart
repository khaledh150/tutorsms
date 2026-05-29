import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/attendance_provider.dart';

class QrScannerView extends ConsumerStatefulWidget {
  const QrScannerView({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends ConsumerState<QrScannerView> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _processing = false;
  _ScanFeedback? _feedback;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) {
              String message;
              switch (error.errorCode) {
                case MobileScannerErrorCode.permissionDenied:
                  message = 'cameraPermissionDenied'.tr();
                case MobileScannerErrorCode.genericError:
                  message = 'cameraInUse'.tr();
                default:
                  message = 'cameraNotFound'.tr();
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          color: Colors.white54, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: AppTextStyles.bodySm
                            .copyWith(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          _buildOverlay(),
          _buildHeader(),
          if (_feedback != null) _buildFeedbackBanner(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Center(
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 3),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.go('/attendance/${widget.courseId}'),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x66000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'scanQr'.tr(),
                  style: AppTextStyles.displaySm
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final fb = _feedback!;
    return Positioned(
      bottom: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: fb.success ? AppColors.success : AppColors.danger,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 16,
              color: (fb.success ? AppColors.success : AppColors.danger)
                  .withValues(alpha: 0.5),
            ),
          ],
        ),
        child: Text(
          fb.message,
          style: AppTextStyles.bodyBoldSm.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final studentId = barcode.rawValue!.trim();
    if (studentId.isEmpty) return;

    setState(() => _processing = true);

    try {
      final user = ref.read(authProvider).valueOrNull;
      if (user == null) return;

      final repo = ref.read(attendanceRepositoryProvider);
      await repo.checkIn(
        studentId: studentId,
        courseId: widget.courseId,
        approverId: user.id,
      );

      HapticFeedback.mediumImpact();
      setState(() {
        _feedback = _ScanFeedback(message: 'checkedInMsg'.tr(), success: true);
      });
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        _feedback = _ScanFeedback(message: 'scanFailed'.tr(), success: false);
      });
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _feedback = null;
          _processing = false;
        });
      }
    });
  }
}

class _ScanFeedback {
  final String message;
  final bool success;
  const _ScanFeedback({required this.message, required this.success});
}
