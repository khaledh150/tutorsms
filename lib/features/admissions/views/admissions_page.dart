import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../courses/providers/course_provider.dart';
import '../../students/providers/student_provider.dart';
import '../models/application_change_model.dart';
import '../models/application_model.dart';
import '../providers/application_provider.dart';

class AdmissionsPage extends ConsumerWidget {
  const AdmissionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(pendingApplicationsProvider);
    final changesAsync = ref.watch(pendingChangesProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final studentsAsync = ref.watch(allStudentsProvider);

    final apps = appsAsync.valueOrNull ?? [];
    final changes = changesAsync.valueOrNull ?? [];
    final courses = coursesAsync.valueOrNull ?? [];
    final students = studentsAsync.valueOrNull ?? [];
    final totalPending = apps.length + changes.length;
    final isLoading = appsAsync.isLoading || changesAsync.isLoading;

    final courseMap = <String, String>{
      for (final c in courses) c.id: c.name,
    };
    final studentMap = <String, String>{
      for (final s in students) s.id: s.displayName,
    };

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: isLoading
            ? const Center(
                child: CircularProgressIndicator(strokeWidth: 2))
            : RefreshIndicator(
                onRefresh: () async {
                  ref.read(pendingApplicationsProvider.notifier).refresh();
                  ref.read(pendingChangesProvider.notifier).refresh();
                },
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text('approvals'.tr(),
                                style: AppTextStyles.displaySm),
                            if (totalPending > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: Text(
                                  '$totalPending',
                                  style: AppTextStyles.bodyBoldSm
                                      .copyWith(color: Colors.white),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (apps.isNotEmpty)
                      _ApplicationsSection(
                          applications: apps, courseMap: courseMap),
                    if (changes.isNotEmpty)
                      _ChangesSection(
                          changes: changes,
                          courseMap: courseMap,
                          studentMap: studentMap),
                    if (totalPending == 0)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_turned_in_rounded,
                                  size: 64,
                                  color: AppColors.primaryLight),
                              const SizedBox(height: 16),
                              Text(
                                'allCaughtUpApprovals'.tr(),
                                style: AppTextStyles.bodySemiBoldBase
                                    .copyWith(
                                        color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

class _ApplicationsSection extends ConsumerWidget {
  const _ApplicationsSection({
    required this.applications,
    required this.courseMap,
  });
  final List<Application> applications;
  final Map<String, String> courseMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Row(
              children: [
                const Icon(Icons.person_add_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${'newApplications'.tr()} (${applications.length})',
                  style: AppTextStyles.bodyBoldBase
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          for (final app in applications)
            _ApplicationCard(
              application: app,
              courseMap: courseMap,
              onApprove: () =>
                  _confirmApprove(context, ref, app.id),
              onReject: () =>
                  _confirmReject(context, ref, app.id),
            ),
        ]),
      ),
    );
  }

  void _confirmApprove(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr(), style: AppTextStyles.displaySm),
        content: Text(
          'approveConfirm'.tr(namedArgs: {'count': '1'}),
          style: AppTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(applicationRepositoryProvider);
              await repo.approveApplications([id]);
              ref
                  .read(pendingApplicationsProvider.notifier)
                  .refresh();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.success),
            child: Text('approve'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr(), style: AppTextStyles.displaySm),
        content: Text(
          'rejectConfirm'.tr(namedArgs: {'count': '1'}),
          style: AppTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(applicationRepositoryProvider);
              await repo.rejectApplications([id]);
              ref
                  .read(pendingApplicationsProvider.notifier)
                  .refresh();
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('reject'.tr()),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.courseMap,
    required this.onApprove,
    required this.onReject,
  });

  final Application application;
  final Map<String, String> courseMap;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final receipts = application.paymentReceiptUrls;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 4,
              color: Color(0x08000000)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        application.initial,
                        style: AppTextStyles.bodyBoldBase
                            .copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(application.displayName,
                              style: AppTextStyles.bodyBoldSm),
                          Text(
                            [
                              if (application.parentPhone != null)
                                'phonePrefixed'.tr(namedArgs: {
                                  'phone': application.parentPhone!,
                                }),
                              if (application.dob != null)
                                'dobPrefixed'.tr(namedArgs: {
                                  'dob': _formatDate(application.dob!),
                                }),
                            ].join(' | '),
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        'newStudentBadge'.tr(),
                        style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._buildCourseEntries(),
                if (receipts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ReceiptRow(urls: receipts),
                ],
                const SizedBox(height: 6),
                Text(
                  'submittedDate'.tr(namedArgs: {
                    'date': _formatDateTime(application.createdAt),
                  }),
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onApprove,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 20, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('approve'.tr(),
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderLight),
              Expanded(
                child: InkWell(
                  onTap: onReject,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text('reject'.tr(),
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCourseEntries() {
    final courses = application.courses;
    if (courses.isEmpty) return [];
    return courses.entries.map((entry) {
      final courseId = entry.key;
      final days = entry.value;
      final hours = application.courseLimits[courseId] ?? 0;
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.bgMain,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    courseMap[courseId] ?? courseId,
                    style: AppTextStyles.bodySemiBoldSm
                        .copyWith(color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    '$hours ${'hrs'.tr()}',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (days is Map) ...[
              for (final dayEntry in days.entries)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${dayEntry.key}: ${(dayEntry.value is List ? (dayEntry.value as List).join(', ') : '')}',
                    style: AppTextStyles.bodyXs
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      );
    }).toList();
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _formatDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ChangesSection extends ConsumerWidget {
  const _ChangesSection({
    required this.changes,
    required this.courseMap,
    required this.studentMap,
  });
  final List<ApplicationChange> changes;
  final Map<String, String> courseMap;
  final Map<String, String> studentMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 16),
            child: Row(
              children: [
                const Icon(Icons.sync_rounded,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  '${'renewals'.tr()} & ${'courseChanges'.tr()} (${changes.length})',
                  style: AppTextStyles.bodyBoldBase
                      .copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
          for (final ch in changes)
            _ChangeCard(
              change: ch,
              courseMap: courseMap,
              studentName: ch.displayName.isNotEmpty
                  ? ch.displayName
                  : studentMap[ch.studentId] ?? 'student'.tr(),
              onApprove: () =>
                  _confirmApprove(context, ref, ch.id),
              onReject: () =>
                  _confirmReject(context, ref, ch.id),
            ),
        ]),
      ),
    );
  }

  void _confirmApprove(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr(), style: AppTextStyles.displaySm),
        content: Text(
          'approveConfirm'.tr(namedArgs: {'count': '1'}),
          style: AppTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(applicationRepositoryProvider);
              await repo.approveChanges([id]);
              ref
                  .read(pendingChangesProvider.notifier)
                  .refresh();
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.success),
            child: Text('approve'.tr()),
          ),
        ],
      ),
    );
  }

  void _confirmReject(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr(), style: AppTextStyles.displaySm),
        content: Text(
          'rejectConfirm'.tr(namedArgs: {'count': '1'}),
          style: AppTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final repo = ref.read(applicationRepositoryProvider);
              await repo.rejectChanges([id]);
              ref.read(pendingChangesProvider.notifier).refresh();
            },
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('reject'.tr()),
          ),
        ],
      ),
    );
  }
}

