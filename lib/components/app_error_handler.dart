import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/services/media_upload_service.dart';
import 'package:cleancity/theme.dart';

class AppErrorHandler {
  const AppErrorHandler._();

  static String toUserMessage(BuildContext context, Object error) {
    final l10n = context.l10n;

    if (error is AuthApiException) {
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'email_exists' ||
          msg.contains('already registered') ||
          msg.contains('already been registered')) {
        return l10n.errorEmailAlreadyUsed;
      }
      if (code == 'weak_password' ||
          msg.contains('password should be at least') ||
          msg.contains('weak password')) {
        return l10n.errorWeakPassword;
      }
      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          msg.contains('invalid login credentials')) {
        return l10n.errorInvalidCredentials;
      }
      if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
        return l10n.errorEmailNotConfirmed;
      }
      if (msg.contains('phone')) {
        return l10n.errorInvalidPhone;
      }
      if (code == 'over_email_send_rate_limit' ||
          msg.contains('rate limit') ||
          msg.contains('security purposes')) {
        return l10n.errorRateLimited;
      }
    }

    final rawMsg = error.toString();
    if (rawMsg.contains('ROLE_ALREADY_CONFIRMED')) {
      return l10n.errorRoleAlreadyConfirmed;
    }
    if (error is StateError && error.message == 'MISSION_ALREADY_ACCEPTED') {
      return l10n.errorAlreadyDone;
    }

    if (error is StorageException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('bucket') && msg.contains('not found')) {
        return l10n.errorPhotoSaveFailed;
      }
      if (msg.contains('permission') || msg.contains('unauthorized')) {
        return l10n.errorPermissionDenied;
      }
      return l10n.errorUploadFailed;
    }

    if (error is MediaUploadException) {
      switch (error.code) {
        case MediaUploadErrorCode.bucketMissing:
          return l10n.errorPhotoSaveFailed;
        case MediaUploadErrorCode.bucketCheckFailed:
          return l10n.errorUploadFailed;
      }
    }

    if (error is PostgrestException) {
      if (error.code == '42501') return l10n.errorActionBlockedBySecurity;
      if (error.code == '23505') return l10n.errorAlreadyDone;
      return l10n.errorGenericTechnical;
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('timeout') ||
        raw.contains('network')) {
      return l10n.errorNetworkUnstable;
    }
    if (raw.contains('table') ||
        raw.contains('bucket') ||
        raw.contains('exception')) {
      return l10n.errorGenericTechnical;
    }
    return l10n.errorUnexpected;
  }

  /// Used by Flutter's ErrorWidget.builder, which has no BuildContext/locale
  /// access at the point it fires. This is a last-resort crash screen, so it
  /// stays as simple static copy rather than attempting a locale workaround.
  static Widget buildGlobalErrorWidget(FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF6F9F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error_outline,
                        size: 40, color: Color(0xFFB3261E)),
                    SizedBox(height: 10),
                    Text(
                      "Une erreur inattendue est survenue / Something went wrong",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Veuillez redémarrer l'écran. Si le problème persiste, vérifiez votre connexion internet.\n"
                      "Please restart the screen. If the problem persists, check your internet connection.",
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
