class Student {
  final String id;
  final String firstName;
  final String lastName;
  final String? nickName;
  final String? dob;
  final String? parentPhone;
  final String? parentLineId;
  final String? joinedAt;
  final String? status;
  final String? qrCodeUrl;
  final String? photoUrl;

  const Student({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.nickName,
    this.dob,
    this.parentPhone,
    this.parentLineId,
    this.joinedAt,
    this.status,
    this.qrCodeUrl,
    this.photoUrl,
  });

  String get displayName {
    if (nickName != null && nickName!.isNotEmpty && firstName.isNotEmpty) {
      return '$nickName $firstName';
    }
    return nickName ?? '$firstName $lastName';
  }

  String get initial =>
      (nickName ?? firstName).isNotEmpty
          ? (nickName ?? firstName)[0].toUpperCase()
          : '?';

  bool get isActive => status == null || status == 'active';

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        nickName: json['nick_name'] as String?,
        dob: json['dob'] as String?,
        parentPhone: json['parent_phone'] as String?,
        parentLineId: json['parent_line_id'] as String?,
        joinedAt: json['joined_at'] as String?,
        status: json['status'] as String?,
        qrCodeUrl: json['qr_code_url'] as String?,
        photoUrl: json['photo_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'nick_name': nickName,
        'dob': dob,
        'parent_phone': parentPhone,
        'parent_line_id': parentLineId,
        'status': status,
      };
}

class StudentWithStatus extends Student {
  final String? lastCheckin;
  final int totalPurchased;
  final double totalUsed;
  final String tab; // active | notActive | finished

  const StudentWithStatus({
    required super.id,
    required super.firstName,
    required super.lastName,
    super.nickName,
    super.dob,
    super.parentPhone,
    super.parentLineId,
    super.joinedAt,
    super.status,
    super.qrCodeUrl,
    super.photoUrl,
    this.lastCheckin,
    this.totalPurchased = 0,
    this.totalUsed = 0,
    this.tab = 'active',
  });

  bool get isOverlimit => totalPurchased > 0 && totalUsed >= totalPurchased;
}
