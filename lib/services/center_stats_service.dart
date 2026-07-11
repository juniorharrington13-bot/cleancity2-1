import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/supabase/supabase_config.dart';

@immutable
class CenterDashboardStats {
  const CenterDashboardStats({
    required this.processedKg,
    required this.processedKgChangePercent,
    required this.recoveryRatePercent,
    required this.pendingSortingKg,
    required this.pendingSortingCount,
    required this.capacityKg,
  });

  final double processedKg;
  final double? processedKgChangePercent;
  final double? recoveryRatePercent;
  final double pendingSortingKg;
  final int pendingSortingCount;
  final double? capacityKg;

  /// Fraction of configured capacity currently occupied by unsorted stock,
  /// or null if the center hasn't set a capacity yet.
  double? get capacityFillRatio {
    final cap = capacityKg;
    if (cap == null || cap <= 0) return null;
    return (pendingSortingKg / cap).clamp(0.0, 1.0);
  }
}

@immutable
class CenterExpectedDelivery {
  const CenterExpectedDelivery({
    required this.requestId,
    required this.wasteType,
    required this.status,
    required this.quantityEstimateKg,
    required this.city,
    required this.neighborhood,
    required this.acceptedAt,
    this.collectorName,
    this.collectorPhone,
  });

  final String requestId;
  final String wasteType;
  final String status;
  final double quantityEstimateKg;
  final String city;
  final String neighborhood;
  final DateTime? acceptedAt;
  final String? collectorName;
  final String? collectorPhone;
}

@immutable
class CenterDeliveryRecord {
  const CenterDeliveryRecord({
    required this.requestId,
    required this.wasteType,
    required this.status,
    required this.quantityEstimateKg,
    required this.city,
    required this.neighborhood,
    required this.collectorName,
    required this.collectorPhone,
    required this.deliveredAt,
  });

  final String requestId;
  final String wasteType;
  final String status;
  final double quantityEstimateKg;
  final String city;
  final String neighborhood;
  final String? collectorName;
  final String? collectorPhone;
  final DateTime? deliveredAt;
}

@immutable
class CenterStockEntry {
  const CenterStockEntry({required this.wasteType, required this.weighedKg});

  final String wasteType;
  final double weighedKg;
}

@immutable
class CenterPendingReception {
  const CenterPendingReception({
    required this.requestId,
    required this.wasteType,
    required this.quantityEstimateKg,
    required this.city,
    required this.neighborhood,
    required this.deliveredAt,
  });

  final String requestId;
  final String wasteType;
  final double quantityEstimateKg;
  final String city;
  final String neighborhood;
  final DateTime? deliveredAt;
}

