import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';

class ChildPicker extends StatelessWidget {
  const ChildPicker({
    super.key,
    required this.students,
    required this.selectedId,
    required this.onChanged,
    this.hint,
  });

  final List<ChildPickerItem> students;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          isExpanded: true,
          hint: Text(
            hint ?? 'selectStudent'.tr(),
            style: AppTextStyles.bodyBase.copyWith(color: AppColors.textMuted),
          ),
          icon: const Icon(Icons.expand_more_rounded,
              color: AppColors.textMuted),
          style: AppTextStyles.bodyBoldBase,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          items: students.map((s) {
            return DropdownMenuItem<String>(
              value: s.id,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: s.photoUrl != null
                        ? ClipOval(
                            child: Image.network(
                              s.photoUrl!,
                              width: 32,
                              height: 32,
                              cacheWidth: 64,
                              cacheHeight: 64,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Text(
                                s.initial,
                                style: AppTextStyles.bodyBoldSm
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          )
                        : Text(
                            s.initial,
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: Colors.white),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.displayName,
                      style: AppTextStyles.bodyBoldSm,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class ChildPickerItem {
  final String id;
  final String displayName;
  final String initial;
  final String? photoUrl;

  const ChildPickerItem({
    required this.id,
    required this.displayName,
    required this.initial,
    this.photoUrl,
  });
}
