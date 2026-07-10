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

@immutable
class AdminOperationRecord {
  const AdminOperationRecord({
    required this.id,
    required this.wasteType,
    required this.status,
    required this.quantityEstimateKg,
    required this.city,
    required this.neighborhood,
    required this.createdAt,
    required this.generatorName,
    required this.collectorName,
    required this.centerName,
  });

  final String id;
  final String wasteType;
  final String status;
  final double quantityEstimateKg;
  final String city;
  final String neighborhood;
  final DateTime? createdAt;
  final String generatorName;
  final String? collectorName;
  final String? centerName;
}

@immutable
class AdminCollectorPayout {
  const AdminCollectorPayout({required this.collectorId, required this.collectorName, required this.totalXaf, required this.count});
  final String collectorId;
  final String collectorName;
  final double totalXaf;
  final int count;
}

@immutable
class AdminCenterVolume {
  const AdminCenterVolume({required this.centerId, required this.centerName, required this.totalKg, required this.count});
  final String centerId;
  final String centerName;
  final double totalKg;
  final int count;
}

@immutable
class AdminFinancialSummary {
  const AdminFinancialSummary({
    required this.totalPayoutsXaf,
    required this.payoutsByCollector,
    required this.volumeByCenter,
  });
  final double totalPayoutsXaf;
  final List<AdminCollectorPayout> payoutsByCollector;
  final List<AdminCenterVolume> volumeByCenter;
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

