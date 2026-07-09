import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/admin_stats_service.dart';
import 'package:cleancity/constants/waste_rates.dart';
import '../theme.dart';

// --- ADMIN WEB DASHBOARD ---
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // If screen is narrow, maybe show a drawer. But let's assume web desktop for this view.
    final isDesktop = MediaQuery.of(context).size.width > 800;

    Widget body = Row(
      children: [
        if (isDesktop) _buildSidebar(),
        Expanded(
          child: Column(
            children: [
              _buildTopBar(isDesktop),
              Expanded(
                child: Container(
                  color: LightModeColors.lightBackground,
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      drawer: !isDesktop ? Drawer(child: _buildSidebar()) : null,
      body: body,
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                Icon(Icons.eco, color: LightModeColors.lightPrimary),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CLEANCITY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(context.l10n.adminBrandSubtitle,
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _buildNavItem(0, Icons.dashboard_outlined, context.l10n.adminNavDashboard),
          _buildNavItem(1, Icons.people_outline, context.l10n.adminNavUsers),
          _buildNavItem(2, Icons.recycling_outlined, context.l10n.adminNavCatalog),
          _buildNavItem(3, Icons.bar_chart_outlined, context.l10n.adminNavReports),
          _buildNavItem(4, Icons.settings_outlined, context.l10n.adminNavSettings),
          const Spacer(),
          const Divider(),
          _buildNavItem(5, Icons.logout, context.l10n.commonLogout, isLogout: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title,
      {bool isLogout = false}) {
    final isSelected = _selectedIndex == index && !isLogout;
    return InkWell(
      onTap: () {
        if (!isLogout) {
          setState(() {
            _selectedIndex = index;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? LightModeColors.lightPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? Colors.white
                    : (isLogout ? Colors.red : Colors.grey.shade700),
                size: 20),
            const SizedBox(width: 16),
            Text(title,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isLogout ? Colors.red : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showSearchField = width >= 860;
        final showAdminLabel = width >= 560;

        return Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.commonBack,
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                    return;
                  }
                  context.go(AppRoutes.roleSelection);
                },
              ),
              if (!isDesktop)
                Builder(
                    builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer())),
              const SizedBox(width: 12),
              if (showSearchField)
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20)),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: context.l10n.adminQuickSearchHint,
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (!showSearchField)
                IconButton(
                  tooltip: context.l10n.commonSearch,
                  icon: const Icon(Icons.search),
                  onPressed: () {},
                ),
              IconButton(
                  icon: const Icon(Icons.notifications_none), onPressed: () {}),
              const SizedBox(width: 8),
              if (showAdminLabel)
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('cleancity',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Admin',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              const SizedBox(width: 12),
              const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.person, color: Colors.white)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardView();
      case 1:
        return const UserManagementView();
      case 2:
        return const WasteCatalogView();
      default:
        return Center(child: Text(context.l10n.adminUnderConstruction));
    }
  }
}

// --- SUBVIEWS ---

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final AdminStatsService _statsService = AdminStatsService();

  late Future<AdminDashboardStats> _statsFuture;
  late Future<List<AdminRecentOperation>> _recentOpsFuture;
  late Future<Map<String, int>> _cityCountsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _statsFuture = _statsService.getDashboardStats();
      _recentOpsFuture = _statsService.getRecentOperations();
      _cityCountsFuture = _statsService.getActiveRequestCountsByCity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isWide = w >= 1100;
        final statCardWidth = isWide ? (w - 16 * 3) / 4 : 280.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<AdminDashboardStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StatsErrorBanner(
                        error: snapshot.error, onRetry: _refresh);
                  }
                  final stats = snapshot.data;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                              context.l10n.adminStatWasteCollected,
                              stats == null ? '—' : _formatNumber(stats.collectedKg, decimals: stats.collectedKg < 10 ? 1 : 0),
                              context.l10n.adminUnitKg,
                              _changeSubtitle(context, stats?.collectedKgChangePercent),
                              Colors.green)),
                      SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                              context.l10n.adminStatActiveCollectors,
                              stats == null ? '—' : '${stats.activeCollectors}',
                              '',
                              _changeSubtitle(context, stats?.activeCollectorsChangePercent),
                              Colors.blue)),
                      SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                              context.l10n.adminStatRecoveryRate,
                              stats?.recoveryRatePercent == null
                                  ? '—'
                                  : '${stats!.recoveryRatePercent!.toStringAsFixed(0)}%',
                              '',
                              context.l10n.adminStatRecoveryGoal,
                              Colors.orange)),
                      SizedBox(
                          width: statCardWidth,
                          child: _buildStatCard(
                              context.l10n.adminStatTotalRevenue,
                              stats == null ? '—' : _formatNumber(stats.revenueXaf),
                              'XAF',
                              _changeSubtitle(context, stats?.revenueXafChangePercent),
                              Colors.purple)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        flex: 2,
                        child: FutureBuilder<Map<String, int>>(
                          future: _cityCountsFuture,
                          builder: (context, snapshot) => _HeatmapPanel(
                              cityCounts: snapshot.data, onRefresh: _refresh),
                        )),
                    const SizedBox(width: 24),
                    Expanded(
                        flex: 1,
                        child: FutureBuilder<List<AdminRecentOperation>>(
                          future: _recentOpsFuture,
                          builder: (context, snapshot) => _RecentOperationsPanel(
                              operations: snapshot.data,
                              error: snapshot.hasError ? snapshot.error : null),
                        )),
                  ],
                )
              else
                Column(
                  children: [
                    FutureBuilder<Map<String, int>>(
                      future: _cityCountsFuture,
                      builder: (context, snapshot) => _HeatmapPanel(
                          cityCounts: snapshot.data, onRefresh: _refresh),
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<AdminRecentOperation>>(
                      future: _recentOpsFuture,
                      builder: (context, snapshot) => _RecentOperationsPanel(
                          operations: snapshot.data,
                          error: snapshot.hasError ? snapshot.error : null),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  String _changeSubtitle(BuildContext context, double? percent) {
    if (percent == null) return context.l10n.adminStatNotEnoughData;
    final sign = percent >= 0 ? '+' : '';
    return context.l10n.adminStatVsLastMonth('$sign${percent.toStringAsFixed(1)}%');
  }

  Widget _buildStatCard(
      String title, String value, String unit, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 32)),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(unit,
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                  subtitle.trim().startsWith('-')
                      ? Icons.trending_down
                      : Icons.trending_up,
                  size: 14,
                  color: color),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(subtitle,
                      style: TextStyle(color: color, fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
            ],
          )
        ],
      ),
    );
  }
}

