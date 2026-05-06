import 'package:flutter/material.dart';

import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/theme.dart';

/// Bottom sheet used by collectors to select the delivery center.
class CenterPickerSheet extends StatefulWidget {
  const CenterPickerSheet({super.key, required this.onSelected});

  final ValueChanged<AppUser> onSelected;

  @override
  State<CenterPickerSheet> createState() => _CenterPickerSheetState();
}

class _CenterPickerSheetState extends State<CenterPickerSheet> {
  final _searchCtrl = TextEditingController();
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<AppUser>> _load() => AppUserService().listUsers(role: 'center', query: _searchCtrl.text.trim(), limit: 50);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Choisir un centre', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.of(context).maybePop(), icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() => _future = _load()),
            decoration: InputDecoration(
              hintText: 'Rechercher un centre (nom ou email)...',
              prefixIcon: Icon(Icons.search, color: LightModeColors.lightPrimary),
              suffixIcon: IconButton(
                tooltip: 'Actualiser',
                onPressed: () => setState(() => _future = _load()),
                icon: Icon(Icons.refresh, color: LightModeColors.lightPrimary),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
              if (snap.hasError) return Text('Erreur: ${snap.error}', style: const TextStyle(color: Colors.red));
              final centers = snap.data ?? const <AppUser>[];
              if (centers.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
                  child: Text('Aucun centre trouvé. Créez au moins un compte avec rôle "center".', style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: centers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = centers[i];
                    final title = (c.fullName?.trim().isNotEmpty ?? false) ? c.fullName!.trim() : c.email;
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () => widget.onSelected(c),
                      child: Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
                        child: Row(
                          children: [
                            const CircleAvatar(backgroundColor: LightModeColors.lightPrimaryContainer, child: Icon(Icons.factory_outlined, color: LightModeColors.lightPrimary)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: context.textStyles.titleSmall?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(c.email, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: LightModeColors.lightOnSurfaceVariant),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
