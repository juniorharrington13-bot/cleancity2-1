import 'package:flutter/foundation.dart';

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
      );
}
