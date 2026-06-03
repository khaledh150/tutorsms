import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../courses/models/course_model.dart';
import '../../courses/providers/course_provider.dart';
import '../../students/providers/student_provider.dart';
import '../../messaging/providers/messaging_provider.dart';
import '../repositories/application_repository.dart';

class EnrollStudentPage extends ConsumerStatefulWidget {
  const EnrollStudentPage({super.key, this.existingMode = false});
  final bool existingMode;

  @override
  ConsumerState<EnrollStudentPage> createState() => _EnrollStudentPageState();
}

class _EnrollStudentPageState extends ConsumerState<EnrollStudentPage> {
  int _step = 1;
  bool _saving = false;
  bool _submitted = false;
  String? _error;

  // Step 1
  final _nickCtrl = TextEditingController();
  final _firstCtrl = TextEditingController();
  final _lastCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _dob;
  XFile? _studentPhoto;
  String? _selectedLineUserId;

  // Step 2
  final Map<String, _CourseSelection> _selections = {};
  final Map<String, int> _hoursRemaining = {};

  // Step 3
  final List<XFile> _receipts = [];

  @override
  void dispose() {
    _nickCtrl.dispose();
    _firstCtrl.dispose();
    _lastCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  bool _validateStep(List<Course> courses) {
    setState(() => _error = null);
    if (_step == 1) {
      if (_nickCtrl.text.trim().isEmpty) {
        setState(() => _error = 'nicknameRequired'.tr());
        return false;
      }
      if (_firstCtrl.text.trim().isEmpty) {
        setState(() => _error = 'firstNameRequired'.tr());
        return false;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        setState(() => _error = 'phoneRequired'.tr());
        return false;
      }
    }
    if (_step == 2) {
      if (_selections.isEmpty) {
        setState(() => _error = 'pleaseSelectCourseAdm'.tr());
        return false;
      }
      for (final cid in _selections.keys) {
        final sel = _selections[cid]!;
        final c = courses.where((x) => x.id == cid).firstOrNull;
        final hasTimes = c != null &&
            c.times.values.any((arr) => arr.isNotEmpty);
        if (hasTimes && sel.days.isEmpty) {
          setState(() => _error =
              '${'pleaseSelectDayTime'.tr()} (${c.name})');
          return false;
        }
      }
    }
    return true;
  }

  void _nextStep(List<Course> courses) {
    if (_validateStep(courses)) {
      setState(() => _step = (_step + 1).clamp(1, 3));
    }
  }

  void _prevStep() {
    setState(() {
      _error = null;
      _step = (_step - 1).clamp(1, 3);
    });
  }

  void _toggleCourse(String courseId, Course course) {
    setState(() {
      if (_selections.containsKey(courseId)) {
        _selections.remove(courseId);
      } else {
        final hasTimes =
            course.times.values.any((arr) => arr.isNotEmpty);
        final autoDays = <String, List<String>>{};
        if (!hasTimes) {
          for (final d in course.weekdays) {
            autoDays[d] = [];
          }
        }
        _selections[courseId] = _CourseSelection(
          days: autoDays,
          packageIdx: 0,
          includeBook: false,
        );
      }
      _error = null;
    });
  }

  void _toggleTime(String courseId, String day, String time) {
    setState(() {
      final sel = _selections[courseId];
      if (sel == null) return;
      final current = List<String>.from(sel.days[day] ?? []);
      if (current.contains(time)) {
        current.remove(time);
      } else {
        current.add(time);
      }
      final newDays = Map<String, List<String>>.from(sel.days);
      if (current.isEmpty) {
        newDays.remove(day);
      } else {
        newDays[day] = current;
      }
      _selections[courseId] = sel.copyWith(days: newDays);
      _error = null;
    });
  }

  void _setPackage(String courseId, int idx) {
    setState(() {
      final sel = _selections[courseId];
      if (sel == null) return;
      _selections[courseId] = sel.copyWith(packageIdx: idx);
    });
  }

  int _totalPrice(List<Course> courses) {
    int total = 0;
    for (final cid in _selections.keys) {
      final c = courses.where((x) => x.id == cid).firstOrNull;
      if (c == null) continue;
      final sel = _selections[cid]!;
      final pkg = sel.packageIdx < c.hourPackages.length
          ? c.hourPackages[sel.packageIdx]
          : null;
      total += pkg?.price ?? 0;
      if (sel.includeBook) total += c.bookPrice;
    }
    return total;
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _studentPhoto = file);
  }

