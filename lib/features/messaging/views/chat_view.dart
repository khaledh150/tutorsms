import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/line_config_model.dart';
import '../models/line_connection_model.dart';
import '../providers/messaging_provider.dart';

const _chatBg = Color(0xFF7494A5);
const _chatBgEnd = Color(0xFF6B8C9E);

class ChatView extends ConsumerStatefulWidget {
  const ChatView({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentInitial,
    required this.messages,
    required this.connections,
    required this.isConfigured,
    required this.onBack,
  });

  final String studentId;
  final String studentName;
  final String studentInitial;
  final List<LineMessage> messages;
  final List<LineConnection> connections;
  final bool isConfigured;
  final VoidCallback onBack;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _editingName = false;
  final _editNameController = TextEditingController();
  String? _previewImage;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _editNameController.dispose();
    super.dispose();
  }

  List<LineMessage> get _chatMessages {
    final outgoing = widget.messages.where((m) =>
        !m.isIncoming &&
        m.recipientStudentIds.contains(widget.studentId));
    final incoming = widget.messages.where(
        (m) => m.isIncoming && m.studentId == widget.studentId);
    final all = [...outgoing, ...incoming];
    all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  LineConnection? get _connection => widget.connections
      .where((c) => c.studentId == widget.studentId)
      .firstOrNull;

  @override
  void didUpdateWidget(ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _chatMessages;
    final conn = _connection;
    final grouped = _groupByDate(msgs);

    return Scaffold(
      backgroundColor: _chatBg,
      body: Column(
        children: [
          // Chat header
          Container(
            color: AppColors.lineGreen,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 4,
              left: 4,
              right: 12,
              bottom: 8,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                  onPressed: widget.onBack,
                ),
                conn?.pictureUrl != null
                    ? CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            NetworkImage(conn!.pictureUrl!),
                      )
                    : CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.2),
                        child: Text(widget.studentInitial,
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: Colors.white)),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.push('/students/${widget.studentId}'),
                        child: Text(widget.studentName,
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (_editingName)
                        SizedBox(
                          height: 22,
                          child: TextField(
                            controller: _editNameController,
                            autofocus: true,
                            style: AppTextStyles.bodyXs.copyWith(
                                color: Colors.white, fontSize: 11),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                              filled: true,
                              fillColor:
                                  Colors.white.withValues(alpha: 0.2),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(4),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _saveDisplayName(),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Text(
                              conn?.displayName ?? '',
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.7),
                                  fontSize: 10),
                            ),
                            if (conn != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  _editNameController.text =
                                      conn.displayName ?? '';
                                  setState(
                                      () => _editingName = true);
                                },
                                child: Icon(Icons.edit_rounded,
                                    size: 12,
                                    color: Colors.white
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chat body
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_chatBg, _chatBgEnd],
                ),
              ),
              child: msgs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_rounded,
                              size: 56,
                              color:
                                  Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('noMessages'.tr(),
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.5))),
                          const SizedBox(height: 4),
                          Text('sendViaLine'.tr(),
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.4))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      itemCount: grouped.length,
                      itemBuilder: (context, gi) {
                        final group = grouped[gi];
                        return Column(
                          children: [
                            // Date header
                            Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 16),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatChatDate(
                                      group.msgs.first.createdAt),
                                  style: AppTextStyles.bodyXs.copyWith(
                                      color: Colors.white
                                          .withValues(alpha: 0.8),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10),
                                ),
                              ),
                            ),
                            // Messages
                            ...group.msgs.map(_buildBubble),
                          ],
                        );
                      },
                    ),
            ),
          ),

          // Image preview overlay
          if (_previewImage != null)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _previewImage = null),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                  child: Center(
                    child: Image.network(_previewImage!,
                        fit: BoxFit.contain),
                  ),
                ),
              ),
            ),

          // Chat input
          Container(
            color: const Color(0xFFF0F0F0),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      decoration: InputDecoration(
                        hintText: 'writeMessage'.tr(),
                        hintStyle: AppTextStyles.bodyXs
                            .copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      style: AppTextStyles.bodySm,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: AppColors.lineGreen,
                      elevation: 0,
                      onPressed: _sending ||
                            !widget.isConfigured ||
                            _messageController.text.trim().isEmpty
                        ? null
                        : _handleSend,
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(LineMessage msg) {
    final isIncoming = msg.isIncoming;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isIncoming)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.status == 'sent'
                        ? 'sent'.tr()
                        : msg.status == 'queued'
                            ? 'queued'.tr()
                            : msg.status,
                    style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  Text(
                    _formatChatTime(msg.createdAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: isIncoming ? Colors.white : AppColors.lineGreen,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isIncoming ? 4 : 16),
                  bottomRight: Radius.circular(isIncoming ? 16 : 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.mediaType == 'image' && msg.mediaUrl != null)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _previewImage = msg.mediaUrl),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        child: Image.network(msg.mediaUrl!,
                            fit: BoxFit.cover,
                            height: 200,
                            width: double.infinity),
                      ),
                    ),
                  if (msg.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        msg.content,
                        style: AppTextStyles.bodySm.copyWith(
                            color: isIncoming
                                ? const Color(0xFF333333)
                                : Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isIncoming)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _formatChatTime(msg.createdAt),
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.5)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(messagingRepositoryProvider).sendMessage(
            content: text,
            recipientStudentIds: [widget.studentId],
          );
      _messageController.clear();
      ref.invalidate(lineMessagesProvider);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveDisplayName() async {
    final conn = _connection;
    if (conn == null) return;
    final name = _editNameController.text.trim();
    if (name.isNotEmpty && name != conn.displayName) {
      await ref
          .read(messagingRepositoryProvider)
          .updateConnectionDisplayName(conn.id, name);
      ref.invalidate(lineConnectionsProvider);
    }
    if (mounted) setState(() => _editingName = false);
  }

  String _formatChatTime(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatChatDate(String dateStr) {
    final d = DateTime.tryParse(dateStr);
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(d.year, d.month, d.day);
    if (dateDay == today) return 'today'.tr();
    final yesterday = today.subtract(const Duration(days: 1));
    if (dateDay == yesterday) return 'yesterday'.tr();
    final weekdays = [
      'monday'.tr(), 'tuesday'.tr(), 'wednesday'.tr(), 'thursday'.tr(),
      'friday'.tr(), 'saturday'.tr(), 'sunday'.tr(),
    ];
    final months = [
      'janShort'.tr(), 'febShort'.tr(), 'marShort'.tr(), 'aprShort'.tr(),
      'mayShort'.tr(), 'junShort'.tr(), 'julShort'.tr(), 'augShort'.tr(),
      'sepShort'.tr(), 'octShort'.tr(), 'novShort'.tr(), 'decShort'.tr(),
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  List<_DateGroup> _groupByDate(List<LineMessage> msgs) {
    final groups = <_DateGroup>[];
    for (final msg in msgs) {
      final dateKey =
          DateTime.tryParse(msg.createdAt)?.toIso8601String().substring(0, 10) ?? '';
      if (groups.isNotEmpty && groups.last.date == dateKey) {
        groups.last.msgs.add(msg);
      } else {
        groups.add(_DateGroup(date: dateKey, msgs: [msg]));
      }
    }
    return groups;
  }
}

class _DateGroup {
  final String date;
  final List<LineMessage> msgs;
  _DateGroup({required this.date, required this.msgs});
}
