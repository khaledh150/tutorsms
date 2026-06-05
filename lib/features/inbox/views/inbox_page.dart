import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../admissions/models/application_change_model.dart';
import '../../admissions/models/application_model.dart';
import '../../admissions/providers/application_provider.dart';
import '../providers/inbox_provider.dart';

class InboxPage extends ConsumerWidget {
  const InboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingApps = ref.watch(pendingApplicationsProvider);
    final pendingChanges = ref.watch(pendingChangesProvider);
    final totalPending = ref.watch(totalPendingProvider);
    final courseMap = ref.watch(courseNameMapProvider);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pendingApplicationsProvider);
            ref.invalidate(pendingChangesProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
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
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text('$totalPending',
                              style: AppTextStyles.bodySm.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const Spacer(),
                      if (totalPending > 1)
                        SizedBox(
                          height: 32,
                          child: FilledButton.icon(
                            onPressed: () => _approveAll(context, ref, pendingApps.valueOrNull ?? [], pendingChanges.valueOrNull ?? []),
                            icon: const Icon(Icons.done_all_rounded, size: 16),
                            label: Text('approveAll'.tr()),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              textStyle: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // New Applications
              ...pendingApps.when(
                data: (apps) => apps.isEmpty
                    ? <Widget>[]
                    : [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 8, 20, 8),
                            child: Row(
                              children: [
                                Icon(Icons.person_add_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${'newApplications'.tr()} (${apps.length})',
                                  style: AppTextStyles.bodyBoldSm
                                      .copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.separated(
                            itemCount: apps.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ApplicationCard(
                              app: apps[i],
                              courseMap: courseMap,
                            ),
                          ),
                        ),
                      ],
                loading: () => [
                  const SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )),
                  ),
                ],
                error: (e, _) => [
                  SliverToBoxAdapter(
                    child: Center(
                        child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('$e',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.danger)),
                    )),
                  ),
                ],
              ),

              // Pending Changes
              ...pendingChanges.when(
                data: (changes) => changes.isEmpty
                    ? <Widget>[]
                    : [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 8),
                            child: Row(
                              children: [
                                Icon(Icons.sync_rounded,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${'renewals'.tr()} & ${'courseChanges'.tr()} (${changes.length})',
                                  style: AppTextStyles.bodyBoldSm
                                      .copyWith(color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList.separated(
                            itemCount: changes.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _ChangeCard(
                              change: changes[i],
                              courseMap: courseMap,
                            ),
                          ),
                        ),
                      ],
                loading: () => const [],
                error: (_, _) => const [],
              ),

              // Empty state
              if (totalPending == 0 &&
                  !pendingApps.isLoading &&
                  !pendingChanges.isLoading)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: '✅',
                    title: 'noPendingItems'.tr(),
                    subtitle: 'noPendingHint'.tr(),
                    iconColor: AppColors.success,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
    );
  }
}

