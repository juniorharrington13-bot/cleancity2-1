import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:cleancity/auth/auth_manager.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/media_upload_service.dart';
import 'package:cleancity/theme.dart';

/// Reusable profile tab for all roles.
class UserProfileTab extends StatefulWidget {
  const UserProfileTab({super.key});

  @override
  State<UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<UserProfileTab> {
  late Future _future;
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _lang = 'fr';
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final profile = await AppUserService().getCurrentProfile();
    _fullNameCtrl.text = profile?.fullName ?? '';
    _phoneCtrl.text = profile?.phoneE164 ?? '';
    _lang = profile?.preferredLanguage ?? 'fr';
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await AppUserService().updateProfile(
        fullName: _fullNameCtrl.text.trim(),
        phoneE164: _phoneCtrl.text.trim(),
        preferredLanguage: _lang,
      );
      if (!mounted) return;
      AppSnackbars.success(context, 'Profil mis à jour.');
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Mise à jour du profil échouée.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changeAvatar() async {
    if (_uploadingAvatar) return;
    if (!mounted) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: AppSpacing.paddingLg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Photo de profil', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.pop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choisir depuis la galerie'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.pop(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Prendre une photo'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
      if (picked == null) return;
      final url = await MediaUploadService().uploadUserAvatar(picked);
      await AppUserService().updateAvatarUrl(url);

      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      AppSnackbars.success(context, 'Photo de profil mise à jour.');
    } on MediaUploadException catch (e) {
      debugPrint('Avatar upload blocked: $e');
      if (!mounted) return;
      AppSnackbars.warning(context, e.userMessage);
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Upload échoué.');
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    try {
      await SupabaseAuthManager().signOut();
      if (!mounted) return;
      context.go(AppRoutes.login);
    } catch (e) {
      debugPrint('Logout failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Déconnexion échouée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        return ListView(
          padding: AppSpacing.paddingLg,
          children: [
            Text('Profil', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FutureBuilder(
              future: AppUserService().getCurrentProfile(),
              builder: (context, profileSnap) {
                final u = profileSnap.data;
                final avatarUrl = (u?.avatarUrl ?? '').trim();
                return Container(
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(color: LightModeColors.lightSurface, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: LightModeColors.lightSurfaceVariant)),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: LightModeColors.lightPrimaryContainer,
                            backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                            child: avatarUrl.isEmpty ? const Icon(Icons.person, color: LightModeColors.lightPrimary) : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: IconButton(
                              tooltip: 'Changer la photo',
                              onPressed: _uploadingAvatar ? null : _changeAvatar,
                              style: IconButton.styleFrom(backgroundColor: LightModeColors.lightSurface, padding: const EdgeInsets.all(6)),
                              icon: _uploadingAvatar
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.edit, size: 18, color: LightModeColors.lightPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((u?.fullName?.trim().isNotEmpty ?? false) ? u!.fullName!.trim() : 'Utilisateur', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(u?.email ?? '', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: LightModeColors.lightPrimaryContainer, borderRadius: BorderRadius.circular(999)),
                        child: Text((u?.role ?? 'generator').toUpperCase(), style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(controller: _fullNameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
            const SizedBox(height: 12),
            TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone (E.164)'), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _lang,
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français (principal)')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _lang = v);
              },
              decoration: const InputDecoration(labelText: 'Langue'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_saving ? 'Sauvegarde...' : 'Sauvegarder'), const SizedBox(width: 8), Icon(_saving ? Icons.hourglass_top : Icons.save)]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Se déconnecter', style: TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}
