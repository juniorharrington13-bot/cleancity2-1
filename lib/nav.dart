import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/supabase/supabase_config.dart';
import 'auth/auth_screens.dart';
import 'generator/generator_screens.dart';
import 'collector/collector_screens.dart';
import 'center/center_screens.dart';
import 'admin/admin_screens.dart';
import 'chat/chat_screens.dart';
import 'notifications/notifications_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String phoneLogin = '/login/phone';
  static const String resetPassword = '/login/reset-password';
  static const String roleSelection = '/roles';
  
  static const String generatorDashboard = '/generator';
  static const String createRequest = '/generator/create';
  static const String requestDetails = '/generator/details';

  static const String collectorDashboard = '/collector';
  static const String missionDetails = '/collector/mission';

  static const String centerDashboard = '/center';
  static const String receptionForm = '/center/reception';

  static const String adminDashboard = '/admin';

  static const String notifications = '/notifications';

  // Chat
  static const String chatThreads = ChatRoutes.threads;
  static const String chatRoom = ChatRoutes.room;
}

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) async {
      final location = state.matchedLocation;

      // Admin is WEB ONLY.
      if (location.startsWith(AppRoutes.adminDashboard)) {
        if (!kIsWeb) return AppRoutes.roleSelection;

        // Require authentication.
        final authUser = SupabaseConfig.client.auth.currentUser;
        if (authUser == null) return AppRoutes.login;

        // Require application-level role = admin.
        try {
          final profile = await AppUserService().getCurrentProfile();
          if (profile?.role != 'admin') return AppRoutes.roleSelection;
        } catch (e) {
          debugPrint('Admin route guard: failed to load profile: $e');
          return AppRoutes.roleSelection;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.phoneLogin,
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.generatorDashboard,
        builder: (context, state) => const GeneratorDashboard(),
      ),
      GoRoute(
        path: AppRoutes.createRequest,
        builder: (context, state) => const CreateRequestScreen(),
      ),
      GoRoute(
        path: AppRoutes.requestDetails,
        builder: (context, state) => RequestDetailsScreen(requestId: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        path: AppRoutes.collectorDashboard,
        builder: (context, state) => const CollectorDashboard(),
      ),
      GoRoute(
        path: AppRoutes.missionDetails,
        builder: (context, state) => MissionDetailsScreen(requestId: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        path: AppRoutes.centerDashboard,
        builder: (context, state) => const CenterDashboard(),
      ),
      GoRoute(
        path: AppRoutes.receptionForm,
        builder: (context, state) => ReceptionFormScreen(requestId: state.extra is String ? state.extra as String : null),
      ),
      GoRoute(
        path: AppRoutes.adminDashboard,
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),

      GoRoute(
        path: AppRoutes.chatThreads,
        builder: (context, state) => const ChatThreadsScreen(),
      ),
      GoRoute(
        path: AppRoutes.chatRoom,
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            final threadId = extra['threadId']?.toString();
            final requestId = extra['requestId']?.toString();
            return ChatRoomScreen(threadId: threadId, requestId: requestId);
          }
          return const ChatRoomScreen(threadId: null, requestId: null);
        },
      ),
    ],
  );
}
