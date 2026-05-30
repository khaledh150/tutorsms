import 'application_model.dart';

class ApplicationChange {
  final String id;
  final String studentId;
  final String type; // renewal | edit | cancel
  final String status;
  final Map<String, dynamic> changes;
  final String createdAt;
  final List<String> receiptUrls;
  final String? submittedBy;
  final String? nickname;
  final String? firstName;
  final String? lastName;
  final List<PurchasedPackage> purchasedPackages;
  final int? totalPrice;

  const ApplicationChange({
    required this.id,
    required this.studentId,
    this.type = 'renewal',
    this.status = 'pending',
    this.changes = const {},
    required this.createdAt,
    this.receiptUrls = const [],
    this.submittedBy,
    this.nickname,
    this.firstName,
    this.lastName,
    this.purchasedPackages = const [],
    this.totalPrice,
  });

  String get displayName {
    final parts = <String>[];
    if (nickname != null && nickname!.isNotEmpty) parts.add('"$nickname"');
    if (firstName != null) parts.add(firstName!);
    if (lastName != null) parts.add(lastName!);
    return parts.join(' ').trim();
  }

  List<String> get allReceipts {
    final r = <String>{};
    r.addAll(receiptUrls);
    final changeReceipts = changes['receipts'];
    if (changeReceipts is List) {
      r.addAll(changeReceipts.cast<String>());
    }
    return r.toList();
  }

  factory ApplicationChange.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    final parsedChanges = <String, dynamic>{};
    if (rawChanges is Map) {
      parsedChanges.addAll(Map<String, dynamic>.from(rawChanges));
    }

    final rawReceipts = json['receipt_urls'];
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

    return ApplicationChange(
      id: json['id'] as String,
      studentId: json['student_id'] as String? ?? '',
      type: json['type'] as String? ?? 'renewal',
      status: json['status'] as String? ?? 'pending',
      changes: parsedChanges,
      createdAt: json['created_at'] as String? ?? '',
      receiptUrls: receipts,
      submittedBy: json['submitted_by'] as String?,
      nickname: json['nickname'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      purchasedPackages: packages,
      totalPrice: (json['total_price'] as num?)?.toInt(),
    );
  }
}
