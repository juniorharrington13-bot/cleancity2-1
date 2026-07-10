import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/constants/waste_rates.dart';
import 'package:cleancity/models/waste_request.dart';
import 'package:cleancity/services/app_settings_service.dart';
import 'package:cleancity/supabase/supabase_config.dart';

class WasteRequestService {
  WasteRequestService({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<List<WasteRequest>> listForCurrentGenerator() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      final rows = await _client
          .from('waste_requests')
          .select('*, addresses(*)')
          .eq('generator_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .map(
              (e) => WasteRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('WasteRequestService.listForCurrentGenerator failed: $e');
      rethrow;
    }
  }

  Future<List<WasteRequest>> listAvailableMissions() async {
    try {
      final rows = await _client
          .from('waste_requests')
          .select('*, addresses(*)')
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map(
              (e) => WasteRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('WasteRequestService.listAvailableMissions failed: $e');
      rethrow;
    }
  }

  Future<WasteRequest?> getById(String id) async {
    try {
      final row = await _client
          .from('waste_requests')
          .select('*, addresses(*)')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return WasteRequest.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('WasteRequestService.getById failed: $e');
      rethrow;
    }
  }

  /// Collector-safe mission loader.
  ///
  /// Some RLS configurations may block direct select on `waste_requests` while
  /// still allowing access through `pickups` joins. This fallback prevents the
  /// UI from showing "Mission introuvable" for existing missions.
  Future<WasteRequest?> getMissionForCollector(String requestId) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final direct = await getById(requestId);
      if (direct != null) return direct;
    } catch (e) {
      debugPrint(
          'WasteRequestService.getMissionForCollector direct lookup failed: $e');
    }

    try {
      final row = await _client
          .from('pickups')
          .select('request_id, collector_id, waste_requests(*, addresses(*))')
          .eq('request_id', requestId)
          .eq('collector_id', uid)
          .maybeSingle();
      if (row == null) return null;
      final req = row['waste_requests'];
      if (req is! Map) return null;
      return WasteRequest.fromJson(Map<String, dynamic>.from(req));
    } catch (e) {
      debugPrint(
          'WasteRequestService.getMissionForCollector pickup join lookup failed: $e');
      rethrow;
    }
  }

  Future<WasteRequest> create({
    required String wasteType,
    required double quantityEstimateKg,
    String? notes,
    DateTime? scheduledAt,
    String? timeSlot,
    String? city,
    String? neighborhood,
    String? details,
    double? latitude,
    double? longitude,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      String? addressId;
      if ((city ?? '').trim().isNotEmpty ||
          (neighborhood ?? '').trim().isNotEmpty ||
          (details ?? '').trim().isNotEmpty) {
        addressId = await _insertAddressBestEffort(
          userId: uid,
          city: (city ?? '').trim(),
          neighborhood: (neighborhood ?? '').trim(),
          details: (details ?? '').trim(),
          latitude: latitude,
          longitude: longitude,
        );
      }

      return await _insertWasteRequestBestEffort(
        generatorId: uid,
        addressId: addressId,
        wasteType: wasteType,
        quantityEstimateKg: quantityEstimateKg,
        notes: notes,
        scheduledAt: scheduledAt,
        timeSlot: timeSlot,
      );
    } catch (e) {
      debugPrint('WasteRequestService.create failed: $e');
      rethrow;
    }
  }

  Future<String> _insertAddressBestEffort({
    required String userId,
    required String city,
    required String neighborhood,
    required String details,
    double? latitude,
    double? longitude,
  }) async {
    final base = {
      'user_id': userId,
      'label': 'Pickup',
      'city': city,
      'neighborhood': neighborhood,
      'details': details,
    };

    // Try with coordinates first; if the DB doesn't have the columns yet, retry without.
    try {
      final addr = await _client
          .from('addresses')
          .insert({
            ...base,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
          })
          .select('id')
          .single();
      return addr['id'] as String;
    } catch (e) {
      debugPrint(
          'WasteRequestService._insertAddressBestEffort retry without lat/lng: $e');
      final addr =
          await _client.from('addresses').insert(base).select('id').single();
      return addr['id'] as String;
    }
  }

