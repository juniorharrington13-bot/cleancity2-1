import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/components/cleancity_map_view.dart';
import 'package:cleancity/components/user_profile_tab.dart';
import 'package:cleancity/chat/chat_screens.dart';
import 'package:cleancity/models/waste_request.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/waste_request_service.dart';
import 'package:cleancity/services/media_upload_service.dart';
import 'package:cleancity/services/maps_service.dart';
import 'package:cleancity/services/push_notification_service.dart';
import 'package:cleancity/services/chat_service.dart';
import 'package:cleancity/theme.dart';

// --- GENERATOR DASHBOARD ---
class GeneratorDashboard extends StatefulWidget {
  const GeneratorDashboard({super.key});

  @override
  State<GeneratorDashboard> createState() => _GeneratorDashboardState();
}

class _GeneratorDashboardState extends State<GeneratorDashboard> {
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
      const _GeneratorHomeTab(),
      const _GeneratorRequestsTab(),
      const _GeneratorMapTab(),
      const ChatThreadsScreen(),
      const UserProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: context.l10n.commonBack,
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => _handleBack(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: LightModeColors.lightPrimaryContainer,
              child: Icon(Icons.person, color: LightModeColors.lightPrimary),
            ),
            const SizedBox(width: 12),
            FutureBuilder(
              future: AppUserService().getCurrentProfile(),
              builder: (context, snap) {
                final name = (snap.data?.fullName?.trim().isNotEmpty ?? false)
                    ? snap.data!.fullName!.trim()
                    : context.l10n.commonUser;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.generatorGreeting,
                        style: context.textStyles.labelSmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant)),
                    Text(name,
                        style: context.textStyles.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: context.l10n.generatorNotificationsTooltip,
            onPressed: () async {
              final ok = await PushNotificationService.requestPermission();
              if (!context.mounted) return;
              if (ok) {
                AppSnackbars.success(context, context.l10n.generatorNotificationsEnabled);
              } else {
                AppSnackbars.warning(context, context.l10n.generatorNotificationsDenied);
              }
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _index == 0 || _index == 1
            ? () => context.push(AppRoutes.createRequest)
            : null,
        backgroundColor: LightModeColors.lightPrimary,
        foregroundColor: LightModeColors.lightOnPrimary,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: context.l10n.generatorNavHome),
          BottomNavigationBarItem(
              icon: const Icon(Icons.list_alt), label: context.l10n.generatorNavRequests),
          BottomNavigationBarItem(
              icon: const Icon(Icons.map_outlined), label: context.l10n.collectorNavMap),
          BottomNavigationBarItem(
              icon: const Icon(Icons.forum_outlined), label: context.l10n.chatTitle),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline), label: context.l10n.profileTitle),
        ],
      ),
    );
  }
}

class _GeneratorHomeTab extends StatelessWidget {
  const _GeneratorHomeTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              color: LightModeColors.lightPrimary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.l10n.generatorEcoPointsTitle,
                        style: context.textStyles.bodyMedium?.copyWith(
                            color: LightModeColors.lightOnPrimary
                                .withValues(alpha: 0.8))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: LightModeColors.lightOnPrimary
                            .withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('+0 pts',
                          style: context.textStyles.labelSmall?.copyWith(
                              color: LightModeColors.lightOnPrimary)),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Text('—',
                    style: context.textStyles.displayMedium?.copyWith(
                        color: LightModeColors.lightOnPrimary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder(
            future: WasteRequestService().listForCurrentGenerator(),
            builder: (context, snap) {
              final data = snap.data ?? const <WasteRequest>[];
              final pending = data.where((e) => e.status == 'pending').length;
              final done = data
                  .where(
                      (e) => e.status == 'delivered' || e.status == 'collected')
                  .length;
              return Row(
                children: [
                  Expanded(
                      child: _StatCard(
                          icon: Icons.pending_actions,
                          label: context.l10n.generatorStatPending,
                          value: '$pending')),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _StatCard(
                          icon: Icons.check_circle_outline,
                          label: context.l10n.generatorStatCompleted,
                          value: '$done')),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.generatorRecentRequestsTitle,
                  style: context.textStyles.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              TextButton(
                  onPressed: () {},
                  child: Text(' ',
                      style: context.textStyles.labelMedium
                          ?.copyWith(color: LightModeColors.lightPrimary))),
            ],
          ),
          const SizedBox(height: 8),
          const _RecentRequestsPreview(),
          const SizedBox(height: 24),
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
                color: LightModeColors.lightPrimaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: LightModeColors.lightPrimary, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.generatorEcoTipTitle,
                          style: context.textStyles.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: LightModeColors.lightPrimary)),
                      const SizedBox(height: 4),
                      Text(
                          context.l10n.generatorEcoTipBody,
                          style: context.textStyles.bodySmall?.copyWith(
                              color: LightModeColors.lightOnPrimaryContainer)),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _RecentRequestsPreview extends StatefulWidget {
  const _RecentRequestsPreview();

  @override
  State<_RecentRequestsPreview> createState() => _RecentRequestsPreviewState();
}

class _RecentRequestsPreviewState extends State<_RecentRequestsPreview> {
  late Future<List<WasteRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = WasteRequestService().listForCurrentGenerator();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
              padding: EdgeInsets.all(12), child: LinearProgressIndicator());
        }
        final items = (snap.data ?? const <WasteRequest>[]).take(3).toList();
        if (items.isEmpty) {
          return _EmptyStateCard(
            icon: Icons.inbox_outlined,
            title: context.l10n.generatorNoRequestsTitle,
            subtitle: context.l10n.generatorNoRequestsSubtitle,
          );
        }
        return Column(
          children: items
              .map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RequestListTile(request: r)))
              .toList(),
        );
      },
    );
  }
}

