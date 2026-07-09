import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/supabase/supabase_config.dart';

@immutable
class AdminDashboardStats {
  const AdminDashboardStats({
    required this.collectedKg,
    required this.collectedKgChangePercent,
    required this.activeCollectors,
    required this.activeCollectorsChangePercent,
    required this.recoveryRatePercent,
    required this.revenueXaf,
    required this.revenueXafChangePercent,
  });

  final double collectedKg;
  final double? collectedKgChangePercent;
  final int activeCollectors;
  final double? activeCollectorsChangePercent;
  final double? recoveryRatePercent;
  final double revenueXaf;
  final double? revenueXafChangePercent;
}

@immutable
class AdminRecentOperation {
  const AdminRecentOperation({
    required this.wasteType,
    required this.location,
    required this.personName,
    required this.status,
  });

  final String wasteType;
  final String location;
  final String personName;
  final String status;
}

/// Reads aggregate metrics for the admin dashboard from Supabase.
///
/// Aggregation happens client-side rather than via a Postgres RPC: request
/// volume in this app is small enough that pulling the raw rows for a 60-day
/// window is cheap, and it avoids maintaining a second copy of this logic in
/// SQL.
class AdminStatsService {
  AdminStatsService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _collectedStatuses = ['collected', 'delivered'];
  static const _inactiveStatuses = ['cancelled', 'delivered'];

  static double? _percentChange(num current, num previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  Future<AdminDashboardStats> getDashboardStats() async {
    final now = DateTime.now().toUtc();
    final periodStart = now.subtract(const Duration(days: 30));
    final prevPeriodStart = now.subtract(const Duration(days: 60));

    try {
      final results = await Future.wait([
        _client
            .from('waste_requests')
            .select('quantity_estimate_kg, updated_at')
            .inFilter('status', _collectedStatuses)
            .gte('updated_at', prevPeriodStart.toIso8601String()),
        _client
            .from('pickups')
            .select('collector_id, accepted_at')
            .gte('accepted_at', prevPeriodStart.toIso8601String()),
        _client.from('processing_events').select('weighed_kg, accepted'),
        _client
            .from('eco_transactions')
            .select('points, created_at')
            .eq('reason', 'payout')
            .gte('created_at', prevPeriodStart.toIso8601String()),
      ]);

      final requestRows = (results[0] as List).whereType<Map>().toList(growable: false);
      final pickupRows = (results[1] as List).whereType<Map>().toList(growable: false);
      final processingRows = (results[2] as List).whereType<Map>().toList(growable: false);
      final ecoRows = (results[3] as List).whereType<Map>().toList(growable: false);

      double sumSince(List<Map> rows, String dateField, String valueField, DateTime since, DateTime? before) {
        var sum = 0.0;
        for (final row in rows) {
          final at = DateTime.tryParse('${row[dateField]}');
          if (at == null || at.isBefore(since)) continue;
          if (before != null && !at.isBefore(before)) continue;
          sum += _asDouble(row[valueField]);
        }
        return sum;
      }

      Set<String> distinctSince(List<Map> rows, String dateField, String idField, DateTime since, DateTime? before) {
        final ids = <String>{};
        for (final row in rows) {
          final at = DateTime.tryParse('${row[dateField]}');
          if (at == null || at.isBefore(since)) continue;
          if (before != null && !at.isBefore(before)) continue;
          final id = row[idField]?.toString();
          if (id != null && id.isNotEmpty) ids.add(id);
        }
        return ids;
      }

      final collectedKg = sumSince(requestRows, 'updated_at', 'quantity_estimate_kg', periodStart, null);
      final collectedKgPrev = sumSince(requestRows, 'updated_at', 'quantity_estimate_kg', prevPeriodStart, periodStart);

      final activeCollectors = distinctSince(pickupRows, 'accepted_at', 'collector_id', periodStart, null);
      final activeCollectorsPrev = distinctSince(pickupRows, 'accepted_at', 'collector_id', prevPeriodStart, periodStart);

      var acceptedKg = 0.0;
      var totalWeighedKg = 0.0;
      for (final row in processingRows) {
        final kg = _asDouble(row['weighed_kg']);
        totalWeighedKg += kg;
        if (row['accepted'] == true) acceptedKg += kg;
      }
      final recoveryRate = totalWeighedKg == 0 ? null : (acceptedKg / totalWeighedKg) * 100;

      final revenue = sumSince(ecoRows, 'created_at', 'points', periodStart, null);
      final revenuePrev = sumSince(ecoRows, 'created_at', 'points', prevPeriodStart, periodStart);

      return AdminDashboardStats(
        collectedKg: collectedKg,
        collectedKgChangePercent: _percentChange(collectedKg, collectedKgPrev),
        activeCollectors: activeCollectors.length,
        activeCollectorsChangePercent: _percentChange(activeCollectors.length, activeCollectorsPrev.length),
        recoveryRatePercent: recoveryRate,
        revenueXaf: revenue,
        revenueXafChangePercent: _percentChange(revenue, revenuePrev),
      );
    } catch (e) {
      debugPrint('AdminStatsService.getDashboardStats failed: $e');
      rethrow;
    }
  }

  Future<List<AdminRecentOperation>> getRecentOperations({int limit = 5}) async {
    try {
      final rows = await _client
          .from('waste_requests')
          .select('waste_type, status, addresses(city, neighborhood), generator:users!generator_id(full_name)')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final address = row['addresses'] is Map ? Map<String, dynamic>.from(row['addresses'] as Map) : null;
        final generator = row['generator'] is Map ? Map<String, dynamic>.from(row['generator'] as Map) : null;
        final neighborhood = (address?['neighborhood'] as String?)?.trim();
        final city = (address?['city'] as String?)?.trim();
        final locationParts = [neighborhood, city].where((e) => e != null && e.isNotEmpty);
        final name = (generator?['full_name'] as String?)?.trim();
        return AdminRecentOperation(
          wasteType: (row['waste_type'] ?? 'mixed').toString(),
          location: locationParts.isEmpty ? '—' : locationParts.join(', '),
          personName: (name == null || name.isEmpty) ? '—' : name,
          status: (row['status'] ?? 'pending').toString(),
        );
      }).toList(growable: false);
    } catch (e) {
      debugPrint('AdminStatsService.getRecentOperations failed: $e');
      rethrow;
    }
  }

  /// Counts active (not cancelled/delivered) requests grouped by city, for the
  /// dashboard heatmap. Keys are the raw city strings as stored on `addresses`.
  Future<Map<String, int>> getActiveRequestCountsByCity() async {
    try {
      final rows = await _client
          .from('waste_requests')
          .select('status, addresses(city)')
          .not('status', 'in', _inactiveStatuses);
      final counts = <String, int>{};
      for (final raw in (rows as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final address = row['addresses'] is Map ? Map<String, dynamic>.from(row['addresses'] as Map) : null;
        final city = (address?['city'] as String?)?.trim();
        if (city == null || city.isEmpty) continue;
        counts[city] = (counts[city] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('AdminStatsService.getActiveRequestCountsByCity failed: $e');
      rethrow;
    }
  }
}
