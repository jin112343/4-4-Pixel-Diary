import 'package:logger/logger.dart';

/// アプリケーションロガー
/// print()は使用禁止、このロガーを使用すること
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 80,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Level.debug,
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
