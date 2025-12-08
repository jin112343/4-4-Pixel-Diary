import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../core/utils/logger.dart';
import 'ble_constants.dart';

/// ペアリング認証の状態
enum PairingState {
  /// 未ペアリング
  notPaired,

  /// ペアリング開始
  initiating,

  /// コード表示中（Numeric Comparison）
  displayingCode,

  /// コード入力待ち（Passkey Entry）
  awaitingPasskey,

  /// 認証確認中
  verifying,

  /// ペアリング完了
  paired,

  /// ペアリング失敗
  failed,
}

/// ペアリング認証の種類
enum PairingMethod {
  /// 数値比較（両方のデバイスに同じ数字を表示）
  numericComparison,

  /// パスキー入力（片方のデバイスにコードを表示、もう片方で入力）
  passkeyEntry,
}

/// ペアリング情報
class PairingInfo {
  const PairingInfo({
    required this.deviceId,
    required this.pairingCode,
    required this.method,
    required this.expiresAt,
    this.isInitiator = false,
  });

  final String deviceId;
  final String pairingCode;
  final PairingMethod method;
  final DateTime expiresAt;
  final bool isInitiator;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// BLEペアリング認証サービス
/// Passkey/Numeric Comparisonによるセキュアな接続を実現
class BlePairingService {
  BlePairingService();

  final Random _random = Random.secure();

  final _pairingStateController = StreamController<PairingState>.broadcast();
  final _pairingInfoController = StreamController<PairingInfo?>.broadcast();

  PairingState _currentState = PairingState.notPaired;
  PairingInfo? _currentPairingInfo;

  // ペアリング済みデバイスのキャッシュ（セッション中のみ有効）
  final Map<String, String> _pairedDevices = {};

  // ペアリングコードの有効期限（秒）
  static const int _pairingCodeValiditySeconds = 60;

  // ペアリングコードの桁数
  static const int _pairingCodeLength = 6;

  // ========== Streams ==========

  /// ペアリング状態ストリーム
  Stream<PairingState> get pairingStateStream =>
      _pairingStateController.stream;

  /// ペアリング情報ストリーム
  Stream<PairingInfo?> get pairingInfoStream =>
      _pairingInfoController.stream;

  /// 現在のペアリング状態
  PairingState get currentState => _currentState;

  /// 現在のペアリング情報
  PairingInfo? get currentPairingInfo => _currentPairingInfo;

  // ========== Public Methods ==========

  /// ペアリングを開始（イニシエータ側）
  /// 6桁の数値コードを生成して相手に送信
  Future<PairingInfo> initiatePairing({
    required BluetoothDevice device,
    required BluetoothCharacteristic writeChar,
    PairingMethod method = PairingMethod.numericComparison,
  }) async {
    _updateState(PairingState.initiating);

    try {
      // 6桁のペアリングコードを生成
      final pairingCode = _generatePairingCode();
      final expiresAt = DateTime.now().add(
        const Duration(seconds: _pairingCodeValiditySeconds),
      );

      // ペアリングリクエストを送信
      final request = _createPairingRequest(
        pairingCode: pairingCode,
        method: method,
        expiresAt: expiresAt,
      );

      await writeChar.write(
        Uint8List.fromList(utf8.encode(request)),
        withoutResponse: false,
      );

      final info = PairingInfo(
        deviceId: device.remoteId.str,
        pairingCode: pairingCode,
        method: method,
        expiresAt: expiresAt,
        isInitiator: true,
      );

      _currentPairingInfo = info;
      _pairingInfoController.add(info);
      _updateState(PairingState.displayingCode);

      logger.i('Pairing initiated with code: $pairingCode');
      return info;
    } catch (e, stackTrace) {
      logger.e('initiatePairing failed', error: e, stackTrace: stackTrace);
      _updateState(PairingState.failed);
      rethrow;
    }
  }

