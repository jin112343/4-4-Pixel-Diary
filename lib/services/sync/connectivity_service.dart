import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/utils/logger.dart';

/// ネットワーク接続状態を監視するサービス
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController = StreamController<bool>.broadcast();
  bool _isOnline = true;

  /// 現在のオンライン状態
  bool get isOnline => _isOnline;

  /// 接続状態の変更を監視するストリーム
  Stream<bool> get onStatusChange => _statusController.stream;

  /// 初期化
  Future<void> init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);

      _subscription = _connectivity.onConnectivityChanged.listen(
        _updateStatus,
        onError: (Object error, StackTrace stackTrace) {
          logger.e(
            'ConnectivityService.onConnectivityChanged error',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );

      logger.i('ConnectivityService initialized, isOnline: $_isOnline');
    } catch (e, stackTrace) {
      logger.e(
        'ConnectivityService.init failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (wasOnline != _isOnline) {
      logger.i('Connectivity changed: ${_isOnline ? "online" : "offline"}');
      _statusController.add(_isOnline);
    }
  }

  /// 現在の接続状態を確認
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
      return _isOnline;
    } catch (e, stackTrace) {
      logger.e(
        'ConnectivityService.checkConnectivity failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// リソースを解放
  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
