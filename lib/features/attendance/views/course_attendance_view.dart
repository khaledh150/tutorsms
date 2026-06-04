import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import '../../../shared/services/offline_checkin_queue.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/attendance_row.dart';
import '../models/course_group.dart';
import '../models/student_for_grid.dart';
import '../providers/attendance_provider.dart';

class CourseAttendanceView extends ConsumerStatefulWidget {
  const CourseAttendanceView({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseAttendanceView> createState() =>
      _CourseAttendanceViewState();
}

class _CourseAttendanceViewState extends ConsumerState<CourseAttendanceView> {
  String? _busyKey;
  _ScanResult? _scanResult;
  bool _walkInOpen = false;
  String _walkInQuery = '';
  List<Map<String, dynamic>> _walkInResults = [];
  Timer? _debounce;
  final _walkInController = TextEditingController();
  bool _showTooltip = false;

  bool _soundEnabled = true;

  String get courseId => widget.courseId;

  @override
  void initState() {
    super.initState();
    _checkFirstVisit();
    _loadSoundPref();
  }

  Future<void> _loadSoundPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _soundEnabled = prefs.getBool('checkin_sound') ?? true);
  }

  void _playCheckinFeedback() {
    HapticFeedback.mediumImpact();
    if (_soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _checkFirstVisit() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('checkin_tooltip_shown') != true) {
      if (mounted) setState(() => _showTooltip = true);
      await prefs.setBool('checkin_tooltip_shown', true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _walkInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(courseAttendanceProvider(courseId));
    final allTimeAsync = ref.watch(allTimeHoursProvider(courseId));
    final groupsAsync = ref.watch(courseGroupsProvider);

    final rows = rowsAsync.valueOrNull ?? [];
    final allTimeHours = allTimeAsync.valueOrNull ?? {};
    final groups = groupsAsync.valueOrNull ?? [];

    final group = groups
        .where((g) => g.courseId == courseId)
        .firstOrNull;
    final students = group?.students ?? [];
    final courseName = group?.courseName ?? '';

    final approvedRows = rows.where((r) => r.isApproved).toList();
    final checkedSet = <String>{};
    final todayUsedMap = <String, int>{};
    for (final r in approvedRows) {
      if (r.courseId == null) continue;
      checkedSet.add(r.studentId);
      final key = '${r.studentId}|${r.courseId}';
      todayUsedMap[key] = (todayUsedMap[key] ?? 0) + 1;
    }

    final checkedCount =
        students.where((s) => checkedSet.contains(s.studentId)).length;
    final uncheckedCount = students.length - checkedCount;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(courseName, checkedCount, students.length,
                  uncheckedCount, rows),
              _buildCourseSwitcher(groups),
              if (_scanResult != null) _buildScanBanner(),
              if (_walkInOpen) _buildWalkInSearch(rows),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(courseAttendanceProvider(courseId));
                ref.invalidate(allTimeHoursProvider(courseId));
                ref.invalidate(courseGroupsProvider);
              },
              child: students.isEmpty
                  ? ListView(children: [_buildEmptyState()])
                  : _buildStudentGrid(
                      students,
                      checkedSet,
                      todayUsedMap,
                      allTimeHours,
                      rows,
                    ),
            ),
          ),
          ],
          ),
          if (_showTooltip)
            Positioned(
              bottom: 24, left: 20, right: 20,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(AppTheme.radius2xl),
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'checkinTooltip'.tr(),
                          style: AppTextStyles.bodySm.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _showTooltip = false),
                        child: Text('gotIt'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCourseSwitcher(List<CourseGroup> groups) {
    if (groups.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final g = groups[i];
          final isCurrent = g.courseId == courseId;
          return GestureDetector(
            onTap: isCurrent ? null : () => context.go('/attendance/${g.courseId}'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                  color: isCurrent ? AppColors.primary : AppColors.borderLight,
                ),
              ),
              child: Text(
                g.courseName,
                style: AppTextStyles.bodyXs.copyWith(
                  color: isCurrent ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(String courseName, int checkedCount, int totalCount,
      int uncheckedCount, List<AttendanceRow> rows) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/attendance'),
            icon: const Icon(Icons.arrow_back_rounded),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              minimumSize: const Size(48, 48),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: AppTextStyles.displaySm
                      .copyWith(color: AppColors.primaryDark),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$checkedCount / $totalCount ${'checkedIn'.tr()}',
                  style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700).copyWith(
                    color: checkedCount > 0
                        ? AppColors.success
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (uncheckedCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: () => _bulkCheckIn(rows),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'checkInAll'.tr(namedArgs: {'count': '$uncheckedCount'}),
                  style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700)
                      .copyWith(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          IconButton(
            onPressed: () {
              setState(() {
                _walkInOpen = !_walkInOpen;
                if (!_walkInOpen) {
                  _walkInQuery = '';
                  _walkInResults = [];
                  _walkInController.clear();
                }
              });
            },
            icon: Icon(_walkInOpen
                ? Icons.close_rounded
                : Icons.person_search_rounded),
            style: IconButton.styleFrom(
              backgroundColor:
                  _walkInOpen ? AppColors.textMuted : AppColors.info,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              minimumSize: const Size(48, 48),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context.go('/attendance/scan/$courseId'),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              minimumSize: const Size(48, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalkInSearch(List<AttendanceRow> rows) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _walkInController,
            autofocus: true,
            style: AppTextStyles.bodySm,
            decoration: InputDecoration(
              hintText: 'searchPlaceholder'.tr(),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: AppColors.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isCollapsed: true,
            ),
            onChanged: _onWalkInSearch,
          ),
          if (_walkInResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _walkInResults.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (context, index) {
                  final s = _walkInResults[index];
                  final name = s['nick_name'] ?? s['first_name'] ?? '';
                  final full =
                      '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'
                          .trim();
                  return ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: Colors.white),
                      ),
                    ),
                    title: Text(name,
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.primary)),
                    subtitle: Text(full, style: AppTextStyles.bodyXs),
                    onTap: () => _walkInCheckIn(
                      s['id'] as String,
                      name,
                      rows,
                    ),
                  );
                },
              ),
            ),
          if (_walkInQuery.isNotEmpty && _walkInResults.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('noStudentsFound'.tr(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }

  void _onWalkInSearch(String query) {
    _walkInQuery = query;
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _walkInResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = query.trim().toLowerCase();
      final res = await supabase
          .from('students')
          .select('id,first_name,last_name,nick_name')
          .or('first_name.ilike.%$q%,last_name.ilike.%$q%,nick_name.ilike.%$q%')
          .eq('status', 'active')
          .limit(10);
      if (mounted && _walkInQuery == query) {
        setState(() => _walkInResults = List<Map<String, dynamic>>.from(res));
      }
    });
  }

  Future<void> _walkInCheckIn(
      String studentId, String name, List<AttendanceRow> rows) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.checkIn(
        studentId: studentId,
        courseId: courseId,
        approverId: user.id,
      );
      ref.invalidate(courseAttendanceProvider(courseId));
      ref.invalidate(allTimeHoursProvider(courseId));
      ref.invalidate(courseGroupsProvider);
      _playCheckinFeedback();
      _showResult('$name — ${'checkedInMsg'.tr()}', true);
      setState(() {
        _walkInOpen = false;
        _walkInQuery = '';
        _walkInResults = [];
        _walkInController.clear();
      });
    } catch (e) {
      _showResult('Error: $e', false);
    }
  }

  Widget _buildScanBanner() {
    final result = _scanResult!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: result.isSuccess ? AppColors.success : AppColors.danger,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 12,
            color: (result.isSuccess ? AppColors.success : AppColors.danger)
                .withValues(alpha: 0.35),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result.message,
              style:
                  AppTextStyles.bodyBoldSm.copyWith(color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _scanResult = null),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius3xl),
        ),
        child: Text(
          'noStudentsEnrolled'.tr(),
          style: AppTextStyles.displaySm.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildStudentCard(
    StudentForGrid stu,
    Set<String> checkedSet,
    Map<String, int> todayUsedMap,
    Map<String, int> allTimeHours,
    List<AttendanceRow> rows,
  ) {
    final checked = checkedSet.contains(stu.studentId);
    final todayHrs = todayUsedMap['${stu.studentId}|$courseId'] ?? 0;
    final totalUsed =
        (allTimeHours['${stu.studentId}|$courseId'] ?? 0) +
            stu.initialUsedHours;
    final purchased = stu.purchasedHours;
    final remaining = purchased - totalUsed;
    final isOverlimit = purchased > 0 && remaining <= 0;
    final isApproaching =
        purchased > 0 && remaining > 0 && remaining <= 2;
    final isLow = purchased > 0 && remaining > 0 && remaining <= 3;
    final isBusy = _busyKey == '${stu.studentId}|$courseId';

    return RepaintBoundary(
      child: _StudentCard(
        student: stu,
        checked: checked,
        todayHrs: todayHrs,
        totalUsed: totalUsed,
        purchased: purchased,
        isOverlimit: isOverlimit,
        isApproaching: isApproaching,
        isLow: isLow,
        isBusy: isBusy,
        onTap: () => _handleCheckIn(stu, checkedSet, allTimeHours, rows),
        onNameTap: () => context.go('/students/${stu.studentId}'),
      ),
    );
  }

  Widget _buildStudentGrid(
    List<StudentForGrid> students,
    Set<String> checkedSet,
    Map<String, int> todayUsedMap,
    Map<String, int> allTimeHours,
    List<AttendanceRow> rows,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3 / 4,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) => _buildStudentCard(
        students[index], checkedSet, todayUsedMap, allTimeHours, rows,
      ),
    );
  }

  void _handleCheckIn(
    StudentForGrid stu,
    Set<String> checkedSet,
    Map<String, int> allTimeHours,
    List<AttendanceRow> rows,
  ) {
    final key = '${stu.studentId}|$courseId';
    if (_busyKey == key) return;

    final isChecked = checkedSet.contains(stu.studentId);

    if (!isChecked) {
      final totalUsed =
          (allTimeHours['${stu.studentId}|$courseId'] ?? 0) +
              stu.initialUsedHours;
      if (stu.purchasedHours > 0 && totalUsed >= stu.purchasedHours) {
        _showOverlimitDialog(stu, totalUsed);
        return;
      }
      _quickCheckIn(stu);
    } else {
      _cancelCheckIn(stu, rows);
    }
  }

  void _showOverlimitDialog(StudentForGrid stu, int totalUsed) {
    final name = stu.nickName ?? stu.firstName;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('overlimitTitle'.tr(), style: AppTextStyles.displaySm),
        content: Text(
          'overlimitConfirm'.tr(namedArgs: {
            'name': name,
            'used': totalUsed.toString(),
            'purchased': stu.purchasedHours.toString(),
          }),
          style: AppTextStyles.bodyBase,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showHourPicker(stu);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning),
            child: Text('continueCheckIn'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _quickCheckIn(StudentForGrid stu) async {
    final key = '${stu.studentId}|$courseId';
    setState(() => _busyKey = key);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() => _busyKey = null);
      return;
    }

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final result = await repo.checkIn(
        studentId: stu.studentId,
        courseId: courseId,
        approverId: user.id,
      );
      ref.invalidate(courseAttendanceProvider(courseId));
      ref.invalidate(allTimeHoursProvider(courseId));
      ref.invalidate(courseGroupsProvider);
      _playCheckinFeedback();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${stu.displayName} — ${'checkedIn'.tr()}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'undoCheckin'.tr(),
              textColor: Colors.white,
              onPressed: () async {
                await repo.cancelAttendance(rowId: result.id, userId: user.id);
                ref.invalidate(courseAttendanceProvider(courseId));
                ref.invalidate(allTimeHoursProvider(courseId));
                ref.invalidate(courseGroupsProvider);
              },
            ),
          ),
        );
      }
    } catch (e) {
      final isNetwork = e.toString().contains('SocketException') ||
          e.toString().contains('Connection') ||
          e.toString().contains('timeout');
      if (isNetwork) {
        await OfflineCheckinQueue.instance.enqueue(
          studentId: stu.studentId,
          courseId: courseId,
          approverId: user.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${stu.displayName} — ${'queuedOffline'.tr()}'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _showResult('Error: $e', false);
      }
    } finally {
      setState(() => _busyKey = null);
    }
  }

  void _showHourPicker(StudentForGrid stu) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _HourPickerSheet(
        student: stu,
        onSelect: (hours) {
          Navigator.pop(ctx);
          _confirmCheckIn(stu, hours);
        },
      ),
    );
  }

  Future<void> _confirmCheckIn(StudentForGrid stu, int hours) async {
    final key = '${stu.studentId}|$courseId';
    setState(() => _busyKey = key);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() => _busyKey = null);
      return;
    }

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      await repo.checkInMultiHour(
        studentId: stu.studentId,
        courseId: courseId,
        approverId: user.id,
        hours: hours,
      );
      ref.invalidate(courseAttendanceProvider(courseId));
      ref.invalidate(allTimeHoursProvider(courseId));
      ref.invalidate(courseGroupsProvider);
      _playCheckinFeedback();
      _showResult(
        '${stu.displayName} — ${hours}h ${'checkedIn'.tr()}',
        true,
      );
    } catch (e) {
      _showResult('Error: $e', false);
    } finally {
      setState(() => _busyKey = null);
    }
  }

  Future<void> _cancelCheckIn(
      StudentForGrid stu, List<AttendanceRow> rows) async {
    final key = '${stu.studentId}|$courseId';
    setState(() => _busyKey = key);

    final user = ref.read(authProvider).valueOrNull;
    if (user == null) {
      setState(() => _busyKey = null);
      return;
    }

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final todayRows = rows
          .where((r) =>
              r.studentId == stu.studentId &&
              r.courseId == courseId &&
              r.attendedAtTs.substring(0, 10) == today)
          .toList();

      if (todayRows.isNotEmpty) {
        final repo = ref.read(attendanceRepositoryProvider);
        await repo.cancelMultiple(
          rowIds: todayRows.map((r) => r.id).toList(),
          userId: user.id,
        );
        ref.invalidate(courseAttendanceProvider(courseId));
        ref.invalidate(allTimeHoursProvider(courseId));
        ref.invalidate(courseGroupsProvider);
      }

      HapticFeedback.lightImpact();
      _showResult(
        'uncheckedStudent'.tr(namedArgs: {
          'first': stu.firstName,
          'last': stu.lastName,
        }),
        false,
      );
    } catch (e) {
      _showResult('Error: $e', false);
    } finally {
      setState(() => _busyKey = null);
    }
  }

  Future<void> _bulkCheckIn(List<AttendanceRow> rows) async {
    final user = ref.read(authProvider).valueOrNull;
    if (user == null) return;

    final groups = ref.read(courseGroupsProvider).valueOrNull ?? [];
    final group = groups.where((g) => g.courseId == courseId).firstOrNull;
    if (group == null) return;

    final approvedRows = rows.where((r) => r.isApproved).toList();
    final checkedSet = <String>{};
    for (final r in approvedRows) {
      checkedSet.add(r.studentId);
    }

    final unchecked = group.students
        .where((s) => !checkedSet.contains(s.studentId))
        .toList();
    if (unchecked.isEmpty) return;

    try {
      final repo = ref.read(attendanceRepositoryProvider);
      for (final s in unchecked) {
        await repo.checkIn(
          studentId: s.studentId,
          courseId: courseId,
          approverId: user.id,
        );
      }
      ref.invalidate(courseAttendanceProvider(courseId));
      ref.invalidate(allTimeHoursProvider(courseId));
      ref.invalidate(courseGroupsProvider);
      _playCheckinFeedback();
      _showResult(
        'checkedInBulk'.tr(namedArgs: {'count': unchecked.length.toString()}),
        true,
      );
    } catch (e) {
      _showResult('Error: $e', false);
    }
  }

  void _showResult(String message, bool success) {
    setState(() {
      _scanResult = _ScanResult(message: message, isSuccess: success);
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _scanResult = null);
    });
  }
}

