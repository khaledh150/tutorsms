import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../students/providers/student_provider.dart';
import '../models/line_config_model.dart';
import '../models/line_connection_model.dart';
import '../models/unlinked_user_model.dart';
import '../providers/messaging_provider.dart';
import 'broadcast_sheet.dart';
import 'chat_view.dart';
import 'line_settings_sheet.dart';
import 'templates_sheet.dart';

class MessagingPage extends ConsumerStatefulWidget {
  const MessagingPage({super.key});

  @override
  ConsumerState<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends ConsumerState<MessagingPage> {
  final _searchController = TextEditingController();
  String? _chatStudentId;
  List<LineMessage> _cachedMessages = const [];
  Map<String, LineMessage> _lastMessageMap = const {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;

    final configAsync = ref.watch(lineConfigProvider);
    final messagesAsync = ref.watch(lineMessagesProvider);
    final connectionsAsync = ref.watch(lineConnectionsProvider);
    final unlinkedAsync = ref.watch(unlinkedUsersProvider);
    final studentsAsync = ref.watch(allStudentsProvider);

    // Show loading indicator while core data is still loading
    if (connectionsAsync.isLoading || studentsAsync.isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final config = configAsync.valueOrNull;
    final messages = messagesAsync.valueOrNull ?? [];
    final connections = connectionsAsync.valueOrNull ?? [];
    final unlinkedUsers = unlinkedAsync.valueOrNull ?? [];
    final students = studentsAsync.valueOrNull ?? [];
    final isConfigured = config?.secretsConfigured ?? false;

    final connectedStudentIds =
        connections.map((c) => c.studentId).toSet();
    final connectedStudents =
        students.where((s) => connectedStudentIds.contains(s.id)).toList();

    final search = _searchController.text.toLowerCase();
    final filteredStudents = search.isEmpty
        ? connectedStudents
        : connectedStudents.where((s) {
            return (s.nickName?.toLowerCase().contains(search) ?? false) ||
                s.firstName.toLowerCase().contains(search) ||
                s.lastName.toLowerCase().contains(search);
          }).toList();

    // Only recompute lastMessageMap when messages list changes
    if (!identical(messages, _cachedMessages)) {
      _cachedMessages = messages;
      final map = <String, LineMessage>{};
      for (final msg in messages) {
        for (final sid in msg.recipientStudentIds) {
          final existing = map[sid];
          if (existing == null ||
              msg.createdAt.compareTo(existing.createdAt) > 0) {
            map[sid] = msg;
          }
        }
        if (msg.isIncoming && msg.studentId != null) {
          final sid = msg.studentId!;
          final existing = map[sid];
          if (existing == null ||
              msg.createdAt.compareTo(existing.createdAt) > 0) {
            map[sid] = msg;
          }
        }
      }
      _lastMessageMap = map;
    }
    final lastMessageMap = _lastMessageMap;

    if (_chatStudentId != null) {
      final student = students
          .where((s) => s.id == _chatStudentId)
          .firstOrNull;
      if (student != null) {
        return ChatView(
          studentId: _chatStudentId!,
          studentName: student.nickName != null
              ? '${student.nickName} (${student.firstName})'
              : '${student.firstName} ${student.lastName}',
          studentInitial:
              (student.nickName ?? student.firstName).characters.first
                  .toUpperCase(),
          messages: messages,
          connections: connections,
          isConfigured: isConfigured,
          onBack: () => setState(() => _chatStudentId = null),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text('lineOa'.tr(), style: AppTextStyles.displaySm),
                if (connections.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lineGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${connections.length}',
                        style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.lineGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 10)),
                  ),
                ],
                const Spacer(),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(Icons.settings_rounded,
                        color: AppColors.textSecondary, size: 22),
                    onPressed: () => _openTemplates(context, config),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'searchPlaceholder'.tr(),
                  hintStyle: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  isCollapsed: true,
                ),
                style: AppTextStyles.bodySm,
              ),
            ),
          ),

          // Setup warning
          if (!isConfigured)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: const Color(0xFFFFD97D)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFB8860B), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('lineSetupRequired'.tr(),
                        style: AppTextStyles.bodyXs.copyWith(
                            color: const Color(0xFFB8860B),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

          // Unlinked accounts (admin only)
          if (isAdmin)
            _UnlinkedAccountsSection(
              unlinkedUsers: unlinkedUsers,
              students: students
                  .where((s) => !connectedStudentIds.contains(s.id))
                  .toList(),
              config: config,
            ),

          // Chat list
          Expanded(
            child: filteredStudents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_rounded,
                            size: 64,
                            color: Colors.grey.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          search.isNotEmpty
                              ? 'noStudentsFound'.tr()
                              : 'noLineLinked'.tr(),
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredStudents.length,
                    itemBuilder: (context, i) {
                      final s = filteredStudents[i];
                      final conn = connections
                          .where((c) => c.studentId == s.id)
                          .firstOrNull;
                      final lastMsg = lastMessageMap[s.id];
                      final displayName = s.nickName != null
                          ? '${s.nickName} (${s.firstName})'
                          : '${s.firstName} ${s.lastName}';

                      return _ChatListItem(
                        displayName: displayName,
                        lineDisplayName: conn?.displayName,
                        pictureUrl: conn?.pictureUrl,
                        initial:
                            (s.nickName ?? s.firstName).characters.first
                                .toUpperCase(),
                        lastMessage: lastMsg,
                        onTap: () =>
                            setState(() => _chatStudentId = s.id),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.lineGreen,
        onPressed: () => _openBroadcast(context, connectedStudents,
            connections, isConfigured),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  void _openTemplates(BuildContext context, LineConfig? config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TemplatesSheet(
        config: config,
        onOpenSettings: () => _openSettings(context, config),
      ),
    );
  }

  void _openSettings(BuildContext context, LineConfig? config) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LineSettingsSheet(
        config: config,
        onOpenTemplates: () {
          Navigator.pop(ctx);
          _openTemplates(context, config);
        },
      ),
    );
  }

  void _openBroadcast(
    BuildContext context,
    List<dynamic> connectedStudents,
    List<LineConnection> connections,
    bool isConfigured,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BroadcastSheet(
        connectedStudents: connectedStudents,
        isConfigured: isConfigured,
      ),
    );
  }
}

