import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/components/user_profile_tab.dart';
import 'package:cleancity/chat/chat_screens.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/center_stats_service.dart';
import 'package:cleancity/services/chat_service.dart';
import 'package:cleancity/services/waste_request_service.dart';
import 'package:cleancity/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- CENTER DASHBOARD ---
class CenterDashboard extends StatefulWidget {
  const CenterDashboard({super.key});

  @override
  State<CenterDashboard> createState() => _CenterDashboardState();
}

class _CenterDashboardState extends State<CenterDashboard> {
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
      const _CenterMainTab(),
      const _CenterDeliveriesTab(),
      const _CenterStocksTab(),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: LightModeColors.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.factory_outlined,
                  color: LightModeColors.lightPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            FutureBuilder(
              future: AppUserService().getCurrentProfile(),
              builder: (context, snap) {
                final name = (snap.data?.fullName?.trim().isNotEmpty ?? false)
                    ? snap.data!.fullName!.trim()
                    : context.l10n.centerDefaultName;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: context.textStyles.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text(context.l10n.authAppBarTitle,
                        style: context.textStyles.labelSmall
                            ?.copyWith(color: LightModeColors.lightPrimary)),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined), label: context.l10n.adminNavDashboard),
          BottomNavigationBarItem(
              icon: const Icon(Icons.local_shipping_outlined), label: context.l10n.centerNavDeliveries),
          BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2_outlined), label: context.l10n.centerNavStocks),
          BottomNavigationBarItem(
              icon: const Icon(Icons.forum_outlined), label: context.l10n.chatTitle),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline), label: context.l10n.profileTitle),
        ],
      ),
    );
  }

}

class _CenterMainTab extends StatefulWidget {
  const _CenterMainTab();

  @override
  State<_CenterMainTab> createState() => _CenterMainTabState();
}

class _CenterMainTabState extends State<_CenterMainTab> {
  final CenterStatsService _statsService = CenterStatsService();

