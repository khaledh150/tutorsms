import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/notification_model.dart';
import '../providers/inbox_provider.dart';

void showNotificationsPanel(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, anim, secondAnim) => const _NotificationsSheet(),
    transitionBuilder: (context, anim, secondAnim, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
  );
}

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(unreadNotificationsProvider);
    final notifications = notificationsAsync.valueOrNull ?? [];
    final topPadding = MediaQuery.of(context).padding.top;

    return Align(
      alignment: Alignment.topCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          margin: EdgeInsets.only(top: topPadding),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded,
                        color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    Text('notifications'.tr(),
                        style: AppTextStyles.displaySm),
                    if (notifications.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Text(
                          '${notifications.length}',
                          style: AppTextStyles.bodyXs.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ref
                              .read(unreadNotificationsProvider.notifier)
                              .markAllRead();
                        },
                        child: Text('markAllRead'.tr(),
                            style: AppTextStyles.bodyBoldSm
                                .copyWith(color: AppColors.primary)),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 48,
                                color: AppColors.textMuted
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('noNotifications'.tr(),
                                style: AppTextStyles.bodySemiBoldBase
                                    .copyWith(
                                        color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: notifications.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        itemBuilder: (_, i) => _NotificationTile(
                          notification: notifications[i],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  Color get _typeColor {
    switch (notification.type) {
      case 'new_application':
        return AppColors.primary;
      case 'renewal_request':
        return AppColors.warning;
      case 'overlimit':
        return AppColors.danger;
      case 'renewal_approaching':
        return const Color(0xFFD97706);
      case 'checkin':
        return AppColors.success;
      case 'cancel_request':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  String get _typeLabel {
    switch (notification.type) {
      case 'new_application':
        return 'newStudentBadge'.tr();
      case 'renewal_request':
        return 'renew'.tr();
      case 'overlimit':
        return 'needsRenewal'.tr();
      case 'renewal_approaching':
        return 'renewalApproaching'.tr();
      case 'checkin':
        return 'checkIn'.tr();
      case 'cancel_request':
        return 'cancelCourse'.tr();
      case 'edit_request':
        return 'addCourseType'.tr();
      default:
        return notification.type ?? '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(unreadNotificationsProvider.notifier).markRead(notification.id);
        Navigator.pop(context);
        if (notification.type == 'new_application') {
          context.go('/inbox');
        } else if (notification.studentId != null &&
            notification.studentId!.isNotEmpty) {
          context.go('/students/${notification.studentId}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Text(
                _typeLabel,
                style: AppTextStyles.bodyXs.copyWith(
                  color: _typeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.displayMessage,
                    style: AppTextStyles.bodySm
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              notification.timeAgo,
              style: AppTextStyles.bodyXs
                  .copyWith(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
