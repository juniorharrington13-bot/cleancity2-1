import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/components/mobile_money_withdraw_sheet.dart';
import 'package:cleancity/components/center_picker_sheet.dart';
import 'package:cleancity/components/user_profile_tab.dart';
import 'package:cleancity/chat/chat_screens.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/services/chat_service.dart';
import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/models/waste_request.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/maps_service.dart';
import 'package:cleancity/services/waste_request_service.dart';
import 'package:cleancity/theme.dart';

// --- COLLECTOR DASHBOARD ---
class CollectorDashboard extends StatefulWidget {
  const CollectorDashboard({super.key});

  @override
  State<CollectorDashboard> createState() => _CollectorDashboardState();
}

class _CollectorDashboardState extends State<CollectorDashboard> {
  int _index = 0;

  void _handleBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.roleSelection);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _CollectorMissionsTab(),
      const _CollectorMapTab(),
      const _CollectorHistoryTab(),
      const _CollectorWalletTab(),
      const ChatThreadsScreen(),
      const UserProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Retour',
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => _handleBack(context),
        ),
        title: Row(
          children: [
            Icon(Icons.eco, color: LightModeColors.lightPrimary),
            const SizedBox(width: 8),
            FutureBuilder(
              future: AppUserService().getCurrentProfile(),
              builder: (context, snap) {
                final name = (snap.data?.fullName?.trim().isNotEmpty ?? false) ? snap.data!.fullName!.trim() : 'Collecteur';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text('CAMEROUN • COLLECTEUR', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant, fontSize: 8)),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: LightModeColors.lightPrimaryContainer,
              child: Icon(Icons.person, size: 16, color: LightModeColors.lightPrimary),
            ),
          )
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.cases_outlined), label: 'Missions'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Carte'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historique'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Portefeuille'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_outlined), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}

class _CollectorMapTab extends StatefulWidget {
  const _CollectorMapTab();

  @override
  State<_CollectorMapTab> createState() => _CollectorMapTabState();
}

class _CollectorMapTabState extends State<_CollectorMapTab> {
  static const LatLng _douala = LatLng(4.0511, 9.7679);

  final _maps = MapsService();
  final fm.MapController _mapCtrl = fm.MapController();
  final _searchCtrl = TextEditingController();

  LatLng? _myLocation;
  LatLng? _destination;
  String? _destinationLabel;
  List<MapPlaceSuggestion> _suggestions = const [];
  List<LatLng> _route = const [];
  int? _routeDistanceMeters;
  int? _routeDurationSec;
  bool _locating = false;
  bool _routing = false;

  late Future<List<Map<String, dynamic>>> _activePickupsFuture;

  @override
  void initState() {
    super.initState();
    _activePickupsFuture = _loadActivePickups();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadActivePickups() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];

      // Active = accepted/collected but not delivered.
      final rows = await client
          .from('pickups')
          .select('id, request_id, accepted_at, collected_at, delivered_at, waste_requests(*, addresses(*))')
          .eq('collector_id', uid)
          .isFilter('delivered_at', null)
          .order('accepted_at', ascending: false)
          .limit(25);

