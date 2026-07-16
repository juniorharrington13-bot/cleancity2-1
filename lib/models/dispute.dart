import 'package:flutter/foundation.dart';

@immutable
class Dispute {
  const Dispute({
    required this.id,
    required this.requestId,
    required this.reportedBy,
    this.againstUserId,
    required this.category,
    required this.description,
    required this.status,
    this.adminNote,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.reporterName,
  });

  final String id;
  final String requestId;
  final String reportedBy;
  final String? againstUserId;
  final String category;
  final String description;
  final String status;
  final String? adminNote;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined reporter name (`reporter:users!reported_by(full_name)`), for admin views.
  final String? reporterName;

  static Dispute fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'];
    final reporterMap = reporter is Map ? Map<String, dynamic>.from(reporter) : null;
    return Dispute(
      id: (json['id'] ?? '') as String,
      requestId: (json['request_id'] ?? '') as String,
      reportedBy: (json['reported_by'] ?? '') as String,
      againstUserId: json['against_user_id'] as String?,
      category: (json['category'] ?? 'other') as String,
      description: (json['description'] ?? '') as String,
      status: (json['status'] ?? 'open') as String,
      adminNote: json['admin_note'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      resolvedAt: json['resolved_at'] == null ? null : DateTime.tryParse('${json['resolved_at']}'),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reporterName: reporterMap?['full_name'] as String?,
    );
  }
}