/// Formats a number with `,` thousands separators, without pulling in intl's
/// locale data (which needs async init we don't want to gate this screen on).
String _formatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final decPart = parts.length > 1 ? '.${parts[1]}' : '';
  return '${negative ? '-' : ''}${buffer.toString()}$decPart';
}

(String, IconData, Color) _wasteTypeMeta(BuildContext context, String code) {
  switch (code) {
    case 'plastic':
      return (context.l10n.adminWastePlastic, Icons.local_drink, Colors.blue);
    case 'organic':
      return (context.l10n.adminWasteOrganic, Icons.eco, Colors.green);
    case 'paper':
      return (context.l10n.adminWasteCardboard, Icons.inventory_2, Colors.orange);
    case 'metal':
      return (context.l10n.adminWasteMetal, Icons.build, Colors.blueGrey);
    case 'glass':
      return (context.l10n.adminWasteGlass, Icons.wine_bar_outlined, Colors.teal);
    case 'ewaste':
      return (context.l10n.adminWasteEwaste, Icons.memory, Colors.deepPurple);
    case 'mixed':
    default:
      return (context.l10n.adminWasteMixed, Icons.delete_outline, Colors.grey);
  }
}

class _StatsErrorBanner extends StatelessWidget {
  const _StatsErrorBanner({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade100)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  AppErrorHandler.toUserMessage(
                      context, error ?? Exception(context.l10n.adminStatsLoadFailed)),
                  style: TextStyle(color: Colors.red.shade700))),
          TextButton(onPressed: onRetry, child: Text(context.l10n.commonRefresh)),
        ],
      ),
    );
  }
}

class _HeatmapPanel extends StatelessWidget {
  const _HeatmapPanel({required this.cityCounts, required this.onRefresh});

  final Map<String, int>? cityCounts;
  final VoidCallback onRefresh;

