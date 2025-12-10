import 'package:logger/logger.dart';

/// アプリケーションロガー
/// print()は使用禁止、このロガーを使用すること
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.info, // パフォーマンス向上のためinfoレベルに変更
);

/// プロダクション用ロガー（最小限のログ）
final prodLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: false,
    printEmojis: false,
  ),
  level: Level.warning,
);