class _ScanResult {
  final String message;
  final bool isSuccess;
  const _ScanResult({required this.message, required this.isSuccess});
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.checked,
    required this.todayHrs,
    required this.totalUsed,
    required this.purchased,
    required this.isOverlimit,
    required this.isApproaching,
    required this.isLow,
    required this.isBusy,
    required this.onTap,
    required this.onNameTap,
  });

  final StudentForGrid student;
  final bool checked;
  final int todayHrs;
  final int totalUsed;
  final int purchased;
  final bool isOverlimit;
  final bool isApproaching;
  final bool isLow;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onNameTap;

  Color get _borderColor {
    if (checked && isOverlimit) return const Color(0xFFEF4444);
    if (checked) return const Color(0xFF34D399);
    if (isOverlimit) return const Color(0xFFEF4444);
    if (isApproaching) return const Color(0xFFF59E0B);
    if (isLow) return const Color(0xFFFBBF24);
    return Colors.transparent;
  }

  Color get _bgColor {
    if (checked && isOverlimit) return const Color(0xF2FEE2E2);
    if (checked) return const Color(0xF2F6FFED);
    if (isOverlimit) return const Color(0xF2FEE2E2);
    if (isApproaching || isLow) return const Color(0xF2FFFBE6);
    return const Color(0xCCFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBusy ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isBusy ? 0.6 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            border: Border.all(color: _borderColor, width: 2),
            boxShadow: const [
              BoxShadow(
                  offset: Offset(0, 2),
                  blurRadius: 8,
                  color: Color(0x12000000)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Expanded(
                flex: 55,
                child: _buildPhotoSection(),
              ),
              Expanded(
                flex: 45,
                child: _buildInfoSection(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: const Color(0xFFEBF0FF),
          child: student.photoUrl != null
              ? Image.network(
                  student.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildInitial(),
                )
              : _buildInitial(),
        ),
        if (checked)
          _CheckOverlay(
            isOverlimit: isOverlimit,
            todayHrs: todayHrs,
          ),
      ],
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        student.initial,
        style: AppTextStyles.displayXl
            .copyWith(color: AppColors.primaryLight, fontSize: 48),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      color: const Color(0xF2FFFFFF),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onNameTap,
            child: Text(
              student.displayName,
              style: AppTextStyles.bodyBoldSm.copyWith(
                color: isOverlimit
                    ? AppColors.danger
                    : isApproaching
                        ? AppColors.warningAccent
                        : AppColors.primary,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isOverlimit
                  ? const Color(0x26F87171)
                  : isLow
                      ? const Color(0x33FBBF24)
                      : const Color(0x0A000000),
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            child: Text(
              '$totalUsed / ${purchased > 0 ? purchased : '∞'} ${'hrs'.tr()}',
              style: AppTextStyles.bodyXs.copyWith(
                color: isOverlimit
                    ? const Color(0xFFEF4444)
                    : isLow
                        ? AppColors.warningAccent
                        : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          if (isOverlimit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'renewalNeeded'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                    color: const Color(0xFFDC2626),
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
          if (isApproaching && !isOverlimit)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7CD),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'renewalApproaching'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.warningAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckOverlay extends StatefulWidget {
  const _CheckOverlay({
    required this.isOverlimit,
    required this.todayHrs,
  });

  final bool isOverlimit;
  final int todayHrs;

  @override
  State<_CheckOverlay> createState() => _CheckOverlayState();
}

class _CheckOverlayState extends State<_CheckOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: const _GummyCurve(),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        color: widget.isOverlimit
            ? const Color(0x4DEF4444)
            : const Color(0x4D34D399),
        alignment: Alignment.center,
        child: Text(
          '✓${widget.todayHrs > 1 ? ' ${widget.todayHrs}h' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(offset: Offset(0, 2), blurRadius: 8, color: Color(0x66000000)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GummyCurve extends Curve {
  const _GummyCurve();

  @override
  double transformInternal(double t) {
    // cubic-bezier(0.34, 1.56, 0.64, 1) approximation
    if (t < 0.5) {
      return 2 * t * t * (3 - 2 * t) * 1.2;
    }
    final p = 2 * t - 1;
    return 0.5 + 0.5 * (1 - (1 - p) * (1 - p));
  }
}

class _HourPickerSheet extends StatelessWidget {
  const _HourPickerSheet({
    required this.student,
    required this.onSelect,
  });

  final StudentForGrid student;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            student.displayName,
            style: AppTextStyles.displaySm
                .copyWith(color: AppColors.primaryDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'howManyHours'.tr(),
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              for (int h = 1; h <= 4; h++) ...[
                if (h > 1) const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(h),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: h == 1 ? AppColors.success : AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                            color:
                                (h == 1 ? AppColors.success : AppColors.primary)
                                    .withValues(alpha: 0.35),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${h}h',
                        style: AppTextStyles.displaySm.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }
}