  late Future<CenterDashboardStats> _statsFuture;
  late Future<List<CenterExpectedDelivery>> _deliveriesFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _statsFuture = _statsService.getDashboardStats();
      _deliveriesFuture = _statsService.getExpectedDeliveries();
    });
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'plastic':
        return Colors.blue;
      case 'organic':
        return Colors.orange;
      case 'glass':
        return Colors.teal;
      case 'paper':
        return Colors.brown;
      case 'metal':
        return Colors.grey;
      case 'ewaste':
        return Colors.purple;
      default:
        return Colors.green;
    }
  }

  String _changeSubtitle(double? percent) {
    if (percent == null) return context.l10n.adminStatNotEnoughData;
    final sign = percent >= 0 ? '+' : '';
    return context.l10n.adminStatVsLastMonth('$sign${percent.toStringAsFixed(1)}%');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.paddingLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.receptionForm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner),
                    const SizedBox(width: 8),
                    Text(context.l10n.centerQuickReception)
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.centerMonthlySummary,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                    onPressed: _refresh,
                    icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<CenterDashboardStats>(
              future: _statsFuture,
              builder: (context, snap) {
                final stats = snap.data;
                final loading = snap.connectionState == ConnectionState.waiting;
                return Row(
                  children: [
                    Expanded(
                        child: _SummaryCard(
                            icon: Icons.scale,
                            title: context.l10n.centerTotalVolumeProcessed,
                            value: loading || stats == null ? '—' : '${stats.processedKg.toStringAsFixed(1)} kg',
                            change: loading || stats == null ? null : _changeSubtitle(stats.processedKgChangePercent))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _SummaryCard(
                            icon: Icons.recycling,
                            title: context.l10n.centerRecoveryRate,
                            value: loading || stats == null || stats.recoveryRatePercent == null
                                ? '—'
                                : '${stats.recoveryRatePercent!.toStringAsFixed(0)}%',
                            change: null)),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            Text(context.l10n.centerExpectedDeliveries,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            FutureBuilder<List<CenterExpectedDelivery>>(
              future: _deliveriesFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }
                if (snap.hasError) {
                  return Text(context.l10n.centerDeliveriesLoadFailed,
                      style: const TextStyle(color: Colors.red));
                }
                final deliveries = snap.data ?? const <CenterExpectedDelivery>[];
                if (deliveries.isEmpty) {
                  return _CenterEmptyStateCard(
                      icon: Icons.local_shipping_outlined,
                      title: context.l10n.centerNoDeliveriesTitle,
                      subtitle: context.l10n.centerNoDeliveriesSubtitle);
                }
                return Column(
                  children: deliveries.map((d) {
                    final location = [d.neighborhood, d.city]
                        .where((s) => s.trim().isNotEmpty)
                        .join(', ');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push(AppRoutes.receptionForm, extra: d.requestId),
                        child: _DeliveryCard(
                          truck: d.requestId.isEmpty
                              ? '—'
                              : 'REQ-${d.requestId.substring(0, 6).toUpperCase()}',
                          type: d.wasteType.toUpperCase(),
                          status:
                              '${_statusLabel(context, d.status)} • ${d.quantityEstimateKg.toStringAsFixed(1)} kg${location.isEmpty ? '' : ' • $location'}',
                          time: context.l10n.commonOpen,
                          color: _colorForType(d.wasteType),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 32),
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.centerStockCapacity,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 12),
                  FutureBuilder<CenterDashboardStats>(
                    future: _statsFuture,
                    builder: (context, snap) {
                      final stats = snap.data;
                      final loading = snap.connectionState == ConnectionState.waiting;
                      if (loading || stats == null) {
                        return const Text('—',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20));
                      }

                      final ratio = stats.capacityFillRatio;
                      if (ratio == null) {
                        // No capacity configured yet: show the raw pending
                        // volume instead of a fabricated percentage.
                        final text = stats.pendingSortingCount == 0
                            ? context.l10n.centerNoPendingSorting
                            : context.l10n.centerPendingSortingValue(
                                stats.pendingSortingKg.toStringAsFixed(1),
                                stats.pendingSortingCount);
                        return Text(text,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20));
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${(ratio * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20)),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                              value: ratio,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  LightModeColors.lightPrimary)),
                          const SizedBox(height: 4),
                          Text(
                              '${stats.pendingSortingKg.toStringAsFixed(1)} / ${stats.capacityKg!.toStringAsFixed(0)} kg',
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.centerSortingZoneTracking,
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class _CenterDeliveriesTab extends StatefulWidget {
  const _CenterDeliveriesTab();

  @override
  State<_CenterDeliveriesTab> createState() => _CenterDeliveriesTabState();
}

class _CenterDeliveriesTabState extends State<_CenterDeliveriesTab> {
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

      // Preferred: show deliveries assigned to THIS center via pickups.center_id.
      // If schema doesn't have that column yet, we fall back to the legacy query.
      try {
        final rows = await client
            .from('pickups')
            .select(
                'id, request_id, collected_at, delivered_at, center_id, waste_requests(id, waste_type, status, created_at, quantity_estimate_kg, addresses(city, neighborhood))')
            .eq('center_id', uid)
            .order('delivered_at', ascending: false)
            .limit(50);

        final mapped = (rows as List)
            .map((e) {
              final m = Map<String, dynamic>.from(e as Map);
              final wr = m['waste_requests'];
              if (wr is Map) return Map<String, dynamic>.from(wr);
              return <String, dynamic>{};
            })
            .where((e) => (e['id'] ?? '').toString().trim().isNotEmpty)
            .toList();

        return mapped;
      } catch (e) {
        debugPrint(
            'Center deliveries preferred query failed (fallback to legacy): $e');
      }

      final rows = await client
          .from('waste_requests')
          .select(
              'id, waste_type, status, created_at, quantity_estimate_kg, addresses(city, neighborhood)')
          .inFilter('status', ['accepted', 'collected', 'delivered'])
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Center deliveries load failed: $e');
      rethrow;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'plastic':
        return Colors.blue;
      case 'organic':
        return Colors.orange;
      case 'glass':
        return Colors.teal;
      case 'paper':
        return Colors.brown;
      case 'metal':
        return Colors.grey;
      case 'ewaste':
        return Colors.purple;
      default:
        return Colors.green;
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
              Text(context.l10n.centerNavDeliveries,
                  style: context.textStyles.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => setState(() => _future = _load()),
                  icon:
                      Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const LinearProgressIndicator();
              if (snap.hasError)
                return Text(context.l10n.centerDeliveriesLoadFailed,
                    style: const TextStyle(color: Colors.red));
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return _CenterEmptyStateCard(
                    icon: Icons.local_shipping_outlined,
                    title: context.l10n.centerNoDeliveriesTitle,
                    subtitle: context.l10n.centerNoDeliveriesSubtitle);
              }
              return Column(
                children: rows.map((r) {
                  final type = (r['waste_type'] ?? 'mixed').toString();
                  final status = (r['status'] ?? '').toString();
                  final addr = r['addresses'] as Map<String, dynamic>?;
                  final city = (addr?['city'] ?? '').toString();
                  final hood = (addr?['neighborhood'] ?? '').toString();
                  final location =
                      [hood, city].where((s) => s.trim().isNotEmpty).join(', ');
                  final kg = (r['quantity_estimate_kg'] ?? '').toString();
                  final color = _colorForType(type);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        final id = (r['id'] ?? '').toString();
                        if (id.trim().isEmpty) return;
                        context.push(AppRoutes.receptionForm, extra: id);
                      },
                      child: _DeliveryCard(
                        truck:
                            'REQ-${(r['id'] ?? '').toString().substring(0, 6).toUpperCase()}',
                        type: type.toUpperCase(),
                        status:
                            '${_statusLabel(context, status)} • $kg kg • ${location.isEmpty ? '—' : location}',
                        time: context.l10n.commonOpen,
                        color: color,
                      ),
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

class _CenterStocksTab extends StatefulWidget {
  const _CenterStocksTab();

  @override
  State<_CenterStocksTab> createState() => _CenterStocksTabState();
}

class _CenterStocksTabState extends State<_CenterStocksTab> {
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
          .from('processing_events')
          .select(
              'id, weighed_kg, created_at, request_id, waste_requests(waste_type)')
          .eq('center_id', uid)
          .order('created_at', ascending: false)
          .limit(200);
      return (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('Center stocks load failed: $e');
      rethrow;
    }
  }

  Map<String, double> _sumByType(List<Map<String, dynamic>> rows) {
    final out = <String, double>{};
    for (final r in rows) {
      final kgRaw = r['weighed_kg'];
      final kg =
          kgRaw is num ? kgRaw.toDouble() : double.tryParse('$kgRaw') ?? 0;
      final wr = r['waste_requests'] as Map<String, dynamic>?;
      final type = (wr?['waste_type'] ?? 'mixed').toString();
      out[type] = (out[type] ?? 0) + kg;
    }
    return out;
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
              Text(context.l10n.centerNavStocks,
                  style: context.textStyles.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: () => setState(() => _future = _load()),
                  icon:
                      Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const LinearProgressIndicator();
              if (snap.hasError)
                return Text(context.l10n.centerStocksLoadFailed,
                    style: const TextStyle(color: Colors.red));
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return _CenterEmptyStateCard(
                    icon: Icons.inventory_2_outlined,
                    title: context.l10n.centerNoStockTitle,
                    subtitle: context.l10n.centerNoStockSubtitle);
              }
              final byType = _sumByType(rows);
              final total = byType.values.fold<double>(0, (a, b) => a + b);

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: AppSpacing.paddingLg,
                    decoration: BoxDecoration(
                        color: LightModeColors.lightSurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: LightModeColors.lightSurfaceVariant)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.centerTotalVolumeProcessed,
                            style: context.textStyles.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('${total.toStringAsFixed(1)} kg',
                            style: context.textStyles.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...byType.entries.map((e) {
                          final ratio = total <= 0
                              ? 0.0
                              : (e.value / total).clamp(0.0, 1.0);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(e.key.toUpperCase(),
                                          style: context.textStyles.labelMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.bold))),
                                  Text('${e.value.toStringAsFixed(1)} kg',
                                      style: context.textStyles.labelMedium)
                                ]),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                    value: ratio,
                                    backgroundColor:
                                        LightModeColors.lightSurfaceVariant,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            LightModeColors.lightPrimary)),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.change});
  final IconData icon;
  final String title;
  final String value;
  final String? change;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: LightModeColors.lightPrimary, size: 20),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        if (change != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.trending_up, size: 10, color: Colors.grey),
            const SizedBox(width: 4),
            Text(change!, style: const TextStyle(fontSize: 10, color: Colors.grey))
          ]),
        ],
      ]),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard(
      {required this.truck,
      required this.type,
      required this.status,
      required this.time,
      required this.color});
  final String truck;
  final String type;
  final String status;
  final String time;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.local_shipping_outlined,
                  color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(truck, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(type,
                        style: TextStyle(
                            color: color,
                            fontSize: 8,
                            fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(status,
                        style:
                            const TextStyle(fontSize: 10, color: Colors.grey))),
              ])
            ]),
          ),
          Text(time, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CenterEmptyStateCard extends StatelessWidget {
  const _CenterEmptyStateCard(
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

String _statusLabel(BuildContext context, String status) {
  switch (status) {
    case 'pending':
      return context.l10n.statusPending;
    case 'accepted':
      return context.l10n.statusAccepted;
    case 'en_route':
      return context.l10n.statusEnRoute;
    case 'collected':
      return context.l10n.statusCollected;
    case 'delivered':
      return context.l10n.statusDelivered;
    case 'cancelled':
      return context.l10n.statusCancelled;
    default:
      return status.toUpperCase();
  }
}

// --- RECEPTION FORM SCREEN ---
class ReceptionFormScreen extends StatelessWidget {
  const ReceptionFormScreen({super.key, this.requestId});

  final String? requestId;

  @override
  Widget build(BuildContext context) {
    // Legacy placeholder screen has been upgraded to use a requestId.
    final id = requestId;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.centerReceptionTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      body: _ReceptionFormBody(requestId: id),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.qr_code_scanner), label: context.l10n.centerNavReceptionShort),
          BottomNavigationBarItem(
              icon: const Icon(Icons.cases_outlined), label: context.l10n.centerNavMissions),
          BottomNavigationBarItem(
              icon: const Icon(Icons.inventory_2_outlined), label: context.l10n.centerNavStockShort),
          BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline), label: context.l10n.profileTitle),
        ],
      ),
    );
  }
}

