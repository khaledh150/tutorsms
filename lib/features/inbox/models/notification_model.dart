class AppNotification {
  final String id;
  final String? type;
  final Map<String, dynamic>? payload;
  final String? studentId;
  final bool read;
  final String createdAt;

  const AppNotification({
    required this.id,
    this.type,
    this.payload,
    this.studentId,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
      studentId: json['student_id'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get studentName {
    if (payload == null) return '';
    return (payload!['student_name'] as String?) ??
        (payload!['name'] as String?) ??
        '';
  }

  String get courseName {
    if (payload == null) return '';
    return (payload!['course_name'] as String?) ?? '';
  }

  String get displayMessage {
    final name = studentName;
    switch (type) {
      case 'new_application':
        return name.isNotEmpty ? '$name — New Student' : 'New Student Application';
      case 'renewal_request':
        final packages = payload?['purchased_packages'];
        if (packages is List && packages.isNotEmpty) {
          final cName = (packages[0] as Map?)?['course_name'] ?? '';
          return name.isNotEmpty ? '$name — Renewal ($cName)' : 'Renewal Request';
        }
        return name.isNotEmpty ? '$name — Renewal Request' : 'Renewal Request';
      case 'overlimit':
        final c = courseName;
        return name.isNotEmpty ? '$name — Needs Renewal ($c)' : 'Needs Renewal';
      case 'renewal_approaching':
        final c = courseName;
        final rem = payload?['remaining'] ?? '';
        return name.isNotEmpty
            ? '$name — Renewal Approaching ($c) · $rem'
            : 'Renewal Approaching';
      case 'checkin':
        final c = courseName;
        return name.isNotEmpty ? '$name — Check In ($c)' : 'Check In';
      case 'cancel_request':
        final c = courseName;
        return name.isNotEmpty ? '$name — Cancel Request ($c)' : 'Cancel Request';
      case 'edit_request':
        return name.isNotEmpty ? '$name — Edit Request' : 'Edit Request';
      default:
        return name.isNotEmpty ? name : (type ?? 'Notification');
    }
  }

  String get timeAgo {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
