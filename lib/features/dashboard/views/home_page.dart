import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/expected_student.dart';
import '../models/renewal_student.dart';
import '../../inbox/providers/inbox_provider.dart';
import '../../inbox/views/notifications_panel.dart';
import '../providers/dashboard_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffset = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _entranceController.forward();

    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollOffset.value = _scrollController.offset;
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _scrollController.dispose();
    _scrollOffset.dispose();
    super.dispose();
  }

  Widget _buildStaggered({
    required int index,
    required Widget child,
  }) {
    final double start = (index * 0.08).clamp(0.0, 0.4);
    final double end = (start + 0.55).clamp(0.0, 1.0);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.12),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(start, end, curve: const Cubic(0.34, 1.56, 0.64, 1.0)),
          ),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authProvider);
    final expectedAsync = ref.watch(expectedTodayProvider);
    final studentsAsync = ref.watch(dashboardStudentsProvider);

    // Show loading indicator while core data is still loading
    if (userAsync.isLoading || expectedAsync.isLoading || studentsAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgMain,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final user = userAsync.valueOrNull;
    final schoolName =
        ref.watch(schoolNameProvider).valueOrNull ?? 'Wonder Kids';
    final expected = expectedAsync.valueOrNull ?? [];
    final students = studentsAsync.valueOrNull ?? [];
    final renewalStudents =
        ref.watch(renewalStudentsProvider).valueOrNull ?? [];
    final todayAttendance =
        ref.watch(todayAttendanceProvider).valueOrNull ?? [];
    final reviewCount = ref.watch(pendingReviewCountProvider).valueOrNull ?? 0;
    final unreadCount = ref.watch(unreadCountProvider);
    final isAdmin = user?.isAdmin ?? false;

    final checkedInIds =
        todayAttendance.map((a) => a['student_id'] as String).toSet();

    final courseGroups = _buildCourseGroups(expected, checkedInIds);
    final overlimitStudents =
        renewalStudents.where((s) => s.hoursRemaining <= 0).toList();
    final approachingStudents = renewalStudents
        .where((s) => s.hoursRemaining > 0 && s.hoursRemaining <= 2)
        .toList();

    final studentMap = {for (final s in students) s['id'] as String: s};
    final courseNameMap = <String, String>{};
    for (final e in expected) {
      courseNameMap[e.courseId] = e.courseName;
    }
    for (final a in todayAttendance) {
      final cid = a['course_id'] as String?;
      if (cid != null && !courseNameMap.containsKey(cid)) {
        final courses = a['courses'];
        if (courses is Map) {
          final cName = courses['name'] as String?;
          if (cName != null) courseNameMap[cid] = cName;
        }
      }
    }
    final feedByCourse =
        _buildFeedByCourse(todayAttendance, studentMap, courseNameMap);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expectedTodayProvider);
          ref.invalidate(dashboardStudentsProvider);
          ref.invalidate(renewalStudentsProvider);
          ref.invalidate(todayAttendanceProvider);
          ref.invalidate(pendingReviewCountProvider);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, child) {
                final double bannerHeight = (120.0 - offset).clamp(70.0, 140.0);
                final double titleOpacity = (1.0 - (offset / 50.0)).clamp(0.0, 1.0);
                final double verticalPadding = (20.0 - offset * 0.2).clamp(8.0, 28.0);

                return AnimatedContainer(
                  duration: Duration.zero,
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.paddingOf(context).top + 4,
                    bottom: verticalPadding,
                    left: 24,
                    right: 24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(32),
                    ),
                  ),
                  alignment: Alignment.center,
                  height: bannerHeight + MediaQuery.paddingOf(context).top,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Opacity(
                          opacity: titleOpacity,
                          child: Text(
                            schoolName,
                            style: AppTextStyles.bodyLg.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showNotificationsPanel(context);
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_rounded,
                                color: Colors.white, size: 28),
                            if (unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 18, minHeight: 18),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Transform.translate(
                offset: const Offset(0, -32),
                child: Column(
                  children: [
                    _buildStaggered(
                      index: 0,
                      child: _buildActionButtons(context),
                    ),
                    const SizedBox(height: 12),
                    _buildStaggered(
                      index: 1,
                      child: _buildTakeAttendanceButton(context),
                    ),
                    _buildOnboardingChecklist(
                      hasCourses: courseGroups.isNotEmpty,
                      hasStudents: students.isNotEmpty,
                      hasCheckin: todayAttendance.isNotEmpty || renewalStudents.isNotEmpty,
                    ),
                    const SizedBox(height: 24),
                    _buildStaggered(
                      index: 2,
                      child: _buildCheckinFeed(context, feedByCourse, checkedInIds.length),
                    ),
                    if (isAdmin && reviewCount > 0) ...[
                      const SizedBox(height: 24),
                      _buildStaggered(
                        index: 3,
                        child: _buildPendingReviews(context, reviewCount),
                      ),
                    ],
                    if (overlimitStudents.isNotEmpty ||
                        approachingStudents.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildStaggered(
                        index: 4,
                        child: _buildRenewalSection(
                            context, overlimitStudents, approachingStudents),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildStaggered(
                      index: 5,
                      child: _buildStatsCards(courseGroups.length, checkedInIds.length),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildOnboardingChecklist({
    required bool hasCourses,
    required bool hasStudents,
    required bool hasCheckin,
  }) {
    final items = [
      (hasCourses, 'setupAddCourses'.tr(), Icons.menu_book_rounded, '/courses'),
      (hasStudents, 'setupAddStudents'.tr(), Icons.people_rounded, '/admissions?mode=new'),
      (hasCheckin, 'setupFirstCheckin'.tr(), Icons.check_circle_rounded, '/attendance'),
    ];
    final done = items.where((i) => i.$1).length;
    if (done >= items.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
          border: Border.all(color: AppColors.borderPurple),
          boxShadow: const [BoxShadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x08000000))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('setupChecklist'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.primary)),
                const Spacer(),
                Text('$done/${items.length}', style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: done / items.length,
                minHeight: 6,
                backgroundColor: AppColors.bgSurface,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: item.$1 ? null : () => context.go(item.$4),
                  child: Row(
                    children: [
                      Icon(
                        item.$1 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: item.$1 ? AppColors.success : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: AppTextStyles.bodySm.copyWith(
                            color: item.$1 ? AppColors.success : AppColors.textPrimary,
                            decoration: item.$1 ? TextDecoration.lineThrough : null,
                            fontWeight: item.$1 ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (!item.$1)
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.person_add_rounded,
            iconColor: const Color(0xFFE91E63),
            label: 'newStudent'.tr(),
            onTap: () => context.go('/admissions?mode=new'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.menu_book_rounded,
            iconColor: AppColors.info,
            label: 'checkCourse'.tr(),
            onTap: () => context.go('/courses'),
          ),
        ),
      ],
    );
  }

  Widget _buildTakeAttendanceButton(BuildContext context) {
    return _TakeAttendanceButton(
      onTap: () => context.go('/attendance'),
    );
  }

  Widget _buildCheckinFeed(
    BuildContext context,
    List<_FeedCourseGroup> feedByCourse,
    int checkedInCount,
  ) {
    const maxVisible = 5;
    final totalEntries =
        feedByCourse.fold<int>(0, (s, g) => s + g.entries.length);
    final hasMore = totalEntries > maxVisible;
    const feedColors = [
      AppColors.primary,
      AppColors.success,
      AppColors.info,
      AppColors.warning,
      Color(0xFFE91E63),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('dailyCheckinFeed'.tr(), style: AppTextStyles.displaySm),
              if (checkedInCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$checkedInCount',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (feedByCourse.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    final locale = context.locale.toString();
                    final dateStr = intl.DateFormat('EEEE, d/M/y', locale).format(now);
                    final buf = StringBuffer();
                    buf.writeln('${'dailyCheckinFeed'.tr()} — $dateStr');
                    buf.writeln('');
                    for (final g in feedByCourse) {
                      buf.writeln('${g.courseName}:');
                      for (var i = 0; i < g.entries.length; i++) {
                        buf.writeln('  ${i + 1}. ${g.entries[i].studentName}${g.entries[i].hours > 1 ? ' (${g.entries[i].hours}h)' : ''}');
                      }
                    }
                    Clipboard.setData(ClipboardData(text: buf.toString()));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.copy_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(width: 6),
              if (feedByCourse.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    final locale = context.locale.toString();
                    final dateStr = intl.DateFormat('EEEE, d/M/y', locale).format(now);
                    final buf = StringBuffer();
                    buf.writeln('${'dailyCheckinFeed'.tr()} — $dateStr');
                    buf.writeln('');
                    for (final g in feedByCourse) {
                      buf.writeln('${g.courseName}:');
                      for (var i = 0; i < g.entries.length; i++) {
                        buf.writeln('  ${i + 1}. ${g.entries[i].studentName}${g.entries[i].hours > 1 ? ' (${g.entries[i].hours}h)' : ''}');
                      }
                      buf.writeln('');
                    }
                    SharePlus.instance.share(ShareParams(text: buf.toString()));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.share_rounded,
                        size: 16, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (feedByCourse.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    const Text('👀', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    Text(
                      'noCheckInsToday'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildFeedList(
                feedByCourse, feedColors, maxVisible, false, context),
            if (hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GestureDetector(
                  onTap: () => _showFeedDialog(context, feedByCourse, feedColors),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Text(
                      '${'seeMore'.tr()} (${totalEntries - maxVisible} ${'more'.tr()})',
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedList(
    List<_FeedCourseGroup> feedByCourse,
    List<Color> colors,
    int maxVisible,
    bool showAll,
    BuildContext context,
  ) {
    var globalIdx = 0;

    return RepaintBoundary(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < feedByCourse.length; i++) ...[
          () {
            final group = feedByCourse[i];
            final color = colors[i % colors.length];
            final start = globalIdx;
            final available =
                showAll ? group.entries.length : (maxVisible - start).clamp(0, group.entries.length);
            globalIdx += group.entries.length;
            if (available <= 0) return const SizedBox.shrink();
            final entries = group.entries.sublist(0, available);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (i > 0) const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        group.courseName.isNotEmpty
                            ? group.courseName[0]
                            : '?',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(group.courseName,
                          style: AppTextStyles.displaySm
                              .copyWith(fontSize: 16)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        '${group.entries.length}',
                        style: AppTextStyles.bodyXs.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Column(
                    children: [
                      for (var j = 0; j < entries.length; j++)
                        GestureDetector(
                          onTap: () =>
                              context.go('/students/${entries[j].studentId}'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Text(
                                    '${j + 1}',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.bodyXs.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entries[j].studentName,
                                    style: AppTextStyles.bodyBoldSm,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (entries[j].hours > 1)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                    ),
                                    child: Text(
                                      '${entries[j].hours}h',
                                      style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }(),
        ],
      ],
    ),
    );
  }

  Widget _buildRenewalSection(
    BuildContext context,
    List<RenewalStudent> overlimit,
    List<RenewalStudent> approaching,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overlimit.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.danger, size: 24),
                const SizedBox(width: 8),
                Text(
                  'needsRenewal'.tr(),
                  style:
                      AppTextStyles.displaySm.copyWith(color: AppColors.danger),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in overlimit.take(5))
              _RenewalCard(
                student: s,
                isDanger: true,
                onTap: () => context.go('/students/${s.studentId}'),
              ),
          ],
          if (overlimit.isNotEmpty && approaching.isNotEmpty)
            const SizedBox(height: 16),
          if (approaching.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.warningAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'renewalApproaching'.tr(),
                  style: AppTextStyles.displaySm
                      .copyWith(fontSize: 16, color: AppColors.warningAccent),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in approaching.take(5))
              _RenewalCard(
                student: s,
                isDanger: false,
                onTap: () => context.go('/students/${s.studentId}'),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPendingReviews(BuildContext context, int count) {
    return GestureDetector(
      onTap: () => context.go('/inbox'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.warningLight,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
          border: Border.all(color: AppColors.warning, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: AppTextStyles.displayMd.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'pendingApprovalsExclaim'.tr(),
                    style: AppTextStyles.displaySm
                        .copyWith(color: AppColors.warningAccent),
                  ),
                  Text(
                    'tapToReviewThem'.tr(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.warningDark),
                  ),
                ],
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFFB923C),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_forward,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(int classCount, int checkedInCount) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF1890FF),
            value: '$classCount',
            label: 'classes'.tr(),
            borderColor: const Color(0xFF91D5FF),
            bgColor: const Color(0xE6E6F7FF),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            icon: Icons.people_rounded,
            iconColor: const Color(0xFF52C41A),
            value: '$checkedInCount',
            label: 'checkedIn'.tr(),
            borderColor: const Color(0xFFB7EB8F),
            bgColor: const Color(0xE6F6FFED),
          ),
        ),
      ],
    );
  }

  void _showFeedDialog(
    BuildContext context,
    List<_FeedCourseGroup> feedByCourse,
    List<Color> colors,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                child: Row(
                  children: [
                    Text(
                      'dailyCheckinFeed'.tr(),
                      style: AppTextStyles.displaySm
                          .copyWith(color: AppColors.primary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < feedByCourse.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        _buildDialogGroup(
                            ctx, feedByCourse[i], colors[i % colors.length]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogGroup(
      BuildContext ctx, _FeedCourseGroup group, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                group.courseName.isNotEmpty ? group.courseName[0] : '?',
                style: AppTextStyles.bodyXs
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(group.courseName,
                  style: AppTextStyles.displaySm.copyWith(fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '${group.entries.length}',
                style: AppTextStyles.bodyXs
                    .copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Column(
            children: [
              for (var j = 0; j < group.entries.length; j++)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/students/${group.entries[j].studentId}');
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: Text(
                            '${j + 1}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            group.entries[j].studentName,
                            style: AppTextStyles.bodyBoldSm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (group.entries[j].hours > 1)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                            ),
                            child: Text(
                              '${group.entries[j].hours}h',
                              style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Map<String, _CourseGroup> _buildCourseGroups(
      List<ExpectedStudent> expected, Set<String> checkedInIds) {
    final map = <String, _CourseGroup>{};
    for (final s in expected) {
      map.putIfAbsent(
          s.courseId, () => _CourseGroup(name: s.courseName, total: 0, checked: 0));
      map[s.courseId]!.total++;
      if (checkedInIds.contains(s.studentId)) {
        map[s.courseId]!.checked++;
      }
    }
    return map;
  }

  List<_FeedCourseGroup> _buildFeedByCourse(
    List<Map<String, dynamic>> todayAttendance,
    Map<String, Map<String, dynamic>> studentMap,
    Map<String, String> courseNameMap,
  ) {
    final map = <String, _FeedCourseGroup>{};
    for (final a in todayAttendance) {
      final courseId = a['course_id'] as String?;
      if (courseId == null) continue;
      final cName = courseNameMap[courseId] ?? 'Unknown Course';
      map.putIfAbsent(courseId, () => _FeedCourseGroup(courseName: cName));
      final studentId = a['student_id'] as String;
      final stu = studentMap[studentId];
      String name;
      if (stu != null) {
        final nick = stu['nick_name'] as String?;
        final first = stu['first_name'] as String? ?? '';
        final last = stu['last_name'] as String? ?? '';
        if (nick != null && nick.isNotEmpty && first.isNotEmpty) {
          name = '$nick $first';
        } else {
          name = nick ?? '$first $last';
        }
      } else {
        name = studentId;
      }
      final existing = map[courseId]!.entries
          .where((e) => e.studentId == studentId)
          .firstOrNull;
      if (existing != null) {
        existing.hours++;
      } else {
        map[courseId]!.entries.add(_FeedEntry(
          studentName: name,
          studentId: studentId,
        ));
      }
    }
    return map.values.toList();
  }
}

class _CourseGroup {
  final String name;
  int total;
  int checked;
  _CourseGroup({required this.name, required this.total, required this.checked});
}

class _FeedCourseGroup {
  final String courseName;
  final List<_FeedEntry> entries = [];
  _FeedCourseGroup({required this.courseName});
}

class _FeedEntry {
  final String studentName;
  final String studentId;
  int hours;
  _FeedEntry({required this.studentName, required this.studentId, this.hours = 1});
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _AnimatedPressableCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight, width: 2),
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 4),
              blurRadius: 12,
              color: Color(0x0D000000),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.displaySm.copyWith(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RenewalCard extends StatelessWidget {
  const _RenewalCard({
    required this.student,
    required this.isDanger,
    required this.onTap,
  });

  final RenewalStudent student;
  final bool isDanger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? AppColors.danger : AppColors.warning;
    final bgColor = isDanger ? AppColors.dangerLight : AppColors.warningLight;
    final borderColor = color.withValues(alpha: 0.2);

    return _AnimatedPressableCard(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: isDanger
                  ? const Text('!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700))
                  : const Text('⏳', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.displayName,
                    style: AppTextStyles.displaySm.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    isDanger
                        ? student.courseName
                        : '${student.courseName} — ${student.hoursUsed.toStringAsFixed(0)}/${student.purchasedHours} ${'hrs'.tr()}',
                    style: AppTextStyles.bodyXs.copyWith(
                      color: isDanger ? AppColors.danger : AppColors.warningAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (isDanger)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  boxShadow: const [
                    BoxShadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Color(0x0D000000),
                    ),
                  ],
                ),
                child: Text(
                  '${student.hoursUsed.toStringAsFixed(0)}/${student.purchasedHours} ${'hrs'.tr()}',
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.borderColor,
    required this.bgColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color borderColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return _AnimatedPressableCard(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.displayLg.copyWith(
                color: iconColor,
              ),
            ),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.bodyXs.copyWith(
                color: iconColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Dynamic Touch & Animation Helper Classes ---

class _AnimatedPressableCard extends StatefulWidget {
  const _AnimatedPressableCard({
    required this.child,
    required this.onTap,
    this.scale = 0.96,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<_AnimatedPressableCard> createState() => _AnimatedPressableCardState();
}

class _AnimatedPressableCardState extends State<_AnimatedPressableCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _isPressed ? const Offset(0.0, 0.02) : Offset.zero,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _TakeAttendanceButton extends StatefulWidget {
  const _TakeAttendanceButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_TakeAttendanceButton> createState() => _TakeAttendanceButtonState();
}

class _TakeAttendanceButtonState extends State<_TakeAttendanceButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.mediumImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          return Transform.translate(
            offset: Offset(0, _pressed ? 4.0 : 0.0),
            child: Transform.scale(
              scale: _pressed ? 0.97 : 1.0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(AppTheme.radius3xl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3 + 0.2 * pulse),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 8),
                      blurRadius: 20 + 8 * pulse,
                      color: AppColors.success.withValues(alpha: 0.3 + 0.15 * pulse),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          );
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_turned_in_rounded,
                color: Colors.white, size: 40),
            const SizedBox(width: 20),
            Text(
              'takeAttendance'.tr(),
              style: AppTextStyles.displayMd.copyWith(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