// ─── Chat List Item ─────────────────────────────────────────────

class _ChatListItem extends StatelessWidget {
  const _ChatListItem({
    required this.displayName,
    this.lineDisplayName,
    this.pictureUrl,
    required this.initial,
    this.lastMessage,
    required this.onTap,
  });

  final String displayName;
  final String? lineDisplayName;
  final String? pictureUrl;
  final String initial;
  final LineMessage? lastMessage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
        ),
        child: Row(
          children: [
            pictureUrl != null
                ? CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(pictureUrl!),
                  )
                : CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.lineGreen,
                    child: Text(initial,
                        style: AppTextStyles.displaySm
                            .copyWith(color: Colors.white)),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(displayName,
                                  style: AppTextStyles.bodyBoldSm,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (lineDisplayName != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text('· $lineDisplayName',
                                    style: AppTextStyles.bodyXs.copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (lastMessage != null)
                        Text(
                          _formatTime(lastMessage!.createdAt),
                          style: AppTextStyles.bodyXs.copyWith(
                              color: const Color(0xFFA0A0A0),
                              fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage?.content ?? 'lineLinked'.tr(),
                    style: AppTextStyles.bodyXs
                        .copyWith(color: const Color(0xFF8E8E8E)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(d.year, d.month, d.day);

    if (dateDay == today) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (dateDay == yesterday) return 'Yesterday';
    return '${_monthAbbr(d.month)} ${d.day}';
  }

  String _monthAbbr(int m) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m - 1];
  }
}

// ─── Unlinked Accounts Section ──────────────────────────────────

class _UnlinkedAccountsSection extends ConsumerStatefulWidget {
  const _UnlinkedAccountsSection({
    required this.unlinkedUsers,
    required this.students,
    this.config,
  });

  final List<UnlinkedLineUser> unlinkedUsers;
  final List<dynamic> students;
  final LineConfig? config;

  @override
  ConsumerState<_UnlinkedAccountsSection> createState() =>
      _UnlinkedAccountsSectionState();
}

class _UnlinkedAccountsSectionState
    extends ConsumerState<_UnlinkedAccountsSection> {
  final _linkSelections = <String, String>{};
  String? _linkingId;
  bool _syncing = false;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 8),
                  Text('unlinkedLineAccounts'.tr(),
                      style: AppTextStyles.bodyBoldSm.copyWith(color: const Color(0xFF92400E))),
                  if (widget.unlinkedUsers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE68A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${widget.unlinkedUsers.length}',
                          style: AppTextStyles.bodyXs.copyWith(
                              color: const Color(0xFF92400E), fontWeight: FontWeight.w700, fontSize: 10)),
                    ),
                  ],
                  const Spacer(),
                  if (_expanded)
                    ElevatedButton.icon(
                      onPressed: _syncing ? null : _handleSyncFollowers,
                      icon: _syncing
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded, size: 14),
                      label: Text(
                        _syncing ? 'syncing'.tr() : 'syncFollowers'.tr(),
                        style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lineGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                      ),
                    )
                  else
                    AnimatedRotation(
                      turns: 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded,
                          size: 18, color: Color(0xFF92400E)),
                    ),
                ],
              ),
            ),
          ),
          if (_expanded)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: widget.unlinkedUsers.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text('noUnlinkedAccounts'.tr(),
                            style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text('unlinkedLineHint'.tr(),
                              style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 11)),
                        ),
                        ...widget.unlinkedUsers.map(_buildUnlinkedRow),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnlinkedRow(UnlinkedLineUser u) {
    final selectedSid = _linkSelections[u.lineUserId];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          u.pictureUrl != null
              ? CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(u.pictureUrl!),
                )
              : CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFFB0BEC5),
                  child: Text(
                    (u.displayName ?? '?').characters.first.toUpperCase(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: Colors.white),
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.displayName ?? 'Unknown',
                    style: AppTextStyles.bodyBoldSm,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${'followedOn'.tr()} ${_formatDate(u.createdAt)}',
                  style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.textMuted, fontSize: 10),
                ),
                const SizedBox(height: 6),
                _StudentDropdown(
                  students: widget.students,
                  selectedId: selectedSid,
                  onSelected: (id) => setState(() {
                    _linkSelections[u.lineUserId] = id;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: selectedSid == null ||
                    _linkingId == u.lineUserId
                ? null
                : () => _handleLink(u),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lineGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 36),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusSm),
              ),
              textStyle: AppTextStyles.bodyXs
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            child: Text(
                _linkingId == u.lineUserId
                    ? 'linking'.tr()
                    : 'linkAccount'.tr(),
                style: AppTextStyles.bodyXs.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLink(UnlinkedLineUser u) async {
    final studentId = _linkSelections[u.lineUserId];
    if (studentId == null) return;

    setState(() => _linkingId = u.lineUserId);
    try {
      final student =
          widget.students.firstWhere((s) => s.id == studentId);
      final name = student.nickName ?? student.firstName ?? '';

      String? welcomeMessage;
      if (widget.config?.autoLinkNotify ?? false) {
        final tpl = widget.config!.messageTemplates.linkWelcome.isNotEmpty
            ? widget.config!.messageTemplates.linkWelcome
            : 'Your LINE account has been linked to {{name}}!\n\n'
                'บัญชี LINE ของคุณเชื่อมต่อกับ {{name}} เรียบร้อยแล้ว!';
        welcomeMessage = tpl.replaceAll('{{name}}', name);
      }

      await ref.read(messagingRepositoryProvider).linkLineAccount(
            studentId: studentId,
            lineUserId: u.lineUserId,
            displayName: u.displayName,
            pictureUrl: u.pictureUrl,
            sendWelcome: welcomeMessage != null,
            welcomeMessage: welcomeMessage,
          );

      ref.invalidate(unlinkedUsersProvider);
      ref.invalidate(lineConnectionsProvider);
      _linkSelections.remove(u.lineUserId);
    } finally {
      if (mounted) setState(() => _linkingId = null);
    }
  }

  Future<void> _handleSyncFollowers() async {
    setState(() => _syncing = true);
    try {
      final res = await supabase.functions.invoke('sync-line-followers');
      if (res.status == 403 || res.status == 400) {
        final body = res.data is Map ? res.data as Map : {};
        if (body['error']?.toString().contains('not available') == true ||
            res.status == 403) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('syncFollowersError403'.tr())),
            );
          }
          return;
        }
      }
      if (res.status >= 400) {
        final body = res.data is Map ? res.data as Map : {};
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content:
                    Text(body['error']?.toString() ?? 'Sync failed')),
          );
        }
        return;
      }
      final result = res.data is Map ? res.data as Map : {};
      final newCount = result['new_count'] ?? 0;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${'syncComplete'.tr()} — $newCount ${'newAccountsFound'.tr()}')),
        );
      }
      ref.invalidate(unlinkedUsersProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _formatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ─── Student Dropdown ───────────────────────────────────────────

class _StudentDropdown extends StatefulWidget {
  const _StudentDropdown({
    required this.students,
    this.selectedId,
    required this.onSelected,
  });

  final List<dynamic> students;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  State<_StudentDropdown> createState() => _StudentDropdownState();
}

class _StudentDropdownState extends State<_StudentDropdown> {
  bool _open = false;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final selectedStudent = widget.selectedId != null
        ? widget.students
            .where((s) => s.id == widget.selectedId)
            .firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedStudent != null
                        ? _displayName(selectedStudent)
                        : 'selectStudent'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(
                        color: selectedStudent != null
                            ? AppColors.textPrimary
                            : AppColors.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more_rounded,
                    size: 14, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        if (_open)
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
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    autofocus: true,
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'searchPlaceholder'.tr(),
                      hintStyle: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                    ),
                    style: AppTextStyles.bodyXs,
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: _filteredStudents.map((s) {
                      return InkWell(
                        onTap: () {
                          widget.onSelected(s.id);
                          setState(() {
                            _open = false;
                            _search = '';
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.lineGreen,
                                child: Text(
                                  (s.nickName ?? s.firstName)
                                      .characters
                                      .first
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_displayName(s),
                                    style: AppTextStyles.bodyXs.copyWith(
                                        fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis),
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

  List<dynamic> get _filteredStudents {
    if (_search.isEmpty) return widget.students;
    final q = _search.toLowerCase();
    return widget.students.where((s) {
      return (s.nickName?.toLowerCase().contains(q) ?? false) ||
          s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q);
    }).toList();
  }

  String _displayName(dynamic s) {
    if (s.nickName != null) {
      return '${s.nickName} (${s.firstName} ${s.lastName})';
    }
    return '${s.firstName} ${s.lastName}';
  }
}
