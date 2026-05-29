import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/course_group.dart';
import '../models/student_for_grid.dart';
import '../providers/attendance_provider.dart';

const _tileColors = [
  AppColors.primary,
  AppColors.info,
  AppColors.warning,
  Color(0xFFE91E63),
  AppColors.success,
  Color(0xFF8B5CF6),
  Color(0xFF0EA5E9),
  Color(0xFFF97316),
];

class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(courseGroupsProvider);
    final checkedInSet = ref.watch(checkedInSetProvider);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('takeAttendance'.tr(),
                  style: AppTextStyles.displaySm),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: groupsAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.danger)),
                ),
                data: (groups) {
                  final q = _search.trim().toLowerCase();
                  if (q.isNotEmpty) {
                    return _buildStudentResults(groups, q, checkedInSet);
                  }
                  if (groups.isEmpty) return _buildEmpty();
                  return _buildGrid(groups, checkedInSet);
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.borderPurple, width: 2),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _search = v),
        style: AppTextStyles.bodySemiBoldBase,
        decoration: InputDecoration(
          hintText: 'searchStudents'.tr(),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppColors.textMuted),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.textMuted),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildStudentResults(
    List<CourseGroup> groups,
    String query,
    Map<String, Set<String>> checkedInSet,
  ) {
    final results = <_StudentResult>[];
    for (final g in groups) {
      for (final s in g.students) {
        final matches = s.displayName.toLowerCase().contains(query) ||
            s.firstName.toLowerCase().contains(query) ||
            s.lastName.toLowerCase().contains(query) ||
            (s.nickName?.toLowerCase().contains(query) ?? false);
        if (matches) {
          results.add(_StudentResult(
            student: s,
            courseId: g.courseId,
            courseName: g.courseName,
            isCheckedIn: checkedInSet[g.courseId]?.contains(s.studentId) ?? false,
          ));
        }
      }
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_search_rounded,
                size: 48, color: AppColors.textMuted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('noStudentsFound'.tr(),
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final r = results[index];
        final s = r.student;
        final colorIndex = groups.indexWhere((g) => g.courseId == r.courseId);
        final color = _tileColors[colorIndex >= 0 ? colorIndex % _tileColors.length : 0];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: InkWell(
              onTap: () => context.go('/attendance/${r.courseId}'),
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: r.isCheckedIn
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.borderLight,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: r.isCheckedIn
                          ? AppColors.success
                          : color,
                      backgroundImage: s.photoUrl != null
                          ? NetworkImage(s.photoUrl!)
                          : null,
                      child: s.photoUrl == null
                          ? Text(s.initial,
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(color: Colors.white))
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.displayName,
                              style: AppTextStyles.bodyBoldSm),
                          const SizedBox(height: 2),
                          Text(r.courseName,
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: color, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (r.isCheckedIn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text('checkedIn'.tr(),
                            style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 10)),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted, size: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
          boxShadow: const [
            BoxShadow(
                offset: Offset(0, 1),
                blurRadius: 4,
                color: Color(0x08000000)),
          ],
        ),
        child: Text(
          'noClassesScheduled'.tr(),
          style: AppTextStyles.displaySm.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildGrid(
      List<CourseGroup> groups, Map<String, Set<String>> checkedInSet) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        final color = _tileColors[index % _tileColors.length];
        final checkedSet = checkedInSet[group.courseId];
        final checkedCount = checkedSet?.length ?? 0;
        final totalStudents = group.students.length;

        return _CourseTile(
          group: group,
          color: color,
          checkedCount: checkedCount,
          totalStudents: totalStudents,
          onTap: () => context.go('/attendance/${group.courseId}'),
        );
      },
    );
  }
}

class _StudentResult {
  final StudentForGrid student;
  final String courseId;
  final String courseName;
  final bool isCheckedIn;

  const _StudentResult({
    required this.student,
    required this.courseId,
    required this.courseName,
    required this.isCheckedIn,
  });
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({
    required this.group,
    required this.color,
    required this.checkedCount,
    required this.totalStudents,
    required this.onTap,
  });

  final CourseGroup group;
  final Color color;
  final int checkedCount;
  final int totalStudents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
          boxShadow: const [
            BoxShadow(
                offset: Offset(0, 2),
                blurRadius: 8,
                color: Color(0x0D000000)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                    color: color.withValues(alpha: 0.35),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                group.courseName.isNotEmpty
                    ? group.courseName[0].toUpperCase()
                    : '?',
                style: AppTextStyles.displayMd
                    .copyWith(color: Colors.white, fontSize: 28),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                group.courseName,
                style: AppTextStyles.bodyBoldSm,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: checkedCount > 0
                    ? const Color(0x2634D399)
                    : const Color(0x0A000000),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                '$checkedCount / $totalStudents',
                style: AppTextStyles.bodyXs.copyWith(
                  color: checkedCount > 0
                      ? AppColors.success
                      : AppColors.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