  /// ペアリングリクエストを受信（レスポンダー側）
  PairingInfo? handlePairingRequest(String requestData) {
    try {
      final json = jsonDecode(requestData) as Map<String, dynamic>;

      if (json['type'] != 'pairing_request') {
        return null;
      }

      final pairingCode = json['code'] as String;
      final methodStr = json['method'] as String;
      final expiresAtStr = json['expires_at'] as String;

      final method = methodStr == 'numeric_comparison'
          ? PairingMethod.numericComparison
          : PairingMethod.passkeyEntry;

      final expiresAt = DateTime.parse(expiresAtStr);

      // 有効期限チェック
      if (DateTime.now().isAfter(expiresAt)) {
        logger.w('Pairing code expired');
        return null;
      }

      final info = PairingInfo(
        deviceId: json['device_id'] as String,
        pairingCode: pairingCode,
        method: method,
        expiresAt: expiresAt,
        isInitiator: false,
      );

      _currentPairingInfo = info;
      _pairingInfoController.add(info);

      if (method == PairingMethod.numericComparison) {
        _updateState(PairingState.displayingCode);
      } else {
        _updateState(PairingState.awaitingPasskey);
      }

      logger.i('Pairing request received with code: $pairingCode');
      return info;
    } catch (e, stackTrace) {
      logger.e('handlePairingRequest failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// ペアリングを確認（Numeric Comparison）
  /// ユーザーが表示されたコードが一致すると確認した場合
  Future<bool> confirmPairing({
    required BluetoothCharacteristic writeChar,
    required bool confirmed,
  }) async {
    if (_currentPairingInfo == null) {
      logger.e('No pairing in progress');
      return false;
    }

    if (_currentPairingInfo!.isExpired) {
      logger.w('Pairing code expired');
      _updateState(PairingState.failed);
      return false;
    }

    _updateState(PairingState.verifying);

    try {
      // 確認結果を送信
      final confirmation = _createPairingConfirmation(
        confirmed: confirmed,
        pairingCode: _currentPairingInfo!.pairingCode,
      );

      await writeChar.write(
        Uint8List.fromList(utf8.encode(confirmation)),
        withoutResponse: false,
      );

      if (confirmed) {
        _pairedDevices[_currentPairingInfo!.deviceId] =
            _currentPairingInfo!.pairingCode;
        _updateState(PairingState.paired);
        logger.i('Pairing confirmed');
        return true;
      } else {
        _updateState(PairingState.failed);
        logger.w('Pairing rejected by user');
        return false;
      }
    } catch (e, stackTrace) {
      logger.e('confirmPairing failed', error: e, stackTrace: stackTrace);
      _updateState(PairingState.failed);
      return false;
    }
  }

  /// パスキーを入力して確認（Passkey Entry）
  Future<bool> submitPasskey({
    required BluetoothCharacteristic writeChar,
    required String enteredCode,
  }) async {
    if (_currentPairingInfo == null) {
      logger.e('No pairing in progress');
      return false;
    }

    if (_currentPairingInfo!.isExpired) {
      logger.w('Pairing code expired');
      _updateState(PairingState.failed);
      return false;
    }

    _updateState(PairingState.verifying);

    // 入力されたコードが正しいか確認
    final isValid = enteredCode == _currentPairingInfo!.pairingCode;

    if (isValid) {
      try {
        // 確認結果を送信
        final confirmation = _createPairingConfirmation(
          confirmed: true,
          pairingCode: _currentPairingInfo!.pairingCode,
        );

        await writeChar.write(
          Uint8List.fromList(utf8.encode(confirmation)),
          withoutResponse: false,
        );

        _pairedDevices[_currentPairingInfo!.deviceId] =
            _currentPairingInfo!.pairingCode;
        _updateState(PairingState.paired);
        logger.i('Passkey verified successfully');
        return true;
      } catch (e, stackTrace) {
        logger.e('submitPasskey failed', error: e, stackTrace: stackTrace);
        _updateState(PairingState.failed);
        return false;
      }
    } else {
      _updateState(PairingState.failed);
      logger.w('Invalid passkey entered');
      return false;
    }
  }

  /// ペアリング確認応答を処理
  bool handlePairingConfirmation(String confirmationData) {
    try {
      final json = jsonDecode(confirmationData) as Map<String, dynamic>;

      if (json['type'] != 'pairing_confirmation') {
        return false;
      }

      final confirmed = json['confirmed'] as bool;
      final receivedCode = json['code'] as String;

      // コードを検証
      if (_currentPairingInfo == null) {
        logger.e('No pairing in progress');
        return false;
      }

      // 署名を検証（改ざん防止）
      final expectedSignature = _calculateSignature(
        receivedCode,
        confirmed,
      );
      final receivedSignature = json['signature'] as String;

      if (receivedSignature != expectedSignature) {
        logger.e('Invalid pairing confirmation signature');
        _updateState(PairingState.failed);
        return false;
      }

      if (confirmed &&
          receivedCode == _currentPairingInfo!.pairingCode) {
        _pairedDevices[_currentPairingInfo!.deviceId] =
            _currentPairingInfo!.pairingCode;
        _updateState(PairingState.paired);
        logger.i('Pairing confirmation received: success');
        return true;
      } else {
        _updateState(PairingState.failed);
        logger.w('Pairing confirmation received: rejected');
        return false;
      }
    } catch (e, stackTrace) {
      logger.e(
        'handlePairingConfirmation failed',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// デバイスがペアリング済みか確認
  bool isPaired(String deviceId) {
    return _pairedDevices.containsKey(deviceId);
  }

  /// ペアリングをリセット
  void resetPairing() {
    _currentPairingInfo = null;
    _pairingInfoController.add(null);
    _updateState(PairingState.notPaired);
    logger.d('Pairing reset');
  }

  /// 特定デバイスのペアリングを解除
  void unpairDevice(String deviceId) {
    _pairedDevices.remove(deviceId);
    logger.i('Device unpaired: $deviceId');
  }

  /// 全てのペアリングを解除
  void unpairAll() {
    _pairedDevices.clear();
    logger.i('All devices unpaired');
  }

  // ========== Private Methods ==========

  /// 6桁のペアリングコードを生成
  String _generatePairingCode() {
    final code = StringBuffer();
    for (var i = 0; i < _pairingCodeLength; i++) {
      code.write(_random.nextInt(10));
    }
    return code.toString();
  }

  /// ペアリングリクエストを作成
  String _createPairingRequest({
    required String pairingCode,
    required PairingMethod method,
    required DateTime expiresAt,
  }) {
    final data = {
      'type': 'pairing_request',
      'code': pairingCode,
      'method': method == PairingMethod.numericComparison
          ? 'numeric_comparison'
          : 'passkey_entry',
      'device_id': 'local_device', // 実際のデバイスIDに置き換え
      'expires_at': expiresAt.toIso8601String(),
      'signature': _calculateSignature(pairingCode, true),
    };
    return jsonEncode(data);
  }

  /// ペアリング確認を作成
  String _createPairingConfirmation({
    required bool confirmed,
    required String pairingCode,
  }) {
    final data = {
      'type': 'pairing_confirmation',
      'confirmed': confirmed,
      'code': pairingCode,
      'signature': _calculateSignature(pairingCode, confirmed),
    };
    return jsonEncode(data);
  }

  /// 署名を計算（改ざん防止）
  String _calculateSignature(String code, bool confirmed) {
    final data = '$code:$confirmed:${BleConstants.pairingSecret}';
    final bytes = utf8.encode(data);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }

  /// 状態を更新
  void _updateState(PairingState state) {
    _currentState = state;
    _pairingStateController.add(state);
  }

  // ========== Cleanup ==========

  /// リソースを解放
  Future<void> dispose() async {
    await _pairingStateController.close();
    await _pairingInfoController.close();
    _pairedDevices.clear();
  }
}