  /// Full filterable operations list backing the admin Reports view.
  /// City filtering happens client-side (see rationale on the class docstring:
  /// request volume here is low enough that this is simpler and cheaper than
  /// juggling PostgREST's embedded-resource filter syntax).
  Future<List<AdminOperationRecord>> getOperationsHistory({
    DateTime? from,
    DateTime? to,
    String? city,
    String? wasteType,
    String? status,
    int limit = 500,
  }) async {
    try {
      var query = _client.from('waste_requests').select(
          'id, waste_type, status, quantity_estimate_kg, created_at, '
          'addresses(city, neighborhood), '
          'generator:users!generator_id(full_name), '
          'pickups(collector:users!collector_id(full_name), center:users!center_id(full_name))');
      if (from != null) query = query.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) query = query.lte('created_at', to.toUtc().toIso8601String());
      if (wasteType != null && wasteType.isNotEmpty) query = query.eq('waste_type', wasteType);
      if (status != null && status.isNotEmpty) query = query.eq('status', status);

      final rows = await query.order('created_at', ascending: false).limit(limit);
      final list = (rows as List).whereType<Map>().map((raw) {
        final row = Map<String, dynamic>.from(raw);
        final address = row['addresses'] is Map ? Map<String, dynamic>.from(row['addresses'] as Map) : const <String, dynamic>{};
        final generator = row['generator'] is Map ? Map<String, dynamic>.from(row['generator'] as Map) : const <String, dynamic>{};
        final pickupsList = (row['pickups'] as List?) ?? const [];
        final pickup0 = pickupsList.isNotEmpty ? Map<String, dynamic>.from(pickupsList.first as Map) : const <String, dynamic>{};
        final collector = pickup0['collector'] is Map ? Map<String, dynamic>.from(pickup0['collector'] as Map) : null;
        final center = pickup0['center'] is Map ? Map<String, dynamic>.from(pickup0['center'] as Map) : null;
        return AdminOperationRecord(
          id: (row['id'] ?? '').toString(),
          wasteType: (row['waste_type'] ?? 'mixed').toString(),
          status: (row['status'] ?? 'pending').toString(),
          quantityEstimateKg: _asDouble(row['quantity_estimate_kg']),
          city: (address['city'] ?? '').toString(),
          neighborhood: (address['neighborhood'] ?? '').toString(),
          createdAt: DateTime.tryParse('${row['created_at']}'),
          generatorName: (generator['full_name'] ?? '').toString(),
          collectorName: (collector?['full_name'] as String?)?.trim(),
          centerName: (center?['full_name'] as String?)?.trim(),
        );
      }).toList(growable: false);

      if (city == null || city.trim().isEmpty) return list;
      final needle = city.trim().toLowerCase();
      return list.where((r) => r.city.toLowerCase() == needle).toList(growable: false);
    } catch (e) {
      debugPrint('AdminStatsService.getOperationsHistory failed: $e');
      rethrow;
    }
  }

  /// Distinct, sorted city names found on `addresses`, used to populate the
  /// Reports filter dropdown.
  Future<List<String>> listDistinctCities() async {
    try {
      final rows = await _client.from('addresses').select('city');
      final set = <String>{};
      for (final raw in (rows as List).whereType<Map>()) {
        final city = (raw['city'] as String?)?.trim();
        if (city != null && city.isNotEmpty) set.add(city);
      }
      return set.toList()..sort();
    } catch (e) {
      debugPrint('AdminStatsService.listDistinctCities failed: $e');
      rethrow;
    }
  }

  /// Collector payouts and center processed volume for the given period.
  /// There's no downstream sale-price data in the schema, so this reports
  /// payouts and processed volume rather than a fabricated profit margin.
  Future<AdminFinancialSummary> getFinancialSummary({DateTime? from, DateTime? to}) async {
    try {
      var payoutQuery = _client.from('eco_transactions').select('points, user_id, created_at, collector:users!user_id(full_name)').eq('reason', 'payout');
      if (from != null) payoutQuery = payoutQuery.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) payoutQuery = payoutQuery.lte('created_at', to.toUtc().toIso8601String());
      final payoutRows = await payoutQuery;

      var processingQuery = _client.from('processing_events').select('weighed_kg, center_id, created_at, center:users!center_id(full_name)');
      if (from != null) processingQuery = processingQuery.gte('created_at', from.toUtc().toIso8601String());
      if (to != null) processingQuery = processingQuery.lte('created_at', to.toUtc().toIso8601String());
      final processingRows = await processingQuery;

      final byCollector = <String, AdminCollectorPayout>{};
      var totalPayouts = 0.0;
      for (final raw in (payoutRows as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final uid = (row['user_id'] ?? '').toString();
        if (uid.isEmpty) continue;
        final pts = _asDouble(row['points']);
        totalPayouts += pts;
        final collector = row['collector'] is Map ? Map<String, dynamic>.from(row['collector'] as Map) : const <String, dynamic>{};
        final name = (collector['full_name'] as String?)?.trim();
        final existing = byCollector[uid];
        byCollector[uid] = AdminCollectorPayout(
          collectorId: uid,
          collectorName: (name == null || name.isEmpty) ? uid.substring(0, 8) : name,
          totalXaf: (existing?.totalXaf ?? 0) + pts,
          count: (existing?.count ?? 0) + 1,
        );
      }

      final byCenter = <String, AdminCenterVolume>{};
      for (final raw in (processingRows as List).whereType<Map>()) {
        final row = Map<String, dynamic>.from(raw);
        final cid = (row['center_id'] ?? '').toString();
        if (cid.isEmpty) continue;
        final kg = _asDouble(row['weighed_kg']);
        final center = row['center'] is Map ? Map<String, dynamic>.from(row['center'] as Map) : const <String, dynamic>{};
        final name = (center['full_name'] as String?)?.trim();
        final existing = byCenter[cid];
        byCenter[cid] = AdminCenterVolume(
          centerId: cid,
          centerName: (name == null || name.isEmpty) ? cid.substring(0, 8) : name,
          totalKg: (existing?.totalKg ?? 0) + kg,
          count: (existing?.count ?? 0) + 1,
        );
      }

      final payoutList = byCollector.values.toList()..sort((a, b) => b.totalXaf.compareTo(a.totalXaf));
      final centerList = byCenter.values.toList()..sort((a, b) => b.totalKg.compareTo(a.totalKg));

      return AdminFinancialSummary(totalPayoutsXaf: totalPayouts, payoutsByCollector: payoutList, volumeByCenter: centerList);
    } catch (e) {
      debugPrint('AdminStatsService.getFinancialSummary failed: $e');
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
