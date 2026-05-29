import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../courses/providers/course_provider.dart';
import '../providers/messaging_provider.dart';

class BroadcastSheet extends ConsumerStatefulWidget {
  const BroadcastSheet({
    super.key,
    required this.connectedStudents,
    required this.isConfigured,
  });

  final List<dynamic> connectedStudents;
  final bool isConfigured;

  @override
  ConsumerState<BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends ConsumerState<BroadcastSheet> {
  final _messageController = TextEditingController();
  String _recipientMode = 'all';
  String? _selectedCourseId;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  List<String> get _recipientIds {
    if (_recipientMode == 'all') {
      return widget.connectedStudents.map<String>((s) => s.id as String).toList();
    }
    if (_selectedCourseId == null) return [];
    final enrollments =
        ref.read(activeEnrollmentsProvider).valueOrNull ?? [];
    final courseStudentIds = enrollments
        .where((e) => e['course_id'] == _selectedCourseId)
        .map((e) => e['student_id'] as String)
        .toSet();
    return widget.connectedStudents
        .where((s) => courseStudentIds.contains(s.id))
        .map<String>((s) => s.id as String)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.lineGreen,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const Spacer(),
                Text('sendMessage'.tr(),
                    style: AppTextStyles.bodyBoldBase
                        .copyWith(color: Colors.white)),
                const Spacer(),
                const SizedBox(width: 24),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipient mode
                Text('selectRecipients'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _ModeButton(
                      icon: Icons.group_rounded,
                      label: 'allParents'.tr(),
                      active: _recipientMode == 'all',
                      onTap: () =>
                          setState(() => _recipientMode = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _ModeButton(
                      icon: Icons.school_rounded,
                      label: 'byCourse'.tr(),
                      active: _recipientMode == 'course',
                      onTap: () =>
                          setState(() => _recipientMode = 'course'),
                    ),
                  ],
                ),

                // Course picker
                if (_recipientMode == 'course') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCourseId,
                        hint: Text('selectCourse'.tr(),
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textMuted)),
                        isExpanded: true,
                        items: courses
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name,
                                      style: AppTextStyles.bodySm),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedCourseId = v),
                      ),
                    ),
                  ),
                ],

                // Recipient count
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.group_rounded,
                        size: 14, color: AppColors.lineGreen),
                    const SizedBox(width: 4),
                    Text(
                      '${'recipients'.tr()}: ${_recipientIds.length}',
                      style: AppTextStyles.bodyXs.copyWith(
                          color: AppColors.lineGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

                // Message input + send
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg),
                          border: Border.all(
                              color: const Color(0xFFE0E0E0)),
                        ),
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: 'writeMessage'.tr(),
                            hintStyle: AppTextStyles.bodyXs
                                .copyWith(color: AppColors.textMuted),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                          style: AppTextStyles.bodySm,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: AppColors.lineGreen,
                        elevation: 0,
                        onPressed: _sending ||
                                _recipientIds.isEmpty ||
                                !widget.isConfigured
                            ? null
                            : _handleSend,
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _recipientIds.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref.read(messagingRepositoryProvider).sendMessage(
            content: text,
            recipientStudentIds: _recipientIds,
          );
      _messageController.clear();
      ref.invalidate(lineMessagesProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.lineGreen : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: active ? Colors.white : AppColors.textMuted),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTextStyles.bodyXs.copyWith(
                      color:
                          active ? Colors.white : AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