  Future<WasteRequest> _insertWasteRequestBestEffort({
    required String generatorId,
    required String? addressId,
    required String wasteType,
    required double quantityEstimateKg,
    required String? notes,
    required DateTime? scheduledAt,
    required String? timeSlot,
  }) async {
    final base = {
      'generator_id': generatorId,
      'address_id': addressId,
      'waste_type': wasteType,
      'quantity_estimate_kg': quantityEstimateKg,
      'notes': notes,
      'status': 'pending',
      if (scheduledAt != null)
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      if (timeSlot != null && timeSlot.trim().isNotEmpty)
        'time_slot': timeSlot.trim(),
    };

    try {
      final row = await _client
          .from('waste_requests')
          .insert(base)
          .select('*, addresses(*)')
          .single();
      return WasteRequest.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      // If the schema doesn't yet contain `time_slot` (or scheduled_at), retry without optional fields.
      debugPrint(
          'WasteRequestService._insertWasteRequestBestEffort retry without optional fields: $e');
      final row = await _client
          .from('waste_requests')
          .insert({
            'generator_id': generatorId,
            'address_id': addressId,
            'waste_type': wasteType,
            'quantity_estimate_kg': quantityEstimateKg,
            'notes': notes,
            'status': 'pending',
          })
          .select('*, addresses(*)')
          .single();
      // We still return a model that contains the values client-side (simulation).
      final wr = WasteRequest.fromJson(Map<String, dynamic>.from(row));
      return wr.copyWith(scheduledAt: scheduledAt, timeSlot: timeSlot);
    }
  }

  Future<void> cancel(String requestId) async {
    try {
      await _client.from('waste_requests').update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('WasteRequestService.cancel failed: $e');
      rethrow;
    }
  }

  /// Collector accepts a mission.
  /// Creates a row in `pickups` and updates request status to `accepted`.
  Future<void> acceptMission(String requestId) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      // `pickups.request_id` is UNIQUE (one pickup per request).
      // Make the operation idempotent and avoid overriding another collector.
      final existing = await _client
          .from('pickups')
          .select('collector_id')
          .eq('request_id', requestId)
          .maybeSingle();
      final existingCollectorId =
          existing == null ? null : (existing['collector_id'] as String?);

      if (existingCollectorId != null &&
          existingCollectorId.trim().isNotEmpty) {
        if (existingCollectorId == uid) {
          // Already accepted by this collector -> treat as success.
          await _client.from('waste_requests').update({
            'status': 'accepted',
            'updated_at': DateTime.now().toUtc().toIso8601String()
          }).eq('id', requestId);
          return;
        }
        // Accepted by someone else.
        throw StateError('MISSION_ALREADY_ACCEPTED');
      }

      // Try inserting; handle race condition if another collector accepted simultaneously.
      final nowIso = DateTime.now().toUtc().toIso8601String();
      try {
        await _client.from('pickups').insert({
          'request_id': requestId,
          'collector_id': uid,
          'accepted_at': nowIso,
          'updated_at': nowIso
        });
      } catch (e) {
        // If the schema doesn't have accepted_at/updated_at yet, retry with minimal columns.
        try {
          await _client
              .from('pickups')
              .insert({'request_id': requestId, 'collector_id': uid});
        } catch (_) {
          // In case of unique violation, re-check who accepted.
          // (Handled below.)
        }
        // In case of unique violation, re-check who accepted.
        try {
          final recheck = await _client
              .from('pickups')
              .select('collector_id')
              .eq('request_id', requestId)
              .maybeSingle();
          final cid =
              recheck == null ? null : (recheck['collector_id'] as String?);
          if (cid == uid) {
            // We lost the race but it is still ours -> ok.
          } else if (cid != null && cid.trim().isNotEmpty) {
            throw StateError('MISSION_ALREADY_ACCEPTED');
          } else {
            rethrow;
          }
        } catch (_) {
          rethrow;
        }
      }

      await _client.from('waste_requests').update({
        'status': 'accepted',
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('WasteRequestService.acceptMission failed: $e');
      rethrow;
    }
  }

  Future<void> markCollected(String requestId) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      await _client
          .from('pickups')
          .update({
            'collected_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String()
          })
          .eq('request_id', requestId)
          .eq('collector_id', uid);
      await _client.from('waste_requests').update({
        'status': 'collected',
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('WasteRequestService.markCollected failed: $e');
      rethrow;
    }
  }

