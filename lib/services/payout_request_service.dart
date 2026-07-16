import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/models/payout_request.dart';
import 'package:cleancity/supabase/supabase_config.dart';

class PayoutRequestService {
  PayoutRequestService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<PayoutRequest>> listMyRequests({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
      final rows = await _client.from('payout_requests').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(limit);
      return rows.whereType<Map>().map((e) => PayoutRequest.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('PayoutRequestService.listMyRequests failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PayoutRequestService.listMyRequests failed: $e');
      rethrow;
    }
  }

  /// Admin-only: lists payout requests across all users, optionally filtered
  /// by status. RLS only lets rows through for the owner or an admin, so a
  /// non-admin calling this simply gets their own requests back.
  Future<List<PayoutRequest>> listAll({String? status, int limit = 100}) async {
    try {
      var query = _client.from('payout_requests').select('*');
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return rows.whereType<Map>().map((e) => PayoutRequest.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('PayoutRequestService.listAll failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PayoutRequestService.listAll failed: $e');
      rethrow;
    }
  }

  /// Admin-only: approves or rejects a payout request. Enforced server-side
  /// by the `payout_requests_update_admin` RLS policy.
  Future<void> updateStatus({required String id, required String status, String? adminNote}) async {
    try {
      await _client.from('payout_requests').update({
        'status': status,
        if (adminNote != null) 'admin_note': adminNote,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    } on PostgrestException catch (e) {
      debugPrint('PayoutRequestService.updateStatus failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PayoutRequestService.updateStatus failed: $e');
      rethrow;
    }
  }

  /// Resolves a pending payout request with the outcome of a simulated
  /// Mobile Money gateway call. Only the request's own owner may call this
  /// (enforced server-side by `simulate_mobile_money_payout`).
  Future<void> simulateCompletion({
    required String id,
    required bool success,
    required String reference,
    String? failureReasonCode,
  }) async {
    try {
      await _client.rpc('simulate_mobile_money_payout', params: {
        'p_payout_id': id,
        'p_success': success,
        'p_reference': reference,
        'p_failure_reason': failureReasonCode,
      });
    } on PostgrestException catch (e) {
      debugPrint('PayoutRequestService.simulateCompletion failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PayoutRequestService.simulateCompletion failed: $e');
      rethrow;
    }
  }

  Future<PayoutRequest> create({required String provider, required String phone, required int amountXaf}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      final row = await _client
          .from('payout_requests')
          .insert({'user_id': uid, 'provider': provider, 'phone': phone, 'amount_xaf': amountXaf, 'status': 'pending'})
          .select('*')
          .single();
      return PayoutRequest.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      debugPrint('PayoutRequestService.create failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('PayoutRequestService.create failed: $e');
      rethrow;
    }
  }
}
