class MessageTemplates {
  final String checkin;
  final String renewalApproaching;
  final String overlimit;
  final String enrollment;
  final String approval;
  final String linkWelcome;
  final String renewalPayment;
  final String newCourse;

  const MessageTemplates({
    this.checkin = '',
    this.renewalApproaching = '',
    this.overlimit = '',
    this.enrollment = '',
    this.approval = '',
    this.linkWelcome = '',
    this.renewalPayment = '',
    this.newCourse = '',
  });

  factory MessageTemplates.fromJson(Map<String, dynamic> json) {
    return MessageTemplates(
      checkin: json['checkin'] as String? ?? '',
      renewalApproaching: json['renewal_approaching'] as String? ?? '',
      overlimit: json['overlimit'] as String? ?? '',
      enrollment: json['enrollment'] as String? ?? '',
      approval: json['approval'] as String? ?? '',
      linkWelcome: json['link_welcome'] as String? ?? '',
      renewalPayment: json['renewal_payment'] as String? ?? '',
      newCourse: json['new_course'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'checkin': checkin,
        'renewal_approaching': renewalApproaching,
        'overlimit': overlimit,
        'enrollment': enrollment,
        'approval': approval,
        'link_welcome': linkWelcome,
        'renewal_payment': renewalPayment,
        'new_course': newCourse,
      };

  MessageTemplates copyWith({
    String? checkin,
    String? renewalApproaching,
    String? overlimit,
    String? enrollment,
    String? approval,
    String? linkWelcome,
    String? renewalPayment,
    String? newCourse,
  }) {
    return MessageTemplates(
      checkin: checkin ?? this.checkin,
      renewalApproaching: renewalApproaching ?? this.renewalApproaching,
      overlimit: overlimit ?? this.overlimit,
      enrollment: enrollment ?? this.enrollment,
      approval: approval ?? this.approval,
      linkWelcome: linkWelcome ?? this.linkWelcome,
      renewalPayment: renewalPayment ?? this.renewalPayment,
      newCourse: newCourse ?? this.newCourse,
    );
  }

  String operator [](String key) {
    switch (key) {
      case 'checkin':
        return checkin;
      case 'renewal_approaching':
        return renewalApproaching;
      case 'overlimit':
        return overlimit;
      case 'enrollment':
        return enrollment;
      case 'approval':
        return approval;
      case 'link_welcome':
        return linkWelcome;
      case 'renewal_payment':
        return renewalPayment;
      case 'new_course':
        return newCourse;
      default:
        return '';
    }
  }
}

class LineConfig {
  final String id;
  final String channelId;
  final bool secretsConfigured;
  final bool autoCheckinNotify;
  final bool autoLimitNotify;
  final bool autoRenewalNotify;
  final bool autoLinkNotify;
  final MessageTemplates messageTemplates;
  final String? paymentQrUrl;

  const LineConfig({
    required this.id,
    this.channelId = '',
    this.secretsConfigured = false,
    this.autoCheckinNotify = true,
    this.autoLimitNotify = true,
    this.autoRenewalNotify = true,
    this.autoLinkNotify = true,
    this.messageTemplates = const MessageTemplates(),
    this.paymentQrUrl,
  });

  factory LineConfig.fromJson(Map<String, dynamic> json) {
    final rawTemplates = json['message_templates'];
    final templates = rawTemplates is Map<String, dynamic>
        ? MessageTemplates.fromJson(rawTemplates)
        : const MessageTemplates();

    return LineConfig(
      id: json['id'] as String,
      channelId: json['channel_id'] as String? ?? '',
      secretsConfigured: json['secrets_configured'] as bool? ?? false,
      autoCheckinNotify: json['auto_checkin_notify'] as bool? ?? true,
      autoLimitNotify: json['auto_limit_notify'] as bool? ?? true,
      autoRenewalNotify: json['auto_renewal_notify'] as bool? ?? true,
      autoLinkNotify: json['auto_link_notify'] as bool? ?? true,
      messageTemplates: templates,
      paymentQrUrl: json['payment_qr_url'] as String?,
    );
  }
}

class LineMessage {
  final String id;
  final String messageType;
  final String content;
  final int recipientCount;
  final List<String> recipientStudentIds;
  final String status;
  final String createdAt;
  final String direction;
  final String? studentId;
  final String? mediaUrl;
  final String? mediaType;

  const LineMessage({
    required this.id,
    this.messageType = 'general',
    this.content = '',
    this.recipientCount = 0,
    this.recipientStudentIds = const [],
    this.status = 'queued',
    required this.createdAt,
    this.direction = 'outgoing',
    this.studentId,
    this.mediaUrl,
    this.mediaType,
  });

  bool get isIncoming => direction == 'incoming';

  factory LineMessage.fromJson(Map<String, dynamic> json) {
    final rawIds = json['recipient_student_ids'];
    final ids = <String>[];
    if (rawIds is List) {
      ids.addAll(rawIds.cast<String>());
    }

    return LineMessage(
      id: json['id'] as String,
      messageType: json['message_type'] as String? ?? 'general',
      content: json['content'] as String? ?? '',
      recipientCount: (json['recipient_count'] as num?)?.toInt() ?? 0,
      recipientStudentIds: ids,
      status: json['status'] as String? ?? 'queued',
      createdAt: json['created_at'] as String? ?? '',
      direction: json['direction'] as String? ?? 'outgoing',
      studentId: json['student_id'] as String?,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
    );
  }
}
