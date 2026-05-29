import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/line_config_model.dart';
import '../providers/messaging_provider.dart';

class LineSettingsSheet extends ConsumerStatefulWidget {
  const LineSettingsSheet({
    super.key,
    this.config,
    this.onOpenTemplates,
  });

  final LineConfig? config;
  final VoidCallback? onOpenTemplates;

  @override
  ConsumerState<LineSettingsSheet> createState() =>
      _LineSettingsSheetState();
}

class _LineSettingsSheetState extends ConsumerState<LineSettingsSheet> {
  late final TextEditingController _channelIdController;
  late final TextEditingController _channelSecretController;
  late final TextEditingController _channelTokenController;
  bool _saving = false;
  bool _uploadingQr = false;
  bool _credentialsExpanded = false;
  bool _webhookExpanded = false;
  bool _qrExpanded = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _channelIdController =
        TextEditingController(text: widget.config?.channelId ?? '');
    _channelSecretController = TextEditingController();
    _channelTokenController = TextEditingController();
    _credentialsExpanded =
        !(widget.config?.secretsConfigured ?? false);

    _channelIdController.addListener(_markChanged);
    _channelSecretController.addListener(_markChanged);
    _channelTokenController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _channelIdController.dispose();
    _channelSecretController.dispose();
    _channelTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final isOwner =
        user?.role == 'owner' || user?.role == 'superadmin';
    final config = widget.config;
    final isConfigured = config?.secretsConfigured ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.lineGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded,
                      size: 18, color: AppColors.lineGreen),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LINE OA ${'settings'.tr()}',
                          style: AppTextStyles.bodyBoldBase),
                      Text(
                        isConfigured
                            ? '● ${'connected'.tr()}'
                            : '○ ${'notConfigured'.tr()}',
                        style: AppTextStyles.bodyXs.copyWith(
                            color: isConfigured
                                ? AppColors.success
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Section 1: API Credentials (owner only)
                if (isOwner) ...[
                  _ExpandableSection(
                    icon: Icons.vpn_key_rounded,
                    iconColor: AppColors.warning,
                    title: 'apiCredentials'.tr(),
                    expanded: _credentialsExpanded,
                    onToggle: () => setState(() =>
                        _credentialsExpanded = !_credentialsExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InputField(
                          label: 'lineChannelId'.tr(),
                          controller: _channelIdController,
                          placeholder: '1234567890',
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          label: 'lineChannelSecret'.tr(),
                          controller: _channelSecretController,
                          obscure: true,
                          placeholder: isConfigured
                              ? '••••••••  (leave blank to keep)'
                              : '',
                        ),
                        const SizedBox(height: 12),
                        _InputField(
                          label: 'lineChannelToken'.tr(),
                          controller: _channelTokenController,
                          obscure: true,
                          placeholder: isConfigured
                              ? '••••••••  (leave blank to keep)'
                              : '',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Section 2: Webhook URL (owner only)
                if (isOwner && config != null) ...[
                  Builder(builder: (context) {
                    final webhookUrl =
                        '${dotenv.env['SUPABASE_URL']!}/functions/v1/line-webhook?school=${user?.schoolId ?? ''}';
                    return _ExpandableSection(
                      icon: Icons.link_rounded,
                      iconColor: AppColors.primary,
                      title: 'webhookUrl'.tr(),
                      expanded: _webhookExpanded,
                      onToggle: () => setState(
                          () => _webhookExpanded = !_webhookExpanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('webhookUrlHint'.tr(),
                              style: AppTextStyles.bodyXs.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 10)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgSurface,
                                    borderRadius:
                                        BorderRadius.circular(
                                            AppTheme.radiusSm),
                                    border: Border.all(
                                        color: AppColors.border),
                                  ),
                                  child: Text(
                                    webhookUrl,
                                    style: AppTextStyles.bodyXs.copyWith(
                                        fontFamily: 'monospace',
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 36,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: webhookUrl));
                                  },
                                  icon: const Icon(
                                      Icons.copy_rounded,
                                      size: 14),
                                  label: Text('copy'.tr(),
                                      style: AppTextStyles.bodyXs
                                          .copyWith(
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        AppColors.lineGreen,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              AppTheme.radiusSm),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Section 3: Auto Notifications
                if (config != null) ...[
                  _buildAutoNotifications(config),
                  const SizedBox(height: 12),
                ],

                // Section 4: Payment QR (owner only)
                if (config != null && isOwner) ...[
                  _ExpandableSection(
                    icon: Icons.qr_code_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'paymentQrCode'.tr(),
                    expanded: _qrExpanded,
                    onToggle: () =>
                        setState(() => _qrExpanded = !_qrExpanded),
                    child: Column(
                      children: [
                        Text('paymentQrHint'.tr(),
                            style: AppTextStyles.bodyXs.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10)),
                        const SizedBox(height: 12),
                        if (config.paymentQrUrl != null) ...[
                          GestureDetector(
                            onTap: () => _showQrPreviewDialog(
                                config.id, config.paymentQrUrl!),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    config.paymentQrUrl!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('paymentQrCode'.tr(),
                                          style: AppTextStyles.bodyBoldSm
                                              .copyWith(fontSize: 12)),
                                      const SizedBox(height: 2),
                                      Text('tapToPreview'.tr(),
                                          style: AppTextStyles.bodyXs
                                              .copyWith(
                                                  color: AppColors
                                                      .textMuted,
                                                  fontSize: 10)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.open_in_new_rounded,
                                    size: 16,
                                    color: Color(0xFF8B5CF6)),
                              ],
                            ),
                          ),
                        ] else
                          GestureDetector(
                            onTap: _uploadingQr
                                ? null
                                : () => _handleQrUpload(config.id),
                            child: Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 24),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(
                                        AppTheme.radiusSm),
                                border: Border.all(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.5),
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.photo_rounded,
                                      size: 24,
                                      color: Color(0xFF8B5CF6)),
                                  const SizedBox(height: 6),
                                  Text(
                                    _uploadingQr
                                        ? 'uploading'.tr()
                                        : 'uploadQrCode'.tr(),
                                    style: AppTextStyles.bodyXs
                                        .copyWith(
                                            color: const Color(
                                                0xFF8B5CF6),
                                            fontWeight:
                                                FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Section 5: Templates button
                if (config != null)
                  GestureDetector(
                    onTap: widget.onOpenTemplates,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                          color: AppColors.lineGreen
                              .withValues(alpha: 0.4),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.description_rounded,
                              size: 16, color: AppColors.lineGreen),
                          const SizedBox(width: 8),
                          Text('editMessageTemplates'.tr(),
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(
                                      color: AppColors.lineGreen)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20,
                MediaQuery.of(context).padding.bottom + 12),
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: Color(0xFFF0F0F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm),
                      ),
                    ),
                    child: Text(
                        isOwner ? 'cancel'.tr() : 'close'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textMuted)),
                  ),
                ),
                if (isOwner) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ||
                              _channelIdController.text.isEmpty ||
                              !_hasChanges
                          ? null
                          : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lineGreen,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                        ),
                      ),
                      child: Text(
                          _saving
                              ? 'saving'.tr()
                              : 'saveLineConfig'.tr(),
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoNotifications(LineConfig config) {
    final toggles = [
      _AutoToggle(
          key: 'auto_checkin_notify',
          label: 'autoCheckInNotify'.tr(),
          color: AppColors.success,
          value: config.autoCheckinNotify),
      _AutoToggle(
          key: 'auto_limit_notify',
          label: 'autoLimitNotify'.tr(),
          color: AppColors.warning,
          value: config.autoLimitNotify),
      _AutoToggle(
          key: 'auto_renewal_reminder',
          label: 'autoRenewalReminder'.tr(),
          color: AppColors.danger,
          value: config.autoRenewalNotify),
      _AutoToggle(
          key: 'auto_link_notify',
          label: 'autoLinkNotify'.tr(),
          color: AppColors.lineGreen,
          value: config.autoLinkNotify),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Text('autoNotifications'.tr(),
                    style: AppTextStyles.bodyBoldSm),
              ],
            ),
          ),
          const Divider(height: 1),
          ...toggles.map((t) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 16, color: t.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.label,
                          style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    Switch(
                      value: t.value,
                      activeTrackColor: AppColors.success,
                      onChanged: (v) async {
                        await ref
                            .read(messagingRepositoryProvider)
                            .toggleAutoNotify(config.id, t.key, v);
                        ref.invalidate(lineConfigProvider);
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  void _showQrPreviewDialog(String configId, String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_rounded,
                      size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('paymentQrCode'.tr(),
                        style: AppTextStyles.bodyBoldBase),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.network(
                  qrUrl,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleQrUpload(configId);
                      },
                      icon: const Icon(Icons.photo_rounded, size: 16),
                      label: Text('replace'.tr(),
                          style: AppTextStyles.bodyBoldSm),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleQrRemove(configId);
                      },
                      icon: const Icon(Icons.delete_rounded,
                          size: 16, color: AppColors.danger),
                      label: Text('remove'.tr(),
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      await ref.read(messagingRepositoryProvider).saveLineConfig(
            configId: widget.config?.id,
            channelId: _channelIdController.text,
            channelSecret: _channelSecretController.text.isNotEmpty
                ? _channelSecretController.text
                : null,
            channelToken: _channelTokenController.text.isNotEmpty
                ? _channelTokenController.text
                : null,
          );
      ref.invalidate(lineConfigProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleQrUpload(String configId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _uploadingQr = true);
    try {
      await ref
          .read(messagingRepositoryProvider)
          .uploadPaymentQr(configId, file);
      ref.invalidate(lineConfigProvider);
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  Future<void> _handleQrRemove(String configId) async {
    await ref
        .read(messagingRepositoryProvider)
        .removePaymentQr(configId);
    ref.invalidate(lineConfigProvider);
  }
}

class LineSettingsInline extends ConsumerStatefulWidget {
  const LineSettingsInline({
    super.key,
    this.config,
    required this.isOwner,
    required this.isConfigured,
  });

  final LineConfig? config;
  final bool isOwner;
  final bool isConfigured;

  @override
  ConsumerState<LineSettingsInline> createState() => _LineSettingsInlineState();
}

class _LineSettingsInlineState extends ConsumerState<LineSettingsInline> {
  late final TextEditingController _channelIdCtrl;
  late final TextEditingController _channelSecretCtrl;
  late final TextEditingController _channelTokenCtrl;
  bool _saving = false;
  bool _uploadingQr = false;
  bool _credentialsExpanded = false;
  bool _webhookExpanded = false;
  bool _qrExpanded = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _channelIdCtrl = TextEditingController(text: widget.config?.channelId ?? '');
    _channelSecretCtrl = TextEditingController();
    _channelTokenCtrl = TextEditingController();
    _credentialsExpanded = !(widget.config?.secretsConfigured ?? false);
    _channelIdCtrl.addListener(_markChanged);
    _channelSecretCtrl.addListener(_markChanged);
    _channelTokenCtrl.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _channelIdCtrl.dispose();
    _channelSecretCtrl.dispose();
    _channelTokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isConfigured
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                widget.isConfigured ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 18,
                color: widget.isConfigured ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 8),
              Text(
                widget.isConfigured ? 'connected'.tr() : 'notConfigured'.tr(),
                style: AppTextStyles.bodyBoldSm.copyWith(
                  color: widget.isConfigured ? AppColors.success : AppColors.warning,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (widget.isOwner) ...[
          _ExpandableSection(
            icon: Icons.vpn_key_rounded,
            iconColor: AppColors.warning,
            title: 'apiCredentials'.tr(),
            expanded: _credentialsExpanded,
            onToggle: () => setState(() => _credentialsExpanded = !_credentialsExpanded),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InputField(label: 'lineChannelId'.tr(), controller: _channelIdCtrl, placeholder: '1234567890'),
                const SizedBox(height: 12),
                _InputField(
                  label: 'lineChannelSecret'.tr(),
                  controller: _channelSecretCtrl,
                  obscure: true,
                  placeholder: widget.isConfigured ? '••••••••  (leave blank to keep)' : '',
                ),
                const SizedBox(height: 12),
                _InputField(
                  label: 'lineChannelToken'.tr(),
                  controller: _channelTokenCtrl,
                  obscure: true,
                  placeholder: widget.isConfigured ? '••••••••  (leave blank to keep)' : '',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving || _channelIdCtrl.text.isEmpty || !_hasChanges ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lineGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _saving ? 'saving'.tr() : 'saveLineConfig'.tr(),
                      style: AppTextStyles.bodyBoldSm.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (widget.isOwner && config != null) ...[
          _buildWebhookSection(),
          const SizedBox(height: 12),
        ],

        if (config != null) ...[
          _buildAutoNotifications(config),
          const SizedBox(height: 12),
        ],

        if (config != null && widget.isOwner) ...[
          _ExpandableSection(
            icon: Icons.qr_code_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: 'paymentQrCode'.tr(),
            expanded: _qrExpanded,
            onToggle: () => setState(() => _qrExpanded = !_qrExpanded),
            child: Column(
              children: [
                Text('paymentQrHint'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 10)),
                const SizedBox(height: 12),
                if (config.paymentQrUrl != null)
                  GestureDetector(
                    onTap: () => _showQrPreviewDialog(config.id, config.paymentQrUrl!),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(config.paymentQrUrl!, width: 56, height: 56, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('paymentQrCode'.tr(), style: AppTextStyles.bodyBoldSm.copyWith(fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('tapToChange'.tr(),
                                  style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 10)),
                            ],
                          ),
                        ),
                        const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF8B5CF6)),
                      ],
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _uploadingQr ? null : () => _handleQrUpload(config.id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5), width: 2),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.photo_rounded, size: 24, color: Color(0xFF8B5CF6)),
                          const SizedBox(height: 6),
                          Text(
                            _uploadingQr ? 'uploading'.tr() : 'uploadQrCode'.tr(),
                            style: AppTextStyles.bodyXs
                                .copyWith(color: const Color(0xFF8B5CF6), fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWebhookSection() {
    final webhookUrl =
        '${dotenv.env['SUPABASE_URL']!}/functions/v1/line-webhook?school=${ref.read(authProvider).valueOrNull?.schoolId ?? ''}';
    return _ExpandableSection(
      icon: Icons.link_rounded,
      iconColor: AppColors.primary,
      title: 'webhookUrl'.tr(),
      expanded: _webhookExpanded,
      onToggle: () => setState(() => _webhookExpanded = !_webhookExpanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('webhookUrlHint'.tr(),
              style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(webhookUrl,
                      style: AppTextStyles.bodyXs.copyWith(fontFamily: 'monospace', fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: webhookUrl)),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: Text('copy'.tr(),
                    style: AppTextStyles.bodyXs.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lineGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoNotifications(LineConfig config) {
    final toggles = [
      ('auto_checkin_notify', 'autoCheckInNotify'.tr(), AppColors.success, config.autoCheckinNotify),
      ('auto_limit_notify', 'autoLimitNotify'.tr(), AppColors.warning, config.autoLimitNotify),
      ('auto_renewal_reminder', 'autoRenewalReminder'.tr(), AppColors.danger, config.autoRenewalNotify),
      ('auto_link_notify', 'autoLinkNotify'.tr(), AppColors.lineGreen, config.autoLinkNotify),
    ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Text('autoNotifications'.tr(), style: AppTextStyles.bodyBoldSm),
              ],
            ),
          ),
          const Divider(height: 1),
          ...toggles.map((t) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: t.$3),
                    const SizedBox(width: 8),
                    Expanded(child: Text(t.$2, style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600, fontSize: 13))),
                    Switch(
                      value: t.$4,
                      activeTrackColor: AppColors.success,
                      onChanged: (v) async {
                        await ref.read(messagingRepositoryProvider).toggleAutoNotify(config.id, t.$1, v);
                        ref.invalidate(lineConfigProvider);
                      },
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    try {
      await ref.read(messagingRepositoryProvider).saveLineConfig(
            configId: widget.config?.id,
            channelId: _channelIdCtrl.text,
            channelSecret: _channelSecretCtrl.text.isNotEmpty ? _channelSecretCtrl.text : null,
            channelToken: _channelTokenCtrl.text.isNotEmpty ? _channelTokenCtrl.text : null,
          );
      ref.invalidate(lineConfigProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('lineConfigSaved'.tr())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleQrUpload(String configId) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _uploadingQr = true);
    try {
      await ref.read(messagingRepositoryProvider).uploadPaymentQr(configId, file);
      ref.invalidate(lineConfigProvider);
    } finally {
      if (mounted) setState(() => _uploadingQr = false);
    }
  }

  void _showQrPreviewDialog(String configId, String qrUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_rounded, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('paymentQrCode'.tr(), style: AppTextStyles.bodyBoldBase)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.network(qrUrl, width: 240, height: 240, fit: BoxFit.contain),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleQrUpload(configId);
                      },
                      icon: const Icon(Icons.photo_rounded, size: 16),
                      label: Text('replace'.tr(), style: AppTextStyles.bodyBoldSm),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _handleQrRemove(configId);
                      },
                      icon: const Icon(Icons.delete_rounded, size: 16, color: AppColors.danger),
                      label: Text('remove'.tr(),
                          style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFFE0E0E0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQrRemove(String configId) async {
    await ref.read(messagingRepositoryProvider).removePaymentQr(configId);
    ref.invalidate(lineConfigProvider);
  }
}

class _ExpandableSection extends StatelessWidget {
  const _ExpandableSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(
                    top: Radius.circular(12))
                : BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: AppTextStyles.bodyBoldSm),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        size: 18, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.placeholder = '',
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodyXs.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: AppTextStyles.bodyXs
                .copyWith(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            isDense: true,
          ),
          style: AppTextStyles.bodySm,
        ),
      ],
    );
  }
}

class _AutoToggle {
  final String key;
  final String label;
  final Color color;
  final bool value;

  const _AutoToggle({
    required this.key,
    required this.label,
    required this.color,
    required this.value,
  });
}
