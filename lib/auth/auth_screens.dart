import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/auth/auth_manager.dart';
import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/models/app_user.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/locale_provider.dart';
import 'package:cleancity/services/push_notification_service.dart';
import 'package:cleancity/theme.dart';

/// Small "FR | EN" toggle for the pre-login auth screens, where there is no
/// user profile yet to read a saved language preference from.
class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    final current = context.watch<LocaleProvider>().locale.languageCode;
    return PopupMenuButton<String>(
      tooltip: 'FR / EN',
      initialValue: current,
      onSelected: (code) => context.read<LocaleProvider>().setLocale(code),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'fr', child: Text('Français')),
        PopupMenuItem(value: 'en', child: Text('English')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language),
            const SizedBox(width: 4),
            Text(current.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// --- SPLASH SCREEN ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _resolveNextRoute();
  }

  /// Supabase persists the session locally, so a returning signed-in user
  /// should never be bounced back to the login screen — send them straight
  /// to their dashboard (or role selection if they haven't picked one yet).
  Future<void> _resolveNextRoute() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) {
      context.go(AppRoutes.login);
      return;
    }

    try {
      final profile = await AppUserService().getCurrentProfile();
      if (!mounted) return;
      if (profile != null && profile.isRoleLocked) {
        context.go(_dashboardRouteForRole(profile.role));
      } else {
        context.go(AppRoutes.roleSelection);
      }
    } catch (e) {
      debugPrint('Splash: failed to resolve returning session: $e');
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(Icons.eco_rounded,
                size: 80, color: LightModeColors.lightPrimary),
            const SizedBox(height: 16),
            Text(
              'CLEANCITY',
              style: context.textStyles.headlineLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: LightModeColors.lightOnSurface,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              context.l10n.authSplashCountry,
              style: context.textStyles.headlineMedium?.copyWith(
                color: LightModeColors.lightPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.authSplashTagline,
              style: context.textStyles.labelSmall?.copyWith(
                color: LightModeColors.lightOnSurfaceVariant,
                letterSpacing: 2.0,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(context.l10n.authSplashInitializing,
                          style: context.textStyles.labelSmall?.copyWith(
                              color: LightModeColors.lightPrimary,
                              fontWeight: FontWeight.bold)),
                      Text('75%',
                          style: context.textStyles.labelSmall?.copyWith(
                              color: LightModeColors.lightOnSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.75,
                    backgroundColor: LightModeColors.lightPrimaryContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        LightModeColors.lightPrimary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: LightModeColors.lightPrimary),
                      const SizedBox(width: 4),
                      Text(context.l10n.authSplashMadeFor,
                          style: context.textStyles.labelSmall
                              ?.copyWith(color: LightModeColors.lightPrimary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

// --- LOGIN SCREEN ---
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Kept as a thin wrapper for stateful implementation.
    return const _LoginScreenBody();
  }
}

class _LoginScreenBody extends StatefulWidget {
  const _LoginScreenBody();

  @override
  State<_LoginScreenBody> createState() => _LoginScreenBodyState();
}

class _LoginScreenBodyState extends State<_LoginScreenBody> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  StreamSubscription<AuthState>? _authSub;
  bool _handledOAuthRedirect = false;

  @override
  void initState() {
    super.initState();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_handledOAuthRedirect) return;
      if (data.event != AuthChangeEvent.signedIn) return;
      final user = data.session?.user;
      if (user == null) return;

      _handledOAuthRedirect = true;
      try {
        await PushNotificationService.setExternalUserId(user.id);
        await PushNotificationService.requestPermission();
        await AppUserService().ensureProfileForAuthUser(user);
      } catch (e) {
        debugPrint('Post-OAuth login setup failed: $e');
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseAuthManager().signInWithGoogle(context);
      // Navigation will happen via onAuthStateChange after redirect.
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.errorGoogleSignInFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      AppSnackbars.warning(context, context.l10n.authFillEmailPassword);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = SupabaseAuthManager();
      final user = await auth.signInWithEmail(context, email, password);
      if (user != null) {
        await PushNotificationService.setExternalUserId(user.id);
        await PushNotificationService.requestPermission();
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.splash),
        ),
        title: Icon(Icons.eco, color: LightModeColors.lightPrimary),
        actions: const [_LanguageToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(context.l10n.authLoginTitle,
                  style: context.textStyles.headlineLarge),
              const SizedBox(height: 8),
              Text(context.l10n.authLoginSubtitle,
                  style: context.textStyles.bodyLarge
                      ?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
              const SizedBox(height: 48),
              Text(context.l10n.commonEmail,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: context.l10n.authEmailHint,
                  prefixIcon: Icon(Icons.person_outline,
                      color: LightModeColors.lightOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
              Text(context.l10n.commonPassword,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('login_pwd_${_obscurePassword ? '1' : '0'}'),
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: context.l10n.authPasswordHint,
                  prefixIcon: Icon(Icons.lock_outline,
                      color: LightModeColors.lightOnSurfaceVariant),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? context.l10n.commonShowPassword
                        : context.l10n.commonHidePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text(context.l10n.authForgotPassword,
                      style: TextStyle(
                          color: LightModeColors.lightPrimary,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLoading
                          ? context.l10n.authLoggingIn
                          : context.l10n.authLoginButton),
                      const SizedBox(width: 8),
                      Icon(_isLoading ? Icons.hourglass_top : Icons.login),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SocialAuthSection(
                isLoading: _isLoading,
                onGoogle: _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => context.push(AppRoutes.phoneLogin),
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(context.l10n.authLoginWithPhone),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.l10n.authNoAccountYet,
                      style: TextStyle(
                          color: LightModeColors.lightOnSurfaceVariant)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.signup),
                    child: Text(context.l10n.authSignUpLink,
                        style: TextStyle(
                            color: LightModeColors.lightPrimary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- SIGNUP SCREEN ---
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SignupScreenBody();
  }
}

// --- PHONE LOGIN (OTP) ---
class PhoneLoginScreen extends StatelessWidget {
  const PhoneLoginScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PhoneLoginBody();
}

class _PhoneLoginBody extends StatefulWidget {
  const _PhoneLoginBody();

  @override
  State<_PhoneLoginBody> createState() => _PhoneLoginBodyState();
}

class _PhoneLoginBodyState extends State<_PhoneLoginBody> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Normalizes user input to E.164.
  ///
  /// This screen targets Cameroon by default:
  /// - `6XXXXXXXX`  -> `+2376XXXXXXXX`
  /// - `2376...`    -> `+2376...` (avoids `+237237...`)
  /// - `+2376...`   -> `+2376...`
  /// - `002376...`  -> `+2376...`
  String _normalizeE164() {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) return '';

    var cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('00')) cleaned = '+${cleaned.substring(2)}';

    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1).replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? '' : '+$digits';
    }

    final digits = cleaned.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // If user already typed the country code (237...), don't double-prefix it.
    if (digits.startsWith('237')) return '+$digits';

    // Otherwise assume local CM number.
    return '+237$digits';
  }

  String _friendlyPhoneSendError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('sms')) {
      return context.l10n.errorSmsUnavailable;
    }
    return AppErrorHandler.toUserMessage(context, e);
  }

  Future<void> _sendCode() async {
    final phone = _normalizeE164();
    // Cameroon E.164 is typically +237 + 9 digits => 13 chars.
    if (phone.length < 12) {
      AppSnackbars.warning(context, context.l10n.authEnterValidPhone);
      return;
    }
    setState(() => _sending = true);
    try {
      await SupabaseAuthManager().sendPhoneOtp(phoneE164: phone);
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppSnackbars.success(context, context.l10n.authCodeSentSms);
    } catch (e) {
      debugPrint('Phone OTP send failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, _friendlyPhoneSendError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final phone = _normalizeE164();
    final code = _codeCtrl.text.trim();
    if (phone.isEmpty || code.length < 4) {
      AppSnackbars.warning(context, context.l10n.authEnterReceivedCode);
      return;
    }
    setState(() => _verifying = true);
    try {
      final user = await SupabaseAuthManager()
          .verifyPhoneOtp(phoneE164: phone, code: code);
      if (user != null) {
        await PushNotificationService.setExternalUserId(user.id);
        await PushNotificationService.requestPermission();
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Phone OTP verify failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.errorInvalidOrExpiredCode);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop())
              context.pop();
            else
              context.go(AppRoutes.login);
          },
        ),
        title: Text(context.l10n.authPhoneLoginTitle),
        actions: const [_LanguageToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Text(context.l10n.authPhoneNumberLabel,
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]')),
                _CameroonPhoneTypingFormatter(),
              ],
              decoration: InputDecoration(
                hintText: '+2376XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined,
                    color: LightModeColors.lightOnSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendCode,
                icon: Icon(_sending ? Icons.hourglass_top : Icons.sms_outlined),
                label: Text(_sending
                    ? context.l10n.authSendingCode
                    : context.l10n.authSendCodeButton),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 24),
              Text(context.l10n.authSmsCodeLabel,
                  style: context.textStyles.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '123456',
                  prefixIcon: Icon(Icons.lock_clock_outlined,
                      color: LightModeColors.lightOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verifying ? null : _verify,
                  icon: Icon(_verifying
                      ? Icons.hourglass_top
                      : Icons.verified_outlined),
                  label: Text(_verifying
                      ? context.l10n.authVerifying
                      : context.l10n.authValidateButton),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: _sending ? null : _sendCode,
                  child: Text(context.l10n.authResendCode)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _SignupScreenBody extends StatefulWidget {
  const _SignupScreenBody();

  @override
  State<_SignupScreenBody> createState() => _SignupScreenBodyState();
}

class _SignupScreenBodyState extends State<_SignupScreenBody> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _password2Ctrl = TextEditingController();

  String _city = 'Douala';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePassword2 = true;
  StreamSubscription<AuthState>? _authSub;
  bool _handledOAuthRedirect = false;

  static final RegExp _cmPhoneRegex = RegExp(r'^\+2376\d{8}$');

  @override
  void initState() {
    super.initState();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_handledOAuthRedirect) return;
      if (data.event != AuthChangeEvent.signedIn) return;
      final user = data.session?.user;
      if (user == null) return;

      _handledOAuthRedirect = true;
      try {
        await PushNotificationService.setExternalUserId(user.id);
        await PushNotificationService.requestPermission();
        await AppUserService().ensureProfileForAuthUser(user);
      } catch (e) {
        debugPrint('Post-OAuth signup setup failed: $e');
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _password2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _oauthGoogle() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await SupabaseAuthManager().signInWithGoogle(context);
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.errorGoogleSignInFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _toE164Cameroon(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    String normalized = digits.startsWith('237') ? digits.substring(3) : digits;
    if (normalized.startsWith('0')) normalized = normalized.substring(1);
    return '+237$normalized';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isLoading) return;

    final fullName = _fullNameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phoneRaw = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final password2 = _password2Ctrl.text;

    if (fullName.isEmpty ||
        email.isEmpty ||
        phoneRaw.isEmpty ||
        password.isEmpty) {
      AppSnackbars.warning(context, context.l10n.authFillRequiredFields);
      return;
    }
    if (password != password2) {
      AppSnackbars.warning(context, context.l10n.authPasswordsMismatch);
      return;
    }
    final phoneE164 = _toE164Cameroon(phoneRaw);
    if (!_cmPhoneRegex.hasMatch(phoneE164)) {
      AppSnackbars.warning(context, context.l10n.errorInvalidPhone);
      return;
    }
    final preferredLanguage =
        context.read<LocaleProvider>().locale.languageCode;

    setState(() => _isLoading = true);
    try {
      final auth = SupabaseAuthManager();
      final user = await auth.createAccountWithEmail(context, email, password);
      if (user == null) throw StateError('Signup succeeded but user is null');

      // When email confirmation is required, signUp() succeeds but leaves no
      // active session: any authenticated call (RLS requires auth.uid()) would
      // fail here. public.users already has a baseline row from the
      // on_auth_user_created trigger; skip the profile upsert until the user
      // confirms their email and actually logs in.
      if (Supabase.instance.client.auth.currentSession == null) {
        if (!mounted) return;
        AppSnackbars.success(
            context, context.l10n.authAccountCreatedCheckEmail);
        context.go(AppRoutes.login);
        return;
      }

      await PushNotificationService.setExternalUserId(user.id);
      await PushNotificationService.requestPermission();

      final userService = AppUserService();
      await userService.upsertProfile(
        userId: user.id,
        email: email,
        fullName: fullName,
        phoneE164: phoneE164,
        preferredLanguage: preferredLanguage,
        role: 'generator',
      );

      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Signup failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.login),
        ),
        title: Text(context.l10n.authSignupTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: const [_LanguageToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: LightModeColors.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Center(
                  child: Icon(Icons.eco_rounded,
                      size: 64,
                      color:
                          LightModeColors.lightPrimary.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                  child: Text(context.l10n.authSignupHeadline,
                      style: context.textStyles.headlineMedium)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  context.l10n.authSignupSubtitle,
                  style: context.textStyles.bodyMedium
                      ?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              _buildLabel(context.l10n.authFullNameLabel),
              TextField(
                  controller: _fullNameCtrl,
                  decoration: _inputDeco(
                      Icons.person_outline, context.l10n.authFullNameHint)),
              const SizedBox(height: 16),
              _buildLabel(context.l10n.authEmailAddressLabel),
              TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDeco(
                      Icons.email_outlined, context.l10n.authEmailHint)),
              const SizedBox(height: 16),
              _buildLabel(context.l10n.authPhoneNumberLabel),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CameroonLocalPhoneFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: context.l10n.authLocalPhoneHint,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag,
                            color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 4),
                        const Text('+237',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                            width: 1,
                            height: 20,
                            color: LightModeColors.lightOutline),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel(context.l10n.authCityLabel),
              DropdownButtonFormField<String>(
                decoration: _inputDeco(Icons.location_city_outlined,
                    context.l10n.authChooseCityHint),
                items: const [
                  DropdownMenuItem(value: 'Douala', child: Text('Douala')),
                  DropdownMenuItem(value: 'Yaoundé', child: Text('Yaoundé')),
                  DropdownMenuItem(
                      value: 'Bafoussam', child: Text('Bafoussam')),
                  DropdownMenuItem(value: 'Garoua', child: Text('Garoua')),
                ],
                value: _city,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _city = v);
                },
              ),
              const SizedBox(height: 16),
              _buildLabel(context.l10n.commonPassword),
              TextField(
                key: ValueKey('signup_pwd_${_obscurePassword ? '1' : '0'}'),
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: _inputDeco(Icons.lock_outline, '••••••••').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? context.l10n.commonShowPassword
                        : context.l10n.commonHidePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLabel(context.l10n.authConfirmPasswordLabel),
              TextField(
                key: ValueKey('signup_pwd2_${_obscurePassword2 ? '1' : '0'}'),
                controller: _password2Ctrl,
                obscureText: _obscurePassword2,
                enableSuggestions: false,
                autocorrect: false,
                decoration: _inputDeco(Icons.lock_outline, '••••••••').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword2
                        ? context.l10n.commonShowPassword
                        : context.l10n.commonHidePassword,
                    onPressed: () =>
                        setState(() => _obscurePassword2 = !_obscurePassword2),
                    icon: Icon(
                      _obscurePassword2
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: Text(_isLoading
                      ? context.l10n.authCreatingAccount
                      : context.l10n.authSignUpLink),
                ),
              ),
              const SizedBox(height: 16),
              SocialAuthSection(
                isLoading: _isLoading,
                onGoogle: _oauthGoogle,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.l10n.authAlreadyHaveAccount,
                      style: TextStyle(
                          color: LightModeColors.lightOnSurfaceVariant)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Text(context.l10n.authLoginButton,
                        style: TextStyle(
                            color: LightModeColors.lightPrimary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  InputDecoration _inputDeco(IconData icon, String hint) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: LightModeColors.lightOnSurfaceVariant),
    );
  }
}

class SocialAuthSection extends StatelessWidget {
  const SocialAuthSection({
    super.key,
    required this.isLoading,
    required this.onGoogle,
  });

  final bool isLoading;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider(height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(context.l10n.commonOr,
                  style: context.textStyles.labelMedium?.copyWith(
                      color: LightModeColors.lightOnSurfaceVariant,
                      fontWeight: FontWeight.w700)),
            ),
            const Expanded(child: Divider(height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded,
                color: LightModeColors.lightPrimary),
            label: Text(context.l10n.authContinueWithGoogle),
          ),
        ),
      ],
    );
  }
}

class _CameroonLocalPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 9 ? digits.substring(0, 9) : digits;
    final b = StringBuffer();
    for (int i = 0; i < clipped.length; i++) {
      b.write(clipped[i]);
      if (i == 2 || i == 5) b.write(' ');
    }
    final text = b.toString().trimRight();
    return TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

class _CameroonPhoneTypingFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.trim();
    if (raw.isEmpty) return newValue;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    String local = digits;
    if (digits.startsWith('237')) {
      local = digits.substring(3);
    }
    if (local.length > 9) local = local.substring(0, 9);
    final b = StringBuffer('+237');
    for (int i = 0; i < local.length; i++) {
      if (i == 0 || i == 3 || i == 6) b.write(i == 0 ? '' : ' ');
      b.write(local[i]);
    }
    final formatted = b.toString().trimRight();
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

String _dashboardRouteForRole(String role) {
  switch (role) {
    case 'collector':
      return AppRoutes.collectorDashboard;
    case 'center':
    case 'processing_center':
      return AppRoutes.centerDashboard;
    case 'admin':
      return AppRoutes.adminDashboard;
    case 'generator':
    default:
      return AppRoutes.generatorDashboard;
  }
}

// --- ROLE SELECTION SCREEN ---
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  late Future<AppUser?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AppUserService().getCurrentProfile();
  }

  Future<void> _openAdminIfAllowed(BuildContext context) async {
    try {
      final profile = await AppUserService().getCurrentProfile();
      if (profile?.role != 'admin') {
        if (!context.mounted) return;
        AppSnackbars.warning(context, context.l10n.authAccessDeniedNotAdmin);
        return;
      }
      if (context.mounted) context.go(AppRoutes.adminDashboard);
    } catch (e) {
      debugPrint('Open admin failed: $e');
      if (!context.mounted) return;
      AppSnackbars.error(context, context.l10n.errorCannotVerifyAdminRole);
    }
  }

  Future<void> _pickRole(String role) async {
    try {
      await AppUserService().updateRole(role);
    } catch (e) {
      debugPrint('Failed updating role: $e');
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
      return;
    }
    if (!mounted) return;
    context.go(_dashboardRouteForRole(role));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(context.l10n.authAppBarTitle,
            style: const TextStyle(fontSize: 14)),
        actions: const [_LanguageToggle()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: FutureBuilder<AppUser?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final profile = snapshot.data;
              if (profile != null && profile.isRoleLocked) {
                return _RoleLockedView(
                    profile: profile,
                    onOpenAdmin: () => _openAdminIfAllowed(context));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(context.l10n.authWelcomeTitle,
                      style: context.textStyles.headlineLarge),
                  const SizedBox(height: 8),
                  Text(context.l10n.authRoleQuestion,
                      style: context.textStyles.bodyLarge?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant)),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(context.l10n.authRoleChoiceFinalNotice,
                        textAlign: TextAlign.center,
                        style: context.textStyles.bodySmall?.copyWith(
                            color: LightModeColors.lightOnSurfaceVariant)),
                  ),
                  const SizedBox(height: 40),
                  _RoleCard(
                    icon: Icons.home_work_outlined,
                    title: context.l10n.authRoleGeneratorTitle,
                    subtitle: context.l10n.authRoleGeneratorSubtitle,
                    description: context.l10n.authRoleGeneratorDescription,
                    onTap: () => _pickRole('generator'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.local_shipping_outlined,
                    title: context.l10n.authRoleCollectorTitle,
                    subtitle: context.l10n.authRoleCollectorSubtitle,
                    description: context.l10n.authRoleCollectorDescription,
                    onTap: () => _pickRole('collector'),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    icon: Icons.factory_outlined,
                    title: context.l10n.authRoleCenterTitle,
                    subtitle: context.l10n.authRoleCenterSubtitle,
                    description: context.l10n.authRoleCenterDescription,
                    onTap: () => _pickRole('center'),
                  ),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () {},
                    child: Text(context.l10n.authNeedHelpChoosing,
                        style: TextStyle(
                            color: LightModeColors.lightOnSurfaceVariant,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleLockedView extends StatelessWidget {
  const _RoleLockedView({required this.profile, required this.onOpenAdmin});

  final AppUser profile;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.lock_outline, size: 48, color: LightModeColors.lightPrimary),
        const SizedBox(height: 16),
        Text(context.l10n.authRoleLockedTitle,
            style: context.textStyles.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: LightModeColors.lightPrimaryContainer,
              borderRadius: BorderRadius.circular(999)),
          child: Text(profile.roleLabel(context),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        Text(context.l10n.authRoleLockedSubtitle,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium
                ?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: () => context.go(_dashboardRouteForRole(profile.role)),
          icon: const Icon(Icons.arrow_forward),
          label: Text(context.l10n.authRoleLockedGoToDashboard),
        ),
        if (kIsWeb && profile.role == 'admin') ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(context.l10n.authRoleLockedOpenAdmin),
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: AppSpacing.paddingLg,
        decoration: BoxDecoration(
          color: LightModeColors.lightSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: LightModeColors.lightSurfaceVariant, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: LightModeColors.lightShadow,
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: LightModeColors.lightPrimaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: LightModeColors.lightPrimary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: context.textStyles.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: context.textStyles.labelSmall?.copyWith(
                          color: LightModeColors.lightPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: context.textStyles.bodyMedium?.copyWith(
                          color: LightModeColors.lightOnSurfaceVariant)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(context.l10n.authChooseArrow,
                        style: TextStyle(
                            color: LightModeColors.lightPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
