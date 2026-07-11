import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/models/app_notification.dart';
import 'package:cleancity/supabase/supabase_config.dart';

/// Reads/updates the current user's in-app notifications. Rows are only ever
/// written server-side (DB triggers / the confirm_reception_and_payout RPC —
/// see the `add_notifications` migration), so this service is read + mark-read
/// only; there is no `create()` method here on purpose.
class NotificationService {
  NotificationService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<AppNotification>> listMine({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('notifications')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map>().map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('NotificationService.listMine failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('NotificationService.listMine failed: $e');
      rethrow;
    }
  }

  Future<int> unreadCount() async {
    final uid = currentUserId;
    if (uid == null) return 0;
    try {
      final rows = await _client.from('notifications').select('id').eq('user_id', uid).filter('read_at', 'is', null);
      return (rows as List).length;
    } catch (e) {
      debugPrint('NotificationService.unreadCount failed: $e');
      return 0;
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _client.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
    } catch (e) {
      debugPrint('NotificationService.markRead failed: $e');
      rethrow;
    }
  }

  Future<void> markAllRead() async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', uid)
          .filter('read_at', 'is', null);
    } catch (e) {
      debugPrint('NotificationService.markAllRead failed: $e');
      rethrow;
    }
  }
}
