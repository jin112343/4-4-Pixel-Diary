import '../constants/app_constants.dart';

/// バリデーションユーティリティ
class Validators {
  Validators._();

  /// タイトルのバリデーション
  static String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return null; // タイトルは任意
    }
    if (value.length > AppConstants.maxTitleLength) {
      return 'タイトルは${AppConstants.maxTitleLength}文字以内で入力してください';
    }
    return null;
  }

  /// ニックネームのバリデーション
  static String? validateNickname(String? value) {
    if (value == null || value.isEmpty) {
      return null; // ニックネームは任意
    }
    if (value.length > AppConstants.maxNicknameLength) {
      return 'ニックネームは${AppConstants.maxNicknameLength}文字以内で入力してください';
    }
    return null;
  }

  /// コメントのバリデーション
  static String? validateComment(String? value) {
    if (value == null || value.isEmpty) {
      return 'コメントを入力してください';
    }
    if (value.length > AppConstants.maxCommentLength) {
      return 'コメントは${AppConstants.maxCommentLength}文字以内で入力してください';
    }
    return null;
  }

  /// ピクセルデータのバリデーション
  static bool validatePixels(List<int> pixels, int gridSize) {
    final expectedCount = gridSize * gridSize;
    if (pixels.length != expectedCount) {
      return false;
    }
    // RGB値の範囲チェック（0x000000 ~ 0xFFFFFF）
    for (final pixel in pixels) {
      if (pixel < 0 || pixel > 0xFFFFFF) {
        return false;
      }
    }
    return true;
  }
}