class _GeneratorRequestsTab extends StatefulWidget {
  const _GeneratorRequestsTab();

  @override
  State<_GeneratorRequestsTab> createState() => _GeneratorRequestsTabState();
}

class _GeneratorRequestsTabState extends State<_GeneratorRequestsTab> {
  late Future<List<WasteRequest>> _future;

  @override
  void initState() {
    super.initState();
    _future = WasteRequestService().listForCurrentGenerator();
  }

  Future<void> _refresh() async {
    setState(() => _future = WasteRequestService().listForCurrentGenerator());
  }

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
              Text(context.l10n.generatorMyRequestsTitle,
                  style: context.textStyles.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: _refresh,
                  icon:
                      Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator());
              }
              final items = snap.data ?? const <WasteRequest>[];
              if (items.isEmpty) {
                return _EmptyStateCard(
                  icon: Icons.list_alt_outlined,
                  title: context.l10n.generatorNoRequestsShortTitle,
                  subtitle: context.l10n.generatorNoRequestsShortSubtitle,
                );
              }
              return Column(
                  children: items
                      .map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RequestListTile(request: r)))
                      .toList());
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _GeneratorMapTab extends StatefulWidget {
  const _GeneratorMapTab();

  @override
  State<_GeneratorMapTab> createState() => _GeneratorMapTabState();
}

class _GeneratorMapTabState extends State<_GeneratorMapTab> {
  static const LatLng _douala = LatLng(4.0511, 9.7679);

  final _searchCtrl = TextEditingController();
  final _maps = MapsService();

