import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/constants/waste_rates.dart';
import 'package:cleancity/supabase/supabase_config.dart';

/// Reads/writes admin-configurable app settings stored in `app_settings`
/// (key/value jsonb rows). Falls back to the hardcoded defaults in
/// `constants/waste_rates.dart` if the table is empty or unreachable, so the
/// rest of the app keeps working even before an admin has ever saved anything.
class AppSettingsService {
  AppSettingsService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  static const _wasteRatesKey = 'waste_rates_xaf_per_kg';
  static const _recoveryGoalKey = 'recovery_rate_goal_percent';

  Future<Map<String, int>> getWasteRates() async {
    try {
      final row = await _client.from('app_settings').select('value').eq('key', _wasteRatesKey).maybeSingle();
      final value = row?['value'];
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), (v is num ? v.toInt() : int.tryParse('$v')) ?? 0));
      }
    } catch (e) {
      debugPrint('AppSettingsService.getWasteRates failed, using defaults: $e');
    }
    return Map<String, int>.from(wasteXafPerKg);
  }

  Future<void> updateWasteRates(Map<String, int> rates) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('app_settings').upsert({
      'key': _wasteRatesKey,
      'value': rates,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': uid,
    });
  }

  Future<double> getRecoveryGoalPercent() async {
    try {
      final row = await _client.from('app_settings').select('value').eq('key', _recoveryGoalKey).maybeSingle();
      final value = row?['value'];
      if (value is num) return value.toDouble();
      final parsed = double.tryParse('$value');
      if (parsed != null) return parsed;
    } catch (e) {
      debugPrint('AppSettingsService.getRecoveryGoalPercent failed, using default: $e');
    }
    return 70;
  }

  Future<void> updateRecoveryGoalPercent(double percent) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('app_settings').upsert({
      'key': _recoveryGoalKey,
      'value': percent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'updated_by': uid,
    });
  }
}
