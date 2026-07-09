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
