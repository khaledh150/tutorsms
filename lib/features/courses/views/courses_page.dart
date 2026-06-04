import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/course_model.dart';
import '../providers/course_provider.dart';

const _weekdayKeys = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Returns the translated display name for a weekday key (e.g. 'Monday' -> 'monday'.tr()).
String _weekdayLabel(String key) => key.toLowerCase().tr();

/// Returns the translated short name for a weekday key (e.g. 'Monday' -> 'mon'.tr()).
String _weekdayShort(String key) => key.substring(0, 3).toLowerCase().tr();

final _hours = [
  for (var h = 6; h < 23; h++)
    '${h.toString().padLeft(2, '0')}:00-${(h + 1).toString().padLeft(2, '0')}:00',
];

class CoursesPage extends ConsumerStatefulWidget {
  const CoursesPage({super.key});

  @override
  ConsumerState<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends ConsumerState<CoursesPage> {
  String _tab = 'check';
  String _courseId = '';

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];
    final isLoading = coursesAsync.isLoading;
    final isAdmin = ref.watch(authProvider).valueOrNull?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('courses'.tr(), style: AppTextStyles.displaySm),
              const SizedBox(height: 16),
              _buildTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(coursesProvider);
                  },
                  child: courses.isEmpty && !isLoading
                      ? ListView(children: [
                          EmptyState(
                            icon: '📚',
                            title: 'noCoursesYet'.tr(),
                            subtitle: 'noCoursesHint'.tr(),
                            actionLabel: isAdmin ? 'addFirstCourse'.tr() : null,
                            onAction: isAdmin ? () => setState(() => _tab = 'manage') : null,
                            iconColor: AppColors.primary,
                          ),
                        ])
                      : _tab == 'check'
                          ? _CheckTab(
                              courses: courses,
                              courseId: _courseId,
                              onCourseChanged: (id) =>
                                  setState(() => _courseId = id),
                            )
                          : _ManageTab(
                              courses: courses,
                              isLoading: isLoading,
                              isAdmin: isAdmin,
                            ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        for (final key in ['check', 'manage']) ...[
          if (key == 'manage') const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:
                      _tab == key ? AppColors.primary : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: _tab == key
                      ? null
                      : Border.all(color: AppColors.border),
                  boxShadow: _tab == key
                      ? const [
                          BoxShadow(
                            offset: Offset(0, 2),
                            blurRadius: 8,
                            color: Color(0x1A6C5CE7),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  key == 'check'
                      ? 'checkCourses'.tr()
                      : 'manageCourses'.tr(),
                  style: AppTextStyles.bodyBoldSm.copyWith(
                    color: _tab == key
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckTab extends ConsumerStatefulWidget {
  const _CheckTab({
    required this.courses,
    required this.courseId,
    required this.onCourseChanged,
  });

  final List<Course> courses;
  final String courseId;
  final ValueChanged<String> onCourseChanged;

  @override
  ConsumerState<_CheckTab> createState() => _CheckTabState();
}

class _CheckTabState extends ConsumerState<_CheckTab> {
  String _dayFilter = '';
  String _timeFilter = '';

  @override
  Widget build(BuildContext context) {
    final studentsAsync = widget.courseId.isNotEmpty
        ? ref.watch(studentsForCourseProvider(widget.courseId))
        : null;
    final students = studentsAsync?.valueOrNull ?? [];
    final loading = studentsAsync?.isLoading ?? false;

    final selectedCourse =
        widget.courses.where((c) => c.id == widget.courseId).firstOrNull;

    final availableDays = <String>[];
    if (selectedCourse != null) {
      final daySet = <String>{};
      for (final d in selectedCourse.weekdays) {
        daySet.add(d);
      }
      for (final d in selectedCourse.times.keys) {
        daySet.add(d);
      }
      availableDays.addAll(_weekdayKeys.where(daySet.contains));
    }

    final availableTimes = <String>[];
    if (selectedCourse?.times != null) {
      final timeSet = <String>{};
      if (_dayFilter.isNotEmpty) {
        for (final t in selectedCourse!.times[_dayFilter] ?? []) {
          timeSet.add(t);
        }
      } else {
        for (final slots in selectedCourse!.times.values) {
          for (final t in slots) {
            timeSet.add(t);
          }
        }
      }
      availableTimes.addAll(_hours.where(timeSet.contains));
    }

    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: widget.courseId.isEmpty ? null : widget.courseId,
          decoration: InputDecoration(
            hintText: 'selectCourse'.tr(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          items: [
            for (final c in widget.courses)
              DropdownMenuItem(value: c.id, child: Text(c.name)),
          ],
          onChanged: (v) {
            widget.onCourseChanged(v ?? '');
            setState(() {
              _dayFilter = '';
              _timeFilter = '';
            });
          },
        ),
        if (widget.courseId.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _dayFilter.isEmpty ? null : _dayFilter,
                  decoration: InputDecoration(
                    hintText: 'allDays'.tr(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: '', child: Text('allDays'.tr())),
                    for (final d in availableDays)
                      DropdownMenuItem(
                          value: d, child: Text(d.toLowerCase().tr())),
                  ],
                  onChanged: (v) => setState(() {
                    _dayFilter = v ?? '';
                    _timeFilter = '';
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _timeFilter.isEmpty ? null : _timeFilter,
                  decoration: InputDecoration(
                    hintText: 'allTimes'.tr(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: '', child: Text('allTimes'.tr())),
                    for (final t in availableTimes)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setState(() => _timeFilter = v ?? ''),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: widget.courseId.isEmpty
              ? Center(
                  child: Text(
                    'selectCoursePrompt'.tr(),
                    style: AppTextStyles.bodyBase
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : loading
                  ? ListView.builder(
                      itemCount: 3,
                      itemBuilder: (_, _) => Container(
                        height: 64,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                        ),
                      ),
                    )
                  : students.isEmpty
                      ? Center(
                          child: Text(
                            'noStudentsFound'.tr(),
                            style: AppTextStyles.bodyBase
                                .copyWith(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          itemCount: students.length,
                          itemBuilder: (context, idx) {
                            final s = students[idx];
                            final nick = s['nick_name'] as String?;
                            final first = s['first_name'] as String? ?? '';
                            final last = s['last_name'] as String? ?? '';
                            final initial =
                                (nick ?? first).isNotEmpty
                                    ? (nick ?? first)[0].toUpperCase()
                                    : '?';

                            return GestureDetector(
                              onTap: () =>
                                  context.go('/students/${s['id']}'),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSm),
                                  border: Border.all(
                                      color: AppColors.borderLight),
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
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initial,
                                        style: AppTextStyles.bodyBoldSm
                                            .copyWith(
                                                color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            if (nick != null &&
                                                nick.isNotEmpty)
                                              TextSpan(
                                                text: '"$nick" ',
                                                style: AppTextStyles
                                                    .bodyBoldSm
                                                    .copyWith(
                                                        color: AppColors
                                                            .primary),
                                              ),
                                            TextSpan(
                                              text: '$first $last',
                                              style:
                                                  AppTextStyles.bodyBoldSm,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

class _ManageTab extends ConsumerStatefulWidget {
  const _ManageTab({required this.courses, required this.isLoading, required this.isAdmin});
  final List<Course> courses;
  final bool isLoading;
  final bool isAdmin;

  @override
  ConsumerState<_ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends ConsumerState<_ManageTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (_, _) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: widget.courses.length,
            itemBuilder: (context, idx) =>
                _CourseCard(course: widget.courses[idx], isAdmin: widget.isAdmin),
          ),
        ),
        if (widget.isAdmin) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _openWizard(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('addCourse'.tr(),
                      style:
                          AppTextStyles.bodyBoldSm.copyWith(color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openWizard(Course? course) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CourseWizard(course: course),
    );
    if (result == null || !mounted) return;

    final notifier = ref.read(coursesProvider.notifier);
    if (course != null) {
      await notifier.updateCourse(course.id, result);
    } else {
      await notifier.createCourse(result);
    }
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.course, required this.isAdmin});
  final Course course;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.name, style: AppTextStyles.bodyBoldBase),
                const SizedBox(height: 4),
                Text(
                  '${course.weekdays.map(_weekdayLabel).join(', ')} | ${'capacity'.tr()}: ${course.capacity ?? '∞'}',
                  style: AppTextStyles.bodyXs
                      .copyWith(color: AppColors.textMuted),
                ),
                for (final entry in course.times.entries)
                  if (entry.value.isNotEmpty)
                    Text(
                      '${entry.key}: ${entry.value.join(', ')}',
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textSecondary),
                    ),
                if (course.hourPackages.isNotEmpty || course.bookPrice > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final pkg in course.hourPackages)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            '${pkg.hours}hrs — ฿${_formatNumber(pkg.price)}',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (course.bookPrice > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            '📕 ฿${_formatNumber(course.bookPrice)}',
                            style: AppTextStyles.bodyXs.copyWith(
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isAdmin)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.info),
                  onPressed: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (_) => _CourseWizard(course: course),
                    );
                    if (result == null) return;
                    ref
                        .read(coursesProvider.notifier)
                        .updateCourse(course.id, result);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded,
                      size: 18, color: AppColors.danger),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('confirm'.tr()),
        content: Text('deleteThisCourse'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(coursesProvider.notifier).deleteCourse(course.id);
            },
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    }
    return '$value';
  }
}

class _CourseWizard extends StatefulWidget {
  const _CourseWizard({this.course});
  final Course? course;

  @override
  State<_CourseWizard> createState() => _CourseWizardState();
}

class _CourseWizardState extends State<_CourseWizard> {
  late String _name;
  late int _capacity;
  late List<String> _weekdaysList;
  late Map<String, List<String>> _times;
  late List<HourPackage> _hourPackages;
  late int _bookPrice;
  int _step = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.course;
    _name = c?.name ?? '';
    _capacity = c?.capacity ?? 0;
    _weekdaysList = List.from(c?.weekdays ?? []);
    _times = {
      for (final e in (c?.times ?? {}).entries) e.key: List.from(e.value),
    };
    _hourPackages = c?.hourPackages
            .map((p) => HourPackage(hours: p.hours, price: p.price))
            .toList() ??
        [];
    _bookPrice = c?.bookPrice ?? 0;
  }

  void _nextStep() {
    setState(() => _error = null);
    if (_step == 1 && _name.trim().isEmpty) {
      setState(() => _error = 'enterName'.tr());
      return;
    }
    if (_step == 1 && _capacity < 0) {
      setState(() => _error = 'capacityMustBePositive'.tr());
      return;
    }
    if (_step == 2 && _weekdaysList.isEmpty) {
      setState(() => _error = 'pleaseSelectDay'.tr());
      return;
    }
    if (_step < 3) {
      setState(() => _step++);
    } else {
      final cleanPkgs =
          _hourPackages.where((p) => p.hours > 0 && p.price > 0).toList();
      Navigator.pop(context, {
        'name': _name.trim(),
        'weekdays': _weekdaysList,
        'times': _times,
        'capacity': _capacity,
        'hour_packages': cleanPkgs.map((p) => p.toJson()).toList(),
        'book_price': _bookPrice,
      });
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_weekdaysList.contains(day)) {
        _weekdaysList.remove(day);
        _times.remove(day);
      } else {
        _weekdaysList.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = ['courseInfo'.tr(), 'schedule'.tr(), 'packagesAndPricing'.tr()];

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          maxWidth: 500,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.course != null
                        ? 'editCourse'.tr()
                        : 'newCourse'.tr(),
                    style: AppTextStyles.displaySm
                        .copyWith(color: AppColors.primary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        size: 24, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var i = 0; i < stepLabels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: i < _step
                                  ? AppColors.primary
                                  : AppColors.bgSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusFull),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            stepLabels[i],
                            style: AppTextStyles.bodyXs.copyWith(
                              color: i < _step
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildStepContent(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _step > 1
                          ? () => setState(() => _step--)
                          : () => Navigator.pop(context),
                      child: Text(
                          _step > 1 ? 'back'.tr() : 'cancel'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _step == 3
                            ? AppColors.success
                            : AppColors.primary,
                      ),
                      onPressed: _nextStep,
                      child: Text(
                          _step == 3 ? 'save'.tr() : 'next'.tr()),
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

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${'name'.tr()} *',
            style: AppTextStyles.bodySemiBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: _name,
          autofocus: true,
          style: AppTextStyles.bodyLg,
          onChanged: (v) {
            _name = v;
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 16),
        Text('capacity'.tr(),
            style: AppTextStyles.bodySemiBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: '$_capacity',
          keyboardType: TextInputType.number,
          onChanged: (v) => _capacity = int.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 4),
        Text(
          '0 = ${'unlimited'.tr()}',
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${'days'.tr()} *',
            style: AppTextStyles.bodySemiBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in _weekdayKeys)
              GestureDetector(
                onTap: () {
                  _toggleDay(d);
                  if (_error != null) setState(() => _error = null);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _weekdaysList.contains(d)
                        ? AppColors.primary
                        : AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: _weekdaysList.contains(d)
                          ? AppColors.primary
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    _weekdayShort(d),
                    style: AppTextStyles.bodyBoldSm.copyWith(
                      color: _weekdaysList.contains(d)
                          ? Colors.white
                          : AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final day in _weekdaysList) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_weekdayLabel(day),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final h in _hours)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            final curr = _times[day] ?? [];
                            if (curr.contains(h)) {
                              curr.remove(h);
                            } else {
                              curr.add(h);
                            }
                            _times[day] = curr;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (_times[day] ?? []).contains(h)
                                ? AppColors.primary
                                : Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSm),
                            border:
                                Border.all(color: AppColors.primary),
                          ),
                          child: Text(
                            h,
                            style: AppTextStyles.bodyXs.copyWith(
                              color: (_times[day] ?? []).contains(h)
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('hourPackages'.tr(),
            style: AppTextStyles.bodySemiBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        for (var i = 0; i < _hourPackages.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: _hourPackages[i].hours > 0
                        ? '${_hourPackages[i].hours}'
                        : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'hours'.tr(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() {
                      _hourPackages[i] = HourPackage(
                        hours: int.tryParse(v) ?? 0,
                        price: _hourPackages[i].price,
                      );
                    }),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('hrs'.tr(),
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textMuted)),
                ),
                Text('—',
                    style: AppTextStyles.bodyLg
                        .copyWith(color: AppColors.textMuted)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('฿',
                      style: AppTextStyles.bodyBoldSm
                          .copyWith(color: AppColors.textMuted)),
                ),
                Expanded(
                  child: TextFormField(
                    initialValue: _hourPackages[i].price > 0
                        ? '${_hourPackages[i].price}'
                        : '',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'price'.tr(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onChanged: (v) => setState(() {
                      _hourPackages[i] = HourPackage(
                        hours: _hourPackages[i].hours,
                        price: int.tryParse(v) ?? 0,
                      );
                    }),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded,
                      size: 18, color: AppColors.danger),
                  onPressed: () => setState(
                      () => _hourPackages.removeAt(i)),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: () => setState(() =>
              _hourPackages.add(const HourPackage(hours: 0, price: 0))),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: AppColors.primary,
                width: 2,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 20, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('addPackage'.tr(),
                    style: AppTextStyles.bodyBoldSm
                        .copyWith(color: AppColors.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('${'bookPrice'.tr()} (฿)',
            style: AppTextStyles.bodySemiBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: _bookPrice > 0 ? '$_bookPrice' : '',
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '0'),
          onChanged: (v) => _bookPrice = int.tryParse(v) ?? 0,
        ),
        const SizedBox(height: 4),
        Text(
          'bookPriceHint'.tr(),
          style: AppTextStyles.bodyXs.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
