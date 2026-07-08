import 'package:flutter/material.dart' hide Route;
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// A colored point to render on the map (waste request, collector, destination...).
class MapPin {
  const MapPin({required this.point, this.color = Colors.red, this.radius = 8});
  final LatLng point;
  final Color color;
  final double radius;
}

/// Shared Mapbox map view (Web + Mobile) used across the app to display
/// waste request pins, the user's position, and a route polyline.
class CleanCityMapView extends StatefulWidget {
  const CleanCityMapView({
    super.key,
    required this.center,
    this.zoom = 13,
    this.markers = const [],
    this.route = const [],
    this.onTap,
  });

  final LatLng center;
  final double zoom;
  final List<MapPin> markers;
  final List<LatLng> route;
  final void Function(LatLng)? onTap;

  @override
  State<CleanCityMapView> createState() => _CleanCityMapViewState();
}

class _CleanCityMapViewState extends State<CleanCityMapView> {
  MapboxMap? _map;
  CircleAnnotationManager? _circles;
  PolylineAnnotationManager? _lines;

  @override
  void didUpdateWidget(covariant CleanCityMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers || oldWidget.route != widget.route) {
      _syncAnnotations();
    }
    if (oldWidget.center != widget.center || oldWidget.zoom != widget.zoom) {
      _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(widget.center.longitude, widget.center.latitude)),
          zoom: widget.zoom,
        ),
        MapAnimationOptions(duration: 600),
      );
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    _circles = await map.annotations.createCircleAnnotationManager();
    _lines = await map.annotations.createPolylineAnnotationManager();
    await _syncAnnotations();
  }

  Future<void> _syncAnnotations() async {
    final circles = _circles;
    final lines = _lines;
    if (circles == null || lines == null) return;

    await circles.deleteAll();
    await lines.deleteAll();

    if (widget.markers.isNotEmpty) {
      await circles.createMulti(widget.markers
          .map((m) => CircleAnnotationOptions(
                geometry: Point(coordinates: Position(m.point.longitude, m.point.latitude)),
                circleColor: m.color.value,
                circleRadius: m.radius,
                circleStrokeColor: Colors.white.value,
                circleStrokeWidth: 2,
              ))
          .toList());
    }

    if (widget.route.length >= 2) {
      await lines.create(PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: widget.route.map((p) => Position(p.longitude, p.latitude)).toList(),
        ),
        lineColor: Colors.blue.value,
        lineWidth: 4,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(widget.center.longitude, widget.center.latitude)),
        zoom: widget.zoom,
      ),
      onMapCreated: _onMapCreated,
      onTapListener: widget.onTap == null
          ? null
          : (ctx) => widget.onTap!(LatLng(ctx.point.coordinates.lat.toDouble(), ctx.point.coordinates.lng.toDouble())),
    );
  }
}
