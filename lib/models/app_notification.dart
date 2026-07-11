import 'package:flutter/foundation.dart';

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.relatedId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? relatedId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] ?? '') as String,
      type: (json['type'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      body: (json['body'] ?? '') as String,
      relatedId: json['related_id']?.toString(),
      readAt: DateTime.tryParse('${json['read_at']}'),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
