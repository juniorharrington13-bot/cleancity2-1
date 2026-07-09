import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:cleancity/supabase/supabase_config.dart';

class MediaUploadService {
  MediaUploadService({SupabaseClient? client}) : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  // Default bucket names expected by the app.
  // If your Supabase project uses different bucket names, you can either:
  // 1) Create buckets with these names in Supabase Storage, OR
  // 2) Rename them here.
  static const String userBucket = 'user_uploads';
  static const String requestBucket = 'request_photos';

  // Common alternative bucket names that teams often use.
  static const List<String> _userBucketFallbacks = <String>['avatars', 'uploads', 'public'];
  static const List<String> _requestBucketFallbacks = <String>['requests', 'uploads', 'public'];

  static DateTime? _bucketCacheAt;
  static List<Bucket>? _bucketCache;
  static const Duration _bucketCacheTtl = Duration(minutes: 5);

  Future<List<Bucket>> _listBucketsCached() async {
    final now = DateTime.now();
    final cachedAt = _bucketCacheAt;
    final cached = _bucketCache;
    if (cachedAt != null && cached != null && now.difference(cachedAt) <= _bucketCacheTtl) return cached;
    final buckets = await _client.storage.listBuckets();
    _bucketCacheAt = now;
    _bucketCache = buckets;
    return buckets;
  }

  Future<({String name, bool isPublic})> _pickBucket({required String preferred, required List<String> fallbacks}) async {
    try {
      final buckets = await _listBucketsCached();
      final names = <String>[preferred, ...fallbacks];
      for (final n in names) {
        final match = buckets.where((b) => b.name == n).firstOrNull;
        if (match != null) return (name: match.name, isPublic: match.public);
      }
      debugPrint('MediaUploadService._pickBucket: no bucket found among $names for "$preferred"');
      throw MediaUploadException(MediaUploadErrorCode.bucketMissing);
    } catch (e) {
      if (e is MediaUploadException) rethrow;
      debugPrint('MediaUploadService._pickBucket failed: $e');
      throw MediaUploadException(MediaUploadErrorCode.bucketCheckFailed);
    }
  }

  Future<String> _getAccessibleUrl({required String bucket, required String objectPath, required bool isPublic}) async {
    if (isPublic) return _client.storage.from(bucket).getPublicUrl(objectPath);
    try {
      // Private buckets require signed URLs.
      final signed = await _client.storage.from(bucket).createSignedUrl(objectPath, 60 * 60 * 24 * 365);
      return signed;
    } catch (e) {
      debugPrint('MediaUploadService._getAccessibleUrl failed: $e');
      // Fallback: return public URL even if it may not be accessible.
      return _client.storage.from(bucket).getPublicUrl(objectPath);
    }
  }

  Future<String> uploadUserAvatar(XFile file) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated');

    try {
      final bucket = await _pickBucket(preferred: userBucket, fallbacks: _userBucketFallbacks);
      final bytes = await file.readAsBytes();
      final ext = _guessExt(file.name, bytes);
      final objectPath = 'avatars/$uid/${DateTime.now().millisecondsSinceEpoch}_${_rand(6)}.$ext';
      final contentType = file.mimeType ?? lookupMimeType(file.name, headerBytes: bytes) ?? 'application/octet-stream';

      await _client.storage.from(bucket.name).uploadBinary(objectPath, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));
      return _getAccessibleUrl(bucket: bucket.name, objectPath: objectPath, isPublic: bucket.isPublic);
    } on StorageException catch (e) {
      // Common root causes:
      // - bucket doesn't exist
      // - bucket is private but you're using getPublicUrl
      // - missing storage policies (INSERT/UPDATE) for authenticated users
      debugPrint('MediaUploadService.uploadUserAvatar StorageException: statusCode=${e.statusCode} message=${e.message}');
      rethrow;
    } on MediaUploadException {
      rethrow;
    } catch (e) {
      debugPrint('MediaUploadService.uploadUserAvatar failed: $e');
      rethrow;
    }
  }

  Future<String> uploadWasteRequestPhoto({required String requestId, required XFile file}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not authenticated');

    try {
      final bucket = await _pickBucket(preferred: requestBucket, fallbacks: _requestBucketFallbacks);
      final bytes = await file.readAsBytes();
      final ext = _guessExt(file.name, bytes);
      final objectPath = 'requests/$requestId/$uid/${DateTime.now().millisecondsSinceEpoch}_${_rand(6)}.$ext';
      final contentType = file.mimeType ?? lookupMimeType(file.name, headerBytes: bytes) ?? 'application/octet-stream';

      await _client.storage.from(bucket.name).uploadBinary(objectPath, bytes, fileOptions: FileOptions(contentType: contentType, upsert: false));
      return _getAccessibleUrl(bucket: bucket.name, objectPath: objectPath, isPublic: bucket.isPublic);
    } on StorageException catch (e) {
      debugPrint('MediaUploadService.uploadWasteRequestPhoto StorageException: statusCode=${e.statusCode} message=${e.message}');
      rethrow;
    } on MediaUploadException {
      rethrow;
    } catch (e) {
      debugPrint('MediaUploadService.uploadWasteRequestPhoto failed: $e');
      rethrow;
    }
  }

  String _guessExt(String name, Uint8List bytes) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'heic';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    final mime = lookupMimeType(name, headerBytes: bytes);
    if (mime == null) return 'jpg';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    if (mime.contains('heic') || mime.contains('heif')) return 'heic';
    return 'jpg';
  }

  String _rand(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

/// Reasons an upload couldn't proceed. AppErrorHandler maps these to a
/// friendly, localized message — this layer never carries user-facing text.
enum MediaUploadErrorCode { bucketMissing, bucketCheckFailed }

/// Thrown when the app can't proceed with uploads due to missing buckets/config.
class MediaUploadException implements Exception {
  MediaUploadException(this.code);
  final MediaUploadErrorCode code;

  @override
  String toString() => 'MediaUploadException($code)';
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
