import 'dart:math';

/// Result of a simulated Mobile Money gateway call. `failureReasonCode` is a
/// stable code (not localized text) — the UI maps it to a translated string.
class SimulatedPaymentResult {
  const SimulatedPaymentResult({required this.success, required this.reference, this.failureReasonCode});

  final bool success;
  final String reference;
  final String? failureReasonCode;
}

/// Stands in for a real MTN/Orange Money merchant API integration, which
/// requires a lengthy administrative approval process to obtain. Simulates
/// the processing delay and generates a transaction reference the same way a
/// real operator would, with an occasional realistic failure.
class MobileMoneySimulatorService {
  static const _referencePrefixes = {
    'Orange Money': 'OM',
    'MTN Mobile Money': 'MTN',
  };

  static const _failureReasonCodes = [
    'insufficient_balance',
    'timeout',
    'incorrect_pin',
    'network_error',
  ];

  final Random _random = Random();

  Future<SimulatedPaymentResult> process({required String provider}) async {
    await Future.delayed(Duration(milliseconds: 1400 + _random.nextInt(1200)));

    final prefix = _referencePrefixes[provider] ?? 'MM';
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final suffix = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    final reference = '$prefix-$suffix';

    // ~90% success rate, similar to a real operator (occasional insufficient
    // balance / timeout / wrong PIN / network hiccup).
    final success = _random.nextDouble() < 0.9;
    if (success) {
      return SimulatedPaymentResult(success: true, reference: reference);
    }
    final code = _failureReasonCodes[_random.nextInt(_failureReasonCodes.length)];
    return SimulatedPaymentResult(success: false, reference: reference, failureReasonCode: code);
  }
}