class _ChangeCard extends StatelessWidget {
  const _ChangeCard({
    required this.change,
    required this.courseMap,
    required this.studentName,
    required this.onApprove,
    required this.onReject,
  });

  final ApplicationChange change;
  final Map<String, String> courseMap;
  final String studentName;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  IconData get _typeIcon {
    switch (change.type) {
      case 'edit':
        return Icons.edit_note_rounded;
      case 'renewal':
        return Icons.sync_rounded;
      case 'cancel':
        return Icons.cancel_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Color get _typeColor {
    switch (change.type) {
      case 'edit':
        return AppColors.info;
      case 'renewal':
        return AppColors.warning;
      case 'cancel':
        return AppColors.danger;
      default:
        return AppColors.info;
    }
  }

  Color get _typeBg {
    switch (change.type) {
      case 'edit':
        return AppColors.infoLight;
      case 'renewal':
        return AppColors.warningLight;
      case 'cancel':
        return AppColors.dangerLight;
      default:
        return AppColors.infoLight;
    }
  }

  String get _typeLabel {
    switch (change.type) {
      case 'edit':
        return 'addCourseType'.tr();
      case 'renewal':
        return 'renewalType'.tr();
      case 'cancel':
        return 'cancellationType'.tr();
      default:
        return change.type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipts = change.allReceipts;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 4,
              color: Color(0x08000000)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _typeBg,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      alignment: Alignment.center,
                      child: Icon(_typeIcon, size: 20, color: _typeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: AppTextStyles.bodyBoldSm,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _typeBg,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusFull),
                            ),
                            child: Text(
                              _typeLabel,
                              style: AppTextStyles.bodyXs.copyWith(
                                color: _typeColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._buildChangeDetails(),
                if (receipts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _ReceiptRow(urls: receipts),
                ],
                if (receipts.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_outlined,
                            size: 14, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'noReceiptAttached'.tr(),
                          style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'submittedDate'.tr(namedArgs: {
                    'date': _formatDateTime(change.createdAt),
                  }),
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onApprove,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 20, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('approve'.tr(),
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: AppColors.success)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                  width: 1, height: 40, color: AppColors.borderLight),
              Expanded(
                child: InkWell(
                  onTap: onReject,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded,
                            size: 20, color: AppColors.danger),
                        const SizedBox(width: 4),
                        Text('reject'.tr(),
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChangeDetails() {
    final details = <Widget>[];
    final changes = change.changes;

    if (change.type == 'edit' && changes['course_changes'] is Map) {
      final courseChanges = changes['course_changes'] as Map;
      for (final entry in courseChanges.entries) {
        final courseId = entry.key as String;
        final days = entry.value;
        final hours =
            (changes['course_limits'] is Map)
                ? ((changes['course_limits'] as Map)[courseId] as num?)
                        ?.toInt() ??
                    0
                : 0;
        details.add(_changeDetailTile(courseId, days, hours));
      }
    } else if (change.type == 'renewal' &&
        changes['course_limits'] is Map) {
      final limits = changes['course_limits'] as Map;
      for (final entry in limits.entries) {
        final courseId = entry.key as String;
        final hours = (entry.value as num?)?.toInt() ?? 0;
        details.add(_changeDetailTile(courseId, null, hours));
      }
    }

    return details;
  }

  Widget _changeDetailTile(
      String courseId, dynamic days, int hours) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.bgMain,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  courseMap[courseId] ?? courseId,
                  style: AppTextStyles.bodySemiBoldSm
                      .copyWith(color: AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  '$hours ${'hrs'.tr()}',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (days is Map)
            for (final dayEntry in days.entries)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${dayEntry.key}: ${dayEntry.value is List ? (dayEntry.value as List).join(', ') : ''}',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
        ],
      ),
    );
  }

  String _formatDateTime(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final url = urls[index];
          final isImage =
              RegExp(r'\.(jpg|jpeg|png|gif|webp)', caseSensitive: false)
                  .hasMatch(url);
          return GestureDetector(
            onTap: () => _showReceiptDialog(context, url),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppColors.border),
                color: AppColors.bgMain,
              ),
              clipBehavior: Clip.antiAlias,
              child: isImage
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      cacheWidth: 128,
                      cacheHeight: 128,
                      errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textMuted),
                    )
                  : const Icon(Icons.description_rounded,
                      color: AppColors.textMuted),
            ),
          );
        },
      ),
    );
  }

  void _showReceiptDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url,
              errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.broken_image_rounded,
                        size: 48, color: AppColors.textMuted),
                  )),
        ),
      ),
    );
  }
}
