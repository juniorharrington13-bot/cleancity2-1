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
    await SupabaseConfig.initialize();
  } catch (e) {
    // Allow the app to boot even if Supabase init fails (e.g., transient web/network issues).
    debugPrint('Supabase initialization failed: $e');
  }

  // Push notifications (OneSignal). Safe no-op if not configured.
  await PushNotificationService.initialize();

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