class _ReceptionFormBody extends StatefulWidget {
  const _ReceptionFormBody({required this.requestId});
  final String? requestId;

  @override
  State<_ReceptionFormBody> createState() => _ReceptionFormBodyState();
}

class _ReceptionFormBodyState extends State<_ReceptionFormBody> {
  final _kgController = TextEditingController();
  bool _loading = false;
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _kgController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _load() async {
    final id = widget.requestId;
    if (id == null || id.trim().isEmpty) return null;
    try {
      final client = Supabase.instance.client;
      final row = await client
          .from('waste_requests')
          .select(
              'id, waste_type, quantity_estimate_kg, status, generator_id, addresses(city, neighborhood), pickups(collector_id, delivered_at)')
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      final map = Map<String, dynamic>.from(row);

      final generatorId = (map['generator_id'] ?? '').toString().trim();
      map['generator_id'] = generatorId;
      if (generatorId.isNotEmpty) {
        final generator = await AppUserService().getProfile(generatorId);
        map['generator_profile'] = generator?.toJson();
      }

      final pickups = (map['pickups'] as List?)?.cast<dynamic>();
      final pickup0 = pickups != null && pickups.isNotEmpty
          ? Map<String, dynamic>.from(pickups.first as Map)
          : null;
      final collectorId = pickup0?['collector_id'] as String?;
      map['collector_id'] = collectorId;
      if (collectorId != null) {
        final collector = await AppUserService().getProfile(collectorId);
        map['collector_profile'] = collector?.toJson();
      }
      return map;
    } catch (e) {
      debugPrint('Reception load failed: $e');
      rethrow;
    }
  }

