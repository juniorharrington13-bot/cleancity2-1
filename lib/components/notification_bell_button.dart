import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cleancity/nav.dart';
import 'package:cleancity/services/notification_service.dart';
import 'package:cleancity/theme.dart';

/// Bell icon used on every dashboard AppBar: navigates to the notifications
/// list and shows a small unread-count badge, refreshed whenever the user
/// comes back from that screen.
class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _countFuture = NotificationService().unreadCount();
  }

  Future<void> _open() async {
    await context.push(AppRoutes.notifications);
    if (!mounted) return;
    setState(() => _countFuture = NotificationService().unreadCount());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: context.l10n.notificationsTitle,
              icon: const Icon(Icons.notifications_none),
              onPressed: _open,
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: const BoxDecoration(color: LightModeColors.lightError, borderRadius: BorderRadius.all(Radius.circular(999))),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
