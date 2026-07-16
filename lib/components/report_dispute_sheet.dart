import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cleancity/components/app_error_handler.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/services/dispute_service.dart';
import 'package:cleancity/theme.dart';

/// Bottom-sheet used by any request participant (generator/collector/center)
/// to flag a problem with a request — e.g. a collector no-show, a
/// under-reported weight, a payment issue. Purely informational: filing a
/// dispute never changes the request's status or blocks anyone's flow: an
/// admin reviews it separately.
class ReportDisputeSheet extends StatefulWidget {
  const ReportDisputeSheet({super.key, required this.requestId, this.againstUserId});

  final String requestId;
  final String? againstUserId;

  @override
  State<ReportDisputeSheet> createState() => _ReportDisputeSheetState();
}

class _ReportDisputeSheetState extends State<ReportDisputeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionCtrl = TextEditingController();
  String _category = 'no_show';
  bool _busy = false;

  List<(String, String)> _categories(BuildContext context) => [
        ('no_show', context.l10n.disputeCategoryNoShow),
        ('weight_mismatch', context.l10n.disputeCategoryWeightMismatch),
        ('payment_issue', context.l10n.disputeCategoryPaymentIssue),
        ('other', context.l10n.disputeCategoryOther),
      ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await DisputeService().create(
        requestId: widget.requestId,
        category: _category,
        description: _descriptionCtrl.text.trim(),
        againstUserId: widget.againstUserId,
      );
      if (!mounted) return;
      context.pop();
      AppSnackbars.success(context, context.l10n.disputeSubmitSuccess);
    } catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, AppErrorHandler.toUserMessage(context, e));
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
            child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: LightModeColors.lightSurfaceVariant, borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 14),
          Text(context.l10n.disputeSheetTitle, style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(context.l10n.disputeSheetSubtitle,
              style: context.textStyles.bodySmall?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  items: _categories(context)
                      .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, overflow: TextOverflow.ellipsis)))
                      .toList(growable: false),
                  onChanged: _busy ? null : (v) => setState(() => _category = v ?? _category),
                  decoration: InputDecoration(labelText: context.l10n.disputeCategoryLabel),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  enabled: !_busy,
                  maxLines: 4,
                  decoration: InputDecoration(labelText: context.l10n.disputeDescriptionLabel),
                  validator: (v) => (v ?? '').trim().isEmpty ? context.l10n.disputeDescriptionRequired : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _submit,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.flag_outlined, color: LightModeColors.lightOnPrimary),
                    label: Text(context.l10n.disputeSubmitButton,
                        style: context.textStyles.titleSmall
                            ?.copyWith(color: LightModeColors.lightOnPrimary, fontWeight: FontWeight.bold)),
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