  int _countFor(String city) {
    final counts = cityCounts;
    if (counts == null) return 0;
    for (final entry in counts.entries) {
      if (entry.key.toLowerCase().contains(city.toLowerCase())) return entry.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loading = cityCounts == null;
    final doualaCount = _countFor('douala');
    final yaoundeCount = _countFor('yaound');
    final knownCities = {'douala', 'yaound'};
    final otherCount = loading
        ? 0
        : cityCounts!.entries
            .where((e) => !knownCities.any((k) => e.key.toLowerCase().contains(k)))
            .fold<int>(0, (sum, e) => sum + e.value);
    final total = doualaCount + yaoundeCount + otherCount;
    final maxCount = [doualaCount, yaoundeCount, 1].reduce((a, b) => a > b ? a : b);

    double sizeFor(int count) => 60 + (count / maxCount) * 60;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.adminHeatmapTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(context.l10n.adminLiveSystemButton),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green,
                    elevation: 0),
              ),
            ],
          ),
          Text(context.l10n.adminHeatmapSubtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        Center(
                            child: Icon(Icons.map,
                                size: 100, color: Colors.grey.shade300)),
                        if (total == 0)
                          Center(
                              child: Text(context.l10n.adminNoActiveRequests,
                                  style: TextStyle(color: Colors.grey.shade500))),
                        Positioned(
                            top: 50,
                            left: 80,
                            child: _HeatmapBlob(
                                color: Colors.orange,
                                label: 'Douala',
                                count: doualaCount,
                                size: sizeFor(doualaCount))),
                        Positioned(
                            top: 150,
                            left: 220,
                            child: _HeatmapBlob(
                                color: Colors.green,
                                label: 'Yaoundé',
                                count: yaoundeCount,
                                size: sizeFor(yaoundeCount))),
                        if (otherCount > 0)
                          Positioned(
                              bottom: 20,
                              right: 20,
                              child: _HeatmapBlob(
                                  color: Colors.blueGrey,
                                  label: context.l10n.adminFilterAll,
                                  count: otherCount,
                                  size: sizeFor(otherCount))),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapBlob extends StatelessWidget {
  const _HeatmapBlob(
      {required this.color, required this.label, required this.count, required this.size});

  final Color color;
  final String label;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: color.withValues(alpha: 0.3)),
      child: Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
              style: TextStyle(
                  color: color.withValues(alpha: 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ],
      )),
    );
  }
}

class _RecentOperationsPanel extends StatelessWidget {
  const _RecentOperationsPanel({required this.operations, required this.error});

