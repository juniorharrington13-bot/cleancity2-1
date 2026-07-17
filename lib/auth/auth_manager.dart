// Authentication Manager - Base interface for auth implementations
//
// This abstract class and mixins define the contract for authentication systems.
// Implement this with concrete classes for Firebase, Supabase, or local auth.
//
// Usage:
// 1. Create a concrete class extending AuthManager
// 2. Mix in the required authentication provider mixins
// 3. Implement all abstract methods with your auth provider logic

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef AuthUser = User;

// Core authentication operations that all auth implementations must provide
abstract class AuthManager {
  Future signOut();
  Future deleteUser(BuildContext context);
  Future updateEmail({required String email, required BuildContext context});
  Future resetPassword({required String email, required BuildContext context});

  /// Supabase handles email verification via Auth settings.
  /// This method can be used to resend verification emails when needed.
  Future resendEmailVerification({required String email});

  /// Returns the current authenticated Supabase user (if any).
  AuthUser? get currentUser;
}

// Email/password authentication mixin
mixin EmailSignInManager on AuthManager {
  Future<AuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  );

  Future<AuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  );
}

// Anonymous authentication for guest users
mixin AnonymousSignInManager on AuthManager {
  Future<AuthUser?> signInAnonymously(BuildContext context);
}

// Google Sign-In authentication (all platforms)
mixin GoogleSignInManager on AuthManager {
  Future<AuthUser?> signInWithGoogle(BuildContext context);
}

// JWT token authentication for custom backends
mixin JwtSignInManager on AuthManager {
  Future<AuthUser?> signInWithJwtToken(
    BuildContext context,
    String jwtToken,
  );
}

// Phone number authentication with SMS verification
mixin PhoneSignInManager on AuthManager {
  Future beginPhoneAuth({
    required BuildContext context,
    required String phoneNumber,
    required void Function(BuildContext) onCodeSent,
  });

  Future verifySmsCode({
    required BuildContext context,
    required String smsCode,
  });
}

// Facebook Sign-In authentication
mixin FacebookSignInManager on AuthManager {
  Future<AuthUser?> signInWithFacebook(BuildContext context);
}

// Microsoft Sign-In authentication (Azure AD)
mixin MicrosoftSignInManager on AuthManager {
  Future<AuthUser?> signInWithMicrosoft(
    BuildContext context,
    List<String> scopes,
    String tenantId,
  );
}

// GitHub Sign-In authentication (OAuth)
mixin GithubSignInManager on AuthManager {
  Future<AuthUser?> signInWithGithub(BuildContext context);
}

/// Supabase implementation (email/password) for Dreamflow projects.
class SupabaseAuthManager extends AuthManager with EmailSignInManager, GoogleSignInManager {
  SupabaseAuthManager({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _client.auth.currentUser;

  @override
  Future<AuthUser?> signInWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return res.user;
    } catch (e) {
      debugPrint('Supabase signInWithEmail failed: $e');
      rethrow;
    }
  }

  @override
  Future<AuthUser?> createAccountWithEmail(
    BuildContext context,
    String email,
    String password,
  ) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      return res.user;
    } catch (e) {
      debugPrint('Supabase createAccountWithEmail failed: $e');
      rethrow;
    }
  }

  @override
  Future signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut failed: $e');
      rethrow;
    }
  }

  @override
  Future deleteUser(BuildContext context) async {
    // Deleting a Supabase Auth user requires a service role key (server-side).
    // In-app we can only sign out; full deletion should be handled by an Edge Function.
    await signOut();
  }

  @override
  Future updateEmail({required String email, required BuildContext context}) async {
    try {
      await _client.auth.updateUser(UserAttributes(email: email));
    } catch (e) {
      debugPrint('Supabase updateEmail failed: $e');
      rethrow;
    }
  }

  @override
  Future resetPassword({required String email, required BuildContext context}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Supabase resetPassword failed: $e');
      rethrow;
    }
  }

  @override
  Future resendEmailVerification({required String email}) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      debugPrint('Supabase resendEmailVerification failed: $e');
      rethrow;
    }
  }

  // Mobile deep link callback registered in AndroidManifest.xml and Info.plist.
  static const String _oauthCallbackUrl = 'io.supabase.flutter://login-callback';

  String _webRedirectTo() {
    // Keep OAuth returning to the Login page (which listens to onAuthStateChange).
    // IMPORTANT: this exact URL must be added to Supabase Dashboard
    // Auth -> URL Configuration -> Additional Redirect URLs.
    final origin = Uri.base.origin;
    return '$origin/login';
  }

  @override
  Future<AuthUser?> signInWithGoogle(BuildContext context) async {
    try {
      // For OAuth flows, the session is established after the browser redirects back.
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? _webRedirectTo() : _oauthCallbackUrl,
      );
      return null;
    } catch (e) {
      debugPrint('Supabase signInWithGoogle failed: $e');
      rethrow;
    }
  }

  /// Sends an OTP SMS to a phone number in E.164 format (e.g. +2376XXXXXXXX).
  Future<void> sendPhoneOtp({required String phoneE164}) async {
    try {
      await _client.auth.signInWithOtp(phone: phoneE164);
    } catch (e) {
      debugPrint('Supabase sendPhoneOtp failed: $e');
      rethrow;
    }
  }

  /// Verifies the OTP and signs the user in.
  Future<AuthUser?> verifyPhoneOtp({required String phoneE164, required String code}) async {
    try {
      final res = await _client.auth.verifyOTP(phone: phoneE164, token: code, type: OtpType.sms);
      return res.user;
    } catch (e) {
      debugPrint('Supabase verifyPhoneOtp failed: $e');
      rethrow;
    }
  }

  /// Verifies the 6-digit code sent by [resetPassword] and signs the user in
  /// (recovery OTPs authenticate the user, same as a clicked reset link would).
  /// Requires the Supabase "Reset Password" email template to include
  /// `{{ .Token }}` so the user actually sees a code to type.
  Future<AuthUser?> verifyRecoveryOtp({required String email, required String code}) async {
    try {
      final res = await _client.auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
      return res.user;
    } catch (e) {
      debugPrint('Supabase verifyRecoveryOtp failed: $e');
      rethrow;
    }
  }

  /// Sets a new password for the currently authenticated session. Call this
  /// right after [verifyRecoveryOtp] succeeds.
  Future<void> updatePasswordAfterRecovery({required String newPassword}) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      debugPrint('Supabase updatePasswordAfterRecovery failed: $e');
      rethrow;
    }
  }
}
