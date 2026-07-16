import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/models/dispute.dart';
import 'package:cleancity/supabase/supabase_config.dart';

class DisputeService {
  DisputeService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Dispute> create({
    required String requestId,
    required String category,
    required String description,
    String? againstUserId,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      final row = await _client
          .from('disputes')
          .insert({
            'request_id': requestId,
            'reported_by': uid,
            'against_user_id': againstUserId,
            'category': category,
            'description': description,
          })
          .select('*')
          .single();
      return Dispute.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      debugPrint('DisputeService.create failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('DisputeService.create failed: $e');
      rethrow;
    }
  }

  Future<List<Dispute>> listMine({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('disputes')
          .select('*')
          .eq('reported_by', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map>().map((e) => Dispute.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('DisputeService.listMine failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('DisputeService.listMine failed: $e');
      rethrow;
    }
  }

  /// Admin-only listing across all disputes (RLS restricts non-admins to
  /// their own), optionally filtered by status.
  Future<List<Dispute>> listAll({String? status, int limit = 200}) async {
    try {
      var query = _client.from('disputes').select('*, reporter:users!reported_by(full_name)');
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return rows.whereType<Map>().map((e) => Dispute.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('DisputeService.listAll failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('DisputeService.listAll failed: $e');
      rethrow;
    }
  }

  /// Admin-only: resolve or dismiss a dispute. Enforced server-side by the
  /// `disputes_update_admin` RLS policy.
  Future<void> updateStatus({required String id, required String status, String? adminNote}) async {
    final uid = currentUserId;
    try {
      await _client.from('disputes').update({
        'status': status,
        if (adminNote != null) 'admin_note': adminNote,
        'resolved_by': uid,
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('DisputeService.updateStatus failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('DisputeService.updateStatus failed: $e');
      rethrow;
    }
  }
}
