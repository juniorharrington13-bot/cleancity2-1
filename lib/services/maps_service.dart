import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Mapbox Geocoding (autocomplete/search) + Directions (routing).
class MapsService {
  static const String mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  const MapsService();

  bool get isConfigured => mapboxAccessToken.trim().isNotEmpty;

  bool get isRoutingConfigured => isConfigured;

  Future<List<MapPlaceSuggestion>> autocomplete({required String input, LatLng? locationBias}) async {
    final q = input.trim();
    if (q.isEmpty || !isConfigured) return const [];

    final uri = Uri.https('api.mapbox.com', '/geocoding/v5/mapbox.places/${Uri.encodeComponent(q)}.json', {
      'access_token': mapboxAccessToken,
      'limit': '8',
      'country': 'cm',
      'language': 'fr',
      if (locationBias != null) 'proximity': '${locationBias.longitude},${locationBias.latitude}',
    });

    try {
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('MapsService.autocomplete HTTP ${res.statusCode} body=${utf8.decode(res.bodyBytes)}');
        return const [];
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final features = (body is Map ? body['features'] as List? : null) ?? const [];
      return features
          .whereType<Map>()
          .map((e) {
            final m = Map<String, dynamic>.from(e);
            final display = (m['place_name'] ?? '').toString();
            final center = (m['center'] as List?) ?? const [];
            if (center.length != 2) return null;
            final lng = (center[0] as num).toDouble();
            final lat = (center[1] as num).toDouble();
            return MapPlaceSuggestion(placeId: '$lat,$lng', description: display);
          })
          .whereType<MapPlaceSuggestion>()
          .where((e) => e.description.trim().isNotEmpty)
          .take(8)
          .toList(growable: false);
    } catch (e) {
      debugPrint('MapsService.autocomplete failed: $e');
      return const [];
    }
  }

  /// `placeId` is encoded as "lat,lon" (see [autocomplete]).
  Future<LatLng?> geocodePlaceId(String placeId) async {
    if (placeId.trim().isEmpty) return null;
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

    final coords = '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.https('api.mapbox.com', '/directions/v5/mapbox/driving/$coords', {
      'access_token': mapboxAccessToken,
      'geometries': 'geojson',
      'overview': 'full',
    });

    try {
      final res = await http.get(uri);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('MapsService.directions HTTP ${res.statusCode} body=${utf8.decode(res.bodyBytes)}');
        return null;
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) return null;
      final routes = (body['routes'] as List? ?? const []);
      if (routes.isEmpty) return null;
      final route0 = Map<String, dynamic>.from(routes.first as Map);

      final geometry = Map<String, dynamic>.from(route0['geometry'] as Map? ?? const {});
      final coordsList = (geometry['coordinates'] as List? ?? const []);
      final points = <LatLng>[];
      for (final c in coordsList) {
        if (c is List && c.length >= 2) {
          final lng = (c[0] as num?)?.toDouble();
          final lat = (c[1] as num?)?.toDouble();
          if (lat != null && lng != null) points.add(LatLng(lat, lng));
        }
      }

      final dist = (route0['distance'] as num?)?.round();
      final dur = (route0['duration'] as num?)?.round();

      return MapDirections(polylinePoints: points, durationSec: dur, distanceMeters: dist);
    } catch (e) {
      debugPrint('MapsService.directions failed: $e');
      return null;
    }
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
