import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart';

/// A colored point to render on the map (waste request, collector, destination...).
class MapPin {
  const MapPin({required this.point, this.color = Colors.red, this.radius = 8});
  final LatLng point;
  final Color color;
  final double radius;
}

/// Shared Mapbox-tiled map view (Web + Mobile + Desktop, via flutter_map) used
/// across the app to display waste request pins, the user's position, and a
/// route polyline. `mapbox_maps_flutter` was tried first but only supports
/// Android/iOS, so tiles are served through Mapbox's Static Tiles API instead.
class CleanCityMapView extends StatefulWidget {
  const CleanCityMapView({
    super.key,
    required this.center,
    this.zoom = 13,
    this.markers = const [],
    this.route = const [],
    this.onTap,
  });

  static const String mapboxAccessToken = String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  final LatLng center;
  final double zoom;
  final List<MapPin> markers;
  final List<LatLng> route;
  final void Function(LatLng)? onTap;

  @override
  State<CleanCityMapView> createState() => _CleanCityMapViewState();
}

class _CleanCityMapViewState extends State<CleanCityMapView> {
  final _mapCtrl = fm.MapController();

  @override
  void didUpdateWidget(covariant CleanCityMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom) {
      try {
        _mapCtrl.move(widget.center, widget.zoom);
      } catch (_) {
        // Map not mounted yet; initialCenter/initialZoom below will cover it.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasToken = CleanCityMapView.mapboxAccessToken.trim().isNotEmpty;
    final tileUrl = hasToken
        ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x?access_token=${CleanCityMapView.mapboxAccessToken}'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    return fm.FlutterMap(
      mapController: _mapCtrl,
      options: fm.MapOptions(
        initialCenter: widget.center,
        initialZoom: widget.zoom,
        interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate),
        onTap: widget.onTap == null ? null : (_, point) => widget.onTap!(point),
      ),
      children: [
        fm.TileLayer(urlTemplate: tileUrl, userAgentPackageName: 'com.cleancity.app'),
        if (widget.route.length >= 2)
          fm.PolylineLayer(polylines: [fm.Polyline(points: widget.route, strokeWidth: 4.5, color: Colors.blue)]),
        if (widget.markers.isNotEmpty)
          fm.MarkerLayer(
            markers: widget.markers
                .map((m) => fm.Marker(
                      point: m.point,
                      width: m.radius * 2 + 6,
                      height: m.radius * 2 + 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: m.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ))
                .toList(),
          ),
      ],
    );
  }
}
