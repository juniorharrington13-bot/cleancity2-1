import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/services/media_upload_service.dart';

class AppErrorHandler {
  const AppErrorHandler._();

  static String toUserMessage(Object error) {
    if (error is AuthApiException) {
      final code = (error.code ?? '').toLowerCase();
      final msg = error.message.toLowerCase();
      if (code == 'email_exists' ||
          msg.contains('already registered') ||
          msg.contains('already been registered')) {
        return 'Cet email est deja utilise. Connectez-vous ou utilisez un autre email.';
      }
      if (code == 'weak_password' ||
          msg.contains('password should be at least') ||
          msg.contains('weak password')) {
        return 'Mot de passe trop faible. Utilisez au moins 8 caracteres.';
      }
      if (code == 'invalid_credentials' ||
          code == 'invalid_grant' ||
          msg.contains('invalid login credentials')) {
        return 'Email ou mot de passe invalide.';
      }
      if (msg.contains('phone')) {
        return 'Numero invalide. Utilisez le format +2376XXXXXXXX.';
      }
    }

    if (error is StorageException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('bucket') && msg.contains('not found')) {
        return 'Nous n avons pas pu enregistrer votre photo pour le moment. Reessayez dans un instant.';
      }
      if (msg.contains('permission') || msg.contains('unauthorized')) {
        return 'Vous n avez pas l autorisation pour cette action.';
      }
      return 'Le televersement de fichier a echoue. Verifiez votre connexion puis reessayez.';
    }

    if (error is MediaUploadException) return error.userMessage;

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('timeout') ||
        raw.contains('network')) {
      return 'Connexion instable. Verifiez internet puis reessayez.';
    }
    if (raw.contains('table') ||
        raw.contains('bucket') ||
        raw.contains('exception')) {
      return 'Une erreur technique est survenue. Reessayez dans quelques instants.';
    }
    return 'Oups, une erreur est survenue. Veuillez reessayer.';
  }

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
                      'Une erreur inattendue est survenue',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Veuillez redemarrer l ecran. Si le probleme persiste, verifiez votre connexion internet.',
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
