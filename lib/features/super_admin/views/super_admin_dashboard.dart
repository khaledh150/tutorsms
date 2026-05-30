import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/supabase_client.dart';
import 'school_detail_modal.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/school_model.dart';
import '../providers/super_admin_provider.dart';
import '../repositories/super_admin_repository.dart';

const _chartColors = [
  Color(0xFF6C5CE7),
  Color(0xFF00C853),
  Color(0xFF2196F3),
  Color(0xFFFFB300),
  Color(0xFFE91E63),
  Color(0xFF06C755),
];

class SuperAdminDashboard extends ConsumerStatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  ConsumerState<SuperAdminDashboard> createState() =>
      _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends ConsumerState<SuperAdminDashboard> {
  String _search = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final schoolsAsync = ref.watch(schoolsProvider);
    final trendAsync = ref.watch(attendanceTrendProvider);
    final activityAsync = ref.watch(recentActivityProvider);

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: schoolsAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (e, _) => Center(
              child: Text(e.toString(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.danger))),
          data: (schools) {
            final filtered = schools.where((s) {
              final matchSearch = _search.isEmpty ||
                  s.name.toLowerCase().contains(_search.toLowerCase()) ||
                  (s.ownerEmail ?? '')
                      .toLowerCase()
                      .contains(_search.toLowerCase());
              final matchStatus =
                  _statusFilter == 'all' || s.status == _statusFilter;
              return matchSearch && matchStatus;
            }).toList();

            final totals = _computeTotals(schools);

            return RefreshIndicator(
              onRefresh: () async {
                ref.read(schoolsProvider.notifier).refresh();
                ref.invalidate(attendanceTrendProvider);
                ref.invalidate(recentActivityProvider);
                ref.invalidate(expiringTrialsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildStatsGrid(totals),
                  const SizedBox(height: 16),
                  _buildCharts(schools, trendAsync),
                  const SizedBox(height: 16),
                  _buildExpiringTrialsWarning(),
                  _buildActivityAndSchools(filtered, activityAsync),
                ],
              ),
            );
          },
        ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('superAdminDashboard'.tr(),
                  style: AppTextStyles.displaySm
                      .copyWith(color: AppColors.primary)),
              const SizedBox(height: 2),
              Text('superAdminDesc'.tr(),
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: _showCreateSchoolDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text('createSchool'.tr()),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: _showAccountSettings,
          icon: const Icon(Icons.settings_rounded, size: 22, color: AppColors.textMuted),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.bgSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        ),
      ],
    );
  }

  void _showAccountSettings() {
    final user = ref.read(authProvider).valueOrNull;
    final usernameCtrl = TextEditingController(text: user?.username ?? '');
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    bool saving = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius2xl)),
          title: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.settings_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('accountSettings'.tr(), style: AppTextStyles.bodyBoldBase),
                    Text(user?.email ?? '', style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameCtrl,
                decoration: InputDecoration(
                  labelText: 'username'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'currentPassword'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'newPassword'.tr(),
                  hintText: 'leaveBlankToKeep'.tr(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: AppTextStyles.bodyXs.copyWith(color: AppColors.danger)),
                ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: saving ? null : () async {
                      if (currentPasswordCtrl.text.isEmpty) {
                        setDialogState(() => error = 'currentPasswordRequired'.tr());
                        return;
                      }
                      setDialogState(() { saving = true; error = null; });
                      try {
                        await supabase.auth.signInWithPassword(
                          email: user!.email!,
                          password: currentPasswordCtrl.text,
                        );
                        if (usernameCtrl.text.isNotEmpty) {
                          await supabase.rpc('update_staff_username', params: {'p_user_id': user.id, 'p_new_username': usernameCtrl.text.trim()});
                        }
                        if (newPasswordCtrl.text.isNotEmpty) {
                          await supabase.rpc('update_staff_password', params: {'p_user_id': user.id, 'p_new_password': newPasswordCtrl.text});
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('accountUpdated'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
                          );
                        }
                      } catch (e) {
                        setDialogState(() { error = e.toString().contains('Invalid') ? 'invalidPassword'.tr() : e.toString(); saving = false; });
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: Text(saving ? 'saving'.tr() : 'save'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, int> totals) {
    final stats = [
      ('saSchools'.tr(), totals['schools']!, Icons.business_rounded,
          AppColors.primary),
      ('totalStudents'.tr(), totals['students']!, Icons.people_rounded,
          AppColors.success),
      ('staff'.tr(), totals['staff']!, Icons.badge_rounded,
          AppColors.info),
      ('courses'.tr(), totals['courses']!, Icons.menu_book_rounded,
          AppColors.warning),
      ('saCheckins30d'.tr(), totals['checkins']!, Icons.access_time_rounded,
          AppColors.lineGreen),
      ('saLineMessages'.tr(), totals['lineMessages']!,
          Icons.chat_bubble_rounded, AppColors.danger),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: stats.map((s) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 48) / 3,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: s.$4,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(s.$3, color: Colors.white, size: 16),
                ),
                const SizedBox(height: 8),
                Text('${s.$2}',
                    style: AppTextStyles.bodyBoldBase
                        .copyWith(fontSize: 18)),
                Text(s.$1,
                    style: AppTextStyles.bodyXs
                        .copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCharts(
    List<SchoolHealth> schools,
    AsyncValue<List<Map<String, dynamic>>> trendAsync,
  ) {
    final trend = trendAsync.valueOrNull ?? [];
    final distribution = schools
        .where((s) => s.activeStudents > 0)
        .toList();

    return Column(
      children: [
        // Attendance trend
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('saAttendanceTrend'.tr(),
                  style: AppTextStyles.bodySemiBoldSm),
              const SizedBox(height: 12),
              if (trend.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                      child: Text('noDataForRange'.tr(),
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.textMuted))),
                )
              else
                SizedBox(
                  height: 160,
                  child: LineChart(LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: (trend.length / 5).ceilToDouble(),
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < 0 || i >= trend.length) {
                              return const SizedBox.shrink();
                            }
                            final d = trend[i]['date']?.toString() ?? '';
                            return Text(
                                d.length >= 10 ? d.substring(5) : d,
                                style: AppTextStyles.bodyXs
                                    .copyWith(fontSize: 9));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(trend.length, (i) {
                          return FlSpot(i.toDouble(),
                              (trend[i]['count'] as num).toDouble());
                        }),
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              AppColors.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  )),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Student distribution pie
        if (distribution.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('saStudentDistribution'.tr(),
                    style: AppTextStyles.bodySemiBoldSm),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: PieChart(PieChartData(
                    sections: List.generate(distribution.length, (i) {
                      final s = distribution[i];
                      return PieChartSectionData(
                        value: s.activeStudents.toDouble(),
                        title: '${s.activeStudents}',
                        color: _chartColors[i % _chartColors.length],
                        radius: 50,
                        titleStyle: AppTextStyles.bodyXs
                            .copyWith(color: Colors.white, fontSize: 10),
                      );
                    }),
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  )),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: List.generate(distribution.length, (i) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color:
                                _chartColors[i % _chartColors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(distribution[i].name,
                            style: AppTextStyles.bodyXs
                                .copyWith(fontSize: 10)),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),

        // School comparison bar chart
        if (schools.length > 1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('saSchoolComparison'.tr(), style: AppTextStyles.bodySemiBoldSm),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: BarChart(BarChartData(
                    barGroups: List.generate(schools.length, (i) {
                      final s = schools[i];
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: s.activeStudents.toDouble(), color: AppColors.primary, width: 8),
                        BarChartRodData(toY: s.checkins30d.toDouble(), color: const Color(0xFF6C5CE7), width: 8),
                        BarChartRodData(toY: s.staffCount.toDouble(), color: AppColors.info, width: 8),
                      ]);
                    }),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) {
                            final i = value.toInt();
                            if (i < 0 || i >= schools.length) return const SizedBox.shrink();
                            final name = schools[i].name;
                            return Text(name.length > 12 ? '${name.substring(0, 12)}…' : name,
                              style: AppTextStyles.bodyXs.copyWith(fontSize: 9));
                          },
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  )),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 16, children: [
                  _chartLegend(AppColors.primary, 'students'.tr()),
                  _chartLegend(const Color(0xFF6C5CE7), 'saCheckins30d'.tr()),
                  _chartLegend(AppColors.info, 'staff'.tr()),
                ]),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chartLegend(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: AppTextStyles.bodyXs.copyWith(fontSize: 10)),
    ]);
  }

  Widget _buildExpiringTrialsWarning() {
    final expiringAsync = ref.watch(expiringTrialsProvider);
    final expiring = expiringAsync.valueOrNull ?? [];
    if (expiring.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.timer_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 8),
            Text('trialEndingSoon'.tr(),
                style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.warning)),
          ]),
          const SizedBox(height: 8),
          ...expiring.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Expanded(child: Text(s.name, style: AppTextStyles.bodySm)),
                  Text(
                    '${s.trialDaysRemaining} ${'daysLeft'.tr()}',
                    style: AppTextStyles.bodyBoldSm.copyWith(
                        color: s.trialDaysRemaining <= 3
                            ? AppColors.danger
                            : AppColors.warning),
                  ),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildActivityAndSchools(
    List<SchoolHealth> filtered,
    AsyncValue<List<Map<String, dynamic>>> activityAsync,
  ) {
    final activity = activityAsync.valueOrNull ?? [];

    return Column(
      children: [
        // Recent activity
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('saRecentActivity'.tr(),
                  style: AppTextStyles.bodySemiBoldSm),
              const SizedBox(height: 8),
              if (activity.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: Text('saNoActivity'.tr(),
                          style: AppTextStyles.bodyXs
                              .copyWith(color: AppColors.textMuted))),
                )
              else
                ...activity.take(10).map((a) {
                  final action = (a['action'] as String? ?? '')
                      .replaceAll('_', ' ');
                  final created = a['created_at'] as String? ?? '';
                  final schoolName =
                      (a['metadata'] as Map?)?['school_name'] as String?;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: action.contains('created')
                                ? AppColors.success
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              action.isNotEmpty
                                  ? action[0].toUpperCase()
                                  : '?',
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(action,
                                  style: AppTextStyles.bodyXs.copyWith(
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${_timeAgo(created)}'
                                '${schoolName != null ? ' · $schoolName' : ''}',
                                style: AppTextStyles.bodyXs.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search + filters
        TextField(
          onChanged: (v) => setState(() => _search = v),
          decoration: InputDecoration(
            hintText: 'saSearchSchools'.tr(),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['all', 'active', 'suspended', 'archived']
                .map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('sa_$s'.tr()),
                        selected: _statusFilter == s,
                        onSelected: (_) =>
                            setState(() => _statusFilter = s),
                        selectedColor: AppColors.primary,
                        labelStyle: AppTextStyles.bodyXs.copyWith(
                          color: _statusFilter == s
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 12),

        // School cards
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.business_rounded,
                      size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text('saNoSchools'.tr(),
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          )
        else
          ...filtered.map((school) => _SchoolCard(
                school: school,
                onTap: () => _showSchoolDetail(school),
                onImpersonate: () => _handleImpersonate(school),
                onStatusChange: (status) =>
                    _handleStatusChange(school, status),
              )),

      ],
    );
  }

  void _showSchoolDetail(SchoolHealth school) {
    showSchoolDetailModal(
      context,
      school,
      onStatusChange: () {
        ref.read(schoolsProvider.notifier).refresh();
      },
      onImpersonate: () => _handleImpersonate(school),
    );
  }

  Future<void> _handleImpersonate(SchoolHealth school) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('saViewAsSchool'.tr()),
        content: Text(
            '${'saImpersonateConfirm'.tr()}\n\n${school.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.warning),
            child: Text('saViewAsSchool'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref
        .read(impersonationProvider.notifier)
        .startImpersonation(school.schoolId, school.name);

    // Reload the auth profile so all downstream providers see the new
    // school_id from the updated profiles row.
    ref.invalidate(authProvider);

    if (mounted) context.go('/dashboard');
  }

  void _showCreateSchoolDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateSchoolSheet(
        onCreated: () {
          ref.read(schoolsProvider.notifier).refresh();
          ref.invalidate(recentActivityProvider);
        },
      ),
    );
  }

  Future<void> _handleStatusChange(
      SchoolHealth school, String status) async {
    final statusLabel = status == 'active'
        ? 'saActivate'.tr()
        : status == 'suspended'
            ? 'saSuspend'.tr()
            : 'saArchive'.tr();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: status == 'active'
                    ? AppColors.successLight
                    : status == 'suspended'
                        ? AppColors.warningLight
                        : AppColors.bgSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'active'
                    ? Icons.check_circle_rounded
                    : status == 'suspended'
                        ? Icons.warning_rounded
                        : Icons.archive_rounded,
                size: 32,
                color: status == 'active'
                    ? AppColors.success
                    : status == 'suspended'
                        ? AppColors.warning
                        : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text('confirmAction'.tr(),
                style: AppTextStyles.displaySm),
            const SizedBox(height: 8),
            Text(
              '$statusLabel "${school.name}"?',
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
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
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: status == 'active'
                        ? AppColors.success
                        : status == 'suspended'
                            ? AppColors.warning
                            : AppColors.textMuted,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                  ),
                  child: Text(statusLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final repo = ref.read(superAdminRepositoryProvider);
    await repo.updateSchoolStatus(school.schoolId, status);
    ref.read(schoolsProvider.notifier).refresh();
  }

  Map<String, int> _computeTotals(List<SchoolHealth> schools) {
    var activeSchools = 0;
    var students = 0;
    var staff = 0;
    var courses = 0;
    var checkins = 0;
    var lineMessages = 0;
    for (final s in schools) {
      if (s.status == 'active') activeSchools++;
      students += s.activeStudents;
      staff += s.staffCount;
      courses += s.courseCount;
      checkins += s.checkins30d;
      lineMessages += s.lineMessages30d;
    }
    return {
      'schools': activeSchools,
      'students': students,
      'staff': staff,
      'courses': courses,
      'checkins': checkins,
      'lineMessages': lineMessages,
    };
  }
}

// ---------------------------------------------------------------------------

String _timeAgo(String iso) {
  try {
    final d = DateTime.parse(iso);
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  } catch (_) {
    return iso;
  }
}

// ---------------------------------------------------------------------------
// School Card
// ---------------------------------------------------------------------------

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.school,
    required this.onTap,
    required this.onImpersonate,
    required this.onStatusChange,
  });

  final SchoolHealth school;
  final VoidCallback onTap;
  final VoidCallback onImpersonate;
  final void Function(String status) onStatusChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Center(
                        child: Text(
                          school.name.isNotEmpty
                              ? school.name[0].toUpperCase()
                              : '?',
                          style: AppTextStyles.bodyBoldBase
                              .copyWith(color: Colors.white, fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(school.name,
                              style: AppTextStyles.bodyBoldSm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              _StatusBadge(status: school.status),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusFull),
                                ),
                                child: Text(school.plan,
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600)),
                              ),
                              if (school.isOnTrial) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: school.isTrialEndingSoon
                                        ? AppColors.dangerLight
                                        : AppColors.infoLight,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull),
                                  ),
                                  child: Text(
                                      '${school.trialDaysRemaining}d trial left',
                                      style: AppTextStyles.bodyXs.copyWith(
                                          color: school.isTrialEndingSoon
                                              ? AppColors.danger
                                              : AppColors.info,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                              if (school.setupPercent < 100) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusFull),
                                  ),
                                  child: Text(
                                      'Setup ${school.setupPercent}%',
                                      style: AppTextStyles.bodyXs.copyWith(
                                          color: AppColors.warning,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Quick metrics
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${school.activeStudents}',
                            style: AppTextStyles.bodyBoldSm),
                        Text('students'.tr(),
                            style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.textMuted, fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Quick stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${'saTeam'.tr()}: ${school.totalTeam}/${school.maxStaff}',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted),
                    ),
                    Text(
                      '30d: ${school.checkins30d} check-ins · LINE: ${school.lineMessages30d}',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Divider(color: AppColors.borderLight, height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${'saOwner'.tr()}: ${school.ownerName ?? '—'}',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (school.ownerLastLogin != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          _timeAgo(school.ownerLastLogin!),
                          style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          'saNeverLoggedIn'.tr(),
                          style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.danger,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 28,
                      child: TextButton.icon(
                        onPressed: onImpersonate,
                        icon: const Icon(Icons.visibility_rounded,
                            size: 14),
                        label: Text('saViewAsSchool'.tr(),
                            style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.warning,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'active'
        ? AppColors.success
        : status == 'suspended'
            ? AppColors.warning
            : AppColors.textMuted;
    final icon = status == 'active'
        ? Icons.check_circle_rounded
        : status == 'suspended'
            ? Icons.warning_rounded
            : Icons.archive_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(status,
              style: AppTextStyles.bodyXs.copyWith(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create School Sheet
// ---------------------------------------------------------------------------

class _CreateSchoolSheet extends StatefulWidget {
  const _CreateSchoolSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  State<_CreateSchoolSheet> createState() => _CreateSchoolSheetState();
}

class _CreateSchoolSheetState extends State<_CreateSchoolSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  String _plan = 'basic';
  int _maxStudents = 50;
  int _maxStaff = 5;
  String? _trialDuration;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'schoolNameRequired'.tr());
      return;
    }
    if (_adminEmailCtrl.text.trim().isEmpty || _adminPasswordCtrl.text.isEmpty) {
      setState(() => _error = 'ownerAccountRequired'.tr());
      return;
    }
    setState(() { _creating = true; _error = null; });
    try {
      final repo = SuperAdminRepository();
      await repo.createSchool(
        name: _nameCtrl.text.trim(),
        contactEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        plan: _plan,
        maxStudents: _maxStudents,
        maxStaff: _maxStaff,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        adminEmail: _adminEmailCtrl.text.trim(),
        adminPassword: _adminPasswordCtrl.text,
        adminName: _adminNameCtrl.text.trim(),
        trialDuration: _trialDuration,
      );
      widget.onCreated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('schoolCreated'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _creating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd));

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle + header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)))),
                Row(
                  children: [
                    Expanded(child: Text('createSchool'.tr(), style: AppTextStyles.displaySm.copyWith(color: AppColors.primary))),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 22), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('createSchoolDesc'.tr(), style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const Divider(height: 16),
          // Scrollable form
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // School details
                  Text('schoolDetails'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: '${'schoolName'.tr()} *', border: border)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'saContactEmail'.tr(), border: border))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'saContactPhone'.tr(), border: border))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: _addressCtrl, decoration: InputDecoration(labelText: 'saAddress'.tr(), border: border)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _plan,
                        decoration: InputDecoration(labelText: 'saPlan'.tr(), border: border),
                        items: ['free', 'basic', 'pro', 'enterprise'].map((p) => DropdownMenuItem(value: p, child: Text(p[0].toUpperCase() + p.substring(1)))).toList(),
                        onChanged: (v) => setState(() => _plan = v ?? 'basic'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: TextFormField(initialValue: '$_maxStudents', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'saMaxStudents'.tr(), border: border), onChanged: (v) => _maxStudents = int.tryParse(v) ?? 50)),
                    const SizedBox(width: 8),
                    SizedBox(width: 90, child: TextFormField(initialValue: '$_maxStaff', keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'saMaxStaff'.tr(), border: border), onChanged: (v) => _maxStaff = int.tryParse(v) ?? 5)),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: _notesCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'notes'.tr(), border: border)),

                  // Trial period
                  const SizedBox(height: 16),
                  Text('trialPeriod'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('trialPeriodHint'.tr(), style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _trialChip(null, 'noTrial'.tr()),
                    _trialChip('7d', '7 ${'days'.tr()}'),
                    _trialChip('30d', '30 ${'days'.tr()}'),
                    _trialChip('6m', '6 ${'months'.tr()}'),
                    _trialChip('1y', '1 ${'year'.tr()}'),
                  ]),

                  // Owner account
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text('saSchoolOwnerAccount'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('saSchoolOwnerDesc'.tr(), style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 8),
                  TextField(controller: _adminNameCtrl, decoration: InputDecoration(labelText: '${'schoolAdminName'.tr()} *', border: border)),
                  const SizedBox(height: 10),
                  TextField(controller: _adminEmailCtrl, decoration: InputDecoration(labelText: '${'schoolAdminEmail'.tr()} *', border: border)),
                  const SizedBox(height: 10),
                  TextField(controller: _adminPasswordCtrl, obscureText: true, decoration: InputDecoration(labelText: '${'schoolAdminPassword'.tr()} *', border: border, helperText: 'minPasswordLength'.tr())),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      child: Text(_error!, style: AppTextStyles.bodyXs.copyWith(color: AppColors.danger)),
                    ),
                  ],

                  // Submit
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _creating ? null : _submit,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: _creating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('createSchool'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trialChip(String? value, String label) {
    final selected = _trialDuration == value;
    return GestureDetector(
      onTap: () => setState(() {
        _trialDuration = value;
        if (value != null) _plan = 'free';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: selected ? AppColors.primary : AppColors.borderLight),
        ),
        child: Text(label, style: AppTextStyles.bodyXs.copyWith(color: selected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
