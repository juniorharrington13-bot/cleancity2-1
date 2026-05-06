import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/supabase/supabase_config.dart';

class AppUserService {
  AppUserService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<AppUser?> getCurrentProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return getProfile(uid);
  }

  Future<AppUser?> getProfile(String userId) async {
    try {
      final res = await _client.from('users').select('*').eq('id', userId).maybeSingle();
      if (res == null) return null;
      return AppUser.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      debugPrint('AppUserService.getProfile failed: $e');
      rethrow;
    }
  }

  Future<void> upsertProfile({
    required String userId,
    required String email,
    String? fullName,
    String phoneE164 = '',
    required String preferredLanguage,
    required String role,
  }) async {
    try {
      await _client.from('users').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone_e164': phoneE164,
        'preferred_language': preferredLanguage,
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('AppUserService.upsertProfile failed: $e');
      rethrow;
    }
  }

  Future<void> updateRole(String role) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.from('users').update({
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('AppUserService.updateRole failed: $e');
      rethrow;
    }
  }

  Future<void> updateProfile({String? fullName, String? phoneE164, String? preferredLanguage}) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      final data = <String, dynamic>{'updated_at': DateTime.now().toUtc().toIso8601String()};
      if (fullName != null) data['full_name'] = fullName;
      if (phoneE164 != null) data['phone_e164'] = phoneE164;
      if (preferredLanguage != null) data['preferred_language'] = preferredLanguage;
      await _client.from('users').update(data).eq('id', uid);
    } catch (e) {
      debugPrint('AppUserService.updateProfile failed: $e');
      rethrow;
    }
  }

  Future<void> updateAvatarUrl(String? avatarUrl) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.from('users').update({
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      debugPrint('AppUserService.updateAvatarUrl failed: $e');
      rethrow;
    }
  }

  Future<List<AppUser>> listUsers({
    String? role,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var req = _client.from('users').select('*');

      if (role != null && role.isNotEmpty && role != 'all') {
        req = req.eq('role', role);
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim();
        // Case-insensitive match on full_name or email.
        req = req.or('full_name.ilike.%$q%,email.ilike.%$q%');
      }

      final res = await req.order('created_at', ascending: false).range(offset, offset + limit - 1);
      if (res is! List) return const [];
      return res
          .whereType<Map>()
          .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } catch (e) {
      debugPrint('AppUserService.listUsers failed: $e');
      rethrow;
    }
  }

  /// Ensures a row exists in public.users for the authenticated Supabase user.
  ///
  /// Useful for OAuth (Google/Apple) where we may not collect phone/name upfront.
  Future<AppUser?> ensureProfileForAuthUser(User user) async {
    try {
      final existing = await getProfile(user.id);
      if (existing != null) return existing;

      final metadata = user.userMetadata ?? const {};
      final fullName = (metadata['full_name'] ?? metadata['name'] ?? metadata['given_name'])?.toString();
      final email = user.email ?? (metadata['email']?.toString() ?? '');

      await _client.from('users').upsert({
        'id': user.id,
        'email': email,
        'full_name': fullName,
        'phone_e164': '',
        'preferred_language': 'fr',
        'role': 'generator',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      return getProfile(user.id);
    } catch (e) {
      debugPrint('AppUserService.ensureProfileForAuthUser failed: $e');
      rethrow;
    }
  }
}
