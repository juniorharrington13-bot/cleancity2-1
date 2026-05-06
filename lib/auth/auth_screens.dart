import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/auth/auth_manager.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/app_user_service.dart';
import 'package:cleancity/services/push_notification_service.dart';
import 'package:cleancity/theme.dart';

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
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.go(AppRoutes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(Icons.eco_rounded, size: 80, color: LightModeColors.lightPrimary),
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
              'Cameroun',
              style: context.textStyles.headlineMedium?.copyWith(
                color: LightModeColors.lightPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'COLLECTER • REVALORISER • PRÉSERVER',
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
                      Text('INITIALISATION', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
                      Text('75%', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: 0.75,
                    backgroundColor: LightModeColors.lightPrimaryContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(LightModeColors.lightPrimary),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: LightModeColors.lightPrimary),
                      const SizedBox(width: 4),
                      Text('Made for Cameroon', style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary)),
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

  String _friendlyLoginError(Object e) {
    // Supabase returns AuthApiException for most auth failures.
    if (e is AuthApiException) {
      final msg = e.message.toLowerCase();
      final code = (e.code ?? '').toLowerCase();
      final isInvalid = msg.contains('invalid login') ||
          msg.contains('invalid credentials') ||
          code == 'invalid_credentials' ||
          code == 'invalid_grant';
      if (isInvalid) return 'MOT DE PASSE OU EMAIL INVALIDE';
    }

    // Fallback: match common message substring patterns.
    final raw = e.toString().toLowerCase();
    if (raw.contains('invalid login') || raw.contains('invalid credentials') || raw.contains('invalid_grant')) {
      return 'MOT DE PASSE OU EMAIL INVALIDE';
    }

    return 'Connexion échouée. Veuillez réessayer.';
  }

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_handledOAuthRedirect) return;
      if (data.event != AuthChangeEvent.signedIn) return;
      final user = data.session?.user;
      if (user == null) return;

      _handledOAuthRedirect = true;
      try {
        await PushNotificationService.setExternalUserId(user.id);
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
      AppSnackbars.error(context, 'Connexion Google échouée.');
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
      AppSnackbars.warning(context, 'Veuillez remplir email et mot de passe.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = SupabaseAuthManager();
      final user = await auth.signInWithEmail(context, email, password);
      if (user != null) {
        await PushNotificationService.setExternalUserId(user.id);
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Login failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, _friendlyLoginError(e));
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Connexion', style: context.textStyles.headlineLarge),
              const SizedBox(height: 8),
              Text('Heureux de vous revoir sur CLEANCITY', style: context.textStyles.bodyLarge?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
              const SizedBox(height: 48),
              
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'votre@email.cm',
                  prefixIcon: Icon(Icons.person_outline, color: LightModeColors.lightOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Mot de passe', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('login_pwd_${_obscurePassword ? '1' : '0'}'),
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Entrez votre mot de passe',
                  prefixIcon: Icon(Icons.lock_outline, color: LightModeColors.lightOnSurfaceVariant),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                  child: Text('Mot de passe oublié ?', style: TextStyle(color: LightModeColors.lightPrimary, fontWeight: FontWeight.w600)),
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
                      Text(_isLoading ? 'Connexion...' : 'Se connecter'),
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
                  onPressed: _isLoading ? null : () => context.push(AppRoutes.phoneLogin),
                  icon: const Icon(Icons.sms_outlined),
                  label: const Text('Se connecter avec un numéro'),
                ),
              ),

              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Pas encore de compte ? ', style: TextStyle(color: LightModeColors.lightOnSurfaceVariant)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.signup),
                    child: Text("S'inscrire", style: TextStyle(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
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
    final msg = e.toString();
    if (msg.contains('Invalid phone number') || msg.contains('phone')) {
      return 'Numéro invalide. Exemple : +2376XXXXXXXX.';
    }
    if (msg.contains('SMS') || msg.contains('sms')) {
      return 'SMS indisponible pour le moment. Réessayez plus tard.';
    }
    return 'Impossible d’envoyer le code.';
  }

  Future<void> _sendCode() async {
    final phone = _normalizeE164();
    // Cameroon E.164 is typically +237 + 9 digits => 13 chars.
    if (phone.length < 12) {
      AppSnackbars.warning(context, 'Entrez un numéro valide.');
      return;
    }
    setState(() => _sending = true);
    try {
      await SupabaseAuthManager().sendPhoneOtp(phoneE164: phone);
      if (!mounted) return;
      setState(() => _codeSent = true);
      AppSnackbars.success(context, 'Code envoyé par SMS.');
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
      AppSnackbars.warning(context, 'Entrez le code reçu.');
      return;
    }
    setState(() => _verifying = true);
    try {
      final user = await SupabaseAuthManager().verifyPhoneOtp(phoneE164: phone, code: code);
      if (user != null) {
        await PushNotificationService.setExternalUserId(user.id);
      }
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Phone OTP verify failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Code invalide ou expiré.');
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
            if (context.canPop()) context.pop();
            else context.go(AppRoutes.login);
          },
        ),
        title: const Text('Connexion par téléphone'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 16),
            Text('Numéro', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '+2376XXXXXXXX',
                prefixIcon: Icon(Icons.phone_outlined, color: LightModeColors.lightOnSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendCode,
                icon: Icon(_sending ? Icons.hourglass_top : Icons.sms_outlined),
                label: Text(_sending ? 'Envoi...' : 'Envoyer le code'),
              ),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 24),
              Text('Code SMS', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '123456',
                  prefixIcon: Icon(Icons.lock_clock_outlined, color: LightModeColors.lightOnSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _verifying ? null : _verify,
                  icon: Icon(_verifying ? Icons.hourglass_top : Icons.verified_outlined),
                  label: Text(_verifying ? 'Vérification...' : 'Valider'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _sending ? null : _sendCode, child: const Text('Renvoyer le code')),
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

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_handledOAuthRedirect) return;
      if (data.event != AuthChangeEvent.signedIn) return;
      final user = data.session?.user;
      if (user == null) return;

      _handledOAuthRedirect = true;
      try {
        await PushNotificationService.setExternalUserId(user.id);
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
      AppSnackbars.error(context, 'Connexion Google échouée.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _toE164Cameroon(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final normalized = digits.startsWith('237') ? digits.substring(3) : digits;
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

    if (fullName.isEmpty || email.isEmpty || phoneRaw.isEmpty || password.isEmpty) {
      AppSnackbars.warning(context, 'Veuillez remplir tous les champs obligatoires.');
      return;
    }
    if (password != password2) {
      AppSnackbars.warning(context, 'Les mots de passe ne correspondent pas.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = SupabaseAuthManager();
      final user = await auth.createAccountWithEmail(context, email, password);
      if (user == null) throw StateError('Signup succeeded but user is null');

      await PushNotificationService.setExternalUserId(user.id);

      final userService = AppUserService();
      await userService.upsertProfile(
        userId: user.id,
        email: email,
        fullName: fullName,
        phoneE164: _toE164Cameroon(phoneRaw),
        preferredLanguage: 'fr',
        role: 'generator',
      );

      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    } catch (e) {
      debugPrint('Signup failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Inscription échouée.');
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
        title: const Text('Inscription', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  child: Icon(Icons.park_outlined, size: 64, color: LightModeColors.lightPrimary.withValues(alpha: 0.5)),
                ),
              ),
              const SizedBox(height: 24),
              Center(child: Text('Rejoignez-nous', style: context.textStyles.headlineMedium)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Contribuez à un Cameroun plus propre avec CLEANCITY', 
                  style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),

              _buildLabel('Nom complet'),
              TextField(controller: _fullNameCtrl, decoration: _inputDeco(Icons.person_outline, 'Ex: Jean-Paul Biya')),
              const SizedBox(height: 16),

              _buildLabel('Adresse Email'),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: _inputDeco(Icons.email_outlined, 'votre@email.cm')),
              const SizedBox(height: 16),

              _buildLabel('Numéro de téléphone'),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '6XX XXX XXX',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, color: Colors.green.shade800, size: 20),
                        const SizedBox(width: 4),
                        const Text('+237', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(width: 1, height: 20, color: LightModeColors.lightOutline),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Ville'),
              DropdownButtonFormField<String>(
                decoration: _inputDeco(Icons.location_city_outlined, 'Choisir votre ville'),
                items: const [
                  DropdownMenuItem(value: 'Douala', child: Text('Douala')),
                  DropdownMenuItem(value: 'Yaoundé', child: Text('Yaoundé')),
                  DropdownMenuItem(value: 'Bafoussam', child: Text('Bafoussam')),
                  DropdownMenuItem(value: 'Garoua', child: Text('Garoua')),
                ],
                value: _city,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _city = v);
                },
              ),
              const SizedBox(height: 16),

              _buildLabel('Mot de passe'),
              TextField(
                key: ValueKey('signup_pwd_${_obscurePassword ? '1' : '0'}'),
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                enableSuggestions: false,
                autocorrect: false,
                decoration: _inputDeco(Icons.lock_outline, '••••••••').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: LightModeColors.lightOnSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildLabel('Confirmer le mot de passe'),
              TextField(
                key: ValueKey('signup_pwd2_${_obscurePassword2 ? '1' : '0'}'),
                controller: _password2Ctrl,
                obscureText: _obscurePassword2,
                enableSuggestions: false,
                autocorrect: false,
                decoration: _inputDeco(Icons.lock_outline, '••••••••').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword2 ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                    onPressed: () => setState(() => _obscurePassword2 = !_obscurePassword2),
                    icon: Icon(
                      _obscurePassword2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
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
                  child: Text(_isLoading ? 'Création...' : "S'inscrire"),
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
                  Text('Déjà un compte ? ', style: TextStyle(color: LightModeColors.lightOnSurfaceVariant)),
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.login),
                    child: Text("Se connecter", style: TextStyle(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold)),
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
              child: Text('OU', style: context.textStyles.labelMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant, fontWeight: FontWeight.w700)),
            ),
            const Expanded(child: Divider(height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onGoogle,
            icon: const Icon(Icons.g_mobiledata_rounded, color: LightModeColors.lightPrimary),
            label: const Text('Continuer avec Google'),
          ),
        ),
      ],
    );
  }
}

// --- ROLE SELECTION SCREEN ---
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  Future<void> _openAdminIfAllowed(BuildContext context) async {
    try {
      final profile = await AppUserService().getCurrentProfile();
      if (profile?.role != 'admin') {
        if (!context.mounted) return;
        AppSnackbars.warning(context, "Accès refusé. Ce compte n'est pas administrateur.");
        return;
      }
      if (context.mounted) context.go(AppRoutes.adminDashboard);
    } catch (e) {
      debugPrint('Open admin failed: $e');
      if (!context.mounted) return;
      AppSnackbars.error(context, 'Impossible de vérifier le rôle admin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('CLEANCITY Cameroun', style: TextStyle(fontSize: 14)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text('Bienvenue !', style: context.textStyles.headlineLarge),
              const SizedBox(height: 8),
              Text('Quel est votre rôle dans l\'écosystème ?', style: context.textStyles.bodyLarge?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
              const SizedBox(height: 40),

               _RoleCard(
                icon: Icons.home_work_outlined,
                title: 'Générateur',
                subtitle: 'PARTICULIER OU ENTREPRISE',
                description: 'Je souhaite faire enlever mes déchets.',
                 onTap: () async {
                   try {
                     await AppUserService().updateRole('generator');
                   } catch (e) {
                     debugPrint('Failed updating role: $e');
                   }
                   if (context.mounted) context.go(AppRoutes.generatorDashboard);
                 },
              ),
              const SizedBox(height: 16),

              _RoleCard(
                icon: Icons.local_shipping_outlined,
                title: 'Collecteur',
                subtitle: 'SERVICE DE TRANSPORT',
                description: 'Je collecte et transporte les déchets.',
                 onTap: () async {
                   try {
                     await AppUserService().updateRole('collector');
                   } catch (e) {
                     debugPrint('Failed updating role: $e');
                   }
                   if (context.mounted) context.go(AppRoutes.collectorDashboard);
                 },
              ),
              const SizedBox(height: 16),

              _RoleCard(
                icon: Icons.factory_outlined,
                title: 'Centre de Revalorisation',
                subtitle: 'TRAITEMENT DES DÉCHETS',
                description: 'Je traite et transforme les déchets.',
                 onTap: () async {
                   try {
                     await AppUserService().updateRole('center');
                   } catch (e) {
                     debugPrint('Failed updating role: $e');
                   }
                   if (context.mounted) context.go(AppRoutes.centerDashboard);
                 },
              ),
              const SizedBox(height: 32),

              if (kIsWeb) ...[
                FutureBuilder(
                  future: AppUserService().getCurrentProfile(),
                  builder: (context, snapshot) {
                    final role = snapshot.data?.role;
                    if (role != 'admin') return const SizedBox.shrink();
                    return Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: AppSpacing.paddingLg,
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: LightModeColors.lightSurfaceVariant, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(color: LightModeColors.lightSurface, shape: BoxShape.circle),
                                child: const Icon(Icons.admin_panel_settings_outlined, color: LightModeColors.lightPrimary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Administration (Web)', style: context.textStyles.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('Accès réservé aux administrateurs', style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                                  ],
                                ),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openAdminIfAllowed(context),
                                icon: const Icon(Icons.open_in_new, color: LightModeColors.lightOnPrimary),
                                label: const Text('Ouvrir', style: TextStyle(color: LightModeColors.lightOnPrimary)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  },
                ),
              ],

              TextButton(
                onPressed: () {},
                child: Text('Besoin d\'aide pour choisir ? Contactez-nous', style: TextStyle(color: LightModeColors.lightOnSurfaceVariant, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
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
          border: Border.all(color: LightModeColors.lightSurfaceVariant, width: 1.5),
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
                  Text(title, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: context.textStyles.labelSmall?.copyWith(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text(description, style: context.textStyles.bodyMedium?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('CHOISIR >', style: TextStyle(color: LightModeColors.lightPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
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
