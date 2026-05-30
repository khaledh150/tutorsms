import 'dart:io';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../admissions/models/application_change_model.dart';
import '../../admissions/repositories/application_repository.dart';
import '../../courses/models/course_model.dart';
import '../../attendance/repositories/attendance_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/providers/course_provider.dart';
import '../../messaging/models/line_config_model.dart';
import '../../messaging/models/line_connection_model.dart';
import '../../messaging/models/unlinked_user_model.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../models/enrollment_model.dart';
import '../providers/student_provider.dart';

class StudentProfilePage extends ConsumerStatefulWidget {
  const StudentProfilePage({super.key, required this.studentId});
  final String studentId;

  @override
  ConsumerState<StudentProfilePage> createState() =>
      _StudentProfilePageState();
}

class _StudentProfilePageState extends ConsumerState<StudentProfilePage> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentProvider(widget.studentId));
    final enrollmentsAsync =
        ref.watch(studentEnrollmentsProvider(widget.studentId));
    final attendanceAsync =
        ref.watch(studentAttendanceProvider(widget.studentId));
    final historyAsync =
        ref.watch(enrollmentHistoryProvider(widget.studentId));
    final pendingAsync =
        ref.watch(pendingChangesForStudentProvider(widget.studentId));
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: studentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('studentNotFound'.tr(),
                  style: AppTextStyles.displaySm
                      .copyWith(color: AppColors.danger)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/students'),
                child: Text('back'.tr()),
              ),
            ],
          ),
        ),
        data: (student) {
          final enrollments = enrollmentsAsync.valueOrNull ?? [];
          final attendance = attendanceAsync.valueOrNull ?? [];
          final history = historyAsync.valueOrNull ?? [];
          final pendingChanges = pendingAsync.valueOrNull ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(studentProvider(widget.studentId));
              ref.invalidate(studentEnrollmentsProvider(widget.studentId));
              ref.invalidate(studentAttendanceProvider(widget.studentId));
              ref.invalidate(enrollmentHistoryProvider(widget.studentId));
              ref.invalidate(pendingChangesForStudentProvider(widget.studentId));
            },
            child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                pinned: true,
                backgroundColor: AppColors.bgCard,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/students'),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: AppColors.primary),
                    onPressed: () => _showEditStudentDialog(
                        context, student),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      onPressed: () =>
                          _confirmDelete(context, student, enrollments, attendance),
                    ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildProfileHeader(student, isAdmin),
                    const SizedBox(height: 24),
                    _buildEnrollmentsSection(
                        enrollments, attendance, pendingChanges),
                    if (isAdmin && history.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildHistorySection(history),
                    ],
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
          );
        },
      ),
    );
  }

  // --- Profile Header ---

  Widget _buildProfileHeader(dynamic student, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            color: Color(0x0D000000),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _pickStudentPhoto(student.id),
                child: Stack(
                  children: [
                    Hero(
                      tag: 'student_avatar_${student.id}',
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: student.photoUrl != null
                            ? Image.network(
                                student.photoUrl!,
                                width: 64,
                                height: 64,
                                cacheWidth: 128,
                                cacheHeight: 128,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _avatarInitial(student),
                              )
                            : _avatarInitial(student),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          if (student.nickName != null &&
                              student.nickName!.isNotEmpty)
                            TextSpan(
                              text: '"${student.nickName}" ',
                              style: AppTextStyles.displaySm
                                  .copyWith(color: AppColors.primary),
                            ),
                          TextSpan(
                            text:
                                '${student.firstName} ${student.lastName}',
                            style: AppTextStyles.displaySm,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        if (student.dob != null)
                          _infoChip(Icons.cake_rounded,
                              '${'dob'.tr()}: ${_formatDate(student.dob!)}'),
                        if (student.parentPhone != null)
                          _infoChip(Icons.phone_rounded,
                              student.parentPhone!),
                        if (student.joinedAt != null)
                          _infoChip(Icons.calendar_today_rounded,
                              '${'joined'.tr()}: ${_formatDate(student.joinedAt!)}'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _showQrDialog(context, student.id, student.displayName),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: QrImageView(
                    data: student.id,
                    version: QrVersions.auto,
                    size: 48,
                    padding: const EdgeInsets.all(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'studentQrCode'.tr(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Icon(Icons.open_in_full_rounded,
                    size: 16, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.borderLight),
          const SizedBox(height: 12),
          _LineConnectionCard(
            studentId: widget.studentId,
            studentName: student.nickName ?? student.firstName,
            isAdmin: isAdmin,
          ),
        ],
      ),
    );
  }

  Widget _avatarInitial(dynamic student) {
    return Center(
      child: Text(
        student.initial,
        style: AppTextStyles.displayMd.copyWith(color: Colors.white),
      ),
    );
  }

  void _showQrDialog(BuildContext context, String studentId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => _QrDialog(studentId: studentId, name: name),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text,
            style: AppTextStyles.bodySm
                .copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  // --- Enrollments ---

  Widget _buildEnrollmentsSection(
      List<Enrollment> enrollments,
      List<Map<String, dynamic>> attendance,
      List<ApplicationChange> pendingChanges) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('enrolledCourses'.tr(), style: AppTextStyles.displaySm),
            GestureDetector(
              onTap: () => _showAddCourseDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('addNewCourse'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.primary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (enrollments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text('noEnrollments'.tr(),
                  style: AppTextStyles.bodyBase
                      .copyWith(color: AppColors.textMuted)),
            ),
          )
        else
          for (final enr in enrollments)
            _EnrollmentCard(
              studentId: widget.studentId,
              enrollment: enr,
              attendanceRecords: attendance
                  .where((a) =>
                      a['course_id'] == enr.courseId &&
                      a['approved_by'] != null &&
                      a['cancelled_by'] == null)
                  .toList(),
              pendingReq: pendingChanges.cast<ApplicationChange?>().firstWhere(
                (c) {
                  final limits = c!.changes['course_limits'];
                  return limits is Map && limits.containsKey(enr.courseId);
                },
                orElse: () => null,
              ),
            ),
      ],
    );
  }

  // --- Enrollment History ---

  Widget _buildHistorySection(List<EnrollmentHistoryRecord> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('enrollmentHistory'.tr(), style: AppTextStyles.displaySm),
        const SizedBox(height: 12),
        for (final h in history)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(h.courseName,
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.primary)),
                    Text(_formatDate(h.renewedAt),
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  children: [
                    Text(
                        '${h.usedHours}/${h.purchasedHours} ${'hrs'.tr()}',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textSecondary)),
                    if (h.price != null)
                      Text('${'price'.tr()}: ฿${intl.NumberFormat('#,###').format(h.price)}',
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.textSecondary)),
                    if (h.bookInfo != null)
                      Text('${'book'.tr()}: ${h.bookInfo}',
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  // --- Actions ---

  void _confirmDelete(BuildContext context, dynamic student,
      List<Enrollment> enrollments, List<Map<String, dynamic>> attendance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 32, color: AppColors.danger),
            ),
            const SizedBox(height: 16),
            Text('deleteConfirmTitle'.tr(),
                style: AppTextStyles.displaySm),
            const SizedBox(height: 8),
            Text('deleteStudentConfirm'.tr(),
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('deleteWillRemove'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.warning)),
                  const SizedBox(height: 4),
                  Text(
                      '• ${enrollments.length} ${'enrolledCourses'.tr().toLowerCase()}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textSecondary)),
                  Text(
                      '• ${attendance.length} ${'attendanceHistory'.tr().toLowerCase()}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textSecondary)),
                  Text('• ${'allFinancialRecords'.tr()}',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Text('cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final nav = GoRouter.of(context);
                    final repo = ref.read(studentRepositoryProvider);
                    await repo.deleteStudent(student.id);
                    ref.invalidate(studentsWithStatusProvider);
                    if (mounted) nav.go('/students');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Text('delete'.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickStudentPhoto(String studentId) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (photo == null) return;
    try {
      final repo = ref.read(studentRepositoryProvider);
      await repo.uploadStudentPhoto(studentId: studentId, photo: photo);
      ref.invalidate(studentProvider(widget.studentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('photoUpdated'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showAddCourseDialog(BuildContext context) {
    final coursesAsync = ref.read(coursesProvider);
    final enrollmentsAsync =
        ref.read(studentEnrollmentsProvider(widget.studentId));
    final courses = coursesAsync.valueOrNull ?? [];
    final enrollments = enrollmentsAsync.valueOrNull ?? [];
    final enrolledCourseIds = enrollments.map((e) => e.courseId).toSet();
    final available =
        courses.where((c) => !enrolledCourseIds.contains(c.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('noAvailableCourses'.tr())),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCourseSheet(
        studentId: widget.studentId,
        courses: available,
      ),
    );
  }

  // --- Edit Student ---

  void _showEditStudentDialog(BuildContext context, dynamic student) {
    showDialog(
      context: context,
      builder: (_) => _EditStudentDialog(
        studentId: student.id,
        initialNickName: student.nickName ?? '',
        initialFirstName: student.firstName,
        initialLastName: student.lastName,
        initialDob: student.dob ?? '',
        initialPhone: student.parentPhone ?? '',
        initialPhotoUrl: student.photoUrl,
        onSaved: () {
          ref.invalidate(studentProvider(widget.studentId));
          ref.invalidate(studentsWithStatusProvider);
        },
      ),
    );
  }

  // --- Helpers ---

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

}

// --- Enrollment Card Widget ---

class _EnrollmentCard extends ConsumerStatefulWidget {
  const _EnrollmentCard({
    required this.studentId,
    required this.enrollment,
    required this.attendanceRecords,
    this.pendingReq,
  });

  final String studentId;
  final Enrollment enrollment;
  final List<Map<String, dynamic>> attendanceRecords;
  final ApplicationChange? pendingReq;

  @override
  ConsumerState<_EnrollmentCard> createState() => _EnrollmentCardState();
}

class _EnrollmentCardState extends ConsumerState<_EnrollmentCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final enr = widget.enrollment;
    final used = enr.usedHours(widget.attendanceRecords.length);
    final purchased = enr.purchasedHours;
    final remaining = enr.remainingHours(widget.attendanceRecords.length);
    final isOverlimit = purchased > 0 && remaining <= 0;
    final isApproaching = purchased > 0 && remaining > 0 && remaining <= 2;

    final statusColor =
        isOverlimit ? AppColors.danger : (isApproaching ? const Color(0xFFF59E0B) : AppColors.success);
    final statusBg = isOverlimit
        ? AppColors.dangerLight
        : (isApproaching ? AppColors.warningLight : AppColors.successLight);
    final statusLabel = isOverlimit
        ? 'renewalNeeded'.tr()
        : (isApproaching ? 'renewalApproaching'.tr() : 'ongoing'.tr());
    final statusIcon = isOverlimit
        ? Icons.error_outline_rounded
        : (isApproaching
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 1),
            blurRadius: 4,
            color: Color(0x08000000),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          enr.courseName ?? enr.courseId,
                          style: AppTextStyles.bodyBoldBase,
                        ),
                        if (enr.schedule.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              enr.schedule.entries
                                  .map((e) =>
                                      '${e.key.substring(0, 3)} ${e.value.join(', ')}')
                                  .join('  '),
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$used/$purchased',
                        style: AppTextStyles.displaySm.copyWith(
                          fontSize: 18,
                          color: isOverlimit
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                      Text('hrs'.tr(),
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: AppTextStyles.bodyXs.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (widget.pendingReq != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 12, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${widget.pendingReq!.type == 'renewal' ? 'renewalPending'.tr() : 'addHoursPending'.tr()}'
                              ' (+${_pendingHours(widget.pendingReq!)} hrs)',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _cancelPendingRequest(
                        widget.pendingReq!.id),
                    child: Text('cancel'.tr(),
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        )),
                  ),
                ],
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: AppColors.bgMain,
                      border:
                          Border(top: BorderSide(color: AppColors.borderLight)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _actionChip(
                                    icon: Icons.add,
                                    label: 'addHours'.tr(),
                                    color: AppColors.primary,
                                    bg: widget.pendingReq != null
                                        ? AppColors.primary.withValues(alpha: 0.5)
                                        : AppColors.primary,
                                    textColor: Colors.white,
                                    onTap: widget.pendingReq != null
                                        ? null
                                        : () => _showAddHoursDialog(context),
                                  ),
                                  if (isOverlimit)
                                    _actionChip(
                                      icon: Icons.refresh_rounded,
                                      label: 'renew'.tr(),
                                      color: AppColors.warning,
                                      bg: widget.pendingReq != null
                                          ? AppColors.warning.withValues(alpha: 0.5)
                                          : AppColors.warning,
                                      textColor: Colors.white,
                                      onTap: widget.pendingReq != null
                                          ? null
                                          : () => _showAddHoursDialog(context),
                                    ),
                                  _actionChip(
                                    icon: Icons.schedule_rounded,
                                    label: 'lateCheckIn'.tr(),
                                    color: AppColors.primary,
                                    bg: AppColors.bgSurface,
                                    textColor: AppColors.primary,
                                    onTap: () => _showLateCheckInDialog(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _actionChip(
                              icon: Icons.close_rounded,
                              label: 'cancelCourse'.tr(),
                              color: AppColors.danger,
                              bg: AppColors.dangerLight,
                              textColor: AppColors.danger,
                              onTap: () => _showCancelCourseDialog(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${'attendanceHistory'.tr()} (${widget.attendanceRecords.length})',
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        if (widget.attendanceRecords.isEmpty)
                          Text('noRecords'.tr(),
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.textMuted))
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 192),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: widget.attendanceRecords.length,
                              itemBuilder: (_, idx) {
                                final a = widget.attendanceRecords[idx];
                                final ts = DateTime.tryParse(
                                    a['attended_at_ts'] as String? ?? '');
                                final timeStr = ts != null
                                    ? intl.DateFormat('E, MMM d, HH:mm', context.locale.toString()).format(ts)
                                    : '';
                                final isCancelled = a['cancelled_by'] != null;
                                final isOwner = ref.read(authProvider).valueOrNull?.role == 'owner';
                                final attId = a['id'] as String?;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(
                                          color: isCancelled ? AppColors.danger : AppColors.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          timeStr,
                                          style: AppTextStyles.bodyXs.copyWith(
                                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                                            color: isCancelled ? AppColors.textMuted : null,
                                          ),
                                        ),
                                      ),
                                      if (isCancelled)
                                        Text('cancelled'.tr(),
                                            style: AppTextStyles.bodyXs
                                                .copyWith(color: AppColors.danger, fontSize: 10)),
                                      if (!isCancelled && isOwner && attId != null)
                                        GestureDetector(
                                          onTap: () => _cancelAttendance(attId),
                                          child: const Padding(
                                            padding: EdgeInsets.only(left: 4),
                                            child: Icon(Icons.close_rounded,
                                                size: 16, color: AppColors.danger),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  int _pendingHours(ApplicationChange change) {
    final limits = change.changes['course_limits'];
    if (limits is Map) {
      final val = limits.values.firstOrNull;
      if (val is num) return val.toInt();
    }
    return 0;
  }

  Future<void> _cancelPendingRequest(String changeId) async {
    await supabase
        .from('application_changes')
        .delete()
        .eq('id', changeId);
    ref.invalidate(
        pendingChangesForStudentProvider(widget.studentId));
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color bg,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 6),
            Text(label,
                style: AppTextStyles.bodySm.copyWith(
                    color: textColor, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showAddHoursDialog(BuildContext context) {
    final enr = widget.enrollment;
    final course = ref
        .read(coursesProvider)
        .valueOrNull
        ?.where((c) => c.id == enr.courseId)
        .firstOrNull;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RenewCourseSheet(
        studentId: widget.studentId,
        courseId: enr.courseId,
        courseName: enr.courseName ?? enr.courseId,
        packages: course?.hourPackages ?? [],
      ),
    );
  }

  void _showLateCheckInDialog(BuildContext context) {
    final enr = widget.enrollment;
    showDialog(
      context: context,
      builder: (ctx) {
        int hours = 1;
        DateTime? selectedDate;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            ),
            title: Text(
              '${'lateCheckIn'.tr()} — ${enr.courseName ?? enr.courseId}',
              style: AppTextStyles.displaySm
                  .copyWith(color: AppColors.primary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('lateCheckInDesc'.tr(),
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Text(
                      selectedDate != null
                          ? '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}'
                          : 'selectDate'.tr(),
                      style: AppTextStyles.bodyBase.copyWith(
                        color: selectedDate != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('hours'.tr(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3, 4].map((h) {
                    final selected = hours == h;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            left: h == 1 ? 0 : 4,
                            right: h == 4 ? 0 : 4),
                        child: GestureDetector(
                          onTap: () =>
                              setDialogState(() => hours = h),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg),
                            ),
                            child: Center(
                              child: Text(
                                '${h}h',
                                style:
                                    AppTextStyles.bodyBoldSm.copyWith(
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg),
                        ),
                      ),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedDate == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final user =
                                  ref.read(authProvider).valueOrNull;
                              if (user == null) return;
                              final attRepo = AttendanceRepository();
                              await attRepo.checkInMultiHour(
                                studentId: widget.studentId,
                                courseId: enr.courseId,
                                approverId: user.id,
                                hours: hours,
                                date: selectedDate,
                              );
                              ref.invalidate(
                                  studentAttendanceProvider(
                                      widget.studentId));
                              ref.invalidate(
                                  studentEnrollmentsProvider(
                                      widget.studentId));
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg),
                        ),
                      ),
                      child: Text('checkIn'.tr(),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelAttendance(String attendanceId) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final attRepo = AttendanceRepository();
    await attRepo.cancelAttendance(
      rowId: attendanceId,
      userId: user.id,
    );
    ref.invalidate(studentAttendanceProvider(widget.studentId));
    ref.invalidate(studentEnrollmentsProvider(widget.studentId));
  }

  void _showCancelCourseDialog(BuildContext context) {
    final enr = widget.enrollment;
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;
    final isAdmin = user.isAdmin;
    final courseName = enr.courseName ?? enr.courseId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close_rounded,
                size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text('cancelCourse'.tr(),
                style: AppTextStyles.displaySm),
            const SizedBox(height: 8),
            Text(courseName,
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(
              isAdmin
                  ? 'confirmCancelCourseAdmin'.tr()
                  : 'confirmCancelCourseStaff'.tr(),
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Text('cancel'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (isAdmin) {
                      final repo = ref.read(studentRepositoryProvider);
                      await repo.cancelEnrollment(
                        enrollmentId: enr.id,
                        cancelledBy: user.id,
                      );
                      ref.invalidate(
                          studentEnrollmentsProvider(widget.studentId));
                    } else {
                      final studentAsync =
                          ref.read(studentProvider(widget.studentId));
                      final student = studentAsync.valueOrNull;
                      await supabase
                          .from('application_changes')
                          .insert({
                        'student_id': widget.studentId,
                        'type': 'cancel_course',
                        'status': 'pending',
                        'changes': {
                          'enrollment_id': enr.id,
                          'course_id': enr.courseId,
                          'course_name': courseName,
                        },
                        'submitted_by': user.id,
                        'nickname': student?.nickName,
                        'first_name': student?.firstName,
                        'last_name': student?.lastName,
                      });
                      await supabase.from('notifications').insert({
                        'student_id': widget.studentId,
                        'type': 'cancel_request',
                        'payload': {
                          'course_name': courseName,
                          'student_name':
                              student?.nickName ?? student?.firstName,
                        },
                      });
                      ref.invalidate(pendingChangesForStudentProvider(
                          widget.studentId));
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('requestSubmitted'.tr()),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Text(
                    isAdmin ? 'cancelCourse'.tr() : 'sendRequest'.tr(),
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── LINE Connection Card ───────────────────────────────────────

class _LineConnectionCard extends ConsumerStatefulWidget {
  const _LineConnectionCard({
    required this.studentId,
    required this.studentName,
    required this.isAdmin,
  });

  final String studentId;
  final String studentName;
  final bool isAdmin;

  @override
  ConsumerState<_LineConnectionCard> createState() =>
      _LineConnectionCardState();
}

class _LineConnectionCardState
    extends ConsumerState<_LineConnectionCard> {
  bool _linkingLine = false;
  bool _dropdownOpen = false;
  String _searchTerm = '';
  String? _selectedUnlinkedId;

  @override
  Widget build(BuildContext context) {
    final connectionAsync =
        ref.watch(studentConnectionProvider(widget.studentId));
    final unlinkedAsync = ref.watch(unlinkedUsersProvider);
    final configAsync = ref.watch(lineConfigProvider);

    final connection = connectionAsync.valueOrNull;
    final unlinkedUsers = unlinkedAsync.valueOrNull ?? [];
    final config = configAsync.valueOrNull;

    return connection != null
        ? _buildLinked(connection)
        : _buildUnlinked(unlinkedUsers, config);
  }

  Widget _buildLinked(LineConnection conn) {
    return Row(
      children: [
        conn.pictureUrl != null
            ? CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(conn.pictureUrl!),
              )
            : CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.lineGreen,
                child: Text('L',
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: Colors.white)),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(conn.displayName ?? 'LINE User',
                  style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis),
              Text('lineLinked'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.lineGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 10)),
            ],
          ),
        ),
        if (widget.isAdmin)
          GestureDetector(
            onTap: _handleUnlink,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('unlinkLine'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 10)),
            ),
          ),
      ],
    );
  }

  Widget _buildUnlinked(
      List<UnlinkedLineUser> unlinkedUsers, dynamic config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.textMuted,
              child: Text('L',
                  style: AppTextStyles.bodyBoldSm
                      .copyWith(color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('lineNotLinked'.tr(),
                  style: AppTextStyles.bodyXs
                      .copyWith(fontWeight: FontWeight.w700, color: AppColors.textMuted)),
            ),
          ],
        ),
        if (unlinkedUsers.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDropdown(unlinkedUsers),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _selectedUnlinkedId == null || _linkingLine
                  ? null
                  : () => _handleLink(unlinkedUsers, config),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedUnlinkedId != null && !_linkingLine
                      ? AppColors.lineGreen
                      : AppColors.lineGreen.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                    _linkingLine ? 'linking'.tr() : 'linkLine'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Text('noUnlinkedAccounts'.tr(),
                style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.textMuted, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildDropdown(List<UnlinkedLineUser> users) {
    final selected = _selectedUnlinkedId != null
        ? users
            .where((u) => u.lineUserId == _selectedUnlinkedId)
            .firstOrNull
        : null;

    final filtered = _searchTerm.isEmpty
        ? users
        : users.where((u) =>
            u.displayName
                ?.toLowerCase()
                .contains(_searchTerm.toLowerCase()) ??
            false).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.displayName ?? 'selectStudent'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(
                        color: selected != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more_rounded,
                    size: 12, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (_dropdownOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 192),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 8,
                    offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) =>
                        setState(() => _searchTerm = v),
                    decoration: InputDecoration(
                      hintText: 'searchPlaceholder'.tr(),
                      hintStyle: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                    ),
                    style: AppTextStyles.bodyXs,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    children: filtered.map((u) {
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedUnlinkedId = u.lineUserId;
                          _dropdownOpen = false;
                          _searchTerm = '';
                        }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              u.pictureUrl != null
                                  ? CircleAvatar(
                                      radius: 12,
                                      backgroundImage: NetworkImage(
                                          u.pictureUrl!),
                                    )
                                  : CircleAvatar(
                                      radius: 12,
                                      backgroundColor:
                                          const Color(0xFFB0BEC5),
                                      child: Text(
                                        (u.displayName ?? '?')
                                            .characters
                                            .first
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w700),
                                      ),
                                    ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    u.displayName ?? 'Unknown',
                                    style: AppTextStyles.bodyXs
                                        .copyWith(
                                            fontWeight:
                                                FontWeight.w600),
                                    overflow:
                                        TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleUnlink() async {
    await ref
        .read(messagingRepositoryProvider)
        .unlinkLineAccount(widget.studentId);
    ref.invalidate(studentConnectionProvider(widget.studentId));
    ref.invalidate(lineConnectionsProvider);
    ref.invalidate(unlinkedUsersProvider);
  }

  Future<void> _handleLink(
      List<UnlinkedLineUser> unlinkedUsers, dynamic config) async {
    if (_selectedUnlinkedId == null) return;
    setState(() => _linkingLine = true);
    try {
      final u = unlinkedUsers
          .where((x) => x.lineUserId == _selectedUnlinkedId)
          .firstOrNull;
      final name = widget.studentName;

      String? welcomeMessage;
      if (config is LineConfig && config.autoLinkNotify) {
        final tpl = config.messageTemplates.linkWelcome.isNotEmpty
            ? config.messageTemplates.linkWelcome
            : 'Your LINE account has been linked to {{name}}!\n\n'
                'บัญชี LINE ของคุณเชื่อมต่อกับ {{name}} เรียบร้อยแล้ว!';
        welcomeMessage = tpl.replaceAll('{{name}}', name);
      }

      await ref.read(messagingRepositoryProvider).linkLineAccount(
            studentId: widget.studentId,
            lineUserId: _selectedUnlinkedId!,
            displayName: u?.displayName,
            pictureUrl: u?.pictureUrl,
            sendWelcome: welcomeMessage != null,
            welcomeMessage: welcomeMessage,
          );

      _selectedUnlinkedId = null;
      ref.invalidate(studentConnectionProvider(widget.studentId));
      ref.invalidate(lineConnectionsProvider);
      ref.invalidate(unlinkedUsersProvider);
    } finally {
      if (mounted) setState(() => _linkingLine = false);
    }
  }
}

// ---------------------------------------------------------------------------
// Renew / Add Hours Bottom Sheet
// ---------------------------------------------------------------------------
class _RenewCourseSheet extends StatefulWidget {
  const _RenewCourseSheet({
    required this.studentId,
    required this.courseId,
    required this.courseName,
    required this.packages,
  });
  final String studentId;
  final String courseId;
  final String courseName;
  final List<HourPackage> packages;

  @override
  State<_RenewCourseSheet> createState() => _RenewCourseSheetState();
}

class _RenewCourseSheetState extends State<_RenewCourseSheet> {
  int _selectedHours = 0;
  XFile? _receipt;
  String? _error;
  bool _saving = false;

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _receipt = file);
  }

  Future<void> _submit() async {
    if (_selectedHours <= 0) {
      setState(() => _error = 'selectPackage'.tr());
      return;
    }
    if (_receipt == null) {
      setState(() => _error = 'receiptRequiredError'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ApplicationRepository();
      final urls = await repo.uploadReceipts([_receipt!]);
      await repo.submitChangeRequest(
        studentId: widget.studentId,
        type: 'renewal',
        changes: {
          'course_limits': {widget.courseId: _selectedHours},
          'receipts': urls,
        },
        receiptUrls: urls,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('requestSubmitted'.tr()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${'addHours'.tr()} — ${widget.courseName}',
                    style: AppTextStyles.displaySm
                        .copyWith(color: AppColors.primary),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('selectPackage'.tr(),
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (widget.packages.isNotEmpty)
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: widget.packages.map((pkg) {
                  final selected = _selectedHours == pkg.hours;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedHours = pkg.hours;
                      _error = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.bgSurface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.borderLight,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '+${pkg.hours} ${'hrs'.tr()}',
                            style: AppTextStyles.bodyBoldBase.copyWith(
                              color:
                                  selected ? Colors.white : AppColors.primary,
                            ),
                          ),
                          Text(
                            '฿${intl.NumberFormat('#,###').format(pkg.price)}',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              TextFormField(
                decoration: InputDecoration(labelText: 'hours'.tr()),
                keyboardType: TextInputType.number,
                onChanged: (v) =>
                    setState(() => _selectedHours = int.tryParse(v) ?? 0),
              ),
            const SizedBox(height: 20),
            Text(
              '${'uploadReceipt'.tr()} *',
              style: AppTextStyles.bodyBoldSm
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: _receipt != null
                        ? AppColors.success
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _receipt != null
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: _receipt != null
                          ? AppColors.success
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _receipt != null
                          ? _receipt!.name
                          : 'tapToUpload'.tr(),
                      style: AppTextStyles.bodySm.copyWith(
                        color: _receipt != null
                            ? AppColors.success
                            : AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Text(_error!,
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.danger)),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('submit'.tr(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Course Bottom Sheet (with day/time selection + package grid + receipt)
// ---------------------------------------------------------------------------
class _AddCourseSheet extends StatefulWidget {
  const _AddCourseSheet({
    required this.studentId,
    required this.courses,
  });
  final String studentId;
  final List<Course> courses;

  @override
  State<_AddCourseSheet> createState() => _AddCourseSheetState();
}

class _AddCourseSheetState extends State<_AddCourseSheet> {
  String? _selectedCourseId;
  Map<String, List<String>> _selectedDays = {};
  int _selectedHours = 0;
  XFile? _receipt;
  String? _error;
  bool _saving = false;

  Course? get _selectedCourse => _selectedCourseId != null
      ? widget.courses
          .where((c) => c.id == _selectedCourseId)
          .firstOrNull
      : null;

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _receipt = file);
  }

  void _toggleTime(String day, String time) {
    setState(() {
      final current = List<String>.from(_selectedDays[day] ?? []);
      if (current.contains(time)) {
        current.remove(time);
      } else {
        current.add(time);
      }
      _selectedDays = Map.from(_selectedDays);
      if (current.isEmpty) {
        _selectedDays.remove(day);
      } else {
        _selectedDays[day] = current;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_selectedCourseId == null) {
      setState(() => _error = 'pleaseSelectCourse'.tr());
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _error = 'pleaseSelectDay'.tr());
      return;
    }
    if (_selectedHours <= 0) {
      setState(() => _error = 'selectPackage'.tr());
      return;
    }
    if (_receipt == null) {
      setState(() => _error = 'receiptRequiredError'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ApplicationRepository();
      final urls = await repo.uploadReceipts([_receipt!]);
      await repo.submitChangeRequest(
        studentId: widget.studentId,
        type: 'edit',
        changes: {
          'course_changes': {_selectedCourseId!: _selectedDays},
          'course_limits': {_selectedCourseId!: _selectedHours},
          'receipts': urls,
        },
        receiptUrls: urls,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('requestSubmitted'.tr()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = _selectedCourse;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text('addNewCourse'.tr(),
                          style: AppTextStyles.displaySm
                              .copyWith(color: AppColors.primary)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course selector
                  Text('selectCourse'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      hintText: 'chooseCourse'.tr(),
                      hintStyle: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textMuted),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    items: widget.courses
                        .map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedCourseId = v;
                      _selectedDays = {};
                      _selectedHours = 0;
                      _error = null;
                    }),
                  ),

                  // Day/time picker
                  if (course != null && course.weekdays.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('selectDay'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    ...course.weekdays.map((day) {
                      final timesForDay = course.times[day] ?? [];
                      final selectedTimes = _selectedDays[day] ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedTimes.isNotEmpty
                              ? AppColors.primary.withValues(alpha: 0.06)
                              : AppColors.bgSurface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: selectedTimes.isNotEmpty
                                ? AppColors.primary
                                : AppColors.borderLight,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(day,
                                style: AppTextStyles.bodyBoldSm
                                    .copyWith(color: AppColors.textPrimary)),
                            if (timesForDay.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: timesForDay.map((time) {
                                  final isOn = selectedTimes.contains(time);
                                  return GestureDetector(
                                    onTap: () => _toggleTime(day, time),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isOn
                                            ? AppColors.primary
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusSm),
                                        border: Border.all(
                                            color: AppColors.primary),
                                      ),
                                      child: Text(
                                        time,
                                        style:
                                            AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700,
                                          color: isOn
                                              ? Colors.white
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],

                  // Package grid
                  if (course != null &&
                      course.hourPackages.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('selectPackage'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.2,
                      children: course.hourPackages.map((pkg) {
                        final selected = _selectedHours == pkg.hours;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedHours = pkg.hours;
                            _error = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.bgSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${pkg.hours} ${'hrs'.tr()}',
                                  style: AppTextStyles.bodyBoldBase.copyWith(
                                    color: selected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                                Text(
                                  '฿${intl.NumberFormat('#,###').format(pkg.price)}',
                                  style: AppTextStyles.bodyXs.copyWith(
                                    color: selected
                                        ? Colors.white
                                            .withValues(alpha: 0.8)
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Receipt upload
                  const SizedBox(height: 20),
                  Text(
                    '${'uploadReceipt'.tr()} *',
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickReceipt,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: _receipt != null
                              ? AppColors.success
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _receipt != null
                                ? Icons.check_circle_rounded
                                : Icons.upload_file_rounded,
                            color: _receipt != null
                                ? AppColors.success
                                : AppColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _receipt != null
                                  ? _receipt!.name
                                  : 'tapToUpload'.tr(),
                              style: AppTextStyles.bodySm.copyWith(
                                color: _receipt != null
                                    ? AppColors.success
                                    : AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(_error!,
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.danger)),
                    ),
                  ],

                  // Buttons
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg),
                            ),
                          ),
                          child: Text('cancel'.tr()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusLg),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white),
                                )
                              : Text('submit'.tr(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Student Dialog
// ---------------------------------------------------------------------------
class _EditStudentDialog extends StatefulWidget {
  const _EditStudentDialog({
    required this.studentId,
    required this.initialNickName,
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialDob,
    required this.initialPhone,
    this.initialPhotoUrl,
    required this.onSaved,
  });

  final String studentId;
  final String initialNickName;
  final String initialFirstName;
  final String initialLastName;
  final String initialDob;
  final String initialPhone;
  final String? initialPhotoUrl;
  final VoidCallback onSaved;

  @override
  State<_EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends State<_EditStudentDialog> {
  late final TextEditingController _nickCtrl;
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _phoneCtrl;
  XFile? _newPhoto;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nickCtrl = TextEditingController(text: widget.initialNickName);
    _firstCtrl = TextEditingController(text: widget.initialFirstName);
    _lastCtrl = TextEditingController(text: widget.initialLastName);
    _dobCtrl = TextEditingController(text: widget.initialDob);
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file != null) setState(() => _newPhoto = file);
  }

  bool get _canSave =>
      _nickCtrl.text.trim().isNotEmpty &&
      _firstCtrl.text.trim().isNotEmpty &&
      _lastCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      if (_newPhoto != null) {
        final bytes = await _newPhoto!.readAsBytes();
        final ext = _newPhoto!.name.split('.').last;
        final path = '${widget.studentId}.$ext';
        await supabase.storage.from('student-photos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
        final publicUrl =
            supabase.storage.from('student-photos').getPublicUrl(path);
        await supabase.from('students').update({
          'photo_url':
              '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}',
        }).eq('id', widget.studentId);
      }

      await supabase.from('students').update({
        'nick_name': _nickCtrl.text.trim().isEmpty
            ? null
            : _nickCtrl.text.trim(),
        'first_name': _firstCtrl.text.trim(),
        'last_name': _lastCtrl.text.trim(),
        'dob': _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
        'parent_phone': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
      }).eq('id', widget.studentId);

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('studentUpdated'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('editStudent'.tr(),
                      style: AppTextStyles.displaySm
                          .copyWith(color: AppColors.primary)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.border,
                            style: BorderStyle.solid),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _newPhoto != null
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 28)
                          : widget.initialPhotoUrl != null
                              ? Image.network(widget.initialPhotoUrl!,
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.camera_alt_rounded,
                                          color: AppColors.textMuted))
                              : const Icon(Icons.camera_alt_rounded,
                                  color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('changePhoto'.tr(),
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 12),
              _field('nickName'.tr(), _nickCtrl),
              _field('firstName'.tr(), _firstCtrl, required: true),
              _field('lastName'.tr(), _lastCtrl, required: true),
              _dateField('dob'.tr(), _dobCtrl),
              _field('phone'.tr(), _phoneCtrl,
                  required: true,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                        ),
                      ),
                      child: Text('cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _saving || !_canSave ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('save'.tr(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false,
      TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label${required ? ' *' : ''}',
              style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            style: AppTextStyles.bodyBase,
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.bodyXs.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: ctrl.text.isNotEmpty
                    ? DateTime.tryParse(ctrl.text) ?? DateTime(2015)
                    : DateTime(2015),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                ctrl.text = picked.toIso8601String().substring(0, 10);
                setState(() {});
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today_rounded,
                      size: 18),
                ),
                style: AppTextStyles.bodyBase,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QrDialog extends StatefulWidget {
  const _QrDialog({required this.studentId, required this.name});

  final String studentId;
  final String name;

  @override
  State<_QrDialog> createState() => _QrDialogState();
}

class _QrDialogState extends State<_QrDialog> {
  final _qrKey = GlobalKey();
  bool _busy = false;

  Future<File?> _captureQrToFile() async {
    final boundary =
        _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/qr_${widget.name.replaceAll(RegExp(r'[^\w]'), '_')}.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  Future<void> _handleDownload() async {
    setState(() => _busy = true);
    try {
      final file = await _captureQrToFile();
      if (file == null || !mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${widget.name} - QR Code',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePrint() async {
    setState(() => _busy = true);
    try {
      final file = await _captureQrToFile();
      if (file == null || !mounted) return;

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: '${widget.name} - QR Code',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.name, style: AppTextStyles.displaySm),
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: widget.studentId,
                  version: QrVersions.auto,
                  size: 200,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'scanForCheckIn'.tr(),
              style:
                  AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _handleDownload,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text('download'.tr(),
                        style: AppTextStyles.bodyBoldSm),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _handlePrint,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: Text('print'.tr(),
                        style: AppTextStyles.bodyBoldSm),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
