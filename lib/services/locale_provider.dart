import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cleancity/services/app_user_service.dart';

/// Tracks the app's current UI language and keeps it in sync with the
/// signed-in user's saved preference (users.preferred_language) and a local
/// cache so the choice survives restarts even before login.
class LocaleProvider extends ChangeNotifier {
  static const String _prefsKey = 'app_locale';
  static const Set<String> _supported = {'fr', 'en'};

  Locale _locale = const Locale('fr');
  Locale get locale => _locale;

  String _normalize(String? code) => _supported.contains(code) ? code! : 'fr';

  /// Must be awaited before `runApp()` so the first frame already has the
  /// right locale (no flash of the wrong language).
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_prefsKey);
    if (cached != null && _supported.contains(cached)) {
      _locale = Locale(cached);
      return;
    }
    final deviceCode = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _locale = Locale(deviceCode == 'en' ? 'en' : 'fr');
  }

  /// Called from language toggles (pre-login and the profile tab). When
  /// [persistToDb] is true, also saves the choice to the signed-in user's
  /// profile so it's remembered across devices.
  Future<void> setLocale(String languageCode, {bool persistToDb = false}) async {
    final code = _normalize(languageCode);
    final changed = code != _locale.languageCode;
    if (changed) {
      _locale = Locale(code);
      notifyListeners();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);

    if (persistToDb) {
      try {
        await AppUserService().updateProfile(preferredLanguage: code);
      } catch (e) {
        debugPrint('LocaleProvider: failed to persist preferredLanguage: $e');
      }
    }
  }

  /// Reconciles the local locale with a freshly-loaded user profile, without
  /// writing back to the DB (avoids a redundant write loop). Call this once
  /// a signed-in user's profile has been fetched.
  Future<void> syncFromProfile(String? dbLanguageCode) async {
    if (dbLanguageCode == null) return;
    final code = _normalize(dbLanguageCode);
    if (code == _locale.languageCode) return;
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
    notifyListeners();
  }
}