      return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Collector map active pickups load failed: $e');
      rethrow;
    }
  }

  Future<void> _ensureLocationAndCenter() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activez la localisation (GPS) pour utiliser la carte.')));
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Autorisation localisation refusée.')));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final here = LatLng(pos.latitude, pos.longitude);
      _myLocation = here;
      _mapCtrl.move(here, 14);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Collector map locate failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Localisation échouée: $e')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _updateSuggestions(String text) async {
    final results = await _maps.autocomplete(input: text, locationBias: _myLocation);
    if (!mounted) return;
    setState(() => _suggestions = results);
  }

  Future<void> _selectSuggestion(MapPlaceSuggestion s) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searchCtrl.text = s.description;
      _suggestions = const [];
      _destinationLabel = s.description;
      _route = const [];
      _routeDistanceMeters = null;
      _routeDurationSec = null;
    });

    final latLng = await _maps.geocodePlaceId(s.placeId);
    if (!mounted) return;
    if (latLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Adresse introuvable.')));
      return;
    }
    setState(() => _destination = latLng);
    _mapCtrl.move(latLng, 14);
    if (_myLocation != null) await _buildRoute();
  }

  Future<void> _selectPickupDestination({required String label, required num lat, required num lng}) async {
    FocusScope.of(context).unfocus();
    final dest = LatLng(lat.toDouble(), lng.toDouble());
    setState(() {
      _destination = dest;
      _destinationLabel = label;
      _suggestions = const [];
      _route = const [];
      _routeDistanceMeters = null;
      _routeDurationSec = null;
      _searchCtrl.text = label;
    });
    _mapCtrl.move(dest, 14);
    if (_myLocation == null) await _ensureLocationAndCenter();
    await _buildRoute();
  }

  Future<void> _buildRoute() async {
    final origin = _myLocation;
    final dest = _destination;
    if (origin == null || dest == null) return;
    if (_routing) return;
    if (!_maps.isRoutingConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clé OpenRouteService manquante: impossible de calculer l’itinéraire.')));
      return;
    }
    setState(() => _routing = true);
    try {
      final dir = await _maps.directions(origin: origin, destination: dest);
      if (!mounted) return;
      if (dir == null || dir.polylinePoints.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Itinéraire indisponible.')));
        return;
      }
      setState(() {
        _route = dir.polylinePoints;
        _routeDistanceMeters = dir.distanceMeters;
        _routeDurationSec = dir.durationSec;
      });
      final bounds = fm.LatLngBounds.fromPoints([origin, dest, ...dir.polylinePoints.take(10)]);
      _mapCtrl.fitCamera(fm.CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)));
    } catch (e) {
      debugPrint('Collector route build failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur itinéraire: $e')));
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  String _formatDistance(int meters) => meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '$meters m';

  String _formatDuration(int seconds) {
    final m = (seconds / 60).round();
    if (m < 60) return '$m min';
    final h = (m / 60).floor();
    final rem = m % 60;
    return '${h}h${rem.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.paddingLg,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Carte', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            IconButton(onPressed: () => setState(() => _activePickupsFuture = _loadActivePickups()), icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _updateSuggestions,
                      decoration: InputDecoration(
                        hintText: 'Destination (adresse ou mission)...',
                        prefixIcon: Icon(Icons.search, color: LightModeColors.lightPrimary),
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Effacer',
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _suggestions = const [];
                                  _destination = null;
                                  _destinationLabel = null;
                                  _route = const [];
                                  _routeDistanceMeters = null;
                                  _routeDurationSec = null;
                                }),
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: _locating ? null : _ensureLocationAndCenter,
                    icon: _locating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
                    label: const Text('Moi'),
                  ),
                ],
              ),
              if (!_maps.isRoutingConfigured)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'Itinéraire: définis OPEN_ROUTE_SERVICE_API_KEY. La carte OSM + recherche restent disponibles.',
                    style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    decoration: BoxDecoration(color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Column(
                      children: _suggestions
                          .map(
                            (s) => ListTile(
                              dense: true,
                              leading: Icon(Icons.place_outlined, color: LightModeColors.lightPrimary),
                              title: Text(s.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _selectSuggestion(s),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              if (_myLocation != null || _destination != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (_myLocation != null) Chip(avatar: Icon(Icons.person_pin_circle, color: LightModeColors.lightPrimary), label: const Text('Ma position')),
                      if (_destinationLabel != null) Chip(avatar: Icon(Icons.flag_outlined, color: LightModeColors.lightSecondary), label: Text(_destinationLabel!, overflow: TextOverflow.ellipsis)),
                      if (_myLocation != null && _destination != null)
                        ActionChip(
                          avatar: _routing ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.alt_route, color: LightModeColors.lightPrimary),
                          label: Text(_routing ? 'Calcul...' : 'Itinéraire'),
                          onPressed: _routing ? null : _buildRoute,
                        ),
                    ],
                  ),
                ),
              if (_routeDistanceMeters != null || _routeDurationSec != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: LightModeColors.lightPrimaryContainer.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Row(children: [Icon(Icons.straighten, color: LightModeColors.lightPrimary), const SizedBox(width: 10), Expanded(child: Text(_routeDistanceMeters == null ? '—' : _formatDistance(_routeDistanceMeters!), style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)))]),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: LightModeColors.lightSurfaceVariant.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(AppRadius.md)),
                          child: Row(children: [Icon(Icons.schedule, color: LightModeColors.lightSecondary), const SizedBox(width: 10), Expanded(child: Text(_routeDurationSec == null ? '—' : _formatDuration(_routeDurationSec!), style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)))]),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CollectorMiniMap(
          mapController: _mapCtrl,
          myLocation: _myLocation,
          destination: _destination,
          route: _route,
        ),
        const SizedBox(height: 12),
        Text('Missions en cours', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        FutureBuilder(
          future: _activePickupsFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
            if (snap.hasError) return Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red));
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return _CollectorEmpty(icon: Icons.alt_route, title: 'Aucune mission active', subtitle: 'Acceptez une mission pour afficher son itinéraire ici.');
            }

            return Column(
              children: rows.map((row) {
                final req = row['waste_requests'] as Map<String, dynamic>?;
                final reqId = req?['id'] as String?;
                final addr = req?['addresses'] as Map<String, dynamic>?;
                final city = (addr?['city'] ?? '') as String;
                final hood = (addr?['neighborhood'] ?? '') as String;
                final label = [hood, city].where((s) => s.trim().isNotEmpty).join(' • ');

                final latRaw = addr?['latitude'];
                final lngRaw = addr?['longitude'];
                final hasCoord = latRaw is num && lngRaw is num;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
                    child: Row(
                      children: [
                        const CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.location_on_outlined, color: LightModeColors.lightPrimary)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label.isEmpty ? 'Adresse de mission' : label, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(reqId == null ? '' : 'Demande #${reqId.substring(0, 6)}', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: hasCoord ? 'Itinéraire' : 'Coordonnées manquantes',
                          onPressed: !hasCoord
                              ? null
                              : () => _selectPickupDestination(label: label.isEmpty ? 'Mission' : label, lat: latRaw, lng: lngRaw),
                          icon: Icon(Icons.alt_route, color: hasCoord ? LightModeColors.lightPrimary : LightModeColors.lightOnSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _CollectorMiniMap extends StatelessWidget {
  const _CollectorMiniMap({required this.mapController, required this.myLocation, required this.destination, required this.route});
  final fm.MapController mapController;
  final LatLng? myLocation;
  final LatLng? destination;
  final List<LatLng> route;

  @override
  Widget build(BuildContext context) {
    final markers = <fm.Marker>[];
    if (myLocation != null) {
      markers.add(
        fm.Marker(
          point: myLocation!,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(color: LightModeColors.lightPrimaryContainer, borderRadius: BorderRadius.circular(AppRadius.max), border: Border.all(color: LightModeColors.lightPrimary)),
            child: Icon(Icons.person_pin_circle, color: LightModeColors.lightPrimary),
          ),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        fm.Marker(
          point: destination!,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.max), border: Border.all(color: LightModeColors.lightSecondary)),
            child: Icon(Icons.flag, color: LightModeColors.lightSecondary),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 260,
        child: fm.FlutterMap(
          mapController: mapController,
          options: fm.MapOptions(
            initialCenter: _CollectorMapTabState._douala,
            initialZoom: 12,
            interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate),
          ),
          children: [
            fm.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'cleancity',
              tileProvider: fm.NetworkTileProvider(headers: const {'User-Agent': MapsService.nominatimUserAgent}),
            ),
            if (route.isNotEmpty)
              fm.PolylineLayer(
                polylines: [fm.Polyline(points: route, strokeWidth: 4.5, color: LightModeColors.lightPrimary)],
              ),
            if (markers.isNotEmpty) fm.MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}

class _CollectorMissionsTab extends StatefulWidget {
  const _CollectorMissionsTab();

  @override
  State<_CollectorMissionsTab> createState() => _CollectorMissionsTabState();
}

class _CollectorMissionsTabState extends State<_CollectorMissionsTab> {
  late Future _future;

  @override
  void initState() {
    super.initState();
    _future = WasteRequestService().listAvailableMissions();
  }

  Future<void> _refresh() async => setState(() => _future = WasteRequestService().listAvailableMissions());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Missions', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: _refresh, icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (snap.hasError) return Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red));
              final items = (snap.data as List?)?.cast<WasteRequest>() ?? const <WasteRequest>[];
              if (items.isEmpty) {
                return _CollectorEmpty(icon: Icons.inbox_outlined, title: 'Aucune mission disponible', subtitle: 'Revenez plus tard ou changez de zone.');
              }
              return Column(
                children: items.map((e) {
                  final r = e;
                  final type = '${r.wasteType}'.toUpperCase();
                  final addr = r.address;
                  final location = addr == null ? '—' : [addr['neighborhood'], addr['city']].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
                  final weight = '${r.quantityEstimateKg.toStringAsFixed(0)} kg';
                  final schedAt = r.scheduledAt;
                  final slot = (r.timeSlot ?? '').trim();
                  final sched = schedAt == null && slot.isEmpty
                      ? ''
                      : [
                          if (schedAt != null) '${schedAt.day.toString().padLeft(2, '0')}/${schedAt.month.toString().padLeft(2, '0')}',
                          if (slot.isNotEmpty) slot,
                        ].join(' • ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MissionCard(
                      type: type,
                      location: location,
                      title: sched.isEmpty ? 'Collecte' : 'Collecte • $sched',
                      weight: weight,
                      price: '— XAF',
                      onTap: () => context.push(AppRoutes.missionDetails, extra: r.id),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CollectorHistoryTab extends StatefulWidget {
  const _CollectorHistoryTab();

  @override
  State<_CollectorHistoryTab> createState() => _CollectorHistoryTabState();
}

class _CollectorHistoryTabState extends State<_CollectorHistoryTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return [];
      final rows = await client
          .from('pickups')
          .select('id, request_id, collector_id, accepted_at, collected_at, delivered_at, waste_requests(*, addresses(*))')
          .eq('collector_id', uid)
          .order('accepted_at', ascending: false)
          .limit(50);
      return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('Collector history load failed: $e');
      rethrow;
    }
  }

  String _fmtDateTime(String raw) {
    if (raw.trim().isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final d = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
      final t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      return '$d • $t';
    } catch (_) {
      return raw;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Acceptée';
      case 'en_route':
        return 'En route';
      case 'collected':
        return 'Collectée';
      case 'delivered':
        return 'Livrée';
      case 'cancelled':
        return 'Annulée';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Historique', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => setState(() => _future = _load()), icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (snap.hasError) return Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red));
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return _CollectorEmpty(icon: Icons.history, title: 'Aucune mission', subtitle: 'Vos missions acceptées et terminées apparaîtront ici.');
              }

              return Column(
                children: rows.map((row) {
                  final req = row['waste_requests'] as Map<String, dynamic>?;
                  final reqId = req?['id'] as String?;
                  final addr = req?['addresses'] as Map<String, dynamic>?;
                  final city = (addr?['city'] ?? '') as String;
                  final hood = (addr?['neighborhood'] ?? '') as String;
                  final location = [hood, city].where((s) => s.trim().isNotEmpty).join(', ');
                  final status = (req?['status'] ?? '—') as String;
                  final type = ((req?['waste_type'] ?? 'mixed') as String).toUpperCase();
                  final acceptedAt = _fmtDateTime((row['accepted_at'] ?? '').toString());
                  final collectedAt = _fmtDateTime((row['collected_at'] ?? '').toString());
                  final deliveredAt = _fmtDateTime((row['delivered_at'] ?? '').toString());
                  final weightKg = (req?['quantity_estimate_kg'] ?? '').toString();

                  final timeline = [
                    if (acceptedAt.isNotEmpty) 'Acceptée: $acceptedAt',
                    if (collectedAt.isNotEmpty) 'Ramassée: $collectedAt',
                    if (deliveredAt.isNotEmpty) 'Livrée: $deliveredAt',
                  ].join('  •  ');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MissionCard(
                      type: type,
                      location: location.isEmpty ? '—' : location,
                      title: 'Statut: ${_statusLabel(status)}',
                      weight: weightKg.trim().isEmpty ? '—' : '${double.tryParse(weightKg)?.toStringAsFixed(0) ?? weightKg} kg',
                      price: timeline.isEmpty ? acceptedAt : timeline,
                      onTap: reqId == null ? () {} : () => context.push(AppRoutes.missionDetails, extra: reqId),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CollectorWalletTab extends StatelessWidget {
  const _CollectorWalletTab();

  @override
  Widget build(BuildContext context) {
    return const _CollectorWalletBody();
  }
}

class _CollectorWalletBody extends StatefulWidget {
  const _CollectorWalletBody();

  @override
  State<_CollectorWalletBody> createState() => _CollectorWalletBodyState();
}

class _CollectorWalletBodyState extends State<_CollectorWalletBody> {
  late Future<_WalletData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WalletData> _load() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return const _WalletData(transactions: [], payoutRequests: []);

      final rows = await client.from('eco_transactions').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(50);
      final tx = (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);

      List<Map<String, dynamic>> payoutRows = const [];
      try {
        final reqs = await client.from('payout_requests').select('*').eq('user_id', uid).order('created_at', ascending: false).limit(50);
        payoutRows = (reqs as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(growable: false);
      } catch (e) {
        // Table/policies might not exist yet in Supabase.
        debugPrint('Payout requests load skipped/failed: $e');
      }

      return _WalletData(transactions: tx, payoutRequests: payoutRows);
    } catch (e) {
      debugPrint('Collector wallet load failed: $e');
      rethrow;
    }
  }

  int _sumPoints(List<Map<String, dynamic>> rows) {
    var sum = 0;
    for (final r in rows) {
      final p = r['points'];
      if (p is int) sum += p;
      if (p is num) sum += p.toInt();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _future = _load()),
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Portefeuille', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => setState(() => _future = _load()), icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (snap.hasError) return Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red));
              final data = snap.data ?? const _WalletData(transactions: [], payoutRequests: []);
              final rows = data.transactions;
              final total = _sumPoints(rows);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(color: LightModeColors.lightPrimary, borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solde (XAF)', style: context.textStyles.labelMedium?.copyWith(color: LightModeColors.lightOnPrimary.withValues(alpha: 0.85))),
                        const SizedBox(height: 8),
                        Text('$total', style: context.textStyles.displaySmall?.copyWith(color: LightModeColors.lightOnPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Crédits après validation centre', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnPrimary.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: LightModeColors.lightSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
                          builder: (context) => MobileMoneyWithdrawSheet(onSuccess: () => setState(() => _future = _load())),
                        );
                      },
                      icon: const Icon(Icons.account_balance_wallet_rounded, color: LightModeColors.lightOnPrimary),
                      label: Text('Retirer via Mobile Money', style: context.textStyles.titleSmall?.copyWith(color: LightModeColors.lightOnPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PayoutRequestsPanel(rows: data.payoutRequests),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    _CollectorEmpty(icon: Icons.receipt_long, title: 'Aucune transaction', subtitle: 'Les paiements virtuels apparaîtront après validation centre.'),
                  if (rows.isNotEmpty)
                    ...rows.map((r) {
                      final pts = r['points']?.toString() ?? '0';
                      final reason = (r['reason'] ?? 'pickup').toString();
                      final at = (r['created_at'] ?? '').toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: AppSpacing.paddingLg,
                          decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
                          child: Row(
                            children: [
                              const CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.stars, color: LightModeColors.lightPrimary)),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(reason, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 2), Text(at, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant))])),
                              Text('+$pts', style: context.textStyles.titleMedium?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

@immutable
class _WalletData {
  const _WalletData({required this.transactions, required this.payoutRequests});

  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> payoutRequests;
}

class _PayoutRequestsPanel extends StatelessWidget {
  const _PayoutRequestsPanel({required this.rows});

  final List<Map<String, dynamic>> rows;

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Payé';
      case 'rejected':
        return 'Rejeté';
      default:
        return 'En attente';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.payments_outlined, color: LightModeColors.lightPrimary)),
            const SizedBox(width: 12),
            Expanded(child: Text('Aucune demande de retrait.', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant))),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Retraits Mobile Money', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...rows.take(6).map((r) {
            final provider = (r['provider'] ?? 'Mobile Money').toString();
            final phone = (r['phone'] ?? '').toString();
            final amount = (r['amount_xaf'] ?? 0).toString();
            final status = (r['status'] ?? 'pending').toString();
            final color = _statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.swap_horiz_rounded, color: LightModeColors.lightPrimary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$provider • $phone', style: context.textStyles.bodyMedium?.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('Montant: $amount XAF', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.35))),
                    child: Text(_statusLabel(status), style: context.textStyles.labelSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.type, required this.location, required this.title, required this.weight, required this.price, required this.onTap});
  final String type;
  final String location;
  final String title;
  final String weight;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.local_shipping_outlined, color: LightModeColors.lightPrimary)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type, style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('$title • $weight', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
              child: Text(
                price,
                textAlign: TextAlign.right,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.labelLarge?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectorEmpty extends StatelessWidget {
  const _CollectorEmpty({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(icon, color: LightModeColors.lightPrimary)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _RequestLocationMap extends StatelessWidget {
  const _RequestLocationMap({required this.address});
  final Map<String, dynamic>? address;

  static const LatLng _douala = LatLng(4.0511, 9.7679);

  @override
  Widget build(BuildContext context) {
    final latRaw = address?['latitude'];
    final lngRaw = address?['longitude'];
    final hasCoords = latRaw is num && lngRaw is num;
    final center = hasCoords ? LatLng(latRaw.toDouble(), lngRaw.toDouble()) : _douala;

    final markers = <fm.Marker>[];
    if (hasCoords) {
      markers.add(
        fm.Marker(
          point: center,
          width: 46,
          height: 46,
          child: Container(
            decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.max), border: Border.all(color: LightModeColors.lightPrimary)),
            child: const Icon(Icons.location_on, color: LightModeColors.lightPrimary),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: fm.FlutterMap(
          options: fm.MapOptions(
            initialCenter: center,
            initialZoom: hasCoords ? 15 : 12,
            interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all & ~fm.InteractiveFlag.rotate),
          ),
          children: [
            fm.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'cleancity',
              tileProvider: fm.NetworkTileProvider(headers: const {'User-Agent': MapsService.nominatimUserAgent}),
            ),
            if (markers.isNotEmpty) fm.MarkerLayer(markers: markers),
            if (!hasCoords)
              fm.RichAttributionWidget(
                attributions: [
                  fm.TextSourceAttribution(
                    'Coordonnées GPS manquantes • Ajoutez “Moi” lors de la création de demande',
                    onTap: () {},
                  )
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// --- MISSION DETAILS SCREEN ---
class MissionDetailsScreen extends StatefulWidget {
  const MissionDetailsScreen({super.key, required this.requestId});

  final String? requestId;

  @override
  State<MissionDetailsScreen> createState() => _MissionDetailsScreenState();
}

class _MissionDetailsScreenState extends State<MissionDetailsScreen> {
  late Future<WasteRequest?> _future;
  bool _busy = false;

  String _friendlyError(Object e) {
    // Supabase RLS violation typically surfaces as PostgrestException with code 42501.
    if (e is StateError && e.message == 'MISSION_ALREADY_ACCEPTED') {
      return 'MISSION DÉJÀ ACCEPTÉE.';
    }
    try {
      final dynamic de = e;
      final String? code = de.code as String?;
      if (code == '42501') {
        return "ACCÈS REFUSÉ — ACTION BLOQUÉE PAR LA SÉCURITÉ (RLS).";
      }
      if (code == '23505') {
        return 'MISSION DÉJÀ ACCEPTÉE.';
      }
    } catch (_) {}
    return 'Erreur: $e';
  }

  @override
  void initState() {
    super.initState();
    _future = widget.requestId == null ? Future.value(null) : WasteRequestService().getById(widget.requestId!);
  }

  Future<void> _run(Future<void> Function() fn, {String? successMessage}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });
    try {
      await fn();
      if (!mounted) return;
      setState(() {
        _future = widget.requestId == null ? Future.value(null) : WasteRequestService().getById(widget.requestId!);
      });
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: scheme.primary,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: scheme.onPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  successMessage ?? 'Mise à jour effectuée.',
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Mission update failed: $e');
      if (!mounted) return;
      final scheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          backgroundColor: scheme.error,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onError),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _friendlyError(e),
                  style: TextStyle(color: scheme.onError, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _confirmDeliveryWithCenter(String requestId) async {
    if (_busy) return;

    AppUser? selected;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: LightModeColors.lightSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      builder: (context) {
        return CenterPickerSheet(
          onSelected: (c) {
            selected = c;
            context.pop();
          },
        );
      },
    );

    final center = selected;
    if (center == null) return;

    return _run(
      () => WasteRequestService().markDeliveredToCenter(requestId: requestId, centerId: center.id),
      successMessage: 'Livraison confirmée.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestId = widget.requestId;
    return Scaffold(
      appBar: AppBar(
        title: Text(requestId == null ? 'Mission' : 'Mission', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Chat',
            icon: const Icon(Icons.forum_outlined),
            onPressed: requestId == null
                ? null
                : () async {
                    try {
                      final threadId = await ChatService().getOrCreateThreadForRequest(requestId: requestId);
                      if (!context.mounted) return;
                      context.push(ChatRoutes.room, extra: {'threadId': threadId, 'requestId': requestId});
                    } catch (e) {
                      debugPrint('Open chat failed: $e');
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    }
                  },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red)));
          final r = snap.data;
          if (requestId == null || r == null) return Center(child: Text('Mission introuvable', style: context.textStyles.titleMedium));

          final addr = r.address;
          final city = (addr?['city'] ?? '') as String;
          final hood = (addr?['neighborhood'] ?? '') as String;
          final details = (addr?['details'] ?? '') as String;
          final addressLine = [hood, city, details].where((s) => s.trim().isNotEmpty).join(' • ');

          return SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RequestLocationMap(address: addr),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: LightModeColors.lightPrimaryContainer, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: LightModeColors.lightPrimary)),
                      const SizedBox(width: 8),
                      Text('STATUT: ${r.status.toUpperCase()}', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // Chat lié à la demande: conserve l'historique de la mission.
                        final threadId = await ChatService().getOrCreateThreadForRequest(requestId: requestId);
                        if (!context.mounted) return;
                        context.push(ChatRoutes.room, extra: {'threadId': threadId, 'requestId': requestId});
                      } catch (e) {
                        debugPrint('Open request chat (collector→generator) failed: $e');
                        if (!context.mounted) return;
                        AppSnackbars.error(context, 'Impossible d’ouvrir le chat.');
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Contacter le générateur'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Détails de la collecte', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: LightModeColors.lightSurfaceVariant), borderRadius: BorderRadius.circular(AppRadius.md), color: LightModeColors.lightSurface),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('TYPE DE DÉCHET', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)), Text(r.wasteType.toUpperCase(), style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold))]),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: LightModeColors.lightSurfaceVariant), borderRadius: BorderRadius.circular(AppRadius.md), color: LightModeColors.lightSurface),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('POIDS ESTIMÉ', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)), Text('${r.quantityEstimateKg.toStringAsFixed(0)} kg', style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: LightModeColors.lightSurfaceVariant), borderRadius: BorderRadius.circular(AppRadius.md), color: LightModeColors.lightSurface),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: LightModeColors.lightOnSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('ADRESSE DE RAMASSAGE', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)), Text(addressLine.isEmpty ? '—' : addressLine, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold))])),
                    ],
                  ),
                ),
                if ((r.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border.all(color: LightModeColors.lightSurfaceVariant), borderRadius: BorderRadius.circular(AppRadius.md), color: LightModeColors.lightSurface),
                    child: Row(children: [const Icon(Icons.sticky_note_2_outlined, color: LightModeColors.lightOnSurfaceVariant), const SizedBox(width: 12), Expanded(child: Text(r.notes!.trim(), style: context.textStyles.bodyMedium))]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : () => _run(() => WasteRequestService().acceptMission(requestId), successMessage: 'Mission acceptée.'),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_busy ? 'Traitement...' : 'Accepter la mission'), const SizedBox(width: 8), Icon(_busy ? Icons.hourglass_top : Icons.check_circle_outline)]),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => WasteRequestService().markCollected(requestId), successMessage: 'Ramassage confirmé.'),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Confirmer le ramassage'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _confirmDeliveryWithCenter(requestId),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Confirmer la livraison'),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
