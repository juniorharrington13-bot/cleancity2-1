import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/services/app_settings_service.dart';
import 'package:cleancity/supabase/supabase_config.dart';

class GeneratorEcoBalance {
  const GeneratorEcoBalance({
    required this.totalPoints,
    required this.availableXaf,
  });

  final int totalPoints;
  final int availableXaf;
}

/// Computes a generator's accumulated eco-points and how much of that is
/// currently redeemable as a Mobile Money withdrawal (via the shared
/// `payout_requests` flow, same as collectors).
class EcoPointsService {
  EcoPointsService({SupabaseClient? client, AppSettingsService? settings})
      : _client = client ?? SupabaseConfig.client,
        _settings = settings ?? AppSettingsService();

  final SupabaseClient _client;
  final AppSettingsService _settings;

  Future<GeneratorEcoBalance> getBalanceForCurrentGenerator() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const GeneratorEcoBalance(totalPoints: 0, availableXaf: 0);

    try {
      final pointRowsFuture = _client
          .from('eco_transactions')
          .select('points')
          .eq('user_id', uid)
          .eq('reason', 'generator_participation');
      final payoutRowsFuture = _client
          .from('payout_requests')
          .select('amount_xaf')
          .eq('user_id', uid)
          .neq('status', 'rejected');
      final payoutSettingsFuture = _settings.getGeneratorPointsPayout();

      final pointRows = await pointRowsFuture;
      final payoutRows = await payoutRowsFuture;
      final (thresholdPoints, amountXaf) = await payoutSettingsFuture;

      final totalPoints = pointRows.fold<num>(0, (sum, row) => sum + ((row)['points'] as num? ?? 0)).toInt();
      final alreadyRequestedXaf =
          payoutRows.fold<num>(0, (sum, row) => sum + ((row)['amount_xaf'] as num? ?? 0)).toInt();
      final earnedXaf = thresholdPoints > 0 ? (totalPoints ~/ thresholdPoints) * amountXaf : 0;
      final availableXaf = (earnedXaf - alreadyRequestedXaf).clamp(0, earnedXaf);

      return GeneratorEcoBalance(totalPoints: totalPoints, availableXaf: availableXaf);
    } catch (e) {
      debugPrint('EcoPointsService.getBalanceForCurrentGenerator failed: $e');
      rethrow;
    }
  }
}