class _ApplicationCard extends ConsumerWidget {
  const _ApplicationCard({required this.app, required this.courseMap});
  final Application app;
  final Map<String, String> courseMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary,
                      child: Text(app.initial,
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(app.displayName,
                              style: AppTextStyles.bodyBoldSm),
                          if (app.parentPhone != null)
                            Text(app.parentPhone!,
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text('newStudentBadge'.tr(),
                          style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Courses
                ...app.courses.entries.map((entry) {
                  final courseName = courseMap[entry.key] ?? entry.key;
                  final hours = app.courseLimits[entry.key] ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgMain,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(courseName,
                              style: AppTextStyles.bodySemiBoldSm
                                  .copyWith(color: AppColors.primary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusFull),
                          ),
                          child: Text('$hours hrs',
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                }),

                // Receipts
                if (app.paymentReceiptUrls.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: app.paymentReceiptUrls.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _showReceiptViewer(
                              context, app.paymentReceiptUrls, i),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm),
                              color: AppColors.bgMain,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm),
                              child: Image.network(
                                app.paymentReceiptUrls[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                    Icons.description_rounded,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                Text(
                  '${'submitted'.tr()}: ${_formatDate(app.createdAt)}',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmAction(
                      context,
                      ref,
                      message: '${'approve'.tr()} ${app.displayName}?\n${app.courses.keys.map((k) => courseMap[k] ?? k).join(', ')}',
                      action: () async {
                        await ref
                            .read(applicationRepositoryProvider)
                            .approveApplications([app.id]);
                        ref.invalidate(pendingApplicationsProvider);
                        ref.invalidate(pendingReviewCountProvider);
                      },
                    ),
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.success),
                    label: Text('approve'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.success)),
                    style: TextButton.styleFrom(
                        minimumSize:
                            const Size(0, AppTheme.touchComfortable)),
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.borderLight),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmAction(
                      context,
                      ref,
                      message: '${'reject'.tr()} ${app.displayName}?',
                      isReject: true,
                      action: () async {
                        await ref
                            .read(applicationRepositoryProvider)
                            .rejectApplications([app.id]);
                        ref.invalidate(pendingApplicationsProvider);
                        ref.invalidate(pendingReviewCountProvider);
                      },
                    ),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.danger),
                    label: Text('reject'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.danger)),
                    style: TextButton.styleFrom(
                        minimumSize:
                            const Size(0, AppTheme.touchComfortable)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeCard extends ConsumerWidget {
  const _ChangeCard({required this.change, required this.courseMap});
  final ApplicationChange change;
  final Map<String, String> courseMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentNames =
        ref.watch(studentNameMapProvider).valueOrNull ?? {};
    final studentName = change.displayName.isNotEmpty
        ? change.displayName
        : (studentNames[change.studentId] ?? 'Unknown Student');

    final typeConfig = _getTypeConfig(change.type);
    final receipts = change.allReceipts;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: typeConfig.bg,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Icon(typeConfig.icon,
                          size: 20, color: typeConfig.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => context.go('/students/${change.studentId}'),
                            child: Text(studentName,
                                style: AppTextStyles.bodyBoldSm.copyWith(
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline)),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeConfig.bg,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: Text(typeConfig.label,
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: typeConfig.color,
                                        fontWeight: FontWeight.w700)),
                              ),
                              if (change.submittedBy != null) ...[
                                const SizedBox(width: 6),
                                Text('by ${_resolveUsername(ref, change.submittedBy!)}',
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.textMuted, fontSize: 10)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Change details
                ..._buildChangeDetails(),

                // Receipts
                if (receipts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: receipts.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _showReceiptViewer(
                              context, receipts, i),
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm),
                              color: AppColors.bgMain,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusSm),
                              child: Image.network(
                                receipts[i],
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                    Icons.description_rounded,
                                    color: AppColors.textMuted),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (receipts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
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
                              size: 16, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text('noReceiptAttached'.tr(),
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: AppColors.warning)),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),
                Text(
                  '${'submitted'.tr()}: ${_formatDate(change.createdAt)}',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppColors.borderLight)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmAction(
                      context,
                      ref,
                      message: '${'approve'.tr()} ${typeConfig.label} — $studentName?',
                      action: () async {
                        await ref
                            .read(applicationRepositoryProvider)
                            .approveChanges([change.id]);
                        ref.invalidate(pendingChangesProvider);
                        ref.invalidate(pendingReviewCountProvider);
                      },
                    ),
                    icon: const Icon(Icons.check_rounded,
                        color: AppColors.success),
                    label: Text('approve'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.success)),
                    style: TextButton.styleFrom(
                        minimumSize:
                            const Size(0, AppTheme.touchComfortable)),
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.borderLight),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _confirmAction(
                      context,
                      ref,
                      message: '${'reject'.tr()} ${typeConfig.label} — $studentName?',
                      isReject: true,
                      action: () async {
                        await ref
                            .read(applicationRepositoryProvider)
                            .rejectChanges([change.id]);
                        ref.invalidate(pendingChangesProvider);
                        ref.invalidate(pendingReviewCountProvider);
                      },
                    ),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.danger),
                    label: Text('reject'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.danger)),
                    style: TextButton.styleFrom(
                        minimumSize:
                            const Size(0, AppTheme.touchComfortable)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChangeDetails() {
    final details = <Widget>[];
    final changes = change.changes;

    if (change.type == 'renewal' && changes['course_limits'] is Map) {
      final limits = changes['course_limits'] as Map;
      for (final entry in limits.entries) {
        final cid = entry.key as String;
        final hrs = entry.value;
        details.add(
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgMain,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(courseMap[cid] ?? cid,
                      style: AppTextStyles.bodySemiBoldSm
                          .copyWith(color: AppColors.primary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text('$hrs hrs',
                      style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      }
    }
    return details;
  }

  _TypeConfig _getTypeConfig(String type) {
    switch (type) {
      case 'renewal':
        return _TypeConfig(
          icon: Icons.sync_rounded,
          label: 'renewalType'.tr(),
          bg: AppColors.warningLight,
          color: AppColors.warning,
        );
      case 'cancel':
        return _TypeConfig(
          icon: Icons.close_rounded,
          label: 'cancellationType'.tr(),
          bg: AppColors.dangerLight,
          color: AppColors.danger,
        );
      default:
        return _TypeConfig(
          icon: Icons.edit_rounded,
          label: 'addCourseType'.tr(),
          bg: AppColors.infoLight,
          color: AppColors.info,
        );
    }
  }
}

class _TypeConfig {
  final IconData icon;
  final String label;
  final Color bg;
  final Color color;
  const _TypeConfig(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.color});
}

void _confirmAction(
  BuildContext context,
  WidgetRef ref, {
  required String message,
  required Future<void> Function() action,
  bool isReject = false,
}) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isReject ? Icons.close_rounded : Icons.check_circle_rounded,
            size: 48,
            color: isReject ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodySm, textAlign: TextAlign.center),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                ),
                child: Text('cancel'.tr()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await action();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isReject ? AppColors.danger : AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                ),
                child: Text(isReject ? 'reject'.tr() : 'approve'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

void _approveAll(
  BuildContext context,
  WidgetRef ref,
  List<Application> apps,
  List<ApplicationChange> changes,
) {
  final appCount = apps.length;
  final changeCount = changes.length;
  final total = appCount + changeCount;

  _confirmAction(
    context,
    ref,
    message: '${'approve'.tr()} $total ${'items'.tr()}?',
    action: () async {
      final repo = ref.read(applicationRepositoryProvider);
      if (appCount > 0) {
        await repo.approveApplications(apps.map((a) => a.id).toList());
      }
      if (changeCount > 0) {
        await repo.approveChanges(changes.map((c) => c.id).toList());
      }
      ref.invalidate(pendingApplicationsProvider);
      ref.invalidate(pendingChangesProvider);
      ref.invalidate(pendingReviewCountProvider);
    },
  );
}

String _resolveUsername(WidgetRef ref, String userId) {
  final map = ref.watch(staffNameMapProvider).valueOrNull ?? {};
  return map[userId] ?? '';
}

String _formatDate(String iso) {
  try {
    final utc = DateTime.parse(iso);
    final d = utc.toLocal();
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return iso;
  }
}

void _showReceiptViewer(BuildContext context, List<String> urls, int initial) {
  showDialog(
    context: context,
    builder: (ctx) {
      final controller = PageController(initialPage: initial);
      return Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: controller,
              itemCount: urls.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    urls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                bottom: MediaQuery.paddingOf(ctx).bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${initial + 1} / ${urls.length}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
