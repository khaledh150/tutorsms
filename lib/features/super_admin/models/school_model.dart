class SchoolHealth {
  final String schoolId;
  final String name;
  final String status; // active | suspended | archived
  final String plan;
  final String? ownerId;
  final String createdAt;
  final int maxStudents;
  final int maxStaff;
  final Map<String, bool> featureFlags;
  final Map<String, bool> setupChecklist;
  final int activeStudents;
  final int totalStudents;
  final int staffCount;
  final int adminCount;
  final int courseCount;
  final int checkins30d;
  final int lineMessages30d;
  final String? ownerLastLogin;
  final String? ownerName;
  final String? ownerEmail;
  final String? contactEmail;
  final String? contactPhone;
  final String? address;
  final String? notes;
  final String? trialEndsAt;    // ISO date string, null if no trial
  final String? trialDuration;  // '7d', '30d', '6m', '1y', null if no trial

  const SchoolHealth({
    required this.schoolId,
    required this.name,
    required this.status,
    required this.plan,
    this.ownerId,
    required this.createdAt,
    this.maxStudents = 50,
    this.maxStaff = 5,
    this.featureFlags = const {},
    this.setupChecklist = const {},
    this.activeStudents = 0,
    this.totalStudents = 0,
    this.staffCount = 0,
    this.adminCount = 0,
    this.courseCount = 0,
    this.checkins30d = 0,
    this.lineMessages30d = 0,
    this.ownerLastLogin,
    this.ownerName,
    this.ownerEmail,
    this.contactEmail,
    this.contactPhone,
    this.address,
    this.notes,
    this.trialEndsAt,
    this.trialDuration,
  });

  factory SchoolHealth.fromJson(Map<String, dynamic> json) {
    return SchoolHealth(
      schoolId: json['school_id'] as String,
      name: json['name'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      plan: json['plan'] as String? ?? 'basic',
      ownerId: json['owner_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      maxStudents: (json['max_students'] as num?)?.toInt() ?? 50,
      maxStaff: (json['max_staff'] as num?)?.toInt() ?? 5,
      featureFlags: _toBoolMap(json['feature_flags']),
      setupChecklist: _toBoolMap(json['setup_checklist']),
      activeStudents: (json['active_students'] as num?)?.toInt() ?? 0,
      totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
      staffCount: (json['staff_count'] as num?)?.toInt() ?? 0,
      adminCount: (json['admin_count'] as num?)?.toInt() ?? 0,
      courseCount: (json['course_count'] as num?)?.toInt() ?? 0,
      checkins30d: (json['checkins_30d'] as num?)?.toInt() ?? 0,
      lineMessages30d: (json['line_messages_30d'] as num?)?.toInt() ?? 0,
      ownerLastLogin: json['owner_last_login'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      trialEndsAt: json['trial_ends_at'] as String?,
      trialDuration: json['trial_duration'] as String?,
    );
  }

  int get setupPercent {
    final items = setupChecklist.values.toList();
    if (items.isEmpty) return 0;
    return (items.where((v) => v).length * 100 ~/ items.length);
  }

  int get totalTeam => adminCount + staffCount;

  bool get isOnTrial => trialEndsAt != null && status == 'free';

  bool get isTrialExpired {
    if (trialEndsAt == null) return false;
    return DateTime.now().isAfter(DateTime.parse(trialEndsAt!));
  }

  int get trialDaysRemaining {
    if (trialEndsAt == null) return 0;
    final diff = DateTime.parse(trialEndsAt!).difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isTrialEndingSoon {
    if (!isOnTrial) return false;
    return trialDaysRemaining <= 7;
  }

  String get trialDurationLabel {
    switch (trialDuration) {
      case '7d': return '7-day';
      case '30d': return '30-day';
      case '6m': return '6-month';
      case '1y': return '1-year';
      default: return trialDuration ?? '';
    }
  }

  SchoolHealth copyWith({
    String? status,
    String? trialEndsAt,
    String? trialDuration,
  }) => SchoolHealth(
        schoolId: schoolId,
        name: name,
        status: status ?? this.status,
        plan: plan,
        ownerId: ownerId,
        createdAt: createdAt,
        maxStudents: maxStudents,
        maxStaff: maxStaff,
        featureFlags: featureFlags,
        setupChecklist: setupChecklist,
        activeStudents: activeStudents,
        totalStudents: totalStudents,
        staffCount: staffCount,
        adminCount: adminCount,
        courseCount: courseCount,
        checkins30d: checkins30d,
        lineMessages30d: lineMessages30d,
        ownerLastLogin: ownerLastLogin,
        ownerName: ownerName,
        ownerEmail: ownerEmail,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        address: address,
        notes: notes,
        trialEndsAt: trialEndsAt ?? this.trialEndsAt,
        trialDuration: trialDuration ?? this.trialDuration,
      );

  static Map<String, bool> _toBoolMap(dynamic raw) {
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v == true));
    }
    return {};
  }
}
