import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/utils/content_filter.dart';
import '../../../core/utils/logger.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/repositories/pixel_art_repository.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/moderation_provider.dart';
import '../../../services/moderation/moderation_service.dart';

part 'home_view_model.freezed.dart';

/// ホーム画面の状態
@freezed
class HomeState with _$HomeState {
  const factory HomeState({
    /// ピクセルデータ
    @Default([]) List<Color> pixels,

    /// 選択中の色
    @Default(Colors.black) Color selectedColor,

    /// タイトル
    @Default('') String title,

    /// タイトルのNGワードエラー
    String? titleError,

    /// グリッドサイズ
    @Default(4) int gridSize,

    /// 交換中かどうか
    @Default(false) bool isExchanging,

    /// 受信した作品
    PixelArt? receivedArt,

    /// エラーメッセージ
    String? errorMessage,

    /// Undo履歴
    @Default([]) List<List<Color>> undoHistory,

    /// Redo履歴
    @Default([]) List<List<Color>> redoHistory,
  }) = _HomeState;
}

/// ホーム画面のViewModel
class HomeViewModel extends StateNotifier<HomeState> {
  final PixelArtRepository _pixelArtRepository;
  final LocalStorage _localStorage;
  final ModerationService _moderationService;

  HomeViewModel(
    this._pixelArtRepository,
    this._localStorage,
    this._moderationService,
  ) : super(const HomeState()) {
    _initializePixels();
  }

  /// ピクセルを初期化
  void _initializePixels() {
    final pixelCount = state.gridSize * state.gridSize;
    state = state.copyWith(
      pixels: List.filled(pixelCount, ColorConstants.defaultCanvasColor),
    );
  }

  /// ピクセルの色を設定
  void setPixelColor(int index, Color color) {
    if (index < 0 || index >= state.pixels.length) return;

    // Undo履歴に現在の状態を保存
    final newUndoHistory = [...state.undoHistory, List<Color>.from(state.pixels)];

    final newPixels = List<Color>.from(state.pixels);
    newPixels[index] = color;

    state = state.copyWith(
      pixels: newPixels,
      undoHistory: newUndoHistory,
      redoHistory: [], // Redoをクリア
    );
  }

  /// 色を選択
  void selectColor(Color color) {
    state = state.copyWith(selectedColor: color);
  }

  /// タイトルを設定
  void setTitle(String title) {
    // 文字数制限のみチェック（NGワードはexchange時にチェック）
    if (title.length <= AppConstants.maxTitleLength) {
      state = state.copyWith(
        title: title,
        titleError: null, // 入力時はエラーをクリア
      );
    }
  }

  /// タイトルエラーをクリア
  void clearTitleError() {
    state = state.copyWith(titleError: null);
  }

  /// タイトルが有効かどうか
  bool get isTitleValid => state.titleError == null;

  /// キャンバスをクリア
  void clearCanvas() {
    // Undo履歴に現在の状態を保存
    final newUndoHistory = [...state.undoHistory, List<Color>.from(state.pixels)];

    final pixelCount = state.gridSize * state.gridSize;
    state = state.copyWith(
      pixels: List.filled(pixelCount, ColorConstants.defaultCanvasColor),
      undoHistory: newUndoHistory,
      redoHistory: [],
    );
  }

  /// 元に戻す
  void undo() {
    if (state.undoHistory.isEmpty) return;

    final newUndoHistory = List<List<Color>>.from(state.undoHistory);
    final previousState = newUndoHistory.removeLast();

    final newRedoHistory = [...state.redoHistory, List<Color>.from(state.pixels)];

    state = state.copyWith(
      pixels: previousState,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
  }

  /// やり直す
  void redo() {
    if (state.redoHistory.isEmpty) return;

    final newRedoHistory = List<List<Color>>.from(state.redoHistory);
    final nextState = newRedoHistory.removeLast();

    final newUndoHistory = [...state.undoHistory, List<Color>.from(state.pixels)];

    state = state.copyWith(
      pixels: nextState,
      undoHistory: newUndoHistory,
      redoHistory: newRedoHistory,
    );
  }

  /// 交換を実行
  Future<void> exchange() async {
    if (state.isExchanging) return;

    // タイトル未入力チェック
    if (state.title.trim().isEmpty) {
      state = state.copyWith(
        titleError: 'タイトルを入力してください',
      );
      return;
    }

    // ステップ1: ローカルフィルタ（超厳格チェック）
    final filterResult = TitleFilter.filter(state.title);
    if (!filterResult.isValid) {
      state = state.copyWith(
        titleError: filterResult.error,
      );
      logger.w('Exchange blocked (Local): NGワード検出 - ${state.title}');
      return;
    }

    // ステップ2: AIモデレーション（Perspective API）
    try {
      final moderationResult = await _moderationService.moderate(state.title);
      if (!moderationResult.isAllowed) {
        state = state.copyWith(
          titleError: moderationResult.userMessage,
        );
        logger.w(
          'Exchange blocked (AI): ${moderationResult.blockReason} - ${state.title}',
        );
        return;
      }
    } catch (e) {
      // AIモデレーションが失敗してもローカルチェックが通っていれば続行
      logger.w('AIモデレーション失敗、ローカルチェックのみで続行: $e');
    }

    state = state.copyWith(
      isExchanging: true,
      errorMessage: null,
      receivedArt: null,
    );

    try {
      // Color から int (RGB) に変換
      final pixelValues =
          state.pixels.map((color) => color.value & 0xFFFFFF).toList();

      // 自分が作成したドット絵をアルバムに保存
      final myArt = PixelArt(
        id: const Uuid().v4(),
        pixels: pixelValues,
        title: state.title,
        createdAt: DateTime.now(),
        source: PixelArtSource.local,
        gridSize: state.gridSize,
      );
      await _localStorage.addToAlbum(myArt);
      logger.i('Saved my art to album: ${myArt.id}');

      final result = await _pixelArtRepository.exchange(
        pixels: pixelValues,
        title: state.title,
        gridSize: state.gridSize,
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isExchanging: false,
            errorMessage: failure.message,
          );
          logger.e('Exchange failed: ${failure.message}');
        },
        (receivedArt) {
          state = state.copyWith(
            isExchanging: false,
            receivedArt: receivedArt,
          );
          logger.i('Exchange successful');

          // キャンバスをクリア
          _initializePixels();
          state = state.copyWith(title: '', undoHistory: [], redoHistory: []);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Exchange error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isExchanging: false,
        errorMessage: '予期しないエラーが発生しました',
      );
    }
  }

  /// 受信した作品をクリア
  void clearReceivedArt() {
    state = state.copyWith(receivedArt: null);
  }

  /// エラーメッセージをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Undo可能かどうか
  bool get canUndo => state.undoHistory.isNotEmpty;

  /// Redo可能かどうか
  bool get canRedo => state.redoHistory.isNotEmpty;
}

/// ホームViewModelプロバイダー
final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  return HomeViewModel(
    ref.watch(pixelArtRepositoryProvider),
    ref.watch(localStorageProvider),
    ref.watch(moderationServiceProvider),
  );
});
