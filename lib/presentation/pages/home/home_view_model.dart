import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/color_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/repositories/pixel_art_repository.dart';
import '../../../providers/app_providers.dart';

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

  HomeViewModel(this._pixelArtRepository) : super(const HomeState()) {
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
    if (title.length <= AppConstants.maxTitleLength) {
      state = state.copyWith(title: title);
    }
  }

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

    state = state.copyWith(
      isExchanging: true,
      errorMessage: null,
      receivedArt: null,
    );

    try {
      // Color から int (RGB) に変換
      final pixelValues = state.pixels.map((color) => color.value & 0xFFFFFF).toList();

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
  return HomeViewModel(ref.watch(pixelArtRepositoryProvider));
});