  LatLng _center = _douala;
  double _zoom = 12;
  LatLng? _myLocation;
  LatLng? _destination;
  String? _destinationLabel;
  List<MapPlaceSuggestion> _suggestions = const [];
  List<LatLng> _route = const [];
  int? _routeDistanceMeters;
  int? _routeDurationSec;
  bool _locating = false;
  bool _routing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLocationAndCenter() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(context.l10n.collectorEnableLocation)));
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.l10n.collectorLocationPermissionDenied)));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final here = LatLng(pos.latitude, pos.longitude);
      _myLocation = here;
      _center = here;
      _zoom = 14;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Map locate failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppErrorHandler.toUserMessage(context, e))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _updateSuggestions(String text) async {
    if (!_maps.isConfigured) {
      setState(() => _suggestions = const []);
      return;
    }
    final bias = _myLocation;
    final results = await _maps.autocomplete(input: text, locationBias: bias);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.collectorAddressNotFound)));
      return;
    }
    setState(() {
      _destination = latLng;
      _center = latLng;
      _zoom = 14;
    });

    // Try routing if we have origin.
    if (_myLocation != null) {
      await _buildRoute();
    }
  }

  Future<void> _buildRoute() async {
    final origin = _myLocation;
    final dest = _destination;
    if (origin == null || dest == null) return;
    if (_routing) return;
    if (!_maps.isRoutingConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.collectorRoutingNotConfiguredNote)));
      return;
    }
    setState(() => _routing = true);
    try {
      final dir = await _maps.directions(origin: origin, destination: dest);
      if (!mounted) return;
      if (dir == null || dir.polylinePoints.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.collectorRouteUnavailable)));
        return;
      }
      setState(() {
        _route = dir.polylinePoints;
        _routeDistanceMeters = dir.distanceMeters;
        _routeDurationSec = dir.durationSec;
        _center = LatLng((origin.latitude + dest.latitude) / 2, (origin.longitude + dest.longitude) / 2);
        _zoom = 12;
      });
    } catch (e) {
      debugPrint('Route build failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppErrorHandler.toUserMessage(context, e))));
    } finally {
      if (mounted) setState(() => _routing = false);
    }
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
    return '$meters m';
  }

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
        Text(context.l10n.collectorNavMap,
            style: context.textStyles.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: LightModeColors.lightSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: LightModeColors.lightSurfaceVariant)),
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
                        hintText: context.l10n.generatorAddressSearchHint,
                        prefixIcon: Icon(Icons.search,
                            color: LightModeColors.lightPrimary),
                        suffixIcon: _searchCtrl.text.trim().isEmpty
                            ? null
                            : IconButton(
                                tooltip: context.l10n.commonClear,
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
                    icon: _locating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.my_location),
                    label: Text(context.l10n.collectorMyLocationButton),
                  ),
                ],
              ),
              if (!_maps.isRoutingConfigured)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    context.l10n.collectorRoutingNotConfiguredNote,
                    style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ),
              if (_suggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    decoration: BoxDecoration(
                        color: LightModeColors.lightSurfaceVariant
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Column(
                      children: _suggestions
                          .map(
                            (s) => ListTile(
                              dense: true,
                              leading: Icon(Icons.place_outlined,
                                  color: LightModeColors.lightPrimary),
                              title: Text(s.description,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
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
                      if (_myLocation != null)
                        Chip(
                          avatar: Icon(Icons.person_pin_circle,
                              color: LightModeColors.lightPrimary),
                          label: Text(context.l10n.collectorMyPositionChip),
                        ),
                      if (_destinationLabel != null)
                        Chip(
                          avatar: Icon(Icons.flag_outlined,
                              color: LightModeColors.lightSecondary),
                          label: Text(_destinationLabel!,
                              overflow: TextOverflow.ellipsis),
                        ),
                      if (_myLocation != null && _destination != null)
                        ActionChip(
                          avatar: _routing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.alt_route,
                                  color: LightModeColors.lightPrimary),
                          label: Text(_routing ? context.l10n.collectorCalculating : context.l10n.collectorRouteChipLabel),
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
                          decoration: BoxDecoration(
                              color: LightModeColors.lightPrimaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          child: Row(
                            children: [
                              Icon(Icons.straighten,
                                  color: LightModeColors.lightPrimary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _routeDistanceMeters == null
                                      ? '—'
                                      : _formatDistance(_routeDistanceMeters!),
                                  style: context.textStyles.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: LightModeColors.lightSurfaceVariant
                                  .withValues(alpha: 0.35),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md)),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  color: LightModeColors.lightSecondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _routeDurationSec == null
                                      ? '—'
                                      : _formatDuration(_routeDurationSec!),
                                  style: context.textStyles.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder(
          future: WasteRequestService().listForCurrentGenerator(),
          builder: (context, snap) {
            final items = snap.data ?? const <WasteRequest>[];
            final myLoc = _myLocation;
            final dest = _destination;
            final route = _route;

            final mapMarkers = <MapPin>[];
            for (final r in items) {
              final addr = r.address;
              if (addr == null) continue;
              final latRaw = addr['latitude'];
              final lngRaw = addr['longitude'];
              if (latRaw is! num || lngRaw is! num) continue;
              mapMarkers.add(MapPin(
                point: LatLng(latRaw.toDouble(), lngRaw.toDouble()),
                color: LightModeColors.lightPrimary,
              ));
            }
            if (myLoc != null) {
              mapMarkers.add(MapPin(point: myLoc, color: LightModeColors.lightPrimaryContainer, radius: 9));
            }
            if (dest != null) {
              mapMarkers.add(MapPin(point: dest, color: LightModeColors.lightSecondary, radius: 9));
            }

            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: SizedBox(
                height: 240,
                child: CleanCityMapView(
                  center: _center,
                  zoom: _zoom,
                  markers: mapMarkers,
                  route: route,
                  onTap: (p) {
                    for (final r in items) {
                      final addr = r.address;
                      final latRaw = addr?['latitude'];
                      final lngRaw = addr?['longitude'];
                      if (latRaw is! num || lngRaw is! num) continue;
                      final d = const Distance().as(LengthUnit.Meter, p, LatLng(latRaw.toDouble(), lngRaw.toDouble()));
                      if (d < 250) {
                        context.push(AppRoutes.requestDetails, extra: r.id);
                        return;
                      }
                    }
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
            context.l10n.generatorMapHint,
            style: context.textStyles.bodySmall
                ?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
        const SizedBox(height: 16),
        FutureBuilder(
          future: WasteRequestService().listForCurrentGenerator(),
          builder: (context, snap) {
            final items = snap.data ?? const <WasteRequest>[];
            if (items.isEmpty) {
              return _EmptyStateCard(
                  icon: Icons.place_outlined,
                  title: context.l10n.generatorNoPinsTitle,
                  subtitle: context.l10n.generatorNoPinsSubtitle);
            }
            return Column(
              children: items.where((e) => e.address != null).take(10).map((r) {
                final addr = r.address!;
                final city = (addr['city'] ?? '') as String;
                final hood = (addr['neighborhood'] ?? '') as String;
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md)),
                  tileColor: LightModeColors.lightSurface,
                  leading: const CircleAvatar(
                      backgroundColor: LightModeColors.lightPrimaryContainer,
                      child: Icon(Icons.place,
                          color: LightModeColors.lightPrimary)),
                  title: Text([hood, city]
                          .where((s) => s.trim().isNotEmpty)
                          .join(' • ')
                          .trim()
                          .isEmpty
                      ? context.l10n.generatorAddressFallback
                      : [hood, city]
                          .where((s) => s.trim().isNotEmpty)
                          .join(' • ')),
                  subtitle: Text(
                      context.l10n.generatorStatusWeightLine(r.status, r.quantityEstimateKg.toStringAsFixed(0)),
                      style: context.textStyles.bodySmall?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant)),
                  trailing: IconButton(
                    tooltip: context.l10n.collectorRouteChipLabel,
                    onPressed: () async {
                      final addr = r.address;
                      if (addr == null) return;
                      final latRaw = addr['latitude'];
                      final lngRaw = addr['longitude'];
                      if (latRaw is! num || lngRaw is! num) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                context.l10n.generatorMissingCoordinatesForAddress)));
                        return;
                      }
                      setState(() {
                        _destination =
                            LatLng(latRaw.toDouble(), lngRaw.toDouble());
                        _center = _destination!;
                        _zoom = 14;
                        _destinationLabel = [hood, city]
                            .where((s) => s.trim().isNotEmpty)
                            .join(' • ');
                        _route = const [];
                        _routeDistanceMeters = null;
                        _routeDurationSec = null;
                      });
                      if (_myLocation == null) await _ensureLocationAndCenter();
                      await _buildRoute();
                    },
                    icon: Icon(Icons.alt_route,
                        color: LightModeColors.lightPrimary),
                  ),
                  onTap: () =>
                      context.push(AppRoutes.requestDetails, extra: r.id),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: LightModeColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: LightModeColors.lightSurfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: LightModeColors.lightPrimary, size: 24),
          const SizedBox(height: 12),
          Text(label,
              style: context.textStyles.labelMedium
                  ?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
          const SizedBox(height: 4),
          Text(value,
              style: context.textStyles.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _RequestListTile extends StatelessWidget {
  const _RequestListTile({required this.request});
  final WasteRequest request;

  String _formatSchedule() {
    final d = request.scheduledAt;
    final slot = (request.timeSlot ?? '').trim();
    if (d == null && slot.isEmpty) return '';
    final dateStr = d == null
        ? ''
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    if (dateStr.isEmpty) return slot;
    if (slot.isEmpty) return dateStr;
    return '$dateStr • $slot';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return LightModeColors.lightSecondary;
      case 'accepted':
      case 'en_route':
        return Colors.blue;
      case 'collected':
      case 'delivered':
        return LightModeColors.lightPrimary;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(request.status);
    final addr = request.address;
    final title = addr == null
        ? context.l10n.generatorRequestIdFallback(request.id.substring(0, 6))
        : [addr['neighborhood'], addr['city']]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' • ');

    final schedule = _formatSchedule();

    return InkWell(
      onTap: () => context.push(AppRoutes.requestDetails, extra: request.id),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
            color: LightModeColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: LightModeColors.lightSurfaceVariant)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: LightModeColors.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(Icons.recycling,
                  color: LightModeColors.lightPrimary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.isEmpty ? context.l10n.generatorRequestFallback : title,
                      style: context.textStyles.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${request.wasteType} • ${request.quantityEstimateKg.toStringAsFixed(0)} kg',
                      if (schedule.isNotEmpty) '⏱ $schedule',
                    ].join('  •  '),
                    style: context.textStyles.labelSmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Text(request.status.toUpperCase(),
                  style: context.textStyles.labelSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingLg,
      decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: LightModeColors.lightSurfaceVariant)),
      child: Row(
        children: [
          CircleAvatar(
              backgroundColor: LightModeColors.lightPrimaryContainer,
              child: Icon(icon, color: LightModeColors.lightPrimary)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.textStyles.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- CREATE REQUEST SCREEN ---
class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  static const LatLng _createRequestDoualaFallback = LatLng(4.0511, 9.7679);

  double _weight = 15;
  String _selectedType = 'plastic';

  DateTime? _scheduledDate;
  String? _timeSlot;
  double? _latitude;
  double? _longitude;
  bool _locating = false;

  final _notesCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Douala');
  final _neighborhoodCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  final List<XFile> _photos = [];
  bool _publishing = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    _cityCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    try {
      final picked =
          await picker.pickMultiImage(imageQuality: 85, maxWidth: 1600);
      if (!mounted) return;
      if (picked.isEmpty) return;
      setState(() => _photos.addAll(picked));
    } catch (e) {
      debugPrint('Pick photos failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.generatorCannotPickPhotos);
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickImage(
          source: ImageSource.camera, imageQuality: 85, maxWidth: 1600);
      if (picked == null) return;
      if (!mounted) return;
      setState(() => _photos.add(picked));
    } catch (e) {
      debugPrint('Take photo failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.generatorCannotTakePhoto);
    }
  }

  Future<void> _publish() async {
    if (_publishing) return;
    if (_latitude == null || _longitude == null) {
      AppSnackbars.warning(
        context,
        context.l10n.generatorGpsRequiredNotice,
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      final scheduledAt = _scheduledDate == null
          ? null
          : _combineDateAndSlot(_scheduledDate!, _timeSlot);
      final req = await WasteRequestService().create(
        wasteType: _selectedType,
        quantityEstimateKg: _weight,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        scheduledAt: scheduledAt,
        timeSlot: _timeSlot,
        city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
        neighborhood: _neighborhoodCtrl.text.trim().isEmpty
            ? null
            : _neighborhoodCtrl.text.trim(),
        details:
            _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );

      var photoFailures = 0;
      if (_photos.isNotEmpty) {
        final uploader = MediaUploadService();
        final service = WasteRequestService();
        for (final p in _photos) {
          try {
            final url = await uploader.uploadWasteRequestPhoto(
                requestId: req.id, file: p);
            await service.addPhotoUrl(requestId: req.id, url: url);
          } catch (e) {
            // The request itself is already published; a photo failure
            // shouldn't block that or lose the remaining photos.
            debugPrint('Publish request photo upload failed: $e');
            photoFailures++;
          }
        }
      }

      if (!mounted) return;
      if (photoFailures > 0) {
        AppSnackbars.warning(
            context,
            context.l10n
                .generatorRequestPublishedPhotosFailed(photoFailures, _photos.length));
      } else {
        AppSnackbars.success(context, context.l10n.generatorRequestPublished);
      }
      context.pop();
    } catch (e) {
      debugPrint('Publish request failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  static DateTime _combineDateAndSlot(DateTime date, String? slot) {
    final s = (slot ?? '').trim();
    final start = s.split('-').first.trim();
    final parts = start.split(':');
    final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
    final m = parts.length >= 2 ? int.tryParse(parts[1]) : 0;
    if (h == null) return DateTime(date.year, date.month, date.day, 9, 0);
    return DateTime(date.year, date.month, date.day, h, m ?? 0);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() => _scheduledDate = picked);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.collectorLocationPermissionDenied)));
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (e) {
      debugPrint('Use my location failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(AppErrorHandler.toUserMessage(context, e))));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.generatorCreateRequestTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Chip(
              label: const Text('CLEANCITY CMR',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              backgroundColor: LightModeColors.lightPrimary,
              labelStyle: const TextStyle(color: Colors.white),
              padding: EdgeInsets.zero,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1', context.l10n.generatorSectionWasteType),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildWasteType('plastic', context.l10n.generatorWastePlastic, Icons.local_drink),
                _buildWasteType('paper', context.l10n.generatorWasteCardboard, Icons.inventory_2_outlined),
                _buildWasteType('metal', context.l10n.generatorWasteMetal, Icons.build_outlined),
                _buildWasteType('organic', context.l10n.generatorWasteOil, Icons.water_drop_outlined),
                _buildWasteType('mixed', context.l10n.generatorWasteHousehold, Icons.delete_outline),
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('2', context.l10n.generatorSectionQuantity),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(context.l10n.generatorWeightLight),
                Expanded(
                  child: Slider(
                    value: _weight,
                    min: 1,
                    max: 100,
                    activeColor: LightModeColors.lightPrimary,
                    onChanged: (v) => setState(() => _weight = v),
                  ),
                ),
                Text(context.l10n.generatorWeightHeavy),
              ],
            ),
            Center(
                child: Text('${_weight.toInt()} kg',
                    style: context.textStyles.headlineMedium?.copyWith(
                        color: LightModeColors.lightPrimary,
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 32),
            _buildSectionTitle('3', context.l10n.generatorSectionDateSlot),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: LightModeColors.lightSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: LightModeColors.lightSurfaceVariant)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          _scheduledDate == null
                              ? context.l10n.generatorChooseDate
                              : '${_scheduledDate!.day.toString().padLeft(2, '0')}/${_scheduledDate!.month.toString().padLeft(2, '0')}/${_scheduledDate!.year}',
                          style: context.textStyles.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(context.l10n.generatorDateButton)),
                    ]),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _timeSlot,
                      decoration: InputDecoration(
                          labelText: context.l10n.generatorTimeSlotLabel),
                      items: const [
                        DropdownMenuItem(
                            value: '08:00-10:00', child: Text('08:00 – 10:00')),
                        DropdownMenuItem(
                            value: '10:00-12:00', child: Text('10:00 – 12:00')),
                        DropdownMenuItem(
                            value: '12:00-14:00', child: Text('12:00 – 14:00')),
                        DropdownMenuItem(
                            value: '14:00-16:00', child: Text('14:00 – 16:00')),
                        DropdownMenuItem(
                            value: '16:00-18:00', child: Text('16:00 – 18:00')),
                      ],
                      onChanged: (v) => setState(() => _timeSlot = v),
                    ),
                  ]),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('4', context.l10n.generatorSectionLocation),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: LightModeColors.lightPrimaryContainer
                      .withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border:
                      Border.all(color: LightModeColors.lightPrimaryContainer)),
              child: Row(children: [
                const Icon(Icons.my_location,
                    color: LightModeColors.lightPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _latitude == null || _longitude == null
                        ? context.l10n.generatorNoCoordinatesRecorded
                        : context.l10n.generatorGpsCoordinates(_latitude!.toStringAsFixed(5), _longitude!.toStringAsFixed(5)),
                    style: context.textStyles.bodySmall?.copyWith(
                        color: LightModeColors.lightOnSurfaceVariant),
                  ),
                ),
                TextButton(
                  onPressed: _locating ? null : _useMyLocation,
                  child: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(context.l10n.collectorMyLocationButton),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                height: 150,
                child: CleanCityMapView(
                  center: _latitude != null && _longitude != null
                      ? LatLng(_latitude!, _longitude!)
                      : _createRequestDoualaFallback,
                  zoom: _latitude != null && _longitude != null ? 15 : 12,
                  markers: _latitude != null && _longitude != null
                      ? [MapPin(point: LatLng(_latitude!, _longitude!), color: LightModeColors.lightPrimary, radius: 9)]
                      : const [],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.business),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                          controller: _neighborhoodCtrl,
                          decoration: InputDecoration(labelText: context.l10n.generatorNeighborhoodLabel)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _cityCtrl,
                          decoration: InputDecoration(labelText: context.l10n.authCityLabel)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _detailsCtrl,
                          decoration: InputDecoration(
                              labelText: context.l10n.generatorDetailsLabel)),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('5', context.l10n.generatorSectionPhotos),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LightModeColors.lightPrimaryContainer
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: LightModeColors.lightPrimary, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(context.l10n.generatorAddPhotosLabel,
                              style: context.textStyles.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.lightPrimary))),
                      IconButton(
                          onPressed: _pickPhotos,
                          icon: Icon(Icons.photo_library,
                              color: LightModeColors.lightPrimary)),
                      IconButton(
                          onPressed: _takePhoto,
                          icon: Icon(Icons.photo_camera,
                              color: LightModeColors.lightPrimary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_photos.isEmpty)
                    Text(
                        context.l10n.generatorPhotosHint,
                        style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant))
                  else
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final p = _photos[i];
                          return Stack(
                            children: [
                              PickedImageThumb(
                                  file: p, size: 84, borderRadius: 14),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: IconButton(
                                  onPressed: () =>
                                      setState(() => _photos.removeAt(i)),
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Colors.red),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionTitle('6', context.l10n.generatorSectionNotes),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                  hintText: context.l10n.generatorNotesHint),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _publishing ? null : _publish,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_publishing ? context.l10n.generatorPublishing : context.l10n.generatorPublishButton),
                  const SizedBox(width: 8),
                  Icon(_publishing ? Icons.hourglass_top : Icons.send)
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.generatorTermsNotice,
              style:
                  context.textStyles.labelSmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String number, String title) {
    return Row(
      children: [
        CircleAvatar(
            radius: 12,
            backgroundColor: LightModeColors.lightPrimary,
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildWasteType(String code, String label, IconData icon) {
    final isSelected = _selectedType == code;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? LightModeColors.lightPrimary : Colors.grey),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (v) => setState(() => _selectedType = code),
      selectedColor: LightModeColors.lightPrimaryContainer,
      backgroundColor: LightModeColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: isSelected
                ? LightModeColors.lightPrimary
                : Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}

class PickedImageThumb extends StatelessWidget {
  const PickedImageThumb(
      {super.key,
      required this.file,
      required this.size,
      required this.borderRadius});

  final XFile file;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: FutureBuilder(
        future: file.readAsBytes(),
        builder: (context, snap) {
          final bytes = snap.data;
          if (bytes == null) {
            return Container(
                width: size,
                height: size,
                color: LightModeColors.lightSurfaceVariant,
                child: const Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))));
          }
          return Image.memory(bytes,
              width: size, height: size, fit: BoxFit.cover);
        },
      ),
    );
  }
}

class _RequestPickupMap extends StatelessWidget {
  const _RequestPickupMap({required this.address});
  final Map<String, dynamic>? address;

  static const LatLng _douala = LatLng(4.0511, 9.7679);

  @override
  Widget build(BuildContext context) {
    final latRaw = address?['latitude'];
    final lngRaw = address?['longitude'];
    final hasCoords = latRaw is num && lngRaw is num;
    final center =
        hasCoords ? LatLng(latRaw.toDouble(), lngRaw.toDouble()) : _douala;

    final markers = <MapPin>[
      if (hasCoords) MapPin(point: center, color: LightModeColors.lightPrimary, radius: 9),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: CleanCityMapView(
          center: center,
          zoom: hasCoords ? 15 : 12,
          markers: markers,
        ),
      ),
    );
  }
}

// --- REQUEST DETAILS SCREEN ---
class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, this.requestId});

  final String? requestId;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  late final String? _id;
  late Future<WasteRequest?> _requestFuture;
  late Future<List<String>> _photosFuture;
  late Future<Map<String, String>?> _collectorContactFuture;
  bool _addingPhoto = false;

  @override
  void initState() {
    super.initState();
    _id = widget.requestId;
    _requestFuture = _id == null
        ? Future<WasteRequest?>.value(null)
        : WasteRequestService().getById(_id);
    _photosFuture = _id == null
        ? Future.value(const <String>[])
        : WasteRequestService().listPhotoUrls(_id);
    _collectorContactFuture = _id == null
        ? Future<Map<String, String>?>.value(null)
        : _loadCollectorContact(_id);
  }

  Future<Map<String, String>?> _loadCollectorContact(String requestId) async {
    try {
      final client = Supabase.instance.client;
      final pickup = await client
          .from('pickups')
          .select('collector_id')
          .eq('request_id', requestId)
          .maybeSingle();
      final collectorId = (pickup?['collector_id'] ?? '').toString().trim();
      if (collectorId.isEmpty) return null;
      final profile = await AppUserService().getProfile(collectorId);
      final name = (profile?.fullName ?? '').trim();
      return {'id': collectorId, 'name': name};
    } catch (e) {
      debugPrint('Load collector contact failed: $e');
      return null;
    }
  }

  Future<void> _refreshPhotos() async {
    final id = _id;
    if (id == null) return;
    setState(() => _photosFuture = WasteRequestService().listPhotoUrls(id));
  }

  Future<void> _addPhoto() async {
    final id = _id;
    if (id == null || _addingPhoto) return;
    setState(() => _addingPhoto = true);
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 1800);
      if (picked == null) return;
      final url = await MediaUploadService()
          .uploadWasteRequestPhoto(requestId: id, file: picked);
      await WasteRequestService().addPhotoUrl(requestId: id, url: url);
      await _refreshPhotos();
      if (!mounted) return;
      AppSnackbars.success(context, context.l10n.generatorPhotoAdded);
    } on StorageException catch (e) {
      debugPrint('Add photo storage failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    } on MediaUploadException catch (e) {
      debugPrint('Add photo upload blocked: $e');
      if (!mounted) return;
      AppSnackbars.warning(context, AppErrorHandler.toUserMessage(context, e));
    } catch (e) {
      debugPrint('Add photo failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveId = _id;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.generatorRequestDetailsTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: context.l10n.chatTitle,
            onPressed: effectiveId == null
                ? null
                : () async {
                    try {
                      final threadId = await ChatService()
                          .getOrCreateThreadForRequest(requestId: effectiveId);
                      if (!context.mounted) return;
                      context.push(ChatRoutes.room, extra: {
                        'threadId': threadId,
                        'requestId': effectiveId
                      });
                    } catch (e) {
                      debugPrint('Open chat failed: $e');
                      if (!context.mounted) return;
                      AppSnackbars.error(
                          context, AppErrorHandler.toUserMessage(context, e));
                    }
                  },
            icon: const Icon(Icons.forum_outlined),
          ),
          IconButton(
            tooltip: context.l10n.generatorAddPhotoTooltip,
            onPressed: _addingPhoto ? null : _addPhoto,
            icon: _addingPhoto
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_a_photo),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _requestFuture,
        builder: (context, snap) {
          final r = snap.data;
          final ref = effectiveId == null
              ? '—'
              : '#${effectiveId.substring(0, 8).toUpperCase()}';
          final status = r?.status ?? 'pending';
          final statusText = status.toUpperCase();

          Color chipBg;
          Color chipFg;
          switch (status) {
            case 'pending':
              chipBg = Colors.blue.shade50;
              chipFg = Colors.blue.shade700;
              break;
            case 'accepted':
            case 'en_route':
              chipBg = Colors.orange.shade50;
              chipFg = Colors.orange.shade800;
              break;
            case 'collected':
            case 'delivered':
              chipBg = Colors.green.shade50;
              chipFg = Colors.green.shade800;
              break;
            case 'cancelled':
              chipBg = Colors.red.shade50;
              chipFg = Colors.red.shade700;
              break;
            default:
              chipBg = Colors.grey.shade200;
              chipFg = Colors.grey.shade700;
          }

          return SingleChildScrollView(
            padding: AppSpacing.paddingLg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: chipBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle, color: chipFg)),
                      const SizedBox(width: 8),
                      Text('STATUT: $statusText',
                          style: context.textStyles.labelSmall?.copyWith(
                              color: chipFg, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      Text(ref,
                          style: context.textStyles.labelSmall?.copyWith(
                              color: chipFg, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder(
                  future: _collectorContactFuture,
                  builder: (context, contactSnap) {
                    final contact = contactSnap.data;
                    final collectorId =
                        (contact?['id'] ?? '').toString().trim();
                    final collectorName =
                        (contact?['name'] ?? '').toString().trim();
                    if (collectorId.isEmpty) return const SizedBox.shrink();
                    return SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            // Chat lié à la demande: conserve l'historique de la demande.
                            final id = effectiveId;
                            if (id == null || id.trim().isEmpty) {
                              AppSnackbars.warning(context,
                                  context.l10n.generatorRequestNotFoundForChat);
                              return;
                            }
                            final threadId = await ChatService()
                                .getOrCreateThreadForRequest(requestId: id);
                            if (!context.mounted) return;
                            context.push(ChatRoutes.room,
                                extra: {'threadId': threadId, 'requestId': id});
                          } catch (e) {
                            debugPrint(
                                'Open request chat (generator→collector) failed: $e');
                            if (!context.mounted) return;
                            AppSnackbars.error(
                                context, context.l10n.errorCannotOpenChat);
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(collectorName.isEmpty
                            ? context.l10n.centerContactCollectorGeneric
                            : context.l10n.centerContactNamed(collectorName)),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Text(context.l10n.generatorPhotosTitle,
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                FutureBuilder(
                  future: _photosFuture,
                  builder: (context, photosSnap) {
                    final photos = photosSnap.data ?? const <String>[];
                    if (photosSnap.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    if (photos.isEmpty) {
                      return Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                            color: LightModeColors.lightSurface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                                color: LightModeColors.lightSurfaceVariant)),
                        child: Row(
                          children: [
                            const CircleAvatar(
                                backgroundColor:
                                    LightModeColors.lightPrimaryContainer,
                                child: Icon(Icons.image_outlined,
                                    color: LightModeColors.lightPrimary)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    context.l10n.generatorNoPhotosHint,
                                    style: context.textStyles.bodySmall
                                        ?.copyWith(
                                            color: LightModeColors
                                                .lightOnSurfaceVariant))),
                          ],
                        ),
                      );
                    }
                    return SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final url = photos[i];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(url,
                                width: 160, height: 120, fit: BoxFit.cover),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.generatorReferenceCaps,
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                                fontWeight: FontWeight.bold)),
                        Text(ref,
                            style: context.textStyles.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(statusText,
                          style: TextStyle(
                              color: chipFg,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                if (snap.connectionState == ConnectionState.waiting)
                  const LinearProgressIndicator(),
                if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(AppErrorHandler.toUserMessage(context, snap.error ?? Exception('unknown')),
                        style: const TextStyle(color: Colors.red)),
                  ),

                // Timeline mockup
                _buildTimelineItem(
                    context.l10n.generatorTimelineReceivedTitle, context.l10n.generatorTimelineReceivedSubtitle,
                    isPast: true),
                _buildTimelineItem(
                    context.l10n.generatorTimelineAcceptedTitle, context.l10n.generatorTimelineAcceptedSubtitle,
                    isActive: true),
                _buildTimelineItem(
                    context.l10n.generatorTimelineInDeliveryTitle, context.l10n.generatorTimelineInDeliverySubtitle),
                _buildTimelineItem(context.l10n.generatorTimelineDoneTitle, context.l10n.generatorTimelineDoneSubtitle,
                    isLast: true),

                const SizedBox(height: 32),
                Text(context.l10n.generatorAssignedCollectorTitle,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(
                              'https://i.pravatar.cc/100')), // Placeholder
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Moussa Ibrahim',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text('Camion Compacteur • LT-192-AB',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                              icon: const Icon(Icons.call, color: Colors.green),
                              onPressed: () {},
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.green.shade50)),
                          IconButton(
                              icon:
                                  const Icon(Icons.message, color: Colors.blue),
                              onPressed: () {},
                              style: IconButton.styleFrom(
                                  backgroundColor: Colors.blue.shade50)),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(context.l10n.generatorCollectorLocationTitle,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12)),
                  child: Stack(
                    children: [
                      Center(
                          child: Icon(Icons.map,
                              size: 48, color: Colors.grey.shade400)),
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: Colors.black12, blurRadius: 4)
                              ]),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(context.l10n.generatorEtaFixed,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12)),
                              const Text('2.4 km',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                Text(context.l10n.generatorWasteSummaryTitle,
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Container(
                  padding: AppSpacing.paddingMd,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildSummaryRow(Icons.local_drink, Colors.orange,
                          context.l10n.generatorSummaryPlasticPetTitle, context.l10n.generatorSummaryPlasticPetDesc, '~15 kg'),
                      const Divider(height: 24),
                      _buildSummaryRow(Icons.description, Colors.blue,
                          context.l10n.generatorSummaryPaperCardboardTitle, context.l10n.generatorSummaryPaperCardboardDesc, '~5 kg'),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.l10n.generatorTotalEstimated,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('2.500 CFA',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: LightModeColors.lightPrimary,
                                  fontSize: 16)),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: effectiveId == null
                        ? () => context.pop()
                        : () async {
                            try {
                              await WasteRequestService().cancel(effectiveId);
                              if (!context.mounted) return;
                              AppSnackbars.success(context, context.l10n.generatorRequestCancelled);
                              context.pop();
                            } catch (e) {
                              debugPrint('Cancel request failed: $e');
                              if (!context.mounted) return;
                              AppSnackbars.error(
                                  context, context.l10n.generatorCancellationFailed);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: Text(context.l10n.generatorCancelRequestButton),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem(String title, String subtitle,
      {bool isPast = false, bool isActive = false, bool isLast = false}) {
    Color color = isPast || isActive
        ? LightModeColors.lightPrimary
        : Colors.grey.shade300;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive ? color : Colors.transparent,
                border: Border.all(color: color, width: 2),
              ),
              child: isPast
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast) Container(width: 2, height: 40, color: color),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.black : Colors.grey,
                    fontSize: 12)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        )
      ],
    );
  }

  Widget _buildSummaryRow(
      IconData icon, Color color, String title, String desc, String weight) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(desc,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        Text(weight, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
