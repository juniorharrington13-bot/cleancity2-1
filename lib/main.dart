import 'dart:async';

import 'package:cleancity/nav.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/l10n/generated/app_localizations.dart';
import 'package:cleancity/services/locale_provider.dart';
import 'package:cleancity/supabase/supabase_config.dart';
import 'package:cleancity/services/push_notification_service.dart';
import 'package:cleancity/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Provider state management (LocaleProvider)
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = AppErrorHandler.buildGlobalErrorWidget;

  final localeProvider = LocaleProvider();
  await localeProvider.initialize();

  try {
    // Bounded: a stalled network call here must never hang first paint
    // indefinitely — better to boot with Supabase unavailable than not boot.
    await SupabaseConfig.initialize().timeout(const Duration(seconds: 8));
  } catch (e) {
    // Allow the app to boot even if Supabase init fails (e.g., transient web/network issues).
    debugPrint('Supabase initialization failed: $e');
  }

  // Push notifications (OneSignal): fire-and-forget. This talks to a
  // third-party service and must never block first paint — previously this
  // was awaited here, so a slow/unreachable OneSignal endpoint stalled the
  // entire app before runApp() ever ran.
  unawaited(PushNotificationService.initialize().catchError((e) {
    debugPrint('Push notification initialization failed: $e');
  }));

  runApp(MyApp(localeProvider: localeProvider));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.localeProvider});

  final LocaleProvider localeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, locale, _) => MaterialApp.router(
          title: 'CLEANCITY Cameroon',
          debugShowCheckedModeBanner: false,

          // Theme configuration
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: ThemeMode.system,

          // Localization: app language follows LocaleProvider, which is
          // wired to the user's saved preference / local choice.
          locale: locale.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,

          // Use context.go() or context.push() to navigate to the routes.
          routerConfig: AppRouter.router,
        ),
      ),
    );
  }
}
