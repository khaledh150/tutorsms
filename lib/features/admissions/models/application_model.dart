class CourseSelection {
  final Map<String, List<String>> days;
  final int packageIdx;
  final bool includeBook;

  const CourseSelection({
    this.days = const {},
    this.packageIdx = 0,
    this.includeBook = false,
  });

  Map<String, dynamic> toJson() => {
        'days': days,
        'packageIdx': packageIdx,
        'includeBook': includeBook,
      };

  factory CourseSelection.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'];
    final parsedDays = <String, List<String>>{};
    if (rawDays is Map) {
      for (final entry in rawDays.entries) {
        final key = entry.key as String;
        final value = entry.value;
        if (value is List) {
          parsedDays[key] = value.cast<String>();
        }
      }
    }
    return CourseSelection(
      days: parsedDays,
      packageIdx: (json['packageIdx'] as num?)?.toInt() ?? 0,
      includeBook: json['includeBook'] as bool? ?? false,
    );
  }
}

class PurchasedPackage {
  final String courseId;
  final String courseName;
  final int hours;
  final int price;

  const PurchasedPackage({
    required this.courseId,
    required this.courseName,
    required this.hours,
    required this.price,
  });

  factory PurchasedPackage.fromJson(Map<String, dynamic> json) =>
      PurchasedPackage(
        courseId: json['course_id'] as String? ?? '',
        courseName: json['course_name'] as String? ?? '',
        hours: (json['hours'] as num?)?.toInt() ?? 0,
        price: (json['price'] as num?)?.toInt() ?? 0,
      );
}

class Application {
  final String id;
  final String? firstName;
  final String? lastName;
  final String? nickName;
  final String? dob;
  final String? parentEmail;
  final String? parentPhone;
  final Map<String, dynamic> courses;
  final Map<String, int> courseLimits;
  final String status;
  final String createdAt;
  final List<String> paymentReceiptUrls;
  final String? submittedBy;
  final List<PurchasedPackage> purchasedPackages;
  final int? totalPrice;

  const Application({
    required this.id,
    this.firstName,
    this.lastName,
    this.nickName,
    this.dob,
    this.parentEmail,
    this.parentPhone,
    this.courses = const {},
    this.courseLimits = const {},
    this.status = 'pending',
    required this.createdAt,
    this.paymentReceiptUrls = const [],
    this.submittedBy,
    this.purchasedPackages = const [],
    this.totalPrice,
  });

  String get displayName {
    final parts = <String>[];
    if (nickName != null && nickName!.isNotEmpty) parts.add('"$nickName"');
    if (firstName != null) parts.add(firstName!);
    if (lastName != null) parts.add(lastName!);
    return parts.join(' ').trim();
  }

  String get initial =>
      (nickName ?? firstName ?? '?').isNotEmpty
          ? (nickName ?? firstName ?? '?')[0].toUpperCase()
          : '?';

  factory Application.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];
    final parsedCourses = <String, dynamic>{};
    if (rawCourses is Map) {
      parsedCourses.addAll(Map<String, dynamic>.from(rawCourses));
    }

    final rawLimits = json['course_limits'];
    final parsedLimits = <String, int>{};
    if (rawLimits is Map) {
      for (final entry in rawLimits.entries) {
        parsedLimits[entry.key as String] =
            (entry.value as num?)?.toInt() ?? 0;
      }
    }

    final rawReceipts = json['payment_receipt_urls'];
    final receipts = <String>[];
    if (rawReceipts is List) {
      receipts.addAll(rawReceipts.cast<String>());
    }

    final rawPackages = json['purchased_packages'];
    final packages = <PurchasedPackage>[];
    if (rawPackages is List) {
      for (final p in rawPackages) {
        if (p is Map<String, dynamic>) {
          packages.add(PurchasedPackage.fromJson(p));
        }
      }
    }

    return Application(
      id: json['id'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      nickName: json['nick_name'] as String?,
      dob: json['dob'] as String?,
      parentEmail: json['parent_email'] as String?,
      parentPhone: json['parent_phone']?.toString(),
      courses: parsedCourses,
      courseLimits: parsedLimits,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      paymentReceiptUrls: receipts,
      submittedBy: json['submitted_by'] as String?,
      purchasedPackages: packages,
      totalPrice: (json['total_price'] as num?)?.toInt(),
    );
  }
}
