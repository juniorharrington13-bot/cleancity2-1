import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/services/payout_request_service.dart';
import 'package:cleancity/theme.dart';

/// Bottom-sheet used to request a Mobile Money withdrawal.
///
/// This does not perform the real Mobile Money transfer; it creates a row in
/// `payout_requests` that an admin can later validate/pay.
class MobileMoneyWithdrawSheet extends StatefulWidget {
  const MobileMoneyWithdrawSheet({super.key, required this.onSuccess});

  final VoidCallback onSuccess;

  @override
  State<MobileMoneyWithdrawSheet> createState() => _MobileMoneyWithdrawSheetState();
}

class _MobileMoneyWithdrawSheetState extends State<MobileMoneyWithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  final _providers = const <String>[
    'Orange Money',
    'MTN Mobile Money',
  ];

  String _provider = 'Orange Money';
  bool _busy = false;

  String _normalizeCameroonPhone(String raw) {
    var s = raw.trim();
    s = s.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (s.startsWith('+')) s = s.substring(1);
    if (s.startsWith('237')) s = s.substring(3);
    return s;
  }

  String? _validateCameroonPhone(String? v) {
    final normalized = _normalizeCameroonPhone(v ?? '');
    if (normalized.isEmpty) return context.l10n.payoutInvalidPhone;
    if (!RegExp(r'^\d{9}$').hasMatch(normalized)) return context.l10n.payoutInvalidPhoneDigits;
    if (!normalized.startsWith('6')) return context.l10n.payoutInvalidPhoneStart;
    return null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final phone = _normalizeCameroonPhone(_phoneCtrl.text);
    final amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    setState(() => _busy = true);
    try {
      await PayoutRequestService().create(provider: _provider, phone: phone, amountXaf: amount);
      if (!mounted) return;
      widget.onSuccess();
      context.pop();
      AppSnackbars.success(context, context.l10n.payoutRequestSent);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().toLowerCase();
      final msg = raw.contains('payout_requests') || raw.contains('relation')
          ? context.l10n.errorPayoutUnavailable
          : AppErrorHandler.toUserMessage(context, e);
      AppSnackbars.error(context, msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 14 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(width: 44, height: 5, decoration: BoxDecoration(color: LightModeColors.lightSurfaceVariant, borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 14),
          Text(context.l10n.payoutSheetTitle, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(context.l10n.payoutSheetSubtitle, style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _provider,
                  items: _providers.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(growable: false),
                  onChanged: _busy ? null : (v) => setState(() => _provider = v ?? _provider),
                  decoration: InputDecoration(labelText: context.l10n.payoutOperatorLabel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: context.l10n.payoutPhoneLabel),
                  validator: _validateCameroonPhone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.l10n.payoutAmountLabel),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim()) ?? 0;
                    if (n <= 0) return context.l10n.payoutInvalidAmount;
                    if (n < 100) return context.l10n.payoutMinAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded, color: LightModeColors.lightOnPrimary),
                    label: Text(context.l10n.payoutSubmitButton, style: context.textStyles.titleSmall?.copyWith(color: LightModeColors.lightOnPrimary, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
