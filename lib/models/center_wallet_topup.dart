import 'package:flutter/foundation.dart';

@immutable
class CenterWalletTopup {
  const CenterWalletTopup({
    required this.id,
    required this.centerId,
    required this.amountXaf,
    required this.provider,
    required this.phone,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.reference,
    this.adminNote,
  });

  final String id;
  final String centerId;
  final int amountXaf;
  final String provider;
  final String phone;
  final String? reference;
  /// One of: pending | confirmed | rejected
  final String status;
  final String? adminNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'center_id': centerId,
        'amount_xaf': amountXaf,
        'provider': provider,
        'phone': phone,
        'reference': reference,
        'status': status,
        'admin_note': adminNote,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static CenterWalletTopup fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount_xaf'];
    final amount = amountRaw is int ? amountRaw : (amountRaw is num ? amountRaw.toInt() : int.tryParse('$amountRaw') ?? 0);
    return CenterWalletTopup(
      id: (json['id'] ?? '') as String,
      centerId: (json['center_id'] ?? '') as String,
      amountXaf: amount,
      provider: (json['provider'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
      reference: json['reference']?.toString(),
      status: (json['status'] ?? 'pending') as String,
      adminNote: json['admin_note']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
