import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:cleancity/theme.dart';

/// Application-level user profile stored in the public `users` table.
///
/// Note: This is distinct from Supabase Auth's `User` (auth.users).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.preferredLanguage,
    required this.phoneE164,
    required this.createdAt,
    required this.updatedAt,
    this.fullName,
    this.avatarUrl,
    this.roleConfirmedAt,
    this.capacityKg,
  });

  final String id;
  final String email;
  final String role;
  final String preferredLanguage;
  final String phoneE164;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fullName;
  final String? avatarUrl;
  final DateTime? roleConfirmedAt;
  final double? capacityKg;

  /// Whether this account has already locked in a role. Once true, only an
  /// admin can change `role` (enforced server-side by enforce_role_change()).
  bool get isRoleLocked => roleConfirmedAt != null;

  AppUser copyWith({
    String? id,
    String? email,
    String? role,
    String? preferredLanguage,
    String? phoneE164,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fullName,
    String? avatarUrl,
    DateTime? roleConfirmedAt,
    double? capacityKg,
  }) =>
      AppUser(
        id: id ?? this.id,
        email: email ?? this.email,
        role: role ?? this.role,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        phoneE164: phoneE164 ?? this.phoneE164,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        fullName: fullName ?? this.fullName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        roleConfirmedAt: roleConfirmedAt ?? this.roleConfirmedAt,
        capacityKg: capacityKg ?? this.capacityKg,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
        'preferred_language': preferredLanguage,
        'phone_e164': phoneE164,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'role_confirmed_at': roleConfirmedAt?.toIso8601String(),
        'capacity_kg': capacityKg,
      };

  static AppUser fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? 'generator') as String,
        preferredLanguage: (json['preferred_language'] ?? 'fr') as String,
        phoneE164: (json['phone_e164'] ?? '') as String,
        createdAt: DateTime.tryParse((json['created_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        updatedAt: DateTime.tryParse((json['updated_at'] ?? '') as String) ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        fullName: json['full_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        roleConfirmedAt: DateTime.tryParse((json['role_confirmed_at'] ?? '') as String),
        capacityKg: json['capacity_kg'] is num ? (json['capacity_kg'] as num).toDouble() : null,
      );
}

extension AppUserUiX on AppUser {
  /// Localized, all-caps role label (e.g. "ADMIN", "COLLECTOR"/"COLLECTEUR").
  String roleLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (role) {
      case 'admin':
        return l10n.roleAdmin;
      case 'collector':
        return l10n.roleCollector;
      case 'center':
      case 'processing_center':
        return l10n.roleCenter;
      case 'generator':
      default:
        return l10n.roleGenerator;
    }
  }

  String displayNameCapitalized(BuildContext context) {
    final raw = (fullName ?? '').trim();
    if (raw.isEmpty) return context.l10n.commonUser;
    final words = raw.split(RegExp(r'\s+'));
    final fixed = words.map((w) {
      final lower = w.toLowerCase();
      if (lower.isEmpty) return lower;
      return '${lower[0].toUpperCase()}${lower.substring(1)}';
    }).toList(growable: false);
    return fixed.join(' ');
  }
}
