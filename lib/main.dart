import 'package:cleancity/nav.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/supabase/supabase_config.dart';
import 'package:cleancity/services/push_notification_service.dart';
import 'package:cleancity/theme.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Provider state management (ThemeProvider, CounterProvider)
/// - go_router navigation
/// - Material 3 theming with light/dark modes
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = AppErrorHandler.buildGlobalErrorWidget;

  MapboxOptions.setAccessToken(
    const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
  );

  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    // Allow the app to boot even if Supabase init fails (e.g., transient web/network issues).
    debugPrint('Supabase initialization failed: $e');
  }

  // Push notifications (OneSignal). Safe no-op if not configured.
  await PushNotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider wraps the app to provide state to all widgets
    // As you extend the app, use MultiProvider to wrap the app
    // and provide state to all widgets
    // Example:
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => ExampleProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Dreamflow Starter',
    //     debugShowCheckedModeBanner: false,
    //     routerConfig: AppRouter.router,
    //   ),
    // );
    return MaterialApp.router(
      title: 'CLEANCITY Cameroon',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,

      // Use context.go() or context.push() to navigate to the routes.
      routerConfig: AppRouter.router,
    );
  }
}
