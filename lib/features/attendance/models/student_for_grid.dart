class StudentForGrid {
  final String studentId;
  final String firstName;
  final String lastName;
  final String? nickName;
  final int purchasedHours;
  final int initialUsedHours;
  final bool isExpectedToday;
  final String? photoUrl;

  const StudentForGrid({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    this.nickName,
    this.purchasedHours = 0,
    this.initialUsedHours = 0,
    this.isExpectedToday = false,
    this.photoUrl,
  });

  String get displayName {
    if (nickName != null && nickName!.isNotEmpty && firstName.isNotEmpty) {
      return '$nickName $firstName';
    }
    return nickName ?? firstName;
  }

  String get initial =>
      (nickName ?? firstName).isNotEmpty
          ? (nickName ?? firstName)[0].toUpperCase()
          : '?';
}
