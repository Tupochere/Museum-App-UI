import '../core/models/ui_models.dart';

class NotificationPost {
  const NotificationPost({
    required this.id,
    required this.postType,
    required this.title,
    required this.summary,
    required this.audience,
    required this.category,
    required this.ctaLabel,
    required this.featured,
    required this.status,
    this.eventDate,
    this.eventTime,
    this.location,
    this.thumbnailUrl,
    required this.recipients,
    this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String postType; // 'event' | 'news'
  final String title;
  final String summary;
  final String audience;
  final String category;
  final String ctaLabel;
  final bool featured;
  final String status;
  final String? eventDate;
  final String? eventTime;
  final String? location;
  final String? thumbnailUrl;
  final int recipients;
  final DateTime? sentAt;
  final DateTime createdAt;

  factory NotificationPost.fromJson(Map<String, dynamic> json) {
    return NotificationPost(
      id: json['id'] as String,
      postType: json['post_type'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      audience: json['audience'] as String,
      category: json['category'] as String,
      ctaLabel: json['cta_label'] as String,
      featured: json['featured'] as bool,
      status: json['status'] as String,
      eventDate: json['event_date'] as String?,
      eventTime: json['event_time'] as String?,
      location: json['location'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      recipients: json['recipients'] as int,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to a UiEventItem for screens that still use the UI model.
  UiEventItem toUiEventItem() {
    final datePart = eventDate ?? '';
    final timePart = eventTime ?? '';
    final dateLabel = (datePart.isNotEmpty && timePart.isNotEmpty)
        ? '$datePart • $timePart'
        : datePart.isNotEmpty
            ? datePart
            : sentAt != null
                ? '${sentAt!.day}/${sentAt!.month}/${sentAt!.year}'
                : '';

    return UiEventItem(
      id: id,
      title: title,
      dateLabel: dateLabel,
      location: location ?? '',
      description: summary,
      imageUrl: thumbnailUrl ?? '',
      isUnread: true,
    );
  }
}
