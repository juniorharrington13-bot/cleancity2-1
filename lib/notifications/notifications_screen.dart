import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cleancity/chat/chat_screens.dart';
import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/models/app_notification.dart';
import 'package:cleancity/services/notification_service.dart';
import 'package:cleancity/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = _service.listMine());

  Future<void> _markAllRead() async {
    try {
      await _service.markAllRead();
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      AppSnackbars.error(context, context.l10n.notificationsMarkAllReadFailed);
    }
  }

  Future<void> _onTap(AppNotification n) async {
    if (n.isUnread) {
      try {
        await _service.markRead(n.id);
      } catch (_) {
        // Non-fatal: the notification just stays visually unread.
      }
    }
    if (!mounted) return;

    if (n.type == 'chat_message' && n.relatedId != null) {
      context.push(ChatRoutes.room, extra: {'threadId': n.relatedId, 'requestId': null});
      return;
    }
    _reload();
  }

  IconData _iconForType(String type) {
    if (type.startsWith('wallet_topup')) return Icons.account_balance_wallet_outlined;
    if (type == 'wallet_payout_received') return Icons.payments_outlined;
    if (type.startsWith('payout_request')) return Icons.phone_iphone_outlined;
    if (type.startsWith('request_')) return Icons.local_shipping_outlined;
    if (type == 'chat_message') return Icons.chat_bubble_outline;
    return Icons.notifications_none;
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsTitle),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(context.l10n.notificationsMarkAllRead),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.paddingLg,
                children: [
                  Text(context.l10n.notificationsLoadFailed, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.l10n.commonRetry),
                  ),
                ],
              );
            }
            final items = snap.data ?? const <AppNotification>[];
            if (items.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AppSpacing.paddingLg,
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(context.l10n.notificationsEmptyTitle, style: context.textStyles.titleSmall),
                      ],
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.paddingLg,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => _onTap(n),
                  child: Container(
                    padding: AppSpacing.paddingMd,
                    decoration: BoxDecoration(
                      color: n.isUnread ? LightModeColors.lightPrimaryContainer.withValues(alpha: 0.35) : LightModeColors.lightSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: LightModeColors.lightSurfaceVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: LightModeColors.lightPrimaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_iconForType(n.type), color: LightModeColors.lightPrimary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(n.title,
                                        style: TextStyle(fontWeight: n.isUnread ? FontWeight.bold : FontWeight.w500)),
                                  ),
                                  if (n.isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: LightModeColors.lightError, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(n.body, style: context.textStyles.bodySmall),
                              const SizedBox(height: 6),
                              Text(_formatDate(n.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
