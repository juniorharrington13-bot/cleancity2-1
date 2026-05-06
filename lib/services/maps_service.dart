import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OpenStreetMap + Nominatim (geocoding/search) + OpenRouteService (routing).
///
/// Nominatim usage policy requires a valid, identifying User-Agent.
class MapsService {
  static const String openRouteServiceApiKey = String.fromEnvironment('OPEN_ROUTE_SERVICE_API_KEY');

  /// Must be unique & identifying (to avoid being blocked by OSM/Nominatim).
  /// You can customize it later to include a contact email/website.
  static const String nominatimUserAgent = 'CLEANCITY-Cameroun/1.0 (Flutter; https://cleancity.cm)';

  const MapsService();

  bool get isConfigured => true;

  bool get isRoutingConfigured => openRouteServiceApiKey.trim().isNotEmpty;

  Future<List<MapPlaceSuggestion>> autocomplete({required String input, LatLng? locationBias}) async {
    final q = input.trim();
    if (q.isEmpty) return const [];

    // Nominatim Search API
    // https://nominatim.openstreetmap.org/search?q=...&format=json
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'limit': '8',
      'addressdetails': '1',
      'countrycodes': 'cm',
      'accept-language': 'fr',
      if (locationBias != null) 'viewbox': _biasViewbox(locationBias),
      if (locationBias != null) 'bounded': '1',
    });

    try {
      final res = await http.get(uri, headers: const {'User-Agent': nominatimUserAgent});
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('MapsService.autocomplete HTTP ${res.statusCode} body=${utf8.decode(res.bodyBytes)}');
        return const [];
      }

      final list = jsonDecode(utf8.decode(res.bodyBytes));
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final display = (m['display_name'] ?? '').toString();
            final lat = (m['lat'] ?? '').toString();
            final lon = (m['lon'] ?? '').toString();
            final placeId = '$lat,$lon';
            return MapPlaceSuggestion(placeId: placeId, description: display);
          })
          .where((e) => e.description.trim().isNotEmpty && e.placeId.split(',').length == 2)
          .take(8)
          .toList(growable: false);
    } catch (e) {
      debugPrint('MapsService.autocomplete failed: $e');
      return const [];
    }
  }

  Future<LatLng?> geocodePlaceId(String placeId) async {
    if (placeId.trim().isEmpty) return null;

    // In this OSM version, `placeId` is encoded as "lat,lon".
    try {
      final parts = placeId.split(',');
      if (parts.length != 2) return null;
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (e) {
      debugPrint('MapsService.geocodePlaceId failed: $e');
      return null;
    }
  }

  Future<MapDirections?> directions({required LatLng origin, required LatLng destination}) async {
    if (!isRoutingConfigured) return null;

    final uri = Uri.https('api.openrouteservice.org', '/v2/directions/driving-car');

    try {
      final payload = jsonEncode({
        'coordinates': [
          [origin.longitude, origin.latitude],
          [destination.longitude, destination.latitude],
        ],
      });

      final res = await http.post(
        uri,
        headers: {
          'Authorization': openRouteServiceApiKey,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: payload,
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('MapsService.directions HTTP ${res.statusCode} body=${utf8.decode(res.bodyBytes)}');
        return null;
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;

      final features = (body['features'] as List? ?? const []);
      if (features.isEmpty) return null;
      final feature0 = Map<String, dynamic>.from(features.first as Map);
      final geometry = Map<String, dynamic>.from(feature0['geometry'] as Map? ?? const {});
      final coords = (geometry['coordinates'] as List? ?? const []);
      final points = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = (c[0] as num?)?.toDouble();
          final lat = (c[1] as num?)?.toDouble();
          if (lat != null && lng != null) points.add(LatLng(lat, lng));
        }
      }

      final props = Map<String, dynamic>.from(feature0['properties'] as Map? ?? const {});
      final summary = Map<String, dynamic>.from(props['summary'] as Map? ?? const {});
      final dist = (summary['distance'] as num?)?.round();
      final dur = (summary['duration'] as num?)?.round();

      return MapDirections(polylinePoints: points, durationSec: dur, distanceMeters: dist);
    } catch (e) {
      debugPrint('MapsService.directions failed: $e');
      return null;
    }
  }

  static String _biasViewbox(LatLng center) {
    // ~15km bounding box; Nominatim expects: left,top,right,bottom in lon/lat.
    const delta = 0.15;
    final left = center.longitude - delta;
    final right = center.longitude + delta;
    final top = center.latitude + delta;
    final bottom = center.latitude - delta;
    return '$left,$top,$right,$bottom';
  }
}

class MapPlaceSuggestion {
  const MapPlaceSuggestion({required this.placeId, required this.description});
  final String placeId;
  final String description;
}

class MapDirections {
  const MapDirections({required this.polylinePoints, required this.durationSec, required this.distanceMeters});
  final List<LatLng> polylinePoints;
  final int? durationSec;
  final int? distanceMeters;
}
