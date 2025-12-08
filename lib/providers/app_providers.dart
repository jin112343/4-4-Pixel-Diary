import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/local/local_storage.dart';
import '../data/datasources/local/secure_storage.dart';
import '../data/datasources/remote/api_client.dart';
import '../data/repositories/album_repository_impl.dart';
import '../data/repositories/pixel_art_repository_impl.dart';
import '../domain/repositories/album_repository.dart';
import '../domain/repositories/pixel_art_repository.dart';
import '../services/auth/anonymous_auth_service.dart';

/// ローカルストレージプロバイダー
final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

/// セキュアストレージプロバイダー
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});

/// 匿名認証サービスプロバイダー
final authServiceProvider = Provider<AnonymousAuthService>((ref) {
  return AnonymousAuthService(
    localStorage: ref.watch(localStorageProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

/// APIクライアントプロバイダー
final apiClientProvider = Provider<ApiClient>((ref) {
  // デバイスIDは非同期で取得されるため、初期は null
  return ApiClient();
});

/// ドット絵リポジトリプロバイダー
final pixelArtRepositoryProvider = Provider<PixelArtRepository>((ref) {
  return PixelArtRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    localStorage: ref.watch(localStorageProvider),
  );
});

/// アルバムリポジトリプロバイダー
final albumRepositoryProvider = Provider.family<AlbumRepository, String>((ref, userId) {
  return AlbumRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    localStorage: ref.watch(localStorageProvider),
    userId: userId,
  );
});
