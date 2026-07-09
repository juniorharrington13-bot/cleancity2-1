import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Supabase configuration — values injected at build time via --dart-define.
/// Never hardcode secrets here; see step 3 of the migration for the env setup.
class SupabaseConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ixrebfrxhfapndprujvt.supabase.co',
  );
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: anonKey,
      debug: kDebugMode,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
}

/// Generic database service for CRUD operations
class SupabaseService {
  /// Select multiple records from a table
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? select,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      // Apply filters
      if (filters != null) {
        for (final entry in filters.entries) {
          query = query.eq(entry.key, entry.value);
        }
      }

      // Apply ordering
      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      // Apply limit
      if (limit != null) {
        query = query.limit(limit);
      }

      return await query;
    } catch (e) {
      _logDatabaseError('select', table, e);
      rethrow;
    }
  }

  /// Select a single record from a table
  static Future<Map<String, dynamic>?> selectSingle(
    String table, {
    String? select,
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).select(select ?? '*');

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.maybeSingle();
    } catch (e) {
      _logDatabaseError('selectSingle', table, e);
      rethrow;
    }
  }

  /// Insert a record into a table
  static Future<List<Map<String, dynamic>>> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      _logDatabaseError('insert', table, e);
      rethrow;
    }
  }

  /// Insert multiple records into a table
  static Future<List<Map<String, dynamic>>> insertMultiple(
    String table,
    List<Map<String, dynamic>> data,
  ) async {
    try {
      return await SupabaseConfig.client.from(table).insert(data).select();
    } catch (e) {
      _logDatabaseError('insertMultiple', table, e);
      rethrow;
    }
  }

  /// Update records in a table
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).update(data);

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      return await query.select();
    } catch (e) {
      _logDatabaseError('update', table, e);
      rethrow;
    }
  }

  /// Delete records from a table
  static Future<void> delete(
    String table, {
    required Map<String, dynamic> filters,
  }) async {
    try {
      dynamic query = SupabaseConfig.client.from(table).delete();

      for (final entry in filters.entries) {
        query = query.eq(entry.key, entry.value);
      }

      await query;
    } catch (e) {
      _logDatabaseError('delete', table, e);
      rethrow;
    }
  }

  /// Get direct table reference for complex queries
  static SupabaseQueryBuilder from(String table) =>
      SupabaseConfig.client.from(table);

  /// Logs technical detail for diagnostics. Callers rethrow the original
  /// exception so AppErrorHandler.toUserMessage can map it to a friendly,
  /// localized message — this layer never builds user-facing text.
  static void _logDatabaseError(String operation, String table, dynamic error) {
    debugPrint('Supabase $operation on $table failed: $error');
  }
}