  final List<AdminRecentOperation>? operations;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.adminRecentOpsTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Builder(builder: (context) {
              if (error != null) {
                return Center(
                    child: Text(AppErrorHandler.toUserMessage(context, error!),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600)));
              }
              final ops = operations;
              if (ops == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ops.isEmpty) {
                return Center(
                    child: Text(context.l10n.adminNoRecentOperations,
                        style: TextStyle(color: Colors.grey.shade600)));
              }
              return ListView.builder(
                itemCount: ops.length,
                itemBuilder: (context, i) {
                  final op = ops[i];
                  final (label, icon, color) = _wasteTypeMeta(context, op.wasteType);
                  return _OperationItem(
                      type: label,
                      location: op.location,
                      person: op.personName,
                      icon: icon,
                      color: color);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _OperationItem extends StatelessWidget {
  const _OperationItem(
      {required this.type,
      required this.location,
      required this.person,
      required this.icon,
      required this.color});

  final String type;
  final String location;
  final String person;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(person,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class UserManagementView extends StatefulWidget {
  const UserManagementView({super.key});

  @override
  State<UserManagementView> createState() => _UserManagementViewState();
}

class _UserManagementViewState extends State<UserManagementView> {
  final AppUserService _userService = AppUserService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _roleFilter = 'all';
  String _query = '';
  Future<List<AppUser>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
    _searchCtrl.addListener(() {
      final next = _searchCtrl.text;
      if (next == _query) return;
      setState(() {
        _query = next;
      });
      _refresh();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future =
          _userService.listUsers(role: _roleFilter, query: _query, limit: 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 820;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.adminNavUsers,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _AdminSearchField(controller: _searchCtrl)),
                        const SizedBox(width: 12),
                        IconButton(
                            tooltip: context.l10n.commonRefresh,
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh)),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                        child: Text(context.l10n.adminNavUsers,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24))),
                    SizedBox(
                        width: 360,
                        child: _AdminSearchField(controller: _searchCtrl)),
                    const SizedBox(width: 12),
                    IconButton(
                        tooltip: context.l10n.commonRefresh,
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh)),
                  ],
                ),
              const SizedBox(height: 16),
              _RoleChips(
                value: _roleFilter,
                onChanged: (v) {
                  setState(() {
                    _roleFilter = v;
                  });
                  _refresh();
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: FutureBuilder<List<AppUser>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return _AdminErrorPanel(error: snapshot.error);
                      }

                      final users = snapshot.data ?? const <AppUser>[];
                      if (users.isEmpty) {
                        return Center(
                            child: Text(context.l10n.adminNoUsersFound));
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 64,
                            columns: [
                              DataColumn(
                                  label: Text(context.l10n.adminColName,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColEmail,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColRole,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColLanguage,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColPhone,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColCreatedAt,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text(context.l10n.adminColActions,
                                      style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: users.map((u) => _buildRow(context, u)).toList(growable: false),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  DataRow _buildRow(BuildContext context, AppUser u) {
    final name = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.displayNameCapitalized(context)
        : '—';
    final created = _formatDate(u.createdAt);
    return DataRow(
      cells: [
        DataCell(Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            child: Text(
                (name == '—'
                        ? (u.email.isNotEmpty ? u.email[0] : '?')
                        : name[0])
                    .toUpperCase(),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black)),
          ),
          const SizedBox(width: 12),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ])),
        DataCell(ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(u.email, overflow: TextOverflow.ellipsis))),
        DataCell(_RoleBadge(role: u.role)),
        DataCell(Text(u.preferredLanguage == 'en' ? context.l10n.commonLanguageEnglish : context.l10n.commonLanguageFrench)),
        DataCell(Text(u.phoneE164.isEmpty ? '—' : u.phoneE164)),
        DataCell(Text(created)),
        DataCell(_RoleActionMenu(
          user: u,
          isSelf: u.id == _userService.currentUserId,
          onChanged: _refresh,
        )),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    String two(int n) => n < 10 ? '0$n' : '$n';
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

class _AdminErrorPanel extends StatelessWidget {
  const _AdminErrorPanel({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 36, color: Colors.grey.shade600),
              const SizedBox(height: 12),
              Text(context.l10n.adminUsersLoadFailedTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                AppErrorHandler.toUserMessage(context, error ?? Exception('unknown')),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSearchField extends StatelessWidget {
  const _AdminSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: context.l10n.adminSearchByNameEmailHint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: LightModeColors.lightPrimary, width: 1.2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (role) {
      'admin' => (Colors.purple.withValues(alpha: 0.12), Colors.purple),
      'collector' => (Colors.blue.withValues(alpha: 0.12), Colors.blue),
      'center' || 'processing_center' => (
          Colors.orange.withValues(alpha: 0.12),
          Colors.orange
        ),
      _ => (Colors.green.withValues(alpha: 0.12), Colors.green),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(_roleLabel(context, role),
          style:
              TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _RoleChips extends StatelessWidget {
  const _RoleChips({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = [
      ('all', context.l10n.adminFilterAll),
      ('generator', context.l10n.adminFilterGenerators),
      ('collector', context.l10n.adminFilterCollectors),
      ('center', context.l10n.adminFilterCenters),
      ('admin', context.l10n.adminFilterAdmins),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: entries
          .map((e) => ChoiceChip(
                label: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(e.$2)),
                selected: value == e.$1,
                onSelected: (_) => onChanged(e.$1),
                selectedColor:
                    LightModeColors.lightPrimary.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                  color: value == e.$1
                      ? LightModeColors.lightPrimary
                      : Colors.grey.shade800,
                  fontWeight: value == e.$1 ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(color: Colors.grey.shade200),
                backgroundColor: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999)),
              ))
          .toList(growable: false),
    );
  }
}

class WasteCatalogView extends StatelessWidget {
  const WasteCatalogView({super.key});

  static const _order = ['plastic', 'paper', 'metal', 'glass', 'organic', 'ewaste', 'mixed'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.adminNavCatalog,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
          const SizedBox(height: 4),
          Text(context.l10n.adminCatalogSubtitle,
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _order.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, i) {
                  final code = _order[i];
                  final (label, icon, color) = _wasteTypeMeta(context, code);
                  final rate = wasteXafPerKg[code] ?? 0;
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text('${_formatNumber(rate)} ${context.l10n.adminCatalogRateUnit}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleActionMenu extends StatelessWidget {
  const _RoleActionMenu({required this.user, required this.isSelf, required this.onChanged});

  final AppUser user;
  final bool isSelf;
  final VoidCallback onChanged;

  static const _roles = ['generator', 'collector', 'center', 'admin'];

  Future<void> _changeRole(BuildContext context, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.adminChangeRoleDialogTitle),
        content: Text(context.l10n.adminChangeRoleDialogContent(
            user.displayNameCapitalized(context), user.email, _roleLabel(context, user.role), _roleLabel(context, role))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.commonConfirm)),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AppUserService().adminUpdateUserRole(userId: user.id, role: role);
      if (!context.mounted) return;
      AppSnackbars.success(context, context.l10n.adminRoleUpdated);
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isSelf) {
      return Tooltip(
        message: context.l10n.adminCannotChangeOwnRole,
        child: Icon(Icons.lock_outline, size: 18, color: Colors.grey.shade400),
      );
    }
    return PopupMenuButton<String>(
      tooltip: context.l10n.adminChangeRoleTooltip,
      icon: const Icon(Icons.edit_outlined, size: 20),
      onSelected: (role) => _changeRole(context, role),
      itemBuilder: (context) => _roles
          .where((r) => r != user.role)
          .map((r) => PopupMenuItem<String>(value: r, child: Text(_roleLabel(context, r))))
          .toList(),
    );
  }
}

String _roleLabel(BuildContext context, String role) {
  switch (role) {
    case 'admin':
      return context.l10n.roleAdmin;
    case 'collector':
      return context.l10n.roleCollector;
    case 'center':
    case 'processing_center':
      return context.l10n.roleCenter;
    default:
      return context.l10n.roleGenerator;
  }
}
