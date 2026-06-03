import 'dart:io';
import 'dart:math';

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../courses/providers/course_provider.dart';
import '../../students/providers/student_provider.dart';
import '../providers/reports_provider.dart';

const _chartColors = [
  Color(0xFF6C5CE7),
  Color(0xFF00C853),
  Color(0xFF2196F3),
  Color(0xFFFFB300),
  Color(0xFFE91E63),
  Color(0xFFFF5252),
  Color(0xFF00BCD4),
  Color(0xFF9C27B0),
];

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  late String _recordDate;
  String _recordCourse = '';
  String _filterFrom = '';
  String _filterTo = '';

  @override
  void initState() {
    super.initState();
    _recordDate = DateTime.now().toIso8601String().substring(0, 10);
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(allStudentsProvider);
    final coursesAsync = ref.watch(coursesProvider);

    // Show loading indicator while core data is still loading
    if (studentsAsync.isLoading || coursesAsync.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.bgMain,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final allStudents = studentsAsync.valueOrNull ?? [];
    final students = allStudents.where((s) => s.status == 'active' || s.status == null).toList();
    final courses = coursesAsync.valueOrNull ?? [];
    final stats = ref.watch(attendanceStats30dProvider).valueOrNull;
    final courseUtil =
        ref.watch(courseUtilizationProvider).valueOrNull ?? [];
    final byDay = ref
        .watch(attendanceByDayProvider((
          from: _filterFrom.isEmpty ? null : _filterFrom,
          to: _filterTo.isEmpty ? null : _filterTo,
        )))
        .valueOrNull ??
        [];

    final records = ref
        .watch(attendanceRecordsProvider(
            (date: _recordDate, courseId: _recordCourse.isEmpty ? null : _recordCourse)))
        .valueOrNull ??
        [];

    final courseMap = {for (final c in courses) c.id: c.name};
    final studentMap = <String, Map<String, dynamic>>{};
    for (final s in students) {
      studentMap[s.id] = {
        'nick_name': s.nickName,
        'first_name': s.firstName,
        'last_name': s.lastName,
      };
    }

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allStudentsProvider);
          ref.invalidate(coursesProvider);
          ref.invalidate(attendanceStats30dProvider);
          ref.invalidate(courseUtilizationProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded,
                    color: AppColors.info, size: 28),
                const SizedBox(width: 8),
                Text('reports'.tr(), style: AppTextStyles.displaySm),
              ],
            ),
            const SizedBox(height: 16),

            // Overview stats
            _buildOverviewStats(students.length, courses.length, stats),
            const SizedBox(height: 16),

            // Date filter + CSV export
            _buildDateFilterBar(records, courseMap, studentMap),
            const SizedBox(height: 16),

            // Line chart
            _buildLineChart(byDay),
            const SizedBox(height: 16),

            // Pie chart
            _buildPieChart(courseUtil),
            const SizedBox(height: 16),

            // Course utilization bars
            _buildUtilization(courseUtil),
            const SizedBox(height: 16),

            // Attendance record
            _buildAttendanceRecord(
                records, courseMap, studentMap, courses),
          ],
        ),
      ),
    );
  }

  Widget _buildDateFilterBar(
    List<Map<String, dynamic>> records,
    Map<String, String> courseMap,
    Map<String, Map<String, dynamic>> studentMap,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _filterFrom.isNotEmpty
                      ? DateTime.tryParse(_filterFrom) ?? DateTime.now()
                      : DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _filterFrom =
                      picked.toIso8601String().substring(0, 10));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  _filterFrom.isEmpty ? 'dateFrom'.tr() : _filterFrom,
                  style: AppTextStyles.bodySm.copyWith(
                      color: _filterFrom.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('—',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _filterTo.isNotEmpty
                      ? DateTime.tryParse(_filterTo) ?? DateTime.now()
                      : DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _filterTo =
                      picked.toIso8601String().substring(0, 10));
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  _filterTo.isEmpty ? 'dateTo'.tr() : _filterTo,
                  style: AppTextStyles.bodySm.copyWith(
                      color: _filterTo.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                ),
              ),
            ),
          ),
          if (_filterFrom.isNotEmpty || _filterTo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () => setState(() {
                  _filterFrom = '';
                  _filterTo = '';
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text('clearFilter'.tr(),
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted)),
                ),
              ),
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _exportCsv(records, courseMap, studentMap),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text('exportCSV'.tr(),
                  style: AppTextStyles.bodyBoldSm
                      .copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(
    List<Map<String, dynamic>> records,
    Map<String, String> courseMap,
    Map<String, Map<String, dynamic>> studentMap,
  ) async {
    final buf = StringBuffer();
    buf.writeln('Date,Course,Student,Time');
    for (final r in records) {
      final cid = r['course_id'] as String;
      final sid = r['student_id'] as String;
      final courseName = courseMap[cid] ?? cid;
      final stu = studentMap[sid];
      final name = stu != null
          ? '${stu['nick_name'] ?? ''} ${stu['first_name'] ?? ''}'.trim()
          : sid.substring(0, 8);
      final time = _formatTime(r['attended_at_ts'] as String);
      buf.writeln('$_recordDate,$courseName,$name,$time');
    }
    final csv = buf.toString();

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/attendance_$_recordDate.csv');
      await file.writeAsString(csv);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)]),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'exportCSV'.tr()} — ${'copied'.tr()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildOverviewStats(
      int studentCount, int courseCount, Map<String, int>? stats) {
    final items = [
      (Icons.people_rounded, studentCount, 'totalStudents'.tr(), AppColors.primary),
      (Icons.school_rounded, courseCount, 'courses'.tr(), AppColors.info),
      (Icons.checklist_rounded, stats?['total_checkins'] ?? 0, 'checkIns30d'.tr(), AppColors.success),
      (Icons.person_rounded, stats?['unique_students'] ?? 0, 'active30d'.tr(), AppColors.warning),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.9,
      children: items
          .map((s) => Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(s.$1, color: s.$4, size: 22),
                    Text('${s.$2}',
                        style: AppTextStyles.displaySm
                            .copyWith(color: s.$4)),
                    Text(s.$3,
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildLineChart(List<Map<String, dynamic>> byDay) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('checkInsOverTime'.tr(),
              style: AppTextStyles.bodyBoldBase),
          const SizedBox(height: 16),
          if (byDay.isEmpty)
            SizedBox(
              height: 200,
              child: Center(
                child: Text('noAttendanceData'.tr(),
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: _computeInterval(byDay),
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: AppColors.borderLight,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.textMuted, fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 5,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= byDay.length) return const SizedBox();
                          return Text(
                            byDay[i]['date'] as String,
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted, fontSize: 9),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        byDay.length,
                        (i) => FlSpot(i.toDouble(),
                            (byDay[i]['count'] as int).toDouble()),
                      ),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 2.5,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (_, _, _, _) =>
                            FlDotCirclePainter(
                          radius: 3,
                          color: AppColors.primary,
                          strokeWidth: 0,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItems: (spots) => spots.map((s) {
                        final i = s.spotIndex;
                        return LineTooltipItem(
                          '${byDay[i]['date']}: ${s.y.toInt()}',
                          AppTextStyles.bodyXs
                              .copyWith(color: AppColors.primary),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _computeInterval(List<Map<String, dynamic>> byDay) {
    final maxVal = byDay.fold<int>(
        0, (m, e) => max(m, (e['count'] as int?) ?? 0));
    if (maxVal <= 5) return 1;
    if (maxVal <= 20) return 5;
    return (maxVal / 4).ceilToDouble();
  }

  Widget _buildPieChart(List<Map<String, dynamic>> courseUtil) {
    final pieData = courseUtil
        .where((c) => ((c['enrolled'] as num?) ?? 0) > 0)
        .toList();
    final total =
        pieData.fold<int>(0, (s, c) => s + ((c['enrolled'] as num?) ?? 0).toInt());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('enrollmentDistribution'.tr(),
              style: AppTextStyles.bodyBoldBase),
          const SizedBox(height: 16),
          if (pieData.isEmpty || total == 0)
            SizedBox(
              height: 200,
              child: Center(
                child: Text('noAttendanceData'.tr(),
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textMuted)),
              ),
            )
          else
            SizedBox(
              height: 240,
              child: PieChart(
                PieChartData(
                  sections: List.generate(pieData.length, (i) {
                    final enrolled =
                        ((pieData[i]['enrolled'] as num?) ?? 0).toDouble();
                    final pct = total > 0 ? (enrolled / total * 100) : 0;
                    return PieChartSectionData(
                      value: enrolled,
                      color: _chartColors[i % _chartColors.length],
                      radius: 60,
                      title: pct >= 5
                          ? '${pieData[i]['course_name']}\n${pct.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: AppTextStyles.bodyXs
                          .copyWith(color: Colors.white, fontSize: 10),
                      titlePositionPercentageOffset: 0.6,
                    );
                  }),
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
          if (pieData.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: List.generate(pieData.length, (i) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _chartColors[i % _chartColors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        pieData[i]['course_name'] as String? ?? '',
                        style: AppTextStyles.bodyXs,
                      ),
                    ],
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUtilization(List<Map<String, dynamic>> courseUtil) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('courseUtilization'.tr(), style: AppTextStyles.bodyBoldBase),
        const SizedBox(height: 8),
        ...courseUtil.map((c) {
          final enrolled = ((c['enrolled'] as num?) ?? 0).toInt();
          final capacity = ((c['capacity'] as num?) ?? 0).toInt();
          final utilPct =
              capacity > 0 ? (enrolled / capacity * 100).round() : 0;
          final checkIns = ((c['checkins_30d'] as num?) ?? 0).toInt();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
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
                    Text(c['course_name'] as String? ?? '',
                        style: AppTextStyles.bodySemiBoldSm),
                    Text('$enrolled / ${capacity > 0 ? '$capacity' : '∞'}',
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                if (capacity > 0) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                    child: LinearProgressIndicator(
                      value: (utilPct / 100).clamp(0, 1).toDouble(),
                      minHeight: 8,
                      backgroundColor: AppColors.bgSurface,
                      valueColor: AlwaysStoppedAnimation(
                        utilPct > 90
                            ? AppColors.danger
                            : utilPct > 70
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('$utilPct% ${'capacityUsedLabel'.tr()}',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(width: 16),
                    Text('$checkIns ${'checkIns'.tr()} (30d)',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAttendanceRecord(
    List<Map<String, dynamic>> records,
    Map<String, String> courseMap,
    Map<String, Map<String, dynamic>> studentMap,
    List<dynamic> courses,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in records) {
      final cid = r['course_id'] as String;
      grouped.putIfAbsent(cid, () => []).add(r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('attendanceRecord'.tr(), style: AppTextStyles.displaySm),
        const SizedBox(height: 8),
        Container(
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
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(_recordDate) ??
                              DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 1)),
                        );
                        if (picked != null) {
                          setState(() => _recordDate = picked
                              .toIso8601String()
                              .substring(0, 10));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: Text(_recordDate,
                            style: AppTextStyles.bodySm),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _navBtn('←', () {
                    final d = DateTime.parse(_recordDate)
                        .subtract(const Duration(days: 1));
                    setState(() => _recordDate =
                        d.toIso8601String().substring(0, 10));
                  }),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => setState(() => _recordDate =
                        DateTime.now()
                            .toIso8601String()
                            .substring(0, 10)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Text('today'.tr(),
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _navBtn('→', () {
                    final d = DateTime.parse(_recordDate)
                        .add(const Duration(days: 1));
                    setState(() => _recordDate =
                        d.toIso8601String().substring(0, 10));
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recordCourse,
                    isExpanded: true,
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textPrimary),
                    items: [
                      DropdownMenuItem(
                        value: '',
                        child: Text('allCourses'.tr()),
                      ),
                      ...courses.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                    ],
                    onChanged: (v) =>
                        setState(() => _recordCourse = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatFullDate(_recordDate)} — ${records.length} check-in(s)',
                style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      Icon(Icons.checklist_rounded,
                          size: 40, color: AppColors.borderLight),
                      const SizedBox(height: 8),
                      Text('noAttendanceData'.tr(),
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                )
              else
                for (final entry
                    in grouped.entries.toList().asMap().entries) ...[
                  Builder(builder: (_) {
                    final idx = entry.key;
                    final cid = entry.value.key;
                    final entries = entry.value.value;
                    final courseName = courseMap[cid] ?? 'Unknown';
                    const colors = [
                      AppColors.primary,
                      AppColors.success,
                      AppColors.info,
                      AppColors.warning,
                      Color(0xFFE91E63),
                    ];
                    final color = colors[idx % colors.length];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (idx > 0) const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                    courseName.isNotEmpty
                                        ? courseName[0]
                                        : '?',
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(courseName,
                                style: AppTextStyles.displaySm
                                    .copyWith(fontSize: 16)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull),
                              ),
                              child: Text('${entries.length}',
                                  style: AppTextStyles.bodyXs.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...entries.asMap().entries.map((e) {
                          final j = e.key;
                          final r = e.value;
                          final sid = r['student_id'] as String;
                          final stu = studentMap[sid];
                          final name = stu != null
                              ? (stu['nick_name'] != null
                                  ? "${stu['nick_name']} '${stu['first_name']}'"
                                  : '${stu['first_name']} ${stu['last_name']}')
                              : sid.substring(0, 8);
                          final ts = r['attended_at_ts'] as String;
                          final time = _formatTime(ts);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.bgSurface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: Text('${j + 1}',
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.bodyXs.copyWith(
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(name,
                                      style: AppTextStyles.bodyBoldSm),
                                ),
                                Text(time,
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  }),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _navBtn(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Text(label,
            style: AppTextStyles.bodyBoldSm
                .copyWith(color: AppColors.textSecondary)),
      ),
    );
  }

  String _formatFullDate(String date) {
    try {
      final d = DateTime.parse(date);
      return intl.DateFormat('EEEE, d/M/y', context.locale.toString()).format(d);
    } catch (_) {
      return date;
    }
  }

  String _formatTime(String iso) {
    try {
      final d = DateTime.parse(iso);
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