/// Reads center-scoped dashboard metrics from Supabase. Aggregation happens
/// client-side, same rationale as [AdminStatsService]: request volume is low
/// enough that pulling raw rows per center is cheap and avoids duplicating
/// this logic in SQL.
class CenterStatsService {
  CenterStatsService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static double? _percentChange(num current, num previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  Future<CenterDashboardStats> getDashboardStats() async {
    final uid = currentUserId;
    if (uid == null) {
      return const CenterDashboardStats(
        processedKg: 0,
        processedKgChangePercent: null,
        recoveryRatePercent: null,
        pendingSortingKg: 0,
        pendingSortingCount: 0,
        capacityKg: null,
      );
    }

    try {
      final now = DateTime.now().toUtc();
      final periodStart = now.subtract(const Duration(days: 30));
      final prevPeriodStart = now.subtract(const Duration(days: 60));

      final results = await Future.wait<dynamic>([
        _client
            .from('processing_events')
            .select('weighed_kg, accepted, created_at, request_id')
            .eq('center_id', uid),
        _client
            .from('pickups')
            .select('request_id, delivered_at, waste_requests(quantity_estimate_kg)')
            .eq('center_id', uid)
            .not('delivered_at', 'is', null),
        _client.from('users').select('capacity_kg').eq('id', uid).maybeSingle(),
      ]);

      final processingRows = (results[0] as List).whereType<Map>().toList(growable: false);
      final deliveredPickupRows = (results[1] as List).whereType<Map>().toList(growable: false);
      final capacityRow = results[2] as Map?;
      final capacityKg = capacityRow?['capacity_kg'] == null ? null : _asDouble(capacityRow?['capacity_kg']);

      var processedKg = 0.0;
      var processedKgPrev = 0.0;
      var acceptedKg = 0.0;
      var totalWeighedKg = 0.0;
      final processedRequestIds = <String>{};
      for (final row in processingRows) {
        final kg = _asDouble(row['weighed_kg']);
        final at = DateTime.tryParse('${row['created_at']}');
        final requestId = row['request_id']?.toString();
        if (requestId != null && requestId.isNotEmpty) processedRequestIds.add(requestId);

        totalWeighedKg += kg;
        if (row['accepted'] == true) acceptedKg += kg;

        if (at != null && !at.isBefore(periodStart)) {
          processedKg += kg;
        } else if (at != null && !at.isBefore(prevPeriodStart) && at.isBefore(periodStart)) {
          processedKgPrev += kg;
        }
      }
      final recoveryRate = totalWeighedKg == 0 ? null : (acceptedKg / totalWeighedKg) * 100;

      var pendingSortingKg = 0.0;
      var pendingSortingCount = 0;
      for (final row in deliveredPickupRows) {
        final requestId = row['request_id']?.toString();
        if (requestId == null || processedRequestIds.contains(requestId)) continue;
        final wr = row['waste_requests'] as Map?;
        pendingSortingKg += _asDouble(wr?['quantity_estimate_kg']);
        pendingSortingCount += 1;
      }

      return CenterDashboardStats(
        processedKg: processedKg,
        processedKgChangePercent: _percentChange(processedKg, processedKgPrev),
        recoveryRatePercent: recoveryRate,
        pendingSortingKg: pendingSortingKg,
        pendingSortingCount: pendingSortingCount,
        capacityKg: capacityKg,
      );
    } catch (e) {
      debugPrint('CenterStatsService.getDashboardStats failed: $e');
      rethrow;
    }
  }

  /// Pickups accepted for this center that haven't arrived yet (en route),
  /// including the assigned collector's contact info so the center knows who
  /// to expect.
  /// Deliveries this center still needs to act on: en route (not yet
  /// arrived) *and* arrived-but-not-yet-weighed — i.e. anything without a
  /// `processing_events` row yet. Includes the collector's contact info so
  /// the center always knows who to expect, even after the drop-off already
  /// happened and it's just awaiting reception.
  Future<List<CenterExpectedDelivery>> getExpectedDeliveries({int limit = 3}) async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final results = await Future.wait<dynamic>([
        _client.from('processing_events').select('request_id').eq('center_id', uid),
        _client
            .from('pickups')
            .select(
                'request_id, accepted_at, delivered_at, users!pickups_collector_id_fkey(full_name, phone_e164), waste_requests(waste_type, status, quantity_estimate_kg, addresses(city, neighborhood))')
            .eq('center_id', uid)
            .order('accepted_at', ascending: true)
            .limit(limit + 20),
      ]);

      final processedIds = (results[0] as List)
          .whereType<Map>()
          .map((r) => (r['request_id'] ?? '').toString())
          .toSet();

      final rows = (results[1] as List).whereType<Map>().toList(growable: false);
      return rows
          .map((raw) {
            final row = Map<String, dynamic>.from(raw);
            final wr = row['waste_requests'] is Map ? Map<String, dynamic>.from(row['waste_requests'] as Map) : const <String, dynamic>{};
            final address = wr['addresses'] is Map ? Map<String, dynamic>.from(wr['addresses'] as Map) : const <String, dynamic>{};
            final collector = row['users'] is Map ? Map<String, dynamic>.from(row['users'] as Map) : const <String, dynamic>{};
            return CenterExpectedDelivery(
              requestId: (row['request_id'] ?? '').toString(),
              wasteType: (wr['waste_type'] ?? 'mixed').toString(),
              status: (wr['status'] ?? 'accepted').toString(),
              quantityEstimateKg: _asDouble(wr['quantity_estimate_kg']),
              city: (address['city'] ?? '').toString(),
              neighborhood: (address['neighborhood'] ?? '').toString(),
              acceptedAt: DateTime.tryParse('${row['accepted_at']}'),
              collectorName: (collector['full_name'] ?? '').toString().trim().isEmpty ? null : collector['full_name'].toString().trim(),
              collectorPhone: (collector['phone_e164'] ?? '').toString().trim().isEmpty ? null : collector['phone_e164'].toString().trim(),
            );
          })
          .where((d) => d.requestId.isNotEmpty && !processedIds.contains(d.requestId))
          .take(limit)
          .toList(growable: false);
    } catch (e) {
      debugPrint('CenterStatsService.getExpectedDeliveries failed: $e');
      rethrow;
    }
  }

  /// All pickups assigned to this center regardless of delivery status
  /// (accepted/collected/delivered), with the collector's contact info.
  /// Backs the center's "Livraisons" tab.
  Future<List<CenterDeliveryRecord>> getCenterDeliveries({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final rows = await _client
          .from('pickups')
          .select(
              'request_id, delivered_at, users!pickups_collector_id_fkey(full_name, phone_e164), waste_requests(waste_type, status, quantity_estimate_kg, addresses(city, neighborhood))')
          .eq('center_id', uid)
          .order('accepted_at', ascending: false)
          .limit(limit);

      return (rows as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final wr = row['waste_requests'] is Map ? Map<String, dynamic>.from(row['waste_requests'] as Map) : const <String, dynamic>{};
        final address = wr['addresses'] is Map ? Map<String, dynamic>.from(wr['addresses'] as Map) : const <String, dynamic>{};
        final collector = row['users'] is Map ? Map<String, dynamic>.from(row['users'] as Map) : const <String, dynamic>{};
        return CenterDeliveryRecord(
          requestId: (row['request_id'] ?? '').toString(),
          wasteType: (wr['waste_type'] ?? 'mixed').toString(),
          status: (wr['status'] ?? 'accepted').toString(),
          quantityEstimateKg: _asDouble(wr['quantity_estimate_kg']),
          city: (address['city'] ?? '').toString(),
          neighborhood: (address['neighborhood'] ?? '').toString(),
          collectorName: (collector['full_name'] ?? '').toString().trim().isEmpty ? null : collector['full_name'].toString().trim(),
          collectorPhone: (collector['phone_e164'] ?? '').toString().trim().isEmpty ? null : collector['phone_e164'].toString().trim(),
          deliveredAt: DateTime.tryParse('${row['delivered_at']}'),
        );
      }).where((d) => d.requestId.isNotEmpty).toList(growable: false);
    } catch (e) {
      debugPrint('CenterStatsService.getCenterDeliveries failed: $e');
      rethrow;
    }
  }

  /// Weighed-in stock for this center, grouped by waste type. Backs the
  /// center's "Stocks" tab.
  Future<List<CenterStockEntry>> getCenterStockSummary({int limit = 200}) async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final rows = await _client
          .from('processing_events')
          .select('weighed_kg, created_at, waste_requests(waste_type)')
          .eq('center_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final wr = row['waste_requests'] is Map ? Map<String, dynamic>.from(row['waste_requests'] as Map) : const <String, dynamic>{};
        return CenterStockEntry(
          wasteType: (wr['waste_type'] ?? 'mixed').toString(),
          weighedKg: _asDouble(row['weighed_kg']),
        );
      }).toList(growable: false);
    } catch (e) {
      debugPrint('CenterStatsService.getCenterStockSummary failed: $e');
      rethrow;
    }
  }

  /// Deliveries that have arrived at this center (`delivered_at` set) but
  /// don't have a `processing_events` row yet, i.e. still awaiting weighing
  /// and reception confirmation. Used to drive the "quick reception" picker.
  Future<List<CenterPendingReception>> getPendingReceptions({int limit = 20}) async {
    final uid = currentUserId;
    if (uid == null) return const [];

    try {
      final results = await Future.wait<dynamic>([
        _client.from('processing_events').select('request_id').eq('center_id', uid),
        _client
            .from('pickups')
            .select('request_id, delivered_at, waste_requests(waste_type, quantity_estimate_kg, addresses(city, neighborhood))')
            .eq('center_id', uid)
            .not('delivered_at', 'is', null)
            .order('delivered_at', ascending: false)
            .limit(limit),
      ]);

      final processedIds = (results[0] as List)
          .whereType<Map>()
          .map((r) => (r['request_id'] ?? '').toString())
          .toSet();

      final rows = (results[1] as List).whereType<Map>().toList(growable: false);
      return rows
          .map((raw) {
            final row = Map<String, dynamic>.from(raw);
            final wr = row['waste_requests'] is Map ? Map<String, dynamic>.from(row['waste_requests'] as Map) : const <String, dynamic>{};
            final address = wr['addresses'] is Map ? Map<String, dynamic>.from(wr['addresses'] as Map) : const <String, dynamic>{};
            return CenterPendingReception(
              requestId: (row['request_id'] ?? '').toString(),
              wasteType: (wr['waste_type'] ?? 'mixed').toString(),
              quantityEstimateKg: _asDouble(wr['quantity_estimate_kg']),
              city: (address['city'] ?? '').toString(),
              neighborhood: (address['neighborhood'] ?? '').toString(),
              deliveredAt: DateTime.tryParse('${row['delivered_at']}'),
            );
          })
          .where((d) => d.requestId.isNotEmpty && !processedIds.contains(d.requestId))
          .toList(growable: false);
    } catch (e) {
      debugPrint('CenterStatsService.getPendingReceptions failed: $e');
      rethrow;
    }
  }
}
