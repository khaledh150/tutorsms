import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/school_model.dart';
import '../providers/super_admin_provider.dart';

const _setupItems = [
  ('has_logo', 'saSetupLogo'),
  ('has_line_config', 'saSetupLine'),
  ('has_students', 'saSetupStudents'),
  ('has_courses', 'saSetupCourses'),
  ('has_checkin', 'saSetupCheckin'),
  ('has_staff', 'saSetupStaff'),
];

void showSchoolDetailModal(
  BuildContext context,
  SchoolHealth school, {
  VoidCallback? onStatusChange,
  VoidCallback? onImpersonate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollCtrl) => _SchoolDetailModal(
        school: school,
        scrollController: scrollCtrl,
        onStatusChange: onStatusChange,
        onImpersonate: onImpersonate,
      ),
    ),
  );
}

class _SchoolDetailModal extends ConsumerStatefulWidget {
  const _SchoolDetailModal({
    required this.school,
    required this.scrollController,
    this.onStatusChange,
    this.onImpersonate,
  });

  final SchoolHealth school;
  final ScrollController scrollController;
  final VoidCallback? onStatusChange;
  final VoidCallback? onImpersonate;

  @override
  ConsumerState<_SchoolDetailModal> createState() => _SchoolDetailModalState();
}

class _SchoolDetailModalState extends ConsumerState<_SchoolDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _maxStudentsCtrl;
  late TextEditingController _maxStaffCtrl;
  String _plan = 'basic';

  List<Map<String, dynamic>> _staff = [];
  List<Map<String, dynamic>> _activity = [];
  List<Map<String, dynamic>> _weeklyCheckins = [];
  bool _staffLoading = true;
  bool _activityLoading = true;

  bool _showAddMember = false;
  final _newNameCtrl = TextEditingController();
  final _newEmailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  String _newRole = 'staff';
  bool _addingMember = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 1 && _staffLoading) _loadStaff();
      if (_tabController.index == 2 && _activityLoading) _loadActivity();
    });

    final s = widget.school;
    _nameCtrl = TextEditingController(text: s.name);
    _emailCtrl = TextEditingController(text: s.contactEmail ?? '');
    _phoneCtrl = TextEditingController(text: s.contactPhone ?? '');
    _addressCtrl = TextEditingController(text: s.address ?? '');
    _notesCtrl = TextEditingController(text: s.notes ?? '');
    _maxStudentsCtrl = TextEditingController(text: '${s.maxStudents}');
    _maxStaffCtrl = TextEditingController(text: '${s.maxStaff}');
    _plan = s.plan;

    _loadStaff();
    _loadWeeklyCheckins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _maxStudentsCtrl.dispose();
    _maxStaffCtrl.dispose();
    _newNameCtrl.dispose();
    _newEmailCtrl.dispose();
    _newPasswordCtrl.dispose();
    super.dispose();
  }

  String get _schoolId => widget.school.schoolId;

  Future<void> _loadStaff() async {
    try {
      final profiles = await supabase
          .from('profiles')
          .select('id,email,full_name,username,role')
          .eq('school_id', _schoolId)
          .neq('role', 'superadmin')
          .order('role', ascending: false);

      final ids = (profiles as List).map((p) => p['id'] as String).toList();
      List<dynamic> logins = [];
      if (ids.isNotEmpty) {
        try {
          logins = await supabase.rpc('get_users_last_login', params: {'user_ids': ids}) ?? [];
        } catch (_) {}
      }
      final loginMap = <String, String>{};
      for (final u in logins) {
        loginMap[u['id'] as String] = u['last_sign_in_at']?.toString() ?? '';
      }

      if (mounted) {
        setState(() {
          _staff = (profiles as List).map((p) {
            final m = Map<String, dynamic>.from(p);
            m['last_sign_in_at'] = loginMap[m['id']];
            return m;
          }).toList();
          _staffLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _staffLoading = false);
    }
  }

  Future<void> _loadActivity() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final results = await Future.wait([
        supabase.from('attendance').select('id,attended_at_ts')
            .eq('school_id', _schoolId).gte('attended_at_ts', since)
            .order('attended_at_ts', ascending: false).limit(20),
        supabase.from('enrollments').select('id,created_at,status')
            .eq('school_id', _schoolId).gte('created_at', since)
            .order('created_at', ascending: false).limit(15),
        supabase.from('students').select('id,created_at,nick_name,first_name')
            .eq('school_id', _schoolId).gte('created_at', since)
            .order('created_at', ascending: false).limit(10),
        supabase.from('audit_log').select('id,action,created_at,metadata')
            .eq('school_id', _schoolId)
            .order('created_at', ascending: false).limit(15),
      ]);

      final activities = <Map<String, dynamic>>[];
      for (final c in (results[0] as List)) {
        activities.add({'type': 'checkin', 'desc': 'Check-in', 'ts': c['attended_at_ts']});
      }
      for (final e in (results[1] as List)) {
        activities.add({'type': 'enrollment', 'desc': 'New enrollment (${e['status']})', 'ts': e['created_at']});
      }
      for (final s in (results[2] as List)) {
        activities.add({'type': 'student', 'desc': 'Student added: ${s['nick_name'] ?? s['first_name'] ?? '—'}', 'ts': s['created_at']});
      }
      for (final a in (results[3] as List)) {
        activities.add({'type': 'audit', 'desc': (a['action'] as String?)?.replaceAll('_', ' ') ?? '', 'ts': a['created_at']});
      }
      activities.sort((a, b) => (b['ts'] as String).compareTo(a['ts'] as String));

      if (mounted) setState(() { _activity = activities.take(50).toList(); _activityLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadWeeklyCheckins() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
      final data = await supabase.from('attendance').select('attended_at_ts')
          .eq('school_id', _schoolId).gte('attended_at_ts', since)
          .order('attended_at_ts');
      final byDay = <String, int>{};
      for (final a in (data as List)) {
        final d = DateTime.tryParse(a['attended_at_ts'] as String? ?? '');
        if (d != null) {
          final key = '${d.month}/${d.day}';
          byDay[key] = (byDay[key] ?? 0) + 1;
        }
      }
      if (mounted) {
        setState(() => _weeklyCheckins = byDay.entries
            .map((e) => {'day': e.key, 'count': e.value})
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _saveSchoolEdits() async {
    setState(() => _saving = true);
    try {
      await supabase.from('schools').update({
        'name': _nameCtrl.text.trim(),
        'plan': _plan,
        'max_students': int.tryParse(_maxStudentsCtrl.text) ?? 50,
        'max_staff': int.tryParse(_maxStaffCtrl.text) ?? 5,
        'contact_email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      }).eq('id', _schoolId);
      ref.read(schoolsProvider.notifier).refresh();
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('saved'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _changeStatus(String status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr()),
        content: Text('${'saStatusConfirm'.tr()} ${status.toUpperCase()}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: status == 'active' ? AppColors.success : status == 'suspended' ? AppColors.warning : AppColors.textMuted),
            child: Text(status == 'active' ? 'saActivate'.tr() : status == 'suspended' ? 'saSuspend'.tr() : 'saArchive'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(superAdminRepositoryProvider).updateSchoolStatus(_schoolId, status);
    ref.read(schoolsProvider.notifier).refresh();
    widget.onStatusChange?.call();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addStaffMember() async {
    if (_newEmailCtrl.text.trim().isEmpty || _newPasswordCtrl.text.isEmpty) return;
    setState(() => _addingMember = true);
    try {
      final raw = _newEmailCtrl.text.trim().toLowerCase();
      final email = raw.contains('@') ? raw : '$raw@school.local';
      final username = raw.contains('@') ? raw.split('@').first : raw;

      await supabase.rpc('create_staff_user', params: {
        'p_email': email,
        'p_password': _newPasswordCtrl.text,
        'p_full_name': _newNameCtrl.text.trim(),
        'p_role': _newRole,
      });

      final newProfiles = await supabase.from('profiles').select('id').eq('email', email).limit(1);
      if ((newProfiles as List).isNotEmpty) {
        await supabase.from('profiles').update({
          'school_id': _schoolId,
          'username': username,
        }).eq('id', newProfiles[0]['id']);
      }

      _newNameCtrl.clear();
      _newEmailCtrl.clear();
      _newPasswordCtrl.clear();
      setState(() { _showAddMember = false; _addingMember = false; });
      _loadStaff();
      ref.read(schoolsProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('userAdded'.tr()), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _addingMember = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _editStaff(Map<String, dynamic> staff) async {
    final usernameCtrl = TextEditingController(text: staff['username'] as String? ?? '');
    final passwordCtrl = TextEditingController();
    String role = staff['role'] as String? ?? 'staff';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius2xl)),
          title: Text(staff['full_name'] as String? ?? staff['username'] as String? ?? '', style: AppTextStyles.bodyBoldBase.copyWith(color: AppColors.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameCtrl, decoration: InputDecoration(labelText: 'username'.tr())),
              const SizedBox(height: 12),
              TextField(controller: passwordCtrl, obscureText: true, decoration: InputDecoration(labelText: 'newPassword'.tr(), hintText: 'leaveBlankToKeep'.tr())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                decoration: InputDecoration(labelText: 'role'.tr()),
                items: ['owner', 'admin', 'staff'].map((r) => DropdownMenuItem(value: r, child: Text('role_$r'.tr()))).toList(),
                onChanged: (v) => setDialogState(() => role = v ?? role),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
            FilledButton(
              onPressed: saving ? null : () async {
                setDialogState(() => saving = true);
                try {
                  await supabase.from('profiles').update({'role': role}).eq('id', staff['id']);
                  if (usernameCtrl.text.isNotEmpty && usernameCtrl.text != staff['username']) {
                    await supabase.rpc('update_staff_username', params: {'p_user_id': staff['id'], 'p_new_username': usernameCtrl.text.trim()});
                  }
                  if (passwordCtrl.text.isNotEmpty) {
                    await supabase.rpc('update_staff_password', params: {'p_user_id': staff['id'], 'p_new_password': passwordCtrl.text});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadStaff();
                  ref.read(schoolsProvider.notifier).refresh();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
                setDialogState(() => saving = false);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              child: Text(saving ? 'saving'.tr() : 'save'.tr()),
            ),
          ],
        ),
      ),
    );
    usernameCtrl.dispose();
    passwordCtrl.dispose();
  }

  Future<void> _removeStaff(Map<String, dynamic> staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr()),
        content: Text('confirmRemoveStaff'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('cancel'.tr())),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text('remove'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await supabase.from('profiles').delete().eq('id', staff['id']);
    _loadStaff();
    ref.read(schoolsProvider.notifier).refresh();
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'saNeverLoggedIn'.tr();
    final d = DateTime.tryParse(dateStr);
    if (d == null) return dateStr;
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}d';
    return '${diff.inDays ~/ 30}mo';
  }

  Color _activityColor(String type) {
    switch (type) {
      case 'checkin': return AppColors.success;
      case 'enrollment': return AppColors.primary;
      case 'student': return AppColors.info;
      case 'line': return const Color(0xFF06C755);
      default: return AppColors.textMuted;
    }
  }

  int get _healthScore {
    final s = widget.school;
    final checklist = s.setupChecklist;
    final setupDone = checklist.values.where((v) => v).length;
    return ((s.ownerLastLogin != null ? 25 : 0) +
        (s.activeStudents > 0 ? 20 : 0) +
        (s.checkins30d > 0 ? 20 : 0) +
        (s.courseCount > 0 ? 15 : 0) +
        (s.lineMessages30d > 0 ? 10 : 0) +
        (checklist.isEmpty ? 0 : (setupDone / _setupItems.length * 10).round()))
        .clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.school;
    final healthColor = _healthScore >= 70 ? AppColors.success : _healthScore >= 40 ? AppColors.warning : AppColors.danger;
    final ownerCount = _staff.where((m) => m['role'] == 'owner').length;
    final adminCount = _staff.where((m) => m['role'] == 'admin').length;
    final staffOnlyCount = _staff.where((m) => m['role'] == 'staff').length;
    final setupDone = s.setupChecklist.values.where((v) => v).length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                  child: Center(child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?', style: AppTextStyles.bodyBoldBase.copyWith(color: Colors.white, fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: AppTextStyles.bodyBoldBase, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          _badge(s.status == 'active' ? 'saActive'.tr() : s.status == 'suspended' ? 'saSuspended'.tr() : 'saArchived'.tr(),
                            s.status == 'active' ? AppColors.success : s.status == 'suspended' ? AppColors.warning : AppColors.textMuted),
                          const SizedBox(width: 4),
                          _badge('${'saHealthScore'.tr()}: $_healthScore', healthColor),
                        ],
                      ),
                    ],
                  ),
                ),
                if (widget.onImpersonate != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onImpersonate!();
                    },
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: Text('saViewAsSchool'.tr(), style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700)),
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
                IconButton(icon: const Icon(Icons.close_rounded, size: 22), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            labelStyle: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: AppTextStyles.bodyXs,
            tabs: [
              Tab(text: 'overview'.tr()),
              Tab(text: '${'saTeam'.tr()} (${_staff.length})'),
              Tab(text: 'saSchoolActivity'.tr()),
              Tab(text: '${'saSetup'.tr()} ($setupDone/${_setupItems.length})'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(s, ownerCount, staffOnlyCount),
                _buildStaffTab(ownerCount, adminCount, staffOnlyCount),
                _buildActivityTab(),
                _buildSetupTab(s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
      child: Text(text, style: AppTextStyles.bodyXs.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 9)),
    );
  }

  // ─── OVERVIEW TAB ───

  Widget _buildOverviewTab(SchoolHealth s, int ownerCount, int staffOnlyCount) {
    if (_editing) return _buildEditForm();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Stats grid
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _miniStat('students'.tr(), s.activeStudents, s.maxStudents, AppColors.success),
            _miniStat('saOwner'.tr(), ownerCount, null, AppColors.primary),
            _miniStat('staff'.tr(), staffOnlyCount, null, AppColors.info),
            _miniStat('saTeamTotal'.tr(), _staff.length, s.maxStaff, AppColors.warning),
            _miniStat('saCheckins'.tr(), s.checkins30d, null, const Color(0xFF06C755)),
            _miniStat('saLineMsgs'.tr(), s.lineMessages30d, null, AppColors.danger),
          ],
        ),
        const SizedBox(height: 16),
        // Info grid
        _infoRow('saPlan'.tr(), s.plan),
        _infoRow('saOwner'.tr(), s.ownerName ?? '—'),
        _infoRow('saLastLogin'.tr(), _timeAgo(s.ownerLastLogin), color: s.ownerLastLogin != null ? AppColors.success : AppColors.danger),
        _infoRow('saContactEmail'.tr(), s.contactEmail ?? '—'),
        _infoRow('saContactPhone'.tr(), s.contactPhone ?? '—'),
        _infoRow('saCreated'.tr(), s.createdAt.length >= 10 ? s.createdAt.substring(0, 10) : s.createdAt),
        // Weekly chart
        if (_weeklyCheckins.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('saWeeklyCheckins'.tr(), style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 9)),
          const SizedBox(height: 4),
          SizedBox(
            height: 100,
            child: BarChart(BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= _weeklyCheckins.length) return const SizedBox.shrink();
                  return Text(_weeklyCheckins[i]['day'] as String, style: AppTextStyles.bodyXs.copyWith(fontSize: 8));
                })),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(_weeklyCheckins.length, (i) {
                return BarChartGroupData(x: i, barRods: [
                  BarChartRodData(toY: (_weeklyCheckins[i]['count'] as int).toDouble(), color: AppColors.primary, width: 12, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                ]);
              }),
            )),
          ),
        ],
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        // Actions
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _editing = true),
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: Text('edit'.tr()),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
            ),
            const Spacer(),
            if (s.status != 'active')
              _statusButton('saActivate'.tr(), AppColors.success, () => _changeStatus('active')),
            if (s.status != 'suspended')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _statusButton('saSuspend'.tr(), AppColors.warning, () => _changeStatus('suspended')),
              ),
            if (s.status != 'archived')
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _statusButton('saArchive'.tr(), AppColors.textMuted, () => _changeStatus('archived')),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: 'schoolName'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _plan,
                decoration: InputDecoration(labelText: 'saPlan'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
                items: ['free', 'basic', 'pro', 'enterprise'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _plan = v ?? _plan),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _maxStudentsCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'saMaxStudents'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _maxStaffCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'saMaxStaff'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: 'saContactEmail'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: 'saContactPhone'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(controller: _addressCtrl, decoration: InputDecoration(labelText: 'saAddress'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
        const SizedBox(height: 12),
        TextField(controller: _notesCtrl, maxLines: 2, decoration: InputDecoration(labelText: 'notes'.tr(), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _saveSchoolEdits,
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(_saving ? 'saving'.tr() : 'save'.tr()),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => setState(() => _editing = false),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24)),
              child: Text('cancel'.tr()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _miniStat(String label, int value, int? max, Color color) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 80) / 3,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppColors.borderLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(text: TextSpan(children: [
              TextSpan(text: '$value', style: AppTextStyles.bodyBoldBase.copyWith(fontSize: 16)),
              if (max != null) TextSpan(text: '/$max', style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
            ])),
            Text(label, style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 9)),
            if (max != null && max > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: (value / max).clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: AppColors.borderLight,
                    valueColor: AlwaysStoppedAnimation(value / max > 0.9 ? AppColors.danger : color),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w700))),
          Expanded(child: Text(value, style: AppTextStyles.bodySm.copyWith(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _statusButton(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 32,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 10), textStyle: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700)),
        child: Text(label),
      ),
    );
  }

  // ─── STAFF TAB ───

  Widget _buildStaffTab(int ownerCount, int adminCount, int staffOnlyCount) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Role counts + add button
        Row(
          children: [
            _badge('$ownerCount ${'roleOwner'.tr()}', AppColors.primary),
            _badge('$adminCount ${'roleAdmin'.tr()}', AppColors.primary),
            _badge('$staffOnlyCount ${'roleStaff'.tr()}', AppColors.info),
            const Spacer(),
            SizedBox(
              height: 32,
              child: FilledButton.icon(
                onPressed: () => setState(() => _showAddMember = true),
                icon: const Icon(Icons.add, size: 16),
                label: Text('addUser'.tr()),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Add member form
        if (_showAddMember) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.bgSurface, borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppColors.primary.withValues(alpha: 0.3))),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _newNameCtrl, decoration: InputDecoration(hintText: 'name'.tr(), isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))))),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: _newRole, isDense: true,
                        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
                        items: ['staff', 'admin', 'owner'].map((r) => DropdownMenuItem(value: r, child: Text('role_$r'.tr(), style: AppTextStyles.bodyXs))).toList(),
                        onChanged: (v) => setState(() => _newRole = v ?? 'staff'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: _newEmailCtrl, decoration: InputDecoration(hintText: '${'username'.tr()} *', isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
                const SizedBox(height: 8),
                TextField(controller: _newPasswordCtrl, obscureText: true, decoration: InputDecoration(hintText: '${'tempPassword'.tr()} *', isDense: true, contentPadding: const EdgeInsets.all(10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _addingMember ? null : _addStaffMember,
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        child: Text(_addingMember ? 'saving'.tr() : 'addUser'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(onPressed: () => setState(() => _showAddMember = false), child: Text('cancel'.tr())),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Staff list
        if (_staffLoading)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_staff.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('noUsers'.tr(), style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted))))
        else
          ..._staff.map((m) => _buildStaffCard(m)),
      ],
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> m) {
    final name = m['full_name'] as String? ?? m['username'] as String? ?? '—';
    final role = m['role'] as String? ?? 'staff';
    final isSchoolOwner = m['id'] == widget.school.ownerId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppColors.borderLight)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: role == 'staff' ? AppColors.info : AppColors.primary,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: AppTextStyles.bodyXs.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, style: AppTextStyles.bodyBoldSm, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isSchoolOwner) ...[const SizedBox(width: 4), Icon(Icons.shield_rounded, size: 14, color: AppColors.primary)],
                  ],
                ),
                Text(
                  '@${m['username'] ?? (m['email'] as String?)?.split('@').first ?? '—'} · ${'role_$role'.tr()} · ${_timeAgo(m['last_sign_in_at'] as String?)}',
                  style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 10),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.primary), onPressed: () => _editStaff(m), visualDensity: VisualDensity.compact),
          if (!isSchoolOwner)
            IconButton(icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.danger), onPressed: () => _removeStaff(m), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }

  // ─── ACTIVITY TAB ───

  Widget _buildActivityTab() {
    if (_activityLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_activity.isEmpty) {
      return Center(child: Text('saNoActivity'.tr(), style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted)));
    }
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _activity.length,
      itemBuilder: (_, i) {
        final a = _activity[i];
        final type = a['type'] as String;
        final desc = a['desc'] as String;
        final ts = a['ts'] as String? ?? '';
        final d = DateTime.tryParse(ts);
        final timeStr = d != null ? '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}' : '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _activityColor(type),
                child: Text(type[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc, style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(timeStr, style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 9)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _activityColor(type).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(AppTheme.radiusFull)),
                child: Text(type.replaceAll('_', ' '), style: AppTextStyles.bodyXs.copyWith(color: _activityColor(type), fontWeight: FontWeight.w700, fontSize: 8)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── SETUP TAB ───

  Widget _buildSetupTab(SchoolHealth s) {
    final checklist = s.setupChecklist;
    final done = checklist.values.where((v) => v).length;
    final total = _setupItems.length;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('saSetupProgress'.tr(), style: AppTextStyles.bodyBoldSm),
            Text('$done/$total', style: AppTextStyles.bodyBoldSm.copyWith(color: done == total ? AppColors.success : AppColors.warning)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total > 0 ? done / total : 0,
            minHeight: 8,
            backgroundColor: AppColors.borderLight,
            valueColor: AlwaysStoppedAnimation(done == total ? AppColors.success : AppColors.warning),
          ),
        ),
        const SizedBox(height: 16),
        for (final item in _setupItems)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (checklist[item.$1] ?? false) ? AppColors.successLight : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: (checklist[item.$1] ?? false) ? AppColors.success.withValues(alpha: 0.3) : AppColors.borderLight),
            ),
            child: Row(
              children: [
                Icon(
                  (checklist[item.$1] ?? false) ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 20,
                  color: (checklist[item.$1] ?? false) ? AppColors.success : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(item.$2.tr(), style: AppTextStyles.bodySm.copyWith(
                  color: (checklist[item.$1] ?? false) ? AppColors.success : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ),
        if (done < total)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('saSetupHint'.tr(), style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted)),
          ),
      ],
    );
  }
}
