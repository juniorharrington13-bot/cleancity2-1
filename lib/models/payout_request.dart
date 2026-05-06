import 'package:flutter/foundation.dart';

@immutable
class PayoutRequest {
  const PayoutRequest({
    required this.id,
    required this.userId,
    required this.provider,
    required this.phone,
    required this.amountXaf,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.adminNote,
  });

  final String id;
  final String userId;
  final String provider;
  final String phone;
  final int amountXaf;
  /// One of: pending | paid | rejected
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  PayoutRequest copyWith({
    String? id,
    String? userId,
    String? provider,
    String? phone,
    int? amountXaf,
    String? status,
    String? adminNote,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PayoutRequest(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        provider: provider ?? this.provider,
        phone: phone ?? this.phone,
        amountXaf: amountXaf ?? this.amountXaf,
        status: status ?? this.status,
        adminNote: adminNote ?? this.adminNote,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'provider': provider,
        'phone': phone,
        'amount_xaf': amountXaf,
        'status': status,
        'admin_note': adminNote,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static PayoutRequest fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount_xaf'];
    final amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : int.tryParse('$amountRaw') ?? 0);
    return PayoutRequest(
      id: (json['id'] ?? '') as String,
      userId: (json['user_id'] ?? '') as String,
      provider: (json['provider'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      amountXaf: amount,
      status: (json['status'] ?? 'pending') as String,
      adminNote: json['admin_note']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
