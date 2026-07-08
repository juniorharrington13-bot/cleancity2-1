import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/services/app_user_service.dart';
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
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CLEANCITY',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('CAMEROUN ADMIN',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          _buildNavItem(0, Icons.dashboard_outlined, 'Tableau de bord'),
          _buildNavItem(1, Icons.people_outline, 'Gestion des utilisateurs'),
          _buildNavItem(2, Icons.recycling_outlined, 'Catalogue des dechets'),
          _buildNavItem(3, Icons.bar_chart_outlined, 'Rapports'),
          _buildNavItem(4, Icons.settings_outlined, 'Parametres'),
          const Spacer(),
          const Divider(),
          _buildNavItem(5, Icons.logout, 'Se deconnecter', isLogout: true),
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
                tooltip: 'Retour',
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
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        hintStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),
              if (!showSearchField)
                IconButton(
                  tooltip: 'Rechercher',
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
        return const Center(child: Text('En construction'));
    }
  }
}

// --- SUBVIEWS ---

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

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
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                      width: statCardWidth,
                      child: _buildStatCard('Dechets collectes', '1,250',
                          'Tonnes', '+12.5% vs mois precedent', Colors.green)),
                  SizedBox(
                      width: statCardWidth,
                      child: _buildStatCard('Collecteurs actifs', '482', '',
                          '+5.2% vs mois precedent', Colors.blue)),
                  SizedBox(
                      width: statCardWidth,
                      child: _buildStatCard('Taux de revalorisation', '64%', '',
                          'Objectif: 70%', Colors.orange)),
                  SizedBox(
                      width: statCardWidth,
                      child: _buildStatCard('Revenus totaux', '45.0M', 'XAF',
                          '+1.2% vs mois precedent', Colors.purple)),
                ],
              ),
              const SizedBox(height: 24),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _HeatmapPanel()),
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _RecentOperationsPanel()),
                  ],
                )
              else
                Column(
                  children: const [
                    _HeatmapPanel(),
                    SizedBox(height: 16),
                    _RecentOperationsPanel(),
                  ],
                ),
            ],
          ),
        );
      },
    );
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
              Icon(Icons.trending_up, size: 14, color: color),
              const SizedBox(width: 4),
              Text(subtitle, style: TextStyle(color: color, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeatmapBlob(Color color, String label, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.3),
      ),
      child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: 12))),
    );
  }

  Widget _buildOperationItem(
      String type, String location, String person, IconData icon, Color color) {
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 8),
              Text(person,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          )
        ],
      ),
    );
  }
}

class _HeatmapPanel extends StatelessWidget {
  const _HeatmapPanel();

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
              const Text('Carte des demandes actives',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Systeme en direct'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green,
                    elevation: 0),
              ),
            ],
          ),
          const Text('Suivi global des operations pour Yaounde et Douala',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Stack(
                children: [
                  Center(
                      child: Icon(Icons.map,
                          size: 100, color: Colors.grey.shade300)),
                  Positioned(
                      top: 50,
                      left: 80,
                      child: _HeatmapBlob(
                          color: Colors.orange, label: 'Douala', size: 80)),
                  Positioned(
                      top: 150,
                      left: 220,
                      child: _HeatmapBlob(
                          color: Colors.green, label: 'Yaoundé', size: 100)),
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
      {required this.color, required this.label, required this.size});

  final Color color;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: color.withValues(alpha: 0.3)),
      child: Center(
          child: Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 1.0),
                  fontWeight: FontWeight.bold,
                  fontSize: 12))),
    );
  }
}

class _RecentOperationsPanel extends StatelessWidget {
  const _RecentOperationsPanel();

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
              const Text('Operations recentes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(onPressed: () {}, child: const Text('Tout voir')),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: const [
                _OperationItem(
                    type: 'Dechet plastique',
                    location: 'Bastos, Yaoundé',
                    person: 'M. Tabi',
                    icon: Icons.local_drink,
                    color: Colors.blue),
                _OperationItem(
                    type: 'Charge organique',
                    location: 'Akwa, Douala',
                    person: 'J. Ngono',
                    icon: Icons.eco,
                    color: Colors.green),
                _OperationItem(
                    type: 'Dechet medical',
                    location: 'Hôpital Central',
                    person: 'P. Eloundou',
                    icon: Icons.medical_services,
                    color: Colors.red),
                _OperationItem(
                    type: 'Carton/Papier',
                    location: 'Bonamoussadi',
                    person: "E. Eto'o",
                    icon: Icons.inventory_2,
                    color: Colors.orange),
              ],
            ),
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
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade300),
              const SizedBox(width: 8),
              Text(person,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ],
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
                    const Text('Gestion des utilisateurs',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 24)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _AdminSearchField(controller: _searchCtrl)),
                        const SizedBox(width: 12),
                        IconButton(
                            tooltip: 'Actualiser',
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh)),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    const Expanded(
                        child: Text('Gestion des utilisateurs',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 24))),
                    SizedBox(
                        width: 360,
                        child: _AdminSearchField(controller: _searchCtrl)),
                    const SizedBox(width: 12),
                    IconButton(
                        tooltip: 'Actualiser',
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
                        return const Center(
                            child: Text('Aucun utilisateur trouve.'));
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 64,
                            columns: const [
                              DataColumn(
                                  label: Text('NOM',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('EMAIL',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('ROLE',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('LANGUE',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('TELEPHONE',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                              DataColumn(
                                  label: Text('CREE LE',
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold))),
                            ],
                            rows: users.map(_buildRow).toList(growable: false),
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

  DataRow _buildRow(AppUser u) {
    final name = (u.fullName?.trim().isNotEmpty ?? false)
        ? u.displayNameCapitalized()
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
        DataCell(Text(u.preferredLanguage == 'en' ? 'ANGLAIS' : 'FRANCAIS')),
        DataCell(Text(u.phoneE164.isEmpty ? '—' : u.phoneE164)),
        DataCell(Text(created)),
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
              const Text('Impossible de charger les utilisateurs',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                '${AppErrorHandler.toUserMessage(error ?? Exception('unknown'))}\nVerifiez vos policies RLS administrateur.',
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
        hintText: 'Rechercher par nom ou email',
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
      child: Text(_roleLabelFr(role),
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
    final entries = const [
      ('all', 'Tous'),
      ('generator', 'Generateurs'),
      ('collector', 'Collecteurs'),
      ('center', 'Centres'),
      ('admin', 'Admins'),
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

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Text('Catalogue des dechets - Bientot disponible'));
  }
}

String _roleLabelFr(String role) {
  switch (role) {
    case 'admin':
      return 'ADMIN';
    case 'collector':
      return 'COLLECTEUR';
    case 'center':
    case 'processing_center':
      return 'CENTRE';
    default:
      return 'GENERATEUR';
  }
}
