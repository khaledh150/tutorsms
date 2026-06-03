import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';

class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  String _tab = 'active';
  String _search = '';
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  int _visibleCount = 50;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    setState(() => _visibleCount += 50);
  }

  @override
  Widget build(BuildContext context) {
    final allStudentsAsync = ref.watch(studentsWithStatusProvider);
    final allStudents = allStudentsAsync.valueOrNull ?? [];
    final isLoading = allStudentsAsync.isLoading;

    final byTab = _groupByTab(allStudents);
    final sourceList = _search.trim().isNotEmpty ? allStudents : (byTab[_tab] ?? []);

    final filtered = _filterStudents(sourceList, _search);
    final visible = filtered.take(_visibleCount).toList();

    final tabs = [
      _TabInfo(
          key: 'active',
          label: 'tabActive'.tr(),
          count: (byTab['active'] ?? []).length,
          color: AppColors.success),
      _TabInfo(
          key: 'notActive',
          label: 'tabNotActive'.tr(),
          count: (byTab['notActive'] ?? []).length,
          color: AppColors.warning),
      _TabInfo(
          key: 'finished',
          label: 'tabFinished'.tr(),
          count: (byTab['finished'] ?? []).length,
          color: AppColors.danger),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text('students'.tr(), style: AppTextStyles.displaySm),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTabs(tabs),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(studentsWithStatusProvider);
                },
                child: isLoading
                    ? _buildShimmer()
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : _buildList(visible, filtered.length),
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildTabs(List<_TabInfo> tabs) {
    final activeIndex = tabs.indexWhere((t) => t.key == _tab);
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 6) / tabs.length;
          return Stack(
            children: [
              // Sliding bubble background
              AnimatedPositioned(
                duration: const Duration(milliseconds: 320),
                curve: const Cubic(0.34, 1.56, 0.64, 1.0),
                left: 3 + (activeIndex * tabWidth),
                top: 3,
                bottom: 3,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: tabs[activeIndex].color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 3),
                        blurRadius: 8,
                        color: tabs[activeIndex].color.withValues(alpha: 0.35),
                      ),
                    ],
                  ),
                ),
              ),
              // Tab labels
              Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _tab = tabs[i].key;
                            _visibleCount = 50;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: AppTextStyles.bodyXs.copyWith(
                              color: _tab == tabs[i].key
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                            child: Text('${tabs[i].label} (${tabs[i].count})'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() {
          _search = v;
          _visibleCount = 50;
        }),
        style: AppTextStyles.bodySm,
        decoration: InputDecoration(
          hintText: 'searchStudents'.tr(),
          hintStyle: AppTextStyles.bodySm.copyWith(
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textMuted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isCollapsed: true,
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      itemBuilder: (_, _) => Container(
        height: 64,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'noStudentsFound'.tr(),
          style: AppTextStyles.bodyLg.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildList(List<StudentWithStatus> visible, int totalCount) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visible.length + (visible.length < totalCount ? 1 : 0),
      itemBuilder: (context, idx) {
        if (idx >= visible.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child:
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final s = visible[idx];
        return RepaintBoundary(
          child: _StudentItemAnimator(
            key: ValueKey('${_tab}_${s.id}'),
            index: idx,
            child: _StudentCard(
              student: s,
              tab: _tab,
              onTap: () {
                HapticFeedback.lightImpact();
                context.go('/students/${s.id}');
              },
            ),
          ),
        );
      },
    );
  }

  Map<String, List<StudentWithStatus>> _groupByTab(
      List<StudentWithStatus> all) {
    final map = <String, List<StudentWithStatus>>{
      'active': [],
      'notActive': [],
      'finished': [],
    };
    for (final s in all) {
      (map[s.tab] ??= []).add(s);
    }
    return map;
  }

  List<StudentWithStatus> _filterStudents(
      List<StudentWithStatus> students, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return students;
    return students.where((s) {
      return (s.nickName ?? '').toLowerCase().contains(q) ||
          s.firstName.toLowerCase().contains(q) ||
          s.lastName.toLowerCase().contains(q) ||
          (s.parentPhone ?? '').contains(q) ||
          (s.lineDisplayName ?? '').toLowerCase().contains(q) ||
          s.courseNames.any((c) => c.toLowerCase().contains(q));
    }).toList();
  }
}

class _TabInfo {
  final String key;
  final String label;
  final int count;
  final Color color;
  const _TabInfo(
      {required this.key,
      required this.label,
      required this.count,
      required this.color});
}

class _StudentItemAnimator extends StatefulWidget {
  const _StudentItemAnimator({
    super.key,
    required this.child,
    required this.index,
  });

  final Widget child;
  final int index;

  @override
  State<_StudentItemAnimator> createState() => _StudentItemAnimatorState();
}

class _StudentItemAnimatorState extends State<_StudentItemAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // Dynamic delay capped to avoid infinite scroll lags
    final delay = Duration(milliseconds: (widget.index * 35).clamp(0, 300));
    Future.delayed(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({
    required this.student,
    required this.tab,
    required this.onTap,
  });

  final StudentWithStatus student;
  final String tab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 1),
              blurRadius: 4,
              color: Color(0x08000000),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(child: _buildInfo()),
            if (tab == 'finished')
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Text(
                  'hoursUp'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Hero(
      tag: 'student_avatar_${student.id}',
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        clipBehavior: Clip.antiAlias,
        child: student.photoUrl != null
            ? Image.network(
                student.photoUrl!,
                width: 40,
                height: 40,
                cacheWidth: 80,
                cacheHeight: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _initialText(),
              )
            : _initialText(),
      ),
    );
  }

  Widget _initialText() {
    return Center(
      child: Text(
        student.initial,
        style: AppTextStyles.bodyBoldSm.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              if (student.nickName != null && student.nickName!.isNotEmpty)
                TextSpan(
                  text: '"${student.nickName}" ',
                  style:
                      AppTextStyles.bodyBoldSm.copyWith(color: AppColors.primary),
                ),
              TextSpan(
                text: '${student.firstName} ${student.lastName}',
                style: AppTextStyles.bodyBoldSm,
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            children: [
              if (tab == 'finished' && student.totalPurchased > 0)
                TextSpan(
                  text:
                      '${student.totalUsed.toStringAsFixed(0)}/${student.totalPurchased} ${'hrs'.tr()} ',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.danger),
                ),
              if (tab == 'notActive' && student.lastCheckin != null)
                TextSpan(
                  text:
                      '${'lastCheckin'.tr()}: ${_formatDate(student.lastCheckin!)} ',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
              if (student.parentPhone != null)
                TextSpan(
                  text: student.parentPhone!,
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
