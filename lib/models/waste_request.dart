import 'package:flutter/foundation.dart';

@immutable
class WasteRequest {
  const WasteRequest({
    required this.id,
    required this.generatorId,
    this.addressId,
    required this.wasteType,
    required this.quantityEstimateKg,
    required this.status,
    this.notes,
    this.scheduledAt,
    this.timeSlot,
    required this.createdAt,
    required this.updatedAt,
    this.address,
    this.pickupGeneratorConfirmedAt,
    List<String>? wasteTypes,
  }) : wasteTypes = wasteTypes ?? const [];

  final String id;
  final String generatorId;
  final String? addressId;
  final String wasteType;
  final double quantityEstimateKg;
  final String status;
  final String? notes;
  final DateTime? scheduledAt;
  /// Optional time window label (e.g. "08:00–10:00").
  ///
  /// This is stored in DB when the `time_slot` column exists; otherwise it can
  /// be simulated client-side.
  final String? timeSlot;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional joined address row (`addresses(*)`).
  final Map<String, dynamic>? address;

  /// Set once the generator has confirmed (non-blocking, informational) that
  /// a collector really came and picked up their waste. From the joined
  /// `pickups(generator_confirmed_at)` embed, when requested.
  final DateTime? pickupGeneratorConfirmedAt;

  /// The full set of waste types the generator picked for this request.
  /// `wasteType` stays the single summary value ('mixed' when this has more
  /// than one entry) used for rate lookups elsewhere in the app.
  final List<String> wasteTypes;

  WasteRequest copyWith({
    String? id,
    String? generatorId,
    String? addressId,
    String? wasteType,
    double? quantityEstimateKg,
    String? status,
    String? notes,
    DateTime? scheduledAt,
    String? timeSlot,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? address,
  }) =>
      WasteRequest(
        id: id ?? this.id,
        generatorId: generatorId ?? this.generatorId,
        addressId: addressId ?? this.addressId,
        wasteType: wasteType ?? this.wasteType,
        quantityEstimateKg: quantityEstimateKg ?? this.quantityEstimateKg,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        timeSlot: timeSlot ?? this.timeSlot,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        address: address ?? this.address,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'generator_id': generatorId,
        'address_id': addressId,
        'waste_type': wasteType,
        'waste_types': wasteTypes,
        'quantity_estimate_kg': quantityEstimateKg,
        'status': status,
        'notes': notes,
        'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'time_slot': timeSlot,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static WasteRequest fromJson(Map<String, dynamic> json) {
    final quantityRaw = json['quantity_estimate_kg'];
    final quantity = quantityRaw is num ? quantityRaw.toDouble() : double.tryParse('$quantityRaw') ?? 0.0;
    return WasteRequest(
      id: (json['id'] ?? '') as String,
      generatorId: (json['generator_id'] ?? '') as String,
      addressId: json['address_id'] as String?,
      wasteType: (json['waste_type'] ?? 'mixed') as String,
      quantityEstimateKg: quantity,
      status: (json['status'] ?? 'pending') as String,
      notes: json['notes'] as String?,
      scheduledAt: json['scheduled_at'] == null ? null : DateTime.tryParse('${json['scheduled_at']}'),
      timeSlot: json['time_slot']?.toString(),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      address: json['addresses'] == null ? null : Map<String, dynamic>.from(json['addresses'] as Map),
      pickupGeneratorConfirmedAt: DateTime.tryParse('${_pickupField(json['pickups'], 'generator_confirmed_at')}'),
      wasteTypes: (json['waste_types'] is List)
          ? (json['waste_types'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : null,
    );
  }

  /// `pickups` may come back as a single joined object or a list, depending
  /// on how PostgREST resolves the one-to-one embed.
  static Object? _pickupField(Object? pickups, String key) {
    if (pickups is Map) return pickups[key];
    if (pickups is List && pickups.isNotEmpty && pickups.first is Map) {
      return (pickups.first as Map)[key];
    }
    return null;
  }
}
