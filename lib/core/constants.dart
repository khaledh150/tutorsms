abstract final class AppConstants {
  // Polling intervals
  static const Duration pollNotifications = Duration(seconds: 30);
  static const Duration pollAttendanceLive = Duration(seconds: 15);

  // Stale/cache durations (maps to React Query staleTime)
  static const Duration staleFast = Duration(seconds: 10);
  static const Duration staleNormal = Duration(seconds: 60);
  static const Duration staleSlow = Duration(minutes: 5);

  // Pagination
  static const int queryPageSize = 50;

  // Auth
  static const String schoolDomain = 'school.local';

  // File uploads
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
  ];
  static const List<String> allowedReceiptTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'application/pdf',
  ];
}
