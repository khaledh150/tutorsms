import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/line_config_model.dart';
import '../providers/messaging_provider.dart';

class TemplatesSheet extends ConsumerStatefulWidget {
  const TemplatesSheet({super.key, this.config, this.onOpenSettings});
  final LineConfig? config;
  final VoidCallback? onOpenSettings;

  @override
  ConsumerState<TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<TemplatesSheet> {
  late Map<String, TextEditingController> _controllers;
  bool _saving = false;

  static const _templateFields = [
    _TemplateField(
      key: 'checkin',
      labelKey: 'autoCheckInNotify',
      vars: '{{name}}, {{course}}, {{time}}',
    ),
    _TemplateField(
      key: 'renewal_approaching',
      labelKey: 'autoLimitNotify',
      vars: '{{name}}, {{course}}, {{used}}, {{purchased}}, {{remaining}}',
    ),
    _TemplateField(
      key: 'overlimit',
      labelKey: 'autoRenewalReminder',
      vars: '{{name}}, {{course}}, {{used}}, {{purchased}}',
    ),
    _TemplateField(
      key: 'enrollment',
      labelKey: 'enrollmentNotify',
      vars: '{{name}}, {{course}}, {{purchased}}, {{school}}',
    ),
    _TemplateField(
      key: 'new_course',
      labelKey: 'newCourseNotify',
      vars: '{{name}}, {{course}}, {{purchased}}, {{school}}',
    ),
    _TemplateField(
      key: 'approval',
      labelKey: 'approvalNotify',
      vars: '{{name}}, {{course}}, {{added}}',
    ),
    _TemplateField(
      key: 'renewal_payment',
      labelKey: 'renewalPaymentNotify',
      vars: '{{name}}, {{course}}, {{remaining}}',
    ),
    _TemplateField(
      key: 'link_welcome',
      labelKey: 'autoLinkNotify',
      vars: '{{name}}',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final templates = widget.config?.messageTemplates;
    _controllers = {
      for (final f in _templateFields)
        f.key: TextEditingController(text: templates?[f.key] ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('editMessageTemplates'.tr(),
                      style: AppTextStyles.displaySm
                          .copyWith(color: AppColors.lineGreen)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('templateHint'.tr(),
                style: AppTextStyles.bodyXs
                    .copyWith(color: AppColors.textMuted, fontSize: 11)),
          ),

          const SizedBox(height: 12),

          // Template fields
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _templateFields.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, i) {
                final f = _templateFields[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.labelKey.tr(),
                        style: AppTextStyles.bodyXs.copyWith(
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(f.vars,
                        style: AppTextStyles.bodyXs.copyWith(
                            color: AppColors.textMuted, fontSize: 10)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _controllers[f.key],
                      maxLines: 4,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                          borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      style: AppTextStyles.bodyXs
                          .copyWith(height: 1.5),
                    ),
                  ],
                );
              },
            ),
          ),

          // Footer
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
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
                    child: Text('cancel'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textMuted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.lineGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm),
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
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final config = widget.config;
    if (config == null) return;

    setState(() => _saving = true);
    try {
      final templates = <String, dynamic>{};
      for (final f in _templateFields) {
        templates[f.key] = _controllers[f.key]!.text;
      }
      await ref
          .read(messagingRepositoryProvider)
          .saveTemplates(config.id, templates);
      ref.invalidate(lineConfigProvider);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TemplateField {
  final String key;
  final String labelKey;
  final String vars;

  const _TemplateField({
    required this.key,
    required this.labelKey,
    required this.vars,
  });
}
