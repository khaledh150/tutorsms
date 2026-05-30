import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

    final items = <_MenuItem>[
      _MenuItem(
        label: 'addExistingStudent'.tr(),
        icon: Icons.people_rounded,
        color: AppColors.info,
        path: '/admissions?mode=existing',
      ),
      _MenuItem(
        label: 'courses'.tr(),
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
        path: '/courses',
      ),
      if (isAdmin) ...[
        _MenuItem(
          label: 'reports'.tr(),
          icon: Icons.bar_chart_rounded,
          color: AppColors.info,
          path: '/reports',
        ),
        _MenuItem(
          label: 'billing'.tr(),
          icon: Icons.attach_money_rounded,
          color: AppColors.warning,
          path: '/billing',
        ),
        _MenuItem(
          label: 'lineOa'.tr(),
          icon: Icons.chat_bubble_rounded,
          color: AppColors.lineGreen,
          path: '/messaging',
        ),
        _MenuItem(
          label: 'settings'.tr(),
          icon: Icons.settings_rounded,
          color: AppColors.textSecondary,
          path: '/settings',
        ),
      ],
      if (isSuperAdmin)
        _MenuItem(
          label: 'superAdmin'.tr(),
          icon: Icons.shield_rounded,
          color: AppColors.primaryDark,
          path: '/admin',
        ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('more'.tr(),
                style: AppTextStyles.displaySm),
            const SizedBox(height: 20),

            // Menu items
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                    child: InkWell(
                      onTap: () => context.go(item.path),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusLg),
                      child: Container(
                        constraints: const BoxConstraints(
                            minHeight: AppTheme.touchLarge),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusLg),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: item.color,
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusSm),
                              ),
                              child: Icon(item.icon,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(item.label,
                                  style:
                                      AppTextStyles.bodySemiBoldBase),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )),

            // Language switcher
            Container(
              constraints:
                  const BoxConstraints(minHeight: AppTheme.touchLarge),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Icon(Icons.language_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('language'.tr(),
                        style: AppTextStyles.bodySemiBoldBase),
                  ),
                  const _LanguageSwitcher(),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Logout
            Material(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: InkWell(
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('confirm'.tr()),
                      content: Text('confirmLogout'.tr()),
                      actions: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  ),
                                ),
                                child: Text('cancel'.tr()),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.danger,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  ),
                                ),
                                child: Text('logout'.tr(),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) context.go('/login');
                },
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLg),
                child: Container(
                  constraints: const BoxConstraints(
                      minHeight: AppTheme.touchLarge),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                        child: const Icon(Icons.logout_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Text('logout'.tr(),
                          style: AppTextStyles.bodySemiBoldBase
                              .copyWith(color: AppColors.danger)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color color;
  final String path;
  const _MenuItem(
      {required this.label,
      required this.icon,
      required this.color,
      required this.path});
}

class _LanguageSwitcher extends StatefulWidget {
  const _LanguageSwitcher();

  @override
  State<_LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<_LanguageSwitcher> {
  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode == 'th' ? 'th' : 'en';

    return GestureDetector(
      onTap: () {
        final newLang = lang == 'en' ? 'th' : 'en';
        context.setLocale(Locale(newLang));
        SharedPreferences.getInstance()
            .then((prefs) => prefs.setString('lang', newLang));
      },
      child: Container(
        width: 56,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(color: const Color(0xFF6654B3), width: 2),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 8),
                  Text('EN',
                      style: AppTextStyles.bodyXs.copyWith(
                          color: const Color(0xFF6654B3),
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                  Text('TH',
                      style: AppTextStyles.bodyXs.copyWith(
                          color: const Color(0xFF6654B3),
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: lang == 'th' ? 26 : 1,
              top: 1,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF6654B3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    lang == 'en' ? 'EN' : 'TH',
                    style: AppTextStyles.bodyXs.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