  Future<void> markDelivered(String requestId) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      await _client
          .from('pickups')
          .update({
            'delivered_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String()
          })
          .eq('request_id', requestId)
          .eq('collector_id', uid);
      await _client.from('waste_requests').update({
        'status': 'delivered',
        'updated_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', requestId);
    } catch (e) {
      debugPrint('WasteRequestService.markDelivered failed: $e');
      rethrow;
    }
  }

  /// Collector marks a request as delivered and assigns a target center.
  ///
  /// This is implemented as "best effort" to support projects where the schema
  /// might not yet have `center_id` columns.
  ///
  /// Supported schema variants (any subset may exist):
  /// - `pickups.center_id`
  /// - `waste_requests.center_id`
  Future<void> markDeliveredToCenter(
      {required String requestId, required String centerId}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');

    final nowIso = DateTime.now().toUtc().toIso8601String();

    // 1) Update pickup row (delivered_at + optionally center_id)
    try {
      await _client
          .from('pickups')
          .update({
            'delivered_at': nowIso,
            'center_id': centerId,
            'updated_at': nowIso
          })
          .eq('request_id', requestId)
          .eq('collector_id', uid);
    } catch (e) {
      debugPrint(
          'WasteRequestService.markDeliveredToCenter pickup update fallback (no center_id?): $e');
      await _client
          .from('pickups')
          .update({'delivered_at': nowIso, 'updated_at': nowIso})
          .eq('request_id', requestId)
          .eq('collector_id', uid);
    }

    // 2) Update request (status delivered + optionally center_id)
    try {
      await _client.from('waste_requests').update({
        'status': 'delivered',
        'center_id': centerId,
        'updated_at': nowIso
      }).eq('id', requestId);
    } catch (e) {
      debugPrint(
          'WasteRequestService.markDeliveredToCenter waste_requests update fallback (no center_id?): $e');
      await _client.from('waste_requests').update(
          {'status': 'delivered', 'updated_at': nowIso}).eq('id', requestId);
    }
  }

  Future<List<String>> listPhotoUrls(String requestId) async {
    try {
      final rows = await _client
          .from('waste_request_photos')
          .select('url')
          .eq('request_id', requestId)
          .order('created_at', ascending: true);
      return (rows as List)
          .map((e) => (e as Map)['url'] as String)
          .where((e) => e.trim().isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('WasteRequestService.listPhotoUrls failed: $e');
      rethrow;
    }
  }

  Future<void> addPhotoUrl(
      {required String requestId, required String url}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      await _client.from('waste_request_photos').insert({
        'request_id': requestId,
        'uploaded_by': uid,
        'url': url,
      });
    } catch (e) {
      debugPrint('WasteRequestService.addPhotoUrl failed: $e');
      rethrow;
    }
  }

  /// Center validates a delivery reception, records a `processing_events` row and
  /// credits the collector with a virtual payout.
  ///
  /// Payout is stored in `eco_transactions.points` (interpreted as XAF) with
  /// `reason = 'payout'`.
  Future<void> confirmReceptionAtCenter({
    required String requestId,
    required double weighedKg,
    bool accepted = true,
    String? notes,
  }) async {
    final centerId = currentUserId;
    if (centerId == null) throw StateError('Not authenticated');

    try {
      // 1) Record processing event (idempotency: multiple receptions allowed, but payout only once).
      await _client.from('processing_events').insert({
        'request_id': requestId,
        'center_id': centerId,
        'weighed_kg': weighedKg,
        'accepted': accepted,
        'notes': notes,
      });

      if (!accepted) return;

      // 2) Find collector for this request (from pickups).
      final pickup = await _client
          .from('pickups')
          .select('collector_id')
          .eq('request_id', requestId)
          .maybeSingle();
      final collectorId =
          pickup == null ? null : (pickup['collector_id'] as String?);
      if (collectorId == null || collectorId.trim().isEmpty) return;

      // 3) Prevent double payout for same request.
      final existing = await _client
          .from('eco_transactions')
          .select('id')
          .eq('user_id', collectorId)
          .eq('request_id', requestId)
          .eq('reason', 'payout')
          .maybeSingle();
      if (existing != null) return;

      // 4) Compute payout by waste type.
      final wr = await _client
          .from('waste_requests')
          .select('waste_type')
          .eq('id', requestId)
          .maybeSingle();
      final wasteType = (wr?['waste_type'] ?? 'mixed').toString();

      final rates = await AppSettingsService().getWasteRates();
      final rate = rates[wasteType] ?? rates['mixed'] ?? wasteXafPerKg['mixed']!;
      final amountXaf = (weighedKg * rate).round();

      await _client.from('eco_transactions').insert({
        'user_id': collectorId,
        'request_id': requestId,
        'points': amountXaf,
        'reason': 'payout',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('WasteRequestService.confirmReceptionAtCenter failed: $e');
      rethrow;
    }
  }
}