  double _parseKg() {
    final raw = _kgController.text.trim().replaceAll(',', '.');
    return double.tryParse(raw) ?? 0;
  }

  Future<void> _confirm() async {
    final id = widget.requestId;
    if (id == null || id.trim().isEmpty) return;
    final kg = _parseKg();
    if (kg <= 0) {
      AppSnackbars.warning(context, context.l10n.centerEnterValidWeight);
      return;
    }
    setState(() => _loading = true);
    try {
      await WasteRequestService().confirmReceptionAtCenter(
          requestId: id, weighedKg: kg, accepted: true);
      if (!mounted) return;
      AppSnackbars.success(context, context.l10n.centerPaymentAcceptedMessage);
      context.pop();
    } catch (e) {
      debugPrint('Confirm reception failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.centerConfirmationFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLg,
      child: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const LinearProgressIndicator();
          if (snap.hasError)
            return Text(context.l10n.centerMissionLoadFailed,
                style: const TextStyle(color: Colors.red));
          final data = snap.data;
          if (data == null) {
            return _CenterEmptyStateCard(
                icon: Icons.qr_code_scanner,
                title: context.l10n.centerMissionNotFoundTitle,
                subtitle: context.l10n.centerMissionNotFoundSubtitle);
          }

          final reqId = (data['id'] ?? '').toString();
          final wasteType = (data['waste_type'] ?? 'mixed').toString();
          final estKgRaw = data['quantity_estimate_kg'];
          final estKg = estKgRaw is num
              ? estKgRaw.toDouble()
              : double.tryParse('$estKgRaw') ?? 0;
          final collectorProfile =
              data['collector_profile'] as Map<String, dynamic>?;
          final collectorName =
              (collectorProfile?['full_name'] ?? '').toString().trim();
          final collectorId = (data['collector_id'] ?? '').toString().trim();

          final generatorProfile =
              data['generator_profile'] as Map<String, dynamic>?;
          final generatorName =
              (generatorProfile?['full_name'] ?? '').toString().trim();
          final generatorId = (data['generator_id'] ?? '').toString().trim();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppSpacing.paddingLg,
                decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(children: [
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: LightModeColors.lightPrimaryContainer,
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(Icons.assignment_outlined,
                              color: LightModeColors.lightPrimary, size: 20)),
                      const SizedBox(width: 12),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('REQUEST ID',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            Text('#${reqId.substring(0, 8).toUpperCase()}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ])
                    ]),
                    const Divider(height: 32),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.centerCollectorLabel,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  CircleAvatar(
                                      radius: 10,
                                      backgroundColor: Colors.grey.shade300),
                                  const SizedBox(width: 8),
                                  Text(
                                      collectorName.isEmpty
                                          ? '—'
                                          : collectorName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ]),
                              ]),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(context.l10n.centerPaymentLabel,
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(context.l10n.centerVirtualPayment,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ])
                        ])
                  ],
                ),
              ),
              if (collectorId.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // Chat lié à la demande: conserve l'historique de cette livraison.
                        final threadId = await ChatService()
                            .getOrCreateThreadForRequest(requestId: reqId);
                        if (!context.mounted) return;
                        context.push(ChatRoutes.room,
                            extra: {'threadId': threadId, 'requestId': reqId});
                      } catch (e) {
                        debugPrint(
                            'Open request chat (center→collector) failed: $e');
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
                ),
              ],
              if (generatorId.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        // Chat lié à la demande: conserve l'historique de cette livraison.
                        final threadId = await ChatService()
                            .getOrCreateThreadForRequest(requestId: reqId);
                        if (!context.mounted) return;
                        context.push(ChatRoutes.room,
                            extra: {'threadId': threadId, 'requestId': reqId});
                      } catch (e) {
                        debugPrint(
                            'Open request chat (center→generator) failed: $e');
                        if (!context.mounted) return;
                        AppSnackbars.error(
                            context, context.l10n.errorCannotOpenChat);
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(generatorName.isEmpty
                        ? context.l10n.centerContactGeneratorGeneric
                        : context.l10n.centerContactNamed(generatorName)),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(context.l10n.centerWasteTypeLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                    color: LightModeColors.lightPrimaryContainer,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(Icons.recycling,
                      color: LightModeColors.lightPrimary, size: 20),
                  const SizedBox(width: 8),
                  Text(wasteType.toUpperCase(),
                      style: TextStyle(
                          color: LightModeColors.lightPrimary,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 24),
              Text(context.l10n.centerActualWeightLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _kgController,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: 'KG',
                  suffixStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: LightModeColors.lightPrimary, width: 2)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                  child: Text(
                      context.l10n.centerEstimatedWeightNote(estKg.toStringAsFixed(1)),
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 10))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(Icons.check_circle_outline),
                              const SizedBox(width: 8),
                              Text(context.l10n.centerConfirmReceptionButton)
                            ]),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                    context.l10n.centerAutoCreditNote,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
