import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/inbox/providers/inbox_provider.dart';
import '../features/admissions/views/admissions_page.dart';
import '../features/admissions/views/enroll_student_page.dart';
import '../features/attendance/views/attendance_page.dart';
import '../features/attendance/views/course_attendance_view.dart';
import '../features/attendance/views/qr_scanner_view.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/views/login_page.dart';
import '../features/auth/views/trial_expired_page.dart';
import '../features/billing/views/billing_page.dart';
import '../features/courses/views/courses_page.dart';
import '../features/dashboard/views/home_page.dart';
import '../features/inbox/views/inbox_page.dart';
import '../features/messaging/views/messaging_page.dart';
import '../features/more/views/more_page.dart';
import '../features/renew/views/renew_course_page.dart';
import '../features/reports/views/reports_page.dart';
import '../features/settings/views/settings_page.dart';
import '../features/students/views/student_profile_page.dart';
import '../features/students/views/students_page.dart';
import '../features/super_admin/providers/super_admin_provider.dart';
import '../features/super_admin/views/super_admin_dashboard.dart';
import '../shared/widgets/offline_banner.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

// Smooth horizontal slide for tabs
Page<dynamic> _buildSlideRoute(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.08, 0.0);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

// Smooth vertical slide-up for details
Page<dynamic> _buildSlideUpRoute(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.12);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final trialState = ref.watch(trialStatusProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      if (isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isLoginRoute = state.matchedLocation == '/login';
      final isPublicRoute =
          state.matchedLocation.startsWith('/renew');
      final isTrialExpiredRoute =
          state.matchedLocation == '/trial-expired';

      if (isPublicRoute) return null;
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';

      // Trial lockout: redirect non-superadmin users to lockout page
      if (isLoggedIn &&
          trialState.isExpired &&
          !user.isSuperAdmin &&
          !isTrialExpiredRoute &&
          !isLoginRoute) {
        return '/trial-expired';
      }
      if (isTrialExpiredRoute && (!trialState.isExpired || !isLoggedIn)) {
        return '/dashboard';
      }

      // Admin-only routes
      const adminRoutes = [
        '/settings',
        '/billing',
        '/reports',
        '/messaging',
      ];
      final isAdminRoute =
          adminRoutes.any((r) => state.matchedLocation.startsWith(r));
      if (isAdminRoute && isLoggedIn && !user.isAdmin) return '/dashboard';

      // Super admin route
      if (state.matchedLocation.startsWith('/admin') &&
          isLoggedIn &&
          !user.isSuperAdmin) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/trial-expired',
        builder: (context, state) {
          final trial = ref.read(trialStatusProvider);
          return TrialExpiredPage(
            trialDuration: trial.trialDuration ?? '',
            schoolName: trial.schoolName ?? '',
          );
        },
      ),
      GoRoute(
        path: '/renew/:studentId/:courseId',
        builder: (context, state) => RenewCoursePage(
          studentId: state.pathParameters['studentId']!,
          courseId: state.pathParameters['courseId']!,
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return _MainShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => _buildSlideRoute(const HomePage(), state),
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (context, state) => _buildSlideRoute(const AttendancePage(), state),
          ),
          GoRoute(
            path: '/attendance/scan/:courseId',
            pageBuilder: (context, state) => _buildSlideUpRoute(
              QrScannerView(
                courseId: state.pathParameters['courseId']!,
              ),
              state,
            ),
          ),
          GoRoute(
            path: '/attendance/:courseId',
            pageBuilder: (context, state) => _buildSlideUpRoute(
              CourseAttendanceView(
                courseId: state.pathParameters['courseId']!,
              ),
              state,
            ),
          ),
          GoRoute(
            path: '/students',
            pageBuilder: (context, state) => _buildSlideRoute(const StudentsPage(), state),
          ),
          GoRoute(
            path: '/students/:id',
            pageBuilder: (context, state) => _buildSlideUpRoute(
              StudentProfilePage(
                studentId: state.pathParameters['id']!,
              ),
              state,
            ),
          ),
          GoRoute(
            path: '/inbox',
            pageBuilder: (context, state) => _buildSlideRoute(const InboxPage(), state),
          ),
          GoRoute(
            path: '/more',
            pageBuilder: (context, state) => _buildSlideRoute(const MorePage(), state),
          ),
          GoRoute(
            path: '/courses',
            pageBuilder: (context, state) => _buildSlideUpRoute(const CoursesPage(), state),
          ),
          GoRoute(
            path: '/admissions',
            pageBuilder: (context, state) {
              final mode = state.uri.queryParameters['mode'];
              if (mode == 'new') {
                return _buildSlideUpRoute(const EnrollStudentPage(), state);
              }
              if (mode == 'existing') {
                return _buildSlideUpRoute(const EnrollStudentPage(existingMode: true), state);
              }
              return _buildSlideUpRoute(const AdmissionsPage(), state);
            },
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _buildSlideUpRoute(const SettingsPage(), state),
          ),
          GoRoute(
            path: '/billing',
            pageBuilder: (context, state) => _buildSlideUpRoute(const BillingPage(), state),
          ),
          GoRoute(
            path: '/reports',
            pageBuilder: (context, state) => _buildSlideUpRoute(const ReportsPage(), state),
          ),
          GoRoute(
            path: '/messaging',
            pageBuilder: (context, state) => _buildSlideUpRoute(const MessagingPage(), state),
          ),
          GoRoute(
            path: '/admin',
            pageBuilder: (context, state) => _buildSlideUpRoute(const SuperAdminDashboard(), state),
          ),
        ],
      ),
    ],
  );
});

