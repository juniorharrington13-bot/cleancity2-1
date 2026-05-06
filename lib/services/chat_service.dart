import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/supabase/supabase_config.dart';

class ChatService {
  ChatService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // --- Simulation fallback ---
  static final Map<String, List<Map<String, dynamic>>> _simMessagesByThread = {};
  static final Map<String, StreamController<List<Map<String, dynamic>>>> _simControllersByThread = {};

  static const Duration _pollInterval = Duration(seconds: 2);

  bool _isSimThread(String threadId) => threadId.startsWith('sim_');

  StreamController<List<Map<String, dynamic>>> _simController(String threadId) {
    return _simControllersByThread.putIfAbsent(threadId, () {
      final c = StreamController<List<Map<String, dynamic>>>.broadcast();
      // Emit initial state.
      c.add(List<Map<String, dynamic>>.from(_simMessagesByThread[threadId] ?? const []));
      return c;
    });
  }

  /// Returns an existing request thread, or creates one and ensures membership.
  Future<String> getOrCreateThreadForRequest({required String requestId}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    try {
      final existing = await _client.from('chat_threads').select('id').eq('request_id', requestId).maybeSingle();
      final threadId = existing != null ? (existing['id'] as String) : (await _client.from('chat_threads').insert({'request_id': requestId}).select('id').single())['id'] as String;

      // Ensure the current user is a member.
      await _client.from('chat_thread_members').upsert({'thread_id': threadId, 'user_id': uid});

      // Opportunistically add known members (generator + collector if available).
      final wr = await _client.from('waste_requests').select('generator_id').eq('id', requestId).maybeSingle();
      final generatorId = (wr?['generator_id'] ?? '').toString();
      if (generatorId.trim().isNotEmpty) await _client.from('chat_thread_members').upsert({'thread_id': threadId, 'user_id': generatorId});

      final pickup = await _client.from('pickups').select('collector_id').eq('request_id', requestId).maybeSingle();
      final collectorId = (pickup?['collector_id'] ?? '').toString();
      if (collectorId.trim().isNotEmpty) await _client.from('chat_thread_members').upsert({'thread_id': threadId, 'user_id': collectorId});

      return threadId;
    } catch (e) {
      // Simulation mode: still allow users to open chat even if chat tables/policies aren't deployed yet.
      debugPrint('ChatService.getOrCreateThreadForRequest failed, falling back to simulation: $e');
      final simThreadId = 'sim_${requestId.trim().isEmpty ? DateTime.now().millisecondsSinceEpoch : requestId}';
      _simMessagesByThread.putIfAbsent(simThreadId, () => <Map<String, dynamic>>[]);
      _simController(simThreadId);
      return simThreadId;
    }
  }

  /// Returns an existing direct thread with [otherUserId], or creates one.
  ///
  /// This enables “contact” flows even when there is no waste request context
  /// (e.g. Center → Collector).
  Future<String> getOrCreateDirectThread({required String otherUserId}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final other = otherUserId.trim();
    if (other.isEmpty) throw ArgumentError('otherUserId is empty');
    if (other == uid) throw ArgumentError('Cannot create a direct chat with yourself');

    // Deterministic key so the same 2 users always map to the same thread.
    final a = uid.compareTo(other) <= 0 ? uid : other;
    final b = uid.compareTo(other) <= 0 ? other : uid;
    final directKey = '${a}_$b';

    try {
      final existing = await _client.from('chat_threads').select('id').eq('kind', 'direct').eq('direct_key', directKey).maybeSingle();
      final threadId = existing != null
          ? (existing['id'] as String)
          : (await _client.from('chat_threads').insert({'kind': 'direct', 'direct_key': directKey}).select('id').single())['id'] as String;

      await _client.from('chat_thread_members').upsert({'thread_id': threadId, 'user_id': uid});
      await _client.from('chat_thread_members').upsert({'thread_id': threadId, 'user_id': other});
      return threadId;
    } catch (e) {
      debugPrint('ChatService.getOrCreateDirectThread failed, falling back to simulation: $e');
      final simThreadId = 'sim_direct_${directKey}_${DateTime.now().millisecondsSinceEpoch}';
      _simMessagesByThread.putIfAbsent(simThreadId, () => <Map<String, dynamic>>[]);
      _simController(simThreadId);
      return simThreadId;
    }
  }

  /// Streams messages for a thread (requires Realtime enabled on the table).
  Stream<List<Map<String, dynamic>>> streamMessages(String threadId) {
    // Realtime is great when enabled, but in many Supabase setups it is not
    // configured/published for the table. To ensure messages are always
    // preserved and readable, we default to polling.
    if (_isSimThread(threadId)) return _simController(threadId).stream;

    return _pollMessages(threadId);
  }

  Stream<List<Map<String, dynamic>>> _pollMessages(String threadId) async* {
    // Initial fetch
    try {
      yield await _fetchMessages(threadId);
    } catch (e) {
      debugPrint('ChatService.streamMessages initial fetch failed: $e');
      yield <Map<String, dynamic>>[];
    }

    while (true) {
      await Future<void>.delayed(_pollInterval);
      try {
        yield await _fetchMessages(threadId);
      } catch (e) {
        debugPrint('ChatService.streamMessages polling error: $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchMessages(String threadId) async {
    final rows = await _client
        .from('chat_messages')
        .select('id, thread_id, sender_id, body, created_at')
        .eq('thread_id', threadId)
        .order('created_at', ascending: true);
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> sendMessage({required String threadId, required String body}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('Not authenticated');
    final text = body.trim();
    if (text.isEmpty) return;
    try {
      if (_isSimThread(threadId)) {
        final list = _simMessagesByThread.putIfAbsent(threadId, () => <Map<String, dynamic>>[]);
        list.add({
          'id': 'sim_${DateTime.now().microsecondsSinceEpoch}',
          'thread_id': threadId,
          'sender_id': uid,
          'body': text,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        _simController(threadId).add(List<Map<String, dynamic>>.from(list));
        return;
      }
      await _client.from('chat_messages').insert({'thread_id': threadId, 'sender_id': uid, 'body': text});
    } catch (e) {
      // IMPORTANT:
      // We must not silently fall back to simulation for a real thread id.
      // Otherwise the UI will poll Supabase (real thread) while we append locally,
      // leading to “message sent but not visible”.
      debugPrint('ChatService.sendMessage failed: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listThreadsForCurrentUser() async {
    final uid = currentUserId;
    if (uid == null) return [];
    try {
      // 1) Find memberships.
      final memberships = await _client
          .from('chat_thread_members')
          // NOTE: keep this aligned with the deployed SQL schema.
          // Current schema: chat_threads(id, request_id, created_at)
          .select('thread_id, created_at, chat_threads(request_id, created_at)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      final rows = (memberships as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      return rows;
    } catch (e) {
      debugPrint('ChatService.listThreadsForCurrentUser failed: $e');
      rethrow;
    }
  }
}
