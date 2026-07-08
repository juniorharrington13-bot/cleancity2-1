import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/components/app_snackbars.dart';
import 'package:cleancity/nav.dart';
import 'package:cleancity/services/chat_service.dart';
import 'package:cleancity/theme.dart';

class ChatRoutes {
  static const String threads = '/chat';
  static const String room = '/chat/room';
}

/// Simple threads list for the current user.
class ChatThreadsScreen extends StatefulWidget {
  const ChatThreadsScreen({super.key});

  @override
  State<ChatThreadsScreen> createState() => _ChatThreadsScreenState();
}

class _ChatThreadsScreenState extends State<ChatThreadsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChatService().listThreadsForCurrentUser();
  }

  Future<void> _refresh() async =>
      setState(() => _future = ChatService().listThreadsForCurrentUser());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Chat',
                  style: context.textStyles.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                  onPressed: _refresh,
                  icon:
                      Icon(Icons.refresh, color: LightModeColors.lightPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting)
                return const LinearProgressIndicator();
              if (snap.hasError) {
                return _ChatEmptyState(
                  title: 'Chat indisponible',
                  subtitle:
                      'Impossible de charger les conversations pour le moment. Réessayez dans quelques instants.',
                );
              }
              final rows = snap.data ?? const <Map<String, dynamic>>[];
              if (rows.isEmpty) {
                return const _ChatEmptyState(
                    title: 'Aucune conversation',
                    subtitle:
                        'Ouvrez une demande puis cliquez sur “Chat”, ou utilisez “Contacter” depuis une fiche.');
              }

              return Column(
                children: rows.map((r) {
                  final thread = r['chat_threads'] as Map<String, dynamic>?;
                  final requestId = (thread?['request_id'] ?? '').toString();
                  final threadCreatedAt =
                      (thread?['created_at'] ?? '').toString();
                  final threadId = (r['thread_id'] ?? '').toString();

                  final title = requestId.trim().isNotEmpty
                      ? 'Demande ${requestId.substring(0, 8).toUpperCase()}'
                      : 'Conversation';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () {
                        if (threadId.trim().isEmpty) return;
                        context.push(ChatRoutes.room, extra: {
                          'threadId': threadId,
                          'requestId': requestId
                        });
                      },
                      child: Container(
                        padding: AppSpacing.paddingLg,
                        decoration: BoxDecoration(
                            color: LightModeColors.lightSurface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                                color: LightModeColors.lightSurfaceVariant)),
                        child: Row(
                          children: [
                            const CircleAvatar(
                                backgroundColor:
                                    LightModeColors.lightPrimaryContainer,
                                child: Icon(Icons.forum_outlined,
                                    color: LightModeColors.lightPrimary)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: context.textStyles.titleSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(threadCreatedAt,
                                        style: context.textStyles.bodySmall
                                            ?.copyWith(
                                                color: LightModeColors
                                                    .lightOnSurfaceVariant)),
                                  ]),
                            ),
                            Icon(Icons.chevron_right,
                                color: Theme.of(context).colorScheme.onSurface),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen(
      {super.key, required this.threadId, required this.requestId});
  final String? threadId;
  final String? requestId;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final threadId = widget.threadId;
    if (threadId == null || threadId.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await ChatService()
          .sendMessage(threadId: threadId, body: _controller.text);
      _controller.clear();
    } catch (e) {
      debugPrint('Send message failed: $e');
      if (!mounted) return;
      AppSnackbars.error(context, 'Envoi du message échoué.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final threadId = widget.threadId;
    final title =
        widget.requestId != null && widget.requestId!.trim().isNotEmpty
            ? 'Chat • ${widget.requestId!.substring(0, 8).toUpperCase()}'
            : 'Chat';
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
            if (context.canPop())
              context.pop();
            else
              context.go(AppRoutes.roleSelection);
          },
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: threadId == null
                ? const _ChatEmptyState(
                    title: 'Conversation introuvable',
                    subtitle: 'Identifiant de conversation manquant.')
                : StreamBuilder(
                    stream: ChatService().streamMessages(threadId),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const _ChatEmptyState(
                            title: 'Chat indisponible',
                            subtitle:
                                'Impossible de charger les messages pour le moment.');
                      }
                      final msgs = snap.data ?? const <Map<String, dynamic>>[];
                      if (msgs.isEmpty) {
                        return const _ChatEmptyState(
                            title: 'Dites bonjour',
                            subtitle: 'Envoyez le premier message.');
                      }
                      final uid = Supabase.instance.client.auth.currentUser?.id;
                      return ListView.builder(
                        padding: AppSpacing.paddingLg,
                        itemCount: msgs.length,
                        itemBuilder: (context, i) {
                          final m = msgs[i];
                          final senderId = (m['sender_id'] ?? '').toString();
                          final body = (m['body'] ?? '').toString();
                          final mine = uid != null && senderId == uid;
                          return _ChatBubble(body: body, mine: mine);
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.paddingLg,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                          hintText: 'Ecrire un message...',
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.lg))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: Icon(Icons.send,
                        color: _sending
                            ? Colors.grey
                            : LightModeColors.lightPrimary),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.body, required this.mine});
  final String body;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final bg = mine
        ? LightModeColors.lightPrimaryContainer
        : LightModeColors.lightSurface;
    final fg = mine
        ? LightModeColors.lightPrimary
        : Theme.of(context).colorScheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LightModeColors.lightSurfaceVariant)),
        child: Text(body,
            style: context.textStyles.bodyMedium?.copyWith(color: fg)),
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
                backgroundColor: LightModeColors.lightPrimaryContainer,
                radius: 28,
                child: Icon(Icons.forum_outlined,
                    color: LightModeColors.lightPrimary, size: 28)),
            const SizedBox(height: 12),
            Text(title,
                style: context.textStyles.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall
                    ?.copyWith(color: LightModeColors.lightOnSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