  Future<void> _pickReceipts() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif', 'pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final pf in result.files) {
      if (pf.path == null) continue;
      if (pf.size > AppConstants.maxFileSize) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('fileTooLarge'.tr())),
          );
        }
        continue;
      }
      _receipts.add(XFile(pf.path!));
    }
    setState(() {});
  }

  Future<void> _submit(List<Course> courses) async {
    if (!_validateStep(courses)) return;
    if (!widget.existingMode && _receipts.isEmpty) {
      setState(() => _error = 'receiptRequiredError'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final repo = ApplicationRepository();
      final user = ref.read(authProvider).valueOrNull;
      final isAdmin = user?.isAdmin ?? false;

      List<String> receiptUrls = [];
      if (_receipts.isNotEmpty) {
        receiptUrls = await repo.uploadReceipts(_receipts);
      }

      final slots = <String, dynamic>{};
      final limits = <String, int>{};
      final enrollmentRows = <Map<String, dynamic>>[];
      final purchasedPackages = <Map<String, dynamic>>[];

      for (final cid in _selections.keys) {
        final sel = _selections[cid]!;
        final c = courses.where((x) => x.id == cid).firstOrNull;
        final pkg = c != null && sel.packageIdx < c.hourPackages.length
            ? c.hourPackages[sel.packageIdx]
            : null;
        final hrs = pkg?.hours ?? 10;
        slots[cid] = sel.days;
        limits[cid] = hrs;

        if (pkg != null) {
          purchasedPackages.add({
            'course_id': cid,
            'course_name': c?.name ?? cid,
            'hours': pkg.hours,
            'price': pkg.price,
          });
        }

        final remaining = _hoursRemaining[cid];
        final initialUsed = widget.existingMode &&
                remaining != null &&
                remaining >= 0
            ? (hrs - remaining).clamp(0, hrs)
            : 0;

        enrollmentRows.add({
          'course_id': cid,
          'schedule': sel.days,
          'purchased_hours': hrs,
          'initial_used_hours': initialUsed,
          'status': 'active',
        });
      }

      final total = _totalPrice(courses);

      if (isAdmin) {
        final studentId = await repo.directEnrollStudent(
          nickName: _nickCtrl.text.trim(),
          firstName: _firstCtrl.text.trim(),
          lastName: _lastCtrl.text.trim(),
          dob: _dob,
          parentPhone: _phoneCtrl.text.trim(),
          courses: slots,
          courseLimits: limits,
          paymentReceiptUrls: receiptUrls,
          enrollmentRows: enrollmentRows,
          studentPhoto: _studentPhoto,
          purchasedPackages: purchasedPackages,
          totalPrice: total,
        );
        if (_selectedLineUserId != null && studentId != null) {
          final unlinked = ref.read(unlinkedUsersProvider).valueOrNull ?? [];
          final u = unlinked.where((x) => x.lineUserId == _selectedLineUserId).firstOrNull;
          await ref.read(messagingRepositoryProvider).linkLineAccount(
            studentId: studentId,
            lineUserId: _selectedLineUserId!,
            displayName: u?.displayName,
            pictureUrl: u?.pictureUrl,
          );
        }
      } else {
        await repo.submitApplication(
          nickName: _nickCtrl.text.trim(),
          firstName: _firstCtrl.text.trim(),
          lastName: _lastCtrl.text.trim(),
          dob: _dob,
          parentPhone: _phoneCtrl.text.trim(),
          courses: slots,
          courseLimits: limits,
          paymentReceiptUrls: receiptUrls,
          submittedBy: user?.id,
          purchasedPackages: purchasedPackages,
          totalPrice: total,
          studentPhotoFile: _studentPhoto,
        );
      }

      ref.invalidate(studentsWithStatusProvider);
      if (mounted) setState(() => _submitted = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reset() {
    setState(() {
      _step = 1;
      _submitted = false;
      _nickCtrl.clear();
      _firstCtrl.clear();
      _lastCtrl.clear();
      _phoneCtrl.clear();
      _dob = null;
      _studentPhoto = null;
      _selectedLineUserId = null;
      _selections.clear();
      _hoursRemaining.clear();
      _receipts.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);
    final courses = coursesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: _submitted
          ? _buildSuccess()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textPrimary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.existingMode
                              ? 'addExistingStudent'.tr()
                              : 'addNewStudent'.tr(),
                          style: AppTextStyles.displaySm,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _step == 1
                        ? _buildStep1()
                        : _step == 2
                            ? _buildStep2(courses)
                            : _buildStep3(courses),
                  ),
                ),
                if (_error != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(_error!,
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.danger)),
                  ),
                _buildNavButtons(courses),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(3, (i) {
          final s = i + 1;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _step >= s
                        ? AppColors.primary
                        : AppColors.bgSurface,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: _step > s
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '$s',
                          style: TextStyle(
                            color: _step >= s
                                ? Colors.white
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
                if (s < 3)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _step > s
                            ? AppColors.primary
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStep1() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 8,
              color: Color(0x0A000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.existingMode
                ? 'existingStudentInfo'.tr()
                : 'studentInfo'.tr(),
            style:
                AppTextStyles.displaySm.copyWith(color: AppColors.primary),
          ),
          if (widget.existingMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text('existingStudentHint'.tr(),
                  style: AppTextStyles.bodyXs.copyWith(
                      color: const Color(0xFFB45309),
                      fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 16),
          _FormField(
            label: '${'nickName'.tr()} *',
            controller: _nickCtrl,
            hint: 'nicknamePlaceholder'.tr(),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: '${'firstName'.tr()} *',
            controller: _firstCtrl,
            hint: 'firstNamePlaceholder'.tr(),
          ),
          const SizedBox(height: 12),
          _FormField(
            label: 'lastName'.tr(),
            controller: _lastCtrl,
            hint: 'lastNamePlaceholder'.tr(),
          ),
          const SizedBox(height: 12),
          Text('dob'.tr(),
              style: AppTextStyles.bodyBoldSm
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2015),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _dob = picked.toIso8601String().split('T')[0]);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderLight),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Text(
                _dob ?? 'selectDate'.tr(),
                style: AppTextStyles.bodyBase.copyWith(
                  color: _dob != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('studentPhoto'.tr(),
              style: AppTextStyles.bodyBoldSm
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _pickPhoto,
            child: _studentPhoto != null
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                          child: Image.file(
                            File(_studentPhoto!.path),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('studentPhoto'.tr(),
                                  style: AppTextStyles.bodyBoldSm),
                              const SizedBox(height: 2),
                              Text('tapToChange'.tr(),
                                  style: AppTextStyles.bodyXs
                                      .copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded,
                            size: 18, color: AppColors.primary),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: AppColors.textMuted),
                        const SizedBox(width: 12),
                        Text('addPhoto'.tr(),
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          Text('guardian'.tr(),
              style: AppTextStyles.displaySm
                  .copyWith(color: AppColors.primary)),
          const SizedBox(height: 12),
          _FormField(
            label: '${'phone'.tr()} *',
            controller: _phoneCtrl,
            hint: '08XXXXXXXX',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),
          _buildLineAccountPicker(),
        ],
      ),
    );
  }

  Widget _buildLineAccountPicker() {
    final unlinkedAsync = ref.watch(unlinkedUsersProvider);
    final unlinked = unlinkedAsync.valueOrNull ?? [];
    if (unlinked.isEmpty) return const SizedBox.shrink();

    final selected = _selectedLineUserId != null
        ? unlinked.where((u) => u.lineUserId == _selectedLineUserId).firstOrNull
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('linkLine'.tr(),
            style: AppTextStyles.bodyBoldSm.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _selectedLineUserId,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'selectLineAccount'.tr(),
            hintStyle: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            prefixIcon: Icon(Icons.chat_bubble_rounded, color: AppColors.lineGreen, size: 20),
          ),
          menuMaxHeight: 250,
          items: [
            DropdownMenuItem<String>(value: null, child: Text('none'.tr(), style: AppTextStyles.bodySm.copyWith(color: AppColors.textMuted))),
            ...unlinked.map((u) => DropdownMenuItem<String>(
              value: u.lineUserId,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.lineGreen,
                    backgroundImage: u.pictureUrl != null ? NetworkImage(u.pictureUrl!) : null,
                    child: u.pictureUrl == null ? Text((u.displayName ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)) : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(u.displayName ?? 'Unknown', overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySm)),
                ],
              ),
            )),
          ],
          onChanged: (v) => setState(() => _selectedLineUserId = v),
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${'linkedTo'.tr()} ${selected.displayName}',
                style: AppTextStyles.bodyXs.copyWith(color: AppColors.lineGreen, fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  Widget _buildStep2(List<Course> courses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('selectSchedule'.tr(),
            style:
                AppTextStyles.displaySm.copyWith(color: AppColors.primary)),
        const SizedBox(height: 12),
        for (final course in courses) _buildCourseCard(course),
      ],
    );
  }

  Widget _buildCourseCard(Course course) {
    final isSelected = _selections.containsKey(course.id);
    final sel = _selections[course.id];
    final hasTimes = course.times.values.any((arr) => arr.isNotEmpty);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 1),
            blurRadius: isSelected ? 8 : 4,
            color: const Color(0x0A000000),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => _toggleCourse(course.id, course),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              color: isSelected ? AppColors.primary : Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: AppTextStyles.bodyBoldBase.copyWith(
                        color:
                            isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : AppColors.borderLight,
                        width: 2,
                      ),
                      color: isSelected ? Colors.white : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: AppColors.primary)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isSelected && sel != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day/time slots
                  if (hasTimes) ...[
                    Text('tapSlotsYouWant'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    for (final day in course.weekdays)
                      if ((course.times[day] ?? []).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(day,
                                  style: AppTextStyles.bodyBoldSm
                                      .copyWith(color: AppColors.textPrimary)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    (course.times[day] ?? []).map((time) {
                                  final active =
                                      sel.days[day]?.contains(time) ?? false;
                                  return GestureDetector(
                                    onTap: () =>
                                        _toggleTime(course.id, day, time),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: active
                                            ? AppColors.success
                                            : AppColors.bgSurface,
                                        borderRadius: BorderRadius.circular(
                                            AppTheme.radiusMd),
                                        border: Border.all(
                                          color: active
                                              ? AppColors.success
                                              : AppColors.borderLight,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        time,
                                        style: AppTextStyles.bodyBoldSm
                                            .copyWith(
                                          color: active
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                    const SizedBox(height: 8),
                  ],
                  // Packages
                  if (course.hourPackages.isNotEmpty) ...[
                    Text('selectPackage'.tr(),
                        style: AppTextStyles.bodyBoldSm
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.0,
                      children: List.generate(
                          course.hourPackages.length, (idx) {
                        final pkg = course.hourPackages[idx];
                        final active = sel.packageIdx == idx;
                        return GestureDetector(
                          onTap: () => _setPackage(course.id, idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.bgSurface,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(
                                color: active
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${pkg.hours} ${'hrs'.tr()}',
                                  style: AppTextStyles.bodyBoldLg.copyWith(
                                    color: active
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '฿${pkg.price}',
                                  style: AppTextStyles.bodyBoldSm.copyWith(
                                    color: active
                                        ? Colors.white
                                            .withValues(alpha: 0.85)
                                        : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                  // Hours remaining (existing mode)
                  if (widget.existingMode &&
                      course.hourPackages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(color: const Color(0xFFF59E0B), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${'hoursRemainingLabel'.tr()} *',
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(color: const Color(0xFFB45309))),
                          const SizedBox(height: 4),
                          Text('hoursRemainingHint'.tr(),
                              style: AppTextStyles.bodyXs
                                  .copyWith(color: const Color(0xFF92400E))),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.displaySm,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd),
                                borderSide: const BorderSide(
                                    color: Color(0xFFF59E0B)),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              hintText: '0',
                            ),
                            onChanged: (v) {
                              _hoursRemaining[course.id] =
                                  int.tryParse(v) ?? 0;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Book price
                  if (course.bookPrice > 0) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selections[course.id] = sel.copyWith(
                            includeBook: !sel.includeBook);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: sel.includeBook
                              ? AppColors.warningLight
                              : AppColors.bgSurface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: sel.includeBook
                                ? AppColors.warning
                                : AppColors.borderLight,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sel.includeBook
                                  ? Icons.check_box
                                  : Icons.check_box_outline_blank,
                              color: sel.includeBook
                                  ? AppColors.warning
                                  : AppColors.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('includeBook'.tr(),
                                  style: AppTextStyles.bodyBoldSm),
                            ),
                            Text(
                              '฿${course.bookPrice}',
                              style: AppTextStyles.bodyBoldSm.copyWith(
                                  color: const Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3(List<Course> courses) {
    final total = _totalPrice(courses);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius2xl),
        border: Border.all(color: AppColors.borderPurple),
        boxShadow: const [
          BoxShadow(
              offset: Offset(0, 2),
              blurRadius: 8,
              color: Color(0x0A000000)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('reviewSubmit'.tr(),
              style: AppTextStyles.displaySm
                  .copyWith(color: AppColors.primary)),
          const SizedBox(height: 16),
          // Student summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgMain,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              children: [
                _reviewRow('nickName'.tr(),
                    '${_nickCtrl.text} (${_firstCtrl.text} ${_lastCtrl.text})'),
                _reviewRow('phone'.tr(), _phoneCtrl.text),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Course summaries
          for (final cid in _selections.keys) ...[
            Builder(builder: (_) {
              final c = courses.where((x) => x.id == cid).firstOrNull;
              final sel = _selections[cid]!;
              final pkg = c != null && sel.packageIdx < c.hourPackages.length
                  ? c.hourPackages[sel.packageIdx]
                  : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c?.name ?? cid,
                        style: AppTextStyles.bodyBoldBase
                            .copyWith(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(
                      sel.days.entries
                          .map((e) => e.value.isNotEmpty
                              ? '${e.key}: ${e.value.join(', ')}'
                              : e.key)
                          .join(' | '),
                      style: AppTextStyles.bodyXs
                          .copyWith(color: AppColors.textMuted),
                    ),
                    if (pkg != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${pkg.hours} ${'hrs'.tr()}',
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(color: AppColors.primary)),
                          const SizedBox(width: 12),
                          Text('฿${pkg.price}',
                              style: AppTextStyles.bodyBoldSm
                                  .copyWith(color: AppColors.success)),
                        ],
                      ),
                    ],
                    if (sel.includeBook && (c?.bookPrice ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ ${'book'.tr()}: ฿${c!.bookPrice}',
                          style: AppTextStyles.bodyBoldSm
                              .copyWith(color: const Color(0xFFB45309)),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
          // Total
          if (total > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('total'.tr(), style: AppTextStyles.bodyBoldBase),
                  Text('฿$total',
                      style: AppTextStyles.displaySm
                          .copyWith(color: AppColors.success)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Receipt upload
          Text(
            widget.existingMode
                ? 'paymentReceiptOptional'.tr()
                : '${'uploadReceipt'.tr()} *',
            style: AppTextStyles.bodyBoldSm
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickReceipts,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: AppColors.borderLight,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Text(
                  _receipts.isNotEmpty
                      ? 'filesSelected'
                          .tr(namedArgs: {'count': '${_receipts.length}'})
                      : 'tapToAttachReceipt'.tr(),
                  style: AppTextStyles.bodyBoldSm
                      .copyWith(color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.textSecondary)),
          Flexible(
            child: Text(value,
                style: AppTextStyles.bodyBoldSm,
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons(List<Course> courses) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_step > 1)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _prevStep,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                label: Text('backBtn'.tr()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
              ),
            ),
          if (_step > 1) const SizedBox(width: 12),
          Expanded(
            child: _step < 3
                ? ElevatedButton.icon(
                    onPressed: () => _nextStep(courses),
                    icon: Text('nextBtn'.tr(),
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    label:
                        const Icon(Icons.arrow_forward_rounded, size: 20),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _saving ? null : () => _submit(courses),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.existingMode ? 'addExistingStudent'.tr() : 'addNewStudent'.tr(),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radius2xl),
            boxShadow: const [
              BoxShadow(
                  offset: Offset(0, 4),
                  blurRadius: 16,
                  color: Color(0x10000000)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 64, color: AppColors.success),
              const SizedBox(height: 16),
              Text(
                widget.existingMode
                    ? 'existingStudentAdded'
                        .tr(namedArgs: {'nick': _nickCtrl.text})
                    : 'studentAdded'
                        .tr(namedArgs: {'nick': _nickCtrl.text}),
                style: AppTextStyles.displayMd
                    .copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('studentEnrolled'.tr(),
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                  ),
                ),
                child: Text('addAnother'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/dashboard'),
                child: Text('backToHome'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.bodyBoldSm
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTextStyles.bodyBase.copyWith(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _CourseSelection {
  final Map<String, List<String>> days;
  final int packageIdx;
  final bool includeBook;

  const _CourseSelection({
    required this.days,
    required this.packageIdx,
    required this.includeBook,
  });

  _CourseSelection copyWith({
    Map<String, List<String>>? days,
    int? packageIdx,
    bool? includeBook,
  }) =>
      _CourseSelection(
        days: days ?? this.days,
        packageIdx: packageIdx ?? this.packageIdx,
        includeBook: includeBook ?? this.includeBook,
      );
}
