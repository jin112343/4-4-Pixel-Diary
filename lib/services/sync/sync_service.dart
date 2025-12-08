import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/utils/logger.dart';
import '../../data/datasources/remote/api_client.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

/// 同期状態
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

/// オフラインデータの同期を管理するサービス
class SyncService {
  final ConnectivityService _connectivityService;
  final OfflineQueueService _offlineQueueService;
  final ApiClient _apiClient;

  SyncStatus _status = SyncStatus.idle;
  StreamSubscription<bool>? _connectivitySubscription;

  final _statusController = StreamController<SyncStatus>.broadcast();
  final _progressController = StreamController<double>.broadcast();

  /// 現在の同期状態
  SyncStatus get status => _status;

  /// 同期状態の変更を監視
  Stream<SyncStatus> get onStatusChange => _statusController.stream;

  /// 同期進捗を監視（0.0 - 1.0）
  Stream<double> get onProgress => _progressController.stream;

  SyncService({
    required ConnectivityService connectivityService,
    required OfflineQueueService offlineQueueService,
    required ApiClient apiClient,
  })  : _connectivityService = connectivityService,
        _offlineQueueService = offlineQueueService,
        _apiClient = apiClient;

  /// 初期化
  Future<void> init() async {
    _connectivitySubscription = _connectivityService.onStatusChange.listen(
      _onConnectivityChanged,
    );

    if (_connectivityService.isOnline && !_offlineQueueService.isEmpty) {
      await sync();
    }

    logger.i('SyncService initialized');
  }

  void _onConnectivityChanged(bool isOnline) {
    if (isOnline && !_offlineQueueService.isEmpty) {
      sync();
    }
  }

  /// 手動同期を実行
  Future<bool> sync() async {
    if (_status == SyncStatus.syncing) {
      logger.w('Sync already in progress');
      return false;
    }

    if (!_connectivityService.isOnline) {
      logger.w('Cannot sync: offline');
      return false;
    }

    if (_offlineQueueService.isEmpty) {
      logger.i('No items to sync');
      return true;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      final items = _offlineQueueService.getAll();
      final total = items.length;
      var processed = 0;
      var success = true;

      logger.i('Starting sync: $total items');

      for (final item in items) {
        try {
          await _processQueueItem(item);
          await _offlineQueueService.remove(item.id);
        } catch (e, stackTrace) {
          logger.e(
            'Failed to sync item: ${item.id}',
            error: e,
            stackTrace: stackTrace,
          );
          await _offlineQueueService.incrementRetry(item.id);
          success = false;
        }

        processed++;
        _progressController.add(processed / total);
      }

      _updateStatus(success ? SyncStatus.completed : SyncStatus.failed);
      logger.i('Sync completed: ${success ? "success" : "partial failure"}');

      return success;
    } catch (e, stackTrace) {
      logger.e('Sync failed', error: e, stackTrace: stackTrace);
      _updateStatus(SyncStatus.failed);
      return false;
    }
  }

  Future<void> _processQueueItem(QueueItem item) async {
    logger.d('Processing queue item: ${item.type} (${item.id})');

    switch (item.method.toUpperCase()) {
      case 'POST':
        await _apiClient.post<dynamic>(item.endpoint, data: item.data);
        break;
      case 'PUT':
        await _apiClient.put<dynamic>(item.endpoint, data: item.data);
        break;
      case 'DELETE':
        await _apiClient.delete<dynamic>(item.endpoint, data: item.data);
        break;
      default:
        throw Exception('Unsupported method: ${item.method}');
    }
  }

  void _updateStatus(SyncStatus status) {
    _status = status;
    _statusController.add(status);
  }

  /// リソースを解放
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
    _progressController.close();
  }
}

/// オフライン対応のリポジトリミックスイン
mixin OfflineSupport {
  OfflineQueueService get offlineQueueService;
  ConnectivityService get connectivityService;

  /// オフライン時はキューに追加、オンライン時は即時実行
  Future<T> executeWithOfflineSupport<T>({
    required String queueItemId,
    required String queueType,
    required String endpoint,
    required String method,
    Map<String, dynamic>? data,
    required Future<T> Function() onlineAction,
    required T Function() offlineResult,
  }) async {
    if (connectivityService.isOnline) {
      try {
        return await onlineAction();
      } on DioException catch (e) {
        if (_isNetworkError(e)) {
          await _enqueueRequest(
            queueItemId,
            queueType,
            endpoint,
            method,
            data,
          );
          return offlineResult();
        }
        rethrow;
      }
    } else {
      await _enqueueRequest(queueItemId, queueType, endpoint, method, data);
      return offlineResult();
    }
  }

  Future<void> _enqueueRequest(
    String id,
    String type,
    String endpoint,
    String method,
    Map<String, dynamic>? data,
  ) async {
    final item = QueueItem(
      id: id,
      type: type,
      endpoint: endpoint,
      method: method,
      data: data,
      createdAt: DateTime.now(),
    );
    await offlineQueueService.enqueue(item);
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}
