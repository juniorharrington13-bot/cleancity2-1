import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:cleancity/auth/auth_manager.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/locale_provider.dart';
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
  bool _saving = false;
  bool _uploadingAvatar = false;

  String _langLabel(String code) => code == 'en' ? 'English' : 'Français';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    final profile = await AppUserService().getCurrentProfile();
    _fullNameCtrl.text = profile?.fullName ?? '';
    _phoneCtrl.text = profile?.phoneE164 ?? '';
    // The app's active language already reflects the saved preference (it was
    // reconciled at login); this just keeps the two in sync if they ever drift.
    if (mounted && profile?.preferredLanguage != null) {
      context.read<LocaleProvider>().syncFromProfile(profile!.preferredLanguage);
    }
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
      );
      if (!mounted) return;
      AppSnackbars.success(context, context.l10n.profileUpdated);
    } catch (e) {
      debugPrint('Profile save failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
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
                Text(context.l10n.profileAvatarSheetTitle,
                    style: context.textStyles.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => context.pop(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: Text(context.l10n.profileChooseFromGallery),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => context.pop(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(context.l10n.profileTakePhoto),
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
      final picked = await picker.pickImage(
          source: source, imageQuality: 85, maxWidth: 1200);
      if (picked == null) return;
      final url = await MediaUploadService().uploadUserAvatar(picked);
      await AppUserService().updateAvatarUrl(url);

      if (!mounted) return;
      setState(() {
        _future = _load();
      });
      AppSnackbars.success(context, context.l10n.profilePhotoUpdated);
    } on MediaUploadException catch (e) {
      debugPrint('Avatar upload blocked: $e');
      if (!mounted) return;
      AppSnackbars.warning(context, AppErrorHandler.toUserMessage(context, e));
    } catch (e) {
      debugPrint('Avatar upload failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
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
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
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
            Text(context.l10n.profileTitle,
                style: context.textStyles.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FutureBuilder(
              future: AppUserService().getCurrentProfile(),
              builder: (context, profileSnap) {
                final u = profileSnap.data;
                final avatarUrl = (u?.avatarUrl ?? '').trim();
                return Container(
                  padding: AppSpacing.paddingLg,
                  decoration: BoxDecoration(
                      color: LightModeColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                          color: LightModeColors.lightSurfaceVariant)),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                LightModeColors.lightPrimaryContainer,
                            backgroundImage: avatarUrl.isEmpty
                                ? null
                                : NetworkImage(avatarUrl),
                            child: avatarUrl.isEmpty
                                ? const Icon(Icons.person,
                                    color: LightModeColors.lightPrimary)
                                : null,
                          ),
                          Positioned(
                            right: -4,
                            bottom: -4,
                            child: IconButton(
                              tooltip: context.l10n.profileChangePhotoTooltip,
                              onPressed:
                                  _uploadingAvatar ? null : _changeAvatar,
                              style: IconButton.styleFrom(
                                  backgroundColor: LightModeColors.lightSurface,
                                  padding: const EdgeInsets.all(6)),
                              icon: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.edit,
                                      size: 18,
                                      color: LightModeColors.lightPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (u != null)
                                  ? u.displayNameCapitalized(context)
                                  : context.l10n.commonUser,
                              style: context.textStyles.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              u?.email ?? '',
                              style: context.textStyles.bodySmall?.copyWith(
                                  color: LightModeColors.lightOnSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: LightModeColors.lightPrimaryContainer,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          (u != null) ? u.roleLabel(context) : context.l10n.roleGenerator,
                          style: context.textStyles.labelSmall?.copyWith(
                              color: LightModeColors.lightPrimary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _fullNameCtrl,
                decoration: InputDecoration(labelText: context.l10n.authFullNameLabel)),
            const SizedBox(height: 12),
            TextField(
                controller: _phoneCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.profilePhoneLabel),
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) => _LanguageSelector(
                currentValue: localeProvider.locale.languageCode,
                labelFor: _langLabel,
                onChanged: (v) =>
                    context.read<LocaleProvider>().setLocale(v, persistToDb: true),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_saving ? context.l10n.profileSaving : context.l10n.commonSave),
                  const SizedBox(width: 8),
                  Icon(_saving ? Icons.hourglass_top : Icons.save)
                ]),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(context.l10n.commonLogout,
                    style: const TextStyle(color: Colors.red)),
              ),
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.currentValue,
    required this.onChanged,
    required this.labelFor,
  });

  final String currentValue;
  final ValueChanged<String> onChanged;
  final String Function(String code) labelFor;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.profileLanguageTooltip,
      onSelected: onChanged,
      itemBuilder: (context) => const [
        PopupMenuItem<String>(value: 'fr', child: Text('Français')),
        PopupMenuItem<String>(value: 'en', child: Text('English')),
      ],
      child: InputDecorator(
        decoration: InputDecoration(labelText: context.l10n.profileLanguageLabel),
        child: Row(
          children: [
            Expanded(
              child: Text(
                labelFor(currentValue),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}