class _AnimatedTabIcon extends StatefulWidget {
  const _AnimatedTabIcon({
    required this.icon,
    required this.isSelected,
    required this.color,
  });

  final IconData icon;
  final bool isSelected;
  final Color color;

  @override
  State<_AnimatedTabIcon> createState() => _AnimatedTabIconState();
}

class _AnimatedTabIconState extends State<_AnimatedTabIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.25)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.25, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_controller);

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedTabIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.reverse(from: 1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(
        widget.icon,
        color: widget.color,
        size: 26,
      ),
    );
  }
}

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final impersonation = ref.watch(impersonationProvider).valueOrNull;
    final user = ref.watch(authProvider).valueOrNull;
    final isAdmin = user?.isAdmin ?? false;
    final totalPending = ref.watch(totalPendingProvider);
    final isDashboard = location == '/dashboard';

    final tabRoutes = [
      '/dashboard',
      '/attendance',
      '/students',
      if (isAdmin) '/inbox',
      '/more',
    ];

    final tabIcons = [
      Icons.home_rounded,
      Icons.qr_code_scanner_rounded,
      Icons.people_rounded,
      if (isAdmin) Icons.inbox_rounded,
      Icons.more_horiz_rounded,
    ];

    final tabKeys = [
      'home',
      'checkIn',
      'students',
      if (isAdmin) 'inbox',
      'more',
    ];

    int currentIndex = tabRoutes.length - 1; // default to More
    for (var i = 0; i < tabRoutes.length; i++) {
      if (location.startsWith(tabRoutes[i])) {
        currentIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            top: !isDashboard,
            child: Column(
              children: [
                const OfflineBanner(),
                if (impersonation != null && impersonation.active)
                  _ImpersonationBanner(schoolName: impersonation.schoolName),
                Expanded(child: child),
              ],
            ),
          ),
          // Bell is built into the home page header directly
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          context.go(tabRoutes[i]);
        },
        destinations: [
          for (var i = 0; i < tabRoutes.length; i++)
            NavigationDestination(
              icon: isAdmin && tabKeys[i] == 'inbox'
                  ? Badge(
                      isLabelVisible: totalPending > 0,
                      label: Text(
                        totalPending > 99 ? '99+' : '$totalPending',
                        style: const TextStyle(fontSize: 9),
                      ),
                      child: _AnimatedTabIcon(
                        icon: tabIcons[i],
                        isSelected: currentIndex == i,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : _AnimatedTabIcon(
                      icon: tabIcons[i],
                      isSelected: currentIndex == i,
                      color: AppColors.textSecondary,
                    ),
              selectedIcon: isAdmin && tabKeys[i] == 'inbox'
                  ? Badge(
                      isLabelVisible: totalPending > 0,
                      label: Text(
                        totalPending > 99 ? '99+' : '$totalPending',
                        style: const TextStyle(fontSize: 9),
                      ),
                      child: _AnimatedTabIcon(
                        icon: tabIcons[i],
                        isSelected: currentIndex == i,
                        color: AppColors.primary,
                      ),
                    )
                  : _AnimatedTabIcon(
                      icon: tabIcons[i],
                      isSelected: currentIndex == i,
                      color: AppColors.primary,
                    ),
              label: tabKeys[i].tr(),
            ),
        ],
      ),
    );
  }
}


class _ImpersonationBanner extends ConsumerWidget {
  const _ImpersonationBanner({this.schoolName});
  final String? schoolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: AppColors.warning,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${'saImpersonating'.tr()}'
                  '${schoolName != null ? ' — $schoolName' : ''}',
                  style: AppTextStyles.bodyBoldSm
                      .copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 28,
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(impersonationProvider.notifier)
                        .stopImpersonation();
                    ref.invalidate(authProvider);
                    if (context.mounted) {
                      context.go('/admin');
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.warning,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: AppTextStyles.bodyXs
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  child: Text('saReturnToAdmin'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
