import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/providers/course_provider.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../../students/providers/student_provider.dart';
import '../../messaging/views/line_settings_sheet.dart' show LineSettingsInline;
import '../repositories/settings_repository.dart';

final _settingsRepoProvider = Provider((ref) => SettingsRepository());

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _profiles = [];
  bool _loading = true;
  String? _error;

  // Invite form
  bool _showInvite = false;
  final _inviteEmail = TextEditingController();
  final _inviteName = TextEditingController();
  final _invitePw = TextEditingController();
  String _inviteRole = 'staff';
  bool _inviting = false;

  // Edit (inline)
  Map<String, dynamic>? _editRow;
  String? _editingProfileId;
  final _editUsername = TextEditingController();
  final _editPassword = TextEditingController();
  final _editName = TextEditingController();
  String _editRole = 'staff';
  bool _saving = false;

  // Activity Log
  List<Map<String, dynamic>> _logEntries = [];
  bool _logLoading = false;
  int _logOffset = 0;
  bool _logHasMore = true;
  String _logFilter = '';
  String? _expandedLogId;

  static const _logPageSize = 50;

  static const _actionLabelKeys = {
    'attendance.insert': 'actionCheckIn',
    'attendance.cancel': 'actionCancelAttendance',
    'attendance.delete': 'actionDeleteAttendance',
    'enrollment.update': 'actionUpdateEnrollment',
    'payment.insert': 'actionAddPayment',
    'payment.delete': 'actionDeletePayment',
    'profile.role_change': 'actionRoleChange',
  };

  static const _actionIcons = {
    'attendance.insert': Icons.login_rounded,
    'attendance.cancel': Icons.cancel_rounded,
    'attendance.delete': Icons.delete_rounded,
    'enrollment.update': Icons.edit_rounded,
    'payment.insert': Icons.payment_rounded,
    'payment.delete': Icons.payment_rounded,
    'profile.role_change': Icons.person_rounded,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteEmail.dispose();
    _inviteName.dispose();
    _invitePw.dispose();
    _editUsername.dispose();
    _editPassword.dispose();
    _editName.dispose();
    super.dispose();
  }

  Future<void> _refreshProfiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(authProvider).valueOrNull;
      final repo = ref.read(_settingsRepoProvider);
      final data = await repo.fetchProfiles(schoolId: user?.schoolId);
      var filtered = data.where((p) => p['role'] != 'superadmin').toList();
      if (user != null && !user.isOwner) {
        filtered = filtered
            .where((p) => p['role'] != 'owner')
            .toList();
      }
      setState(() {
        _profiles = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchLogs({int offset = 0}) async {
    setState(() => _logLoading = true);
    try {
      final repo = ref.read(_settingsRepoProvider);
      final entries = await repo.fetchAuditLog(
        offset: offset,
        limit: _logPageSize,
        actionFilter: _logFilter.isEmpty ? null : _logFilter,
      );

      final allUserIds = <String>{};
      final allStudentIds = <String>{};
      final allCourseIds = <String>{};
      for (final e in entries) {
        final aid = e['actor_id'] as String?;
        if (aid != null) allUserIds.add(aid);
        final meta = e['metadata'] as Map<String, dynamic>?;
        if (meta != null) {
          final sid = meta['student_id'] as String?;
          final cid = meta['course_id'] as String?;
          final cby = meta['cancelled_by'] as String?;
          final sby = meta['submitted_by'] as String?;
          if (sid != null) allStudentIds.add(sid);
          if (cid != null) allCourseIds.add(cid);
          if (cby != null) allUserIds.add(cby);
          if (sby != null) allUserIds.add(sby);
        }
      }
      final actorNames = await repo.fetchActorNames(allUserIds.toList());
      final studentNames = allStudentIds.isNotEmpty
          ? await ref.read(studentRepositoryProvider).fetchStudentNameMap(allStudentIds.toList())
          : <String, String>{};
      final courses = ref.read(coursesProvider).valueOrNull ?? [];
      final courseNames = {for (final c in courses) c.id: c.name};

      for (final e in entries) {
        e['actor_name'] = actorNames[e['actor_id']] ?? 'System';
        final meta = e['metadata'] as Map<String, dynamic>?;
        if (meta != null) {
          final sid = meta['student_id'] as String?;
          final cid = meta['course_id'] as String?;
          final cby = meta['cancelled_by'] as String?;
          final sby = meta['submitted_by'] as String?;
          if (sid != null) e['_student'] = studentNames[sid] ?? meta['nick_name'] ?? meta['first_name'];
          if (cid != null) e['_course'] = courseNames[cid];
          if (cby != null) e['_cancelledBy'] = actorNames[cby];
          if (sby != null) e['_submittedBy'] = actorNames[sby];
          if (meta['attended_at'] != null) {
            final d = DateTime.tryParse(meta['attended_at'].toString())?.toLocal();
            if (d != null) e['_time'] = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
          }
          if (meta['purchased_hours'] != null) e['_hours'] = meta['purchased_hours'];
          if (meta['old_hours'] != null) e['_oldHours'] = meta['old_hours'];
          if (meta['new_hours'] != null) e['_newHours'] = meta['new_hours'];
          if (meta['name'] != null) e['_name'] = meta['name'];
        }
      }

      setState(() {
        if (offset == 0) {
          _logEntries = entries;
        } else {
          _logEntries.addAll(entries);
        }
        _logHasMore = entries.length == _logPageSize;
        _logOffset = offset + entries.length;
        _logLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _logLoading = false;
      });
    }
  }

  Future<void> _handleInvite() async {
    if (_inviteEmail.text.isEmpty || _invitePw.text.isEmpty) return;
    if (_invitePw.text.length < 6) return;
    setState(() => _inviting = true);
    try {
      final repo = ref.read(_settingsRepoProvider);
      await repo.createStaffUser(
        email: _inviteEmail.text.trim().toLowerCase(),
        password: _invitePw.text,
        fullName: _inviteName.text.trim(),
        role: _inviteRole,
      );
      _inviteEmail.clear();
      _inviteName.clear();
      _invitePw.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('userAdded'.tr())));
      }
      _refreshProfiles();
    } catch (e) {
      setState(() => _error = e.toString());
    }
    setState(() => _inviting = false);
  }

  Future<void> _saveEdits() async {
    if (_editRow == null) return;
    if (_editPassword.text.isNotEmpty && _editPassword.text.length < 6) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(_settingsRepoProvider);
      final id = _editRow!['id'] as String;
      await repo.updateProfile(id, {
        'full_name': _editName.text.trim(),
        'role': _editRole,
      });

      if (_editUsername.text.isNotEmpty) {
        await repo.updateUsername(id, _editUsername.text.trim());
      }
      if (_editPassword.text.isNotEmpty) {
        await repo.updatePassword(id, _editPassword.text);
      }

      setState(() => _editRow = null);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('userUpdated'.tr())));
      }
      _refreshProfiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    setState(() => _saving = false);
  }

  Future<void> _deleteProfile(Map<String, dynamic> p) async {
    final userName = p['full_name'] as String? ?? '—';
    final userEmail = p['username'] as String? ??
        (p['email'] as String?)?.split('@').first ??
        '—';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius2xl)),
        title: Text('deleteConfirmTitle'.tr(),
            style: AppTextStyles.bodyBoldBase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('confirmRemoveStaff'.tr()),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userName,
                      style: AppTextStyles.bodyBoldSm),
                  const SizedBox(height: 2),
                  Text('@$userEmail',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger),
            child: Text('delete'.tr(),
                style: AppTextStyles.bodyBoldSm
                    .copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repo = ref.read(_settingsRepoProvider);
    await repo.deleteProfile(p['id'] as String);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('userDeleted'.tr())));
    }
    _refreshProfiles();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isOwner = user?.isOwner ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('settingsTitle'.tr(),
                  style: AppTextStyles.displaySm),
            ),
            if (isOwner)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TabBar(
                  controller: _tabController,
                  onTap: (i) {
                    if (i == 1 && _logEntries.isEmpty) _fetchLogs();
                  },
                  isScrollable: true,
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTextStyles.bodyBoldSm,
                  tabs: [
                    Tab(text: 'teamMembers'.tr()),
                    Tab(text: 'activityLog'.tr()),
                    const Tab(text: 'LINE'),
                  ],
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!,
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.danger)),
              ),
            Expanded(
              child: isOwner
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTeamTab(user),
                        _buildLogTab(),
                        _buildLineConfigTab(),
                      ],
                    )
                  : _buildTeamTab(user),
            ),
          ],
        ),
    );
  }

  Widget _buildTeamTab(dynamic user) {
    final isAdmin = user?.isAdmin ?? false;
    final isOwner = user?.isOwner ?? false;

    return RefreshIndicator(
      onRefresh: _refreshProfiles,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('teamMembers'.tr(), style: AppTextStyles.bodyBoldBase),
              if (isAdmin)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showInvite = !_showInvite),
                  icon: Icon(_showInvite
                      ? Icons.close_rounded
                      : Icons.add_circle_rounded),
                  label: Text(
                      _showInvite ? 'close'.tr() : 'addUser'.tr()),
                ),
            ],
          ),

          // Invite form
          if (_showInvite && isAdmin) ...[
            const SizedBox(height: 12),
            Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppColors.borderPurple),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _inviteName,
                  decoration:
                      InputDecoration(hintText: 'optionalName'.tr()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inviteEmail,
                  decoration:
                      InputDecoration(hintText: 'username'.tr()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _invitePw,
                  obscureText: true,
                  decoration:
                      InputDecoration(hintText: 'tempPassword'.tr()),
                  onChanged: (_) => setState(() {}),
                ),
                if (_invitePw.text.isNotEmpty && _invitePw.text.length < 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'minPasswordLength'.tr(),
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _inviteRole,
                  items: [
                    DropdownMenuItem(
                        value: 'staff',
                        child: Text('roleStaff'.tr())),
                    if (isOwner)
                      DropdownMenuItem(
                          value: 'admin',
                          child: Text('roleAdmin'.tr())),
                  ],
                  onChanged: (v) =>
                      setState(() => _inviteRole = v ?? 'staff'),
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _inviting ? null : _handleInvite,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                    child: Text(
                        _inviting ? 'inviting'.tr() : 'addUser'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),

          if (_loading)
            ...List.generate(3, (_) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
            ))
          else
            ..._profiles.expand((p) => [
              _buildProfileCard(p, user),
              if (_editingProfileId == p['id'])
                _buildInlineEditor(p),
            ]),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> p, dynamic user) {
    final role = p['role'] as String? ?? 'staff';
    final name = p['full_name'] as String? ??
        p['username'] as String? ??
        '—';
    final username =
        p['username'] as String? ?? (p['email'] as String?)?.split('@').first;
    final isAdminRole =
        role == 'owner' || role == 'admin' || role == 'superadmin';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isAdminRole ? AppColors.primary : AppColors.info,
                child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.bodyBoldSm),
                    Text('@${username ?? ''}',
                        style: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAdminRole
                      ? AppColors.bgSurface
                      : AppColors.infoLight,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(role,
                    style: AppTextStyles.bodyXs.copyWith(
                        color: isAdminRole
                            ? AppColors.primary
                            : AppColors.info,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInlineEdit(p, role),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text('edit'.tr()),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40)),
                ),
              ),
              if (user?.isAdmin == true &&
                  p['id'] != user?.id &&
                  role != 'owner') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteProfile(p),
                    icon: const Icon(Icons.delete_rounded,
                        size: 16, color: AppColors.danger),
                    label: Text('delete'.tr(),
                        style: AppTextStyles.bodySm
                            .copyWith(color: AppColors.danger)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                      minimumSize: const Size(0, 40),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _openInlineEdit(Map<String, dynamic> p, String role) {
    setState(() {
      _editingProfileId = p['id'] as String?;
      _editRow = p;
      _editName.text = p['full_name'] as String? ?? '';
      _editUsername.text = p['username'] as String? ??
          (p['email'] as String?)?.split('@').first ?? '';
      _editPassword.clear();
      _editRole = role;
    });
  }

  Widget _buildInlineEditor(Map<String, dynamic> p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderPurple),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('editUser'.tr(),
              style: AppTextStyles.bodyBoldSm
                  .copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          TextField(
            controller: _editName,
            decoration: InputDecoration(
              labelText: 'name'.tr(),
              hintText: 'optionalName'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _editUsername,
            decoration: InputDecoration(
              labelText: 'username'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: AppTextStyles.bodySm,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _editPassword,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'newPassword'.tr(),
              hintText: 'leaveBlankToKeep'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: AppTextStyles.bodySm,
            onChanged: (_) => setState(() {}),
          ),
          if (_editPassword.text.isNotEmpty &&
              _editPassword.text.length < 6)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('minPasswordLength'.tr(),
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.danger)),
            ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: (_editRole == 'staff' ||
                    _editRole == 'admin' ||
                    _editRole == 'owner')
                ? _editRole
                : 'staff',
            items: [
              DropdownMenuItem(
                  value: 'staff', child: Text('roleStaff'.tr())),
              DropdownMenuItem(
                  value: 'admin', child: Text('roleAdmin'.tr())),
              if (ref.read(authProvider).valueOrNull?.isOwner == true)
                DropdownMenuItem(
                    value: 'owner', child: Text('roleOwner'.tr())),
            ],
            onChanged: (v) => setState(() => _editRole = v ?? 'staff'),
            decoration: InputDecoration(
              labelText: 'role'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      setState(() => _editingProfileId = null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text('cancel'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textMuted)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          _editRow = p;
                          await _saveEdits();
                          setState(() => _editingProfileId = null);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: Text(
                      _saving ? 'saving'.tr() : 'save'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogTab() {
    return Column(
      children: [
        // Filter
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: DropdownButtonFormField<String>(
            initialValue: _logFilter.isEmpty ? '' : _logFilter,
            items: [
              DropdownMenuItem(
                  value: '', child: Text('allActions'.tr())),
              ..._actionLabelKeys.entries.map(
                (e) => DropdownMenuItem(
                    value: e.key, child: Text(e.value.tr())),
              ),
            ],
            onChanged: (v) {
              _logFilter = v ?? '';
              _fetchLogs();
            },
            decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          ),
        ),

        Expanded(
          child: _logLoading && _logEntries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _logEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt_rounded,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          Text('noActivityLogs'.tr(),
                              style: AppTextStyles.bodySm
                                  .copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount:
                          _logEntries.length + (_logHasMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _logEntries.length) {
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: OutlinedButton(
                              onPressed: _logLoading
                                  ? null
                                  : () => _fetchLogs(offset: _logOffset),
                              child: Text(_logLoading
                                  ? 'loading'.tr()
                                  : 'loadMore'.tr()),
                            ),
                          );
                        }
                        return _buildLogEntry(_logEntries[i]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> entry) {
    final action = entry['action'] as String? ?? '';
    final actorName = entry['actor_name'] as String? ?? 'System';
    final createdAt = entry['created_at'] as String? ?? '';
    final id = entry['id'] as String;
    final isExpanded = _expandedLogId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() =>
                _expandedLogId = isExpanded ? null : id),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _actionIcons[action] ?? Icons.list_alt_rounded,
                    size: 24,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(actorName,
                                style: AppTextStyles.bodySemiBoldSm),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusFull),
                              ),
                              child: Text(
                                (_actionLabelKeys[action] ?? action).tr(),
                                style: AppTextStyles.bodyXs
                                    .copyWith(color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                        Text(_timeAgo(createdAt),
                            style: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgMain,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (entry['_student'] != null)
                      _logDetail('student'.tr(), entry['_student']),
                    if (entry['_course'] != null)
                      _logDetail('course'.tr(), entry['_course']),
                    if (entry['_hours'] != null)
                      _logDetail('hours'.tr(), '${entry['_hours']}'),
                    if (entry['_oldHours'] != null && entry['_newHours'] != null)
                      _logDetail('hours'.tr(), '${entry['_oldHours']} → ${entry['_newHours']}'),
                    if (entry['_time'] != null)
                      _logDetail('time'.tr(), entry['_time']),
                    if (entry['_submittedBy'] != null)
                      _logDetail('by'.tr(), entry['_submittedBy']),
                    if (entry['_cancelledBy'] != null)
                      _logDetail('cancelledBy'.tr(), entry['_cancelledBy']),
                    if (entry['_name'] != null)
                      _logDetail('name'.tr(), entry['_name']),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _logDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyXs)),
        ],
      ),
    );
  }

  Widget _buildLineConfigTab() {
    final configAsync = ref.watch(lineConfigProvider);
    final config = configAsync.valueOrNull;
    final user = ref.watch(authProvider).valueOrNull;
    final isOwner = user?.role == 'owner' || user?.role == 'superadmin';
    final isConfigured = config?.secretsConfigured ?? false;

    return configAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
      data: (_) => LineSettingsInline(
        config: config,
        isOwner: isOwner,
        isConfigured: isConfigured,
      ),
    );
  }

  String _timeAgo(String iso) {
    try {
      final d = DateTime.parse(iso);
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
