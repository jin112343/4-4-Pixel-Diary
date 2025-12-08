import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/logger.dart';

/// オフラインキューのアイテム
class QueueItem {
  final String id;
  final String type;
  final String endpoint;
  final String method;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;

  QueueItem({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.method,
    this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  QueueItem copyWith({int? retryCount}) {
    return QueueItem(
      id: id,
      type: type,
      endpoint: endpoint,
      method: method,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'endpoint': endpoint,
        'method': method,
        'data': data,
        'createdAt': createdAt.toIso8601String(),
        'retryCount': retryCount,
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        id: json['id'] as String,
        type: json['type'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        data: json['data'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        retryCount: json['retryCount'] as int? ?? 0,
      );
}

/// キューの種類
class QueueType {
  static const String pixelArtExchange = 'pixel_art_exchange';
  static const String like = 'like';
  static const String comment = 'comment';
  static const String report = 'report';
}

/// オフラインキューを管理するサービス
class OfflineQueueService {
  static const String _boxName = 'offline_queue';
  static const int _maxRetries = 3;

  Box<String>? _box;

  /// 初期化
  Future<void> init() async {
    try {
      _box = await Hive.openBox<String>(_boxName);
      logger.i('OfflineQueueService initialized, items: ${_box?.length ?? 0}');
    } catch (e, stackTrace) {
      logger.e(
        'OfflineQueueService.init failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// キューにアイテムを追加
  Future<void> enqueue(QueueItem item) async {
    try {
      final jsonString = jsonEncode(item.toJson());
      await _box?.put(item.id, jsonString);
      logger.d('Enqueued item: ${item.type} (${item.id})');
    } catch (e, stackTrace) {
      logger.e(
        'OfflineQueueService.enqueue failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// キューからアイテムを取得（削除せず）
  List<QueueItem> getAll() {
    final items = <QueueItem>[];
    try {
      for (final jsonString in _box?.values ?? <String>[]) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        items.add(QueueItem.fromJson(json));
      }
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e, stackTrace) {
      logger.e(
        'OfflineQueueService.getAll failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
    return items;
  }

  /// 特定のタイプのアイテムを取得
  List<QueueItem> getByType(String type) {
    return getAll().where((item) => item.type == type).toList();
  }

  /// キューからアイテムを削除
  Future<void> remove(String id) async {
    try {
      await _box?.delete(id);
      logger.d('Removed item from queue: $id');
    } catch (e, stackTrace) {
      logger.e(
        'OfflineQueueService.remove failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// リトライ回数を更新
  Future<void> incrementRetry(String id) async {
    try {
      final jsonString = _box?.get(id);
      if (jsonString == null) return;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final item = QueueItem.fromJson(json);

      if (item.retryCount >= _maxRetries - 1) {
        await remove(id);
        logger.w('Item removed after max retries: $id');
      } else {
        final updatedItem = item.copyWith(retryCount: item.retryCount + 1);
        await _box?.put(id, jsonEncode(updatedItem.toJson()));
        logger.d('Incremented retry count for: $id');
      }
    } catch (e, stackTrace) {
      logger.e(
        'OfflineQueueService.incrementRetry failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// キューが空かどうか
  bool get isEmpty => (_box?.isEmpty ?? true);

  /// キュー内のアイテム数
  int get length => _box?.length ?? 0;

  /// すべてクリア
  Future<void> clear() async {
    await _box?.clear();
    logger.i('Offline queue cleared');
  }

  /// リソースを解放
  Future<void> close() async {
    await _box?.close();
  }
}
