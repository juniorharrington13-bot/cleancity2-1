import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/models/center_wallet_topup.dart';
import 'package:cleancity/supabase/supabase_config.dart';

@immutable
class CenterWalletTransaction {
  const CenterWalletTransaction({
    required this.id,
    required this.type,
    required this.amountXaf,
    required this.createdAt,
    this.reference,
  });

  final String id;
  /// One of: topup | payout_debit | adjustment
  final String type;
  /// Signed: positive = credit, negative = debit.
  final double amountXaf;
  final DateTime? createdAt;

  /// Real Mobile Money transaction reference, for `topup` rows (joined from
  /// `wallet_topups.reference`). Null for `payout_debit`/`adjustment` rows,
  /// which have no external reference.
  final String? reference;
}

/// Manages a center's wallet: top-up requests (funded by the center via
/// Mobile Money, confirmed by an admin) and the resulting transaction ledger
/// that caps how much a center can pay collectors on delivery reception.
///
/// Wallet credits/debits are never inserted directly by this service — they
/// only happen server-side via the `confirm_wallet_topup` and
/// `confirm_reception_and_payout` RPCs (see [CenterWalletService.confirmTopup]
/// and `WasteRequestService.confirmReceptionAtCenter`).
class CenterWalletService {
  CenterWalletService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<double> getBalance({String? centerId}) async {
    final id = centerId ?? currentUserId;
    if (id == null) return 0;
    try {
      final rows = await _client.from('center_wallet_transactions').select('amount_xaf').eq('center_id', id);
      double total = 0;
      for (final row in (rows as List).whereType<Map>()) {
        total += _asDouble(row['amount_xaf']);
      }
      return total;
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.getBalance failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.getBalance failed: $e');
      rethrow;
    }
  }

  Future<List<CenterWalletTransaction>> listTransactions({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('center_wallet_transactions')
          .select('id, type, amount_xaf, created_at, wallet_topups(reference)')
          .eq('center_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final topup = row['wallet_topups'];
        final topupMap = topup is Map
            ? Map<String, dynamic>.from(topup)
            : (topup is List && topup.isNotEmpty && topup.first is Map) ? Map<String, dynamic>.from(topup.first as Map) : null;
        return CenterWalletTransaction(
          id: (row['id'] ?? '').toString(),
          type: (row['type'] ?? '').toString(),
          amountXaf: _asDouble(row['amount_xaf']),
          createdAt: DateTime.tryParse('${row['created_at']}'),
          reference: topupMap?['reference'] as String?,
        );
      }).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.listTransactions failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.listTransactions failed: $e');
      rethrow;
    }
  }

  Future<List<CenterWalletTopup>> listMyTopups({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('wallet_topups')
          .select('*')
          .eq('center_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.whereType<Map>().map((e) => CenterWalletTopup.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.listMyTopups failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.listMyTopups failed: $e');
      rethrow;
    }
  }

  /// Admin-only: lists top-up requests across all centers, optionally
  /// filtered by status. RLS only lets rows through for the owning center or
  /// an admin, so a non-admin caller simply gets their own requests back.
  Future<List<CenterWalletTopup>> listAllTopups({String? status, int limit = 100}) async {
    try {
      var query = _client.from('wallet_topups').select('*');
      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      final rows = await query.order('created_at', ascending: false).limit(limit);
      return rows.whereType<Map>().map((e) => CenterWalletTopup.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.listAllTopups failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.listAllTopups failed: $e');
      rethrow;
    }
  }

  Future<CenterWalletTopup> requestTopup({
    required int amountXaf,
    required String provider,
    required String phone,
    String? reference,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      final row = await _client
          .from('wallet_topups')
          .insert({
            'center_id': uid,
            'amount_xaf': amountXaf,
            'provider': provider,
            'phone': phone,
            'reference': reference,
            'status': 'pending',
          })
          .select('*')
          .single();
      return CenterWalletTopup.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.requestTopup failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.requestTopup failed: $e');
      rethrow;
    }
  }

  /// Resolves a pending top-up with the outcome of a simulated Mobile Money
  /// gateway call. Only the requesting center may call this (enforced
  /// server-side by `simulate_mobile_money_topup`).
  Future<void> simulateTopupCompletion({
    required String id,
    required bool success,
    required String reference,
    String? failureReasonCode,
  }) async {
    try {
      await _client.rpc('simulate_mobile_money_topup', params: {
        'p_topup_id': id,
        'p_success': success,
        'p_reference': reference,
        'p_failure_reason': failureReasonCode,
      });
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.simulateTopupCompletion failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.simulateTopupCompletion failed: $e');
      rethrow;
    }
  }

  /// Admin-only: confirms or rejects a pending top-up. Enforced server-side
  /// by the `confirm_wallet_topup` RPC (checks `current_user_role() = 'admin'`).
  Future<void> confirmTopup({required String id, required bool approve, String? adminNote}) async {
    try {
      await _client.rpc('confirm_wallet_topup', params: {
        'p_topup_id': id,
        'p_approve': approve,
        'p_admin_note': adminNote,
      });
    } on PostgrestException catch (e) {
      debugPrint('CenterWalletService.confirmTopup failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('CenterWalletService.confirmTopup failed: $e');
      rethrow;
    }
  }
}
