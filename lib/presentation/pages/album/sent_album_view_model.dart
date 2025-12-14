import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/repositories/album_repository.dart';
import '../../../providers/app_providers.dart';

part 'sent_album_view_model.freezed.dart';

/// おくったアルバム画面のソート順
enum SentAlbumSortOrder {
  /// 新しい順
  newest,

  /// 古い順
  oldest,
}

/// おくったアルバム画面の状態
@freezed
class SentAlbumState with _$SentAlbumState {
  const factory SentAlbumState({
    /// ドット絵リスト
    @Default([]) List<PixelArt> pixelArts,

    /// ローディング中かどうか
    @Default(false) bool isLoading,

    /// エラーメッセージ
    String? errorMessage,

    /// ソート順
    @Default(SentAlbumSortOrder.newest) SentAlbumSortOrder sortOrder,

    /// 現在のページ
    @Default(1) int currentPage,

    /// さらに読み込み可能か
    @Default(true) bool hasMore,

    /// 選択モードかどうか
    @Default(false) bool isSelectionMode,

    /// 複数選択中のドット絵IDセット
    @Default({}) Set<String> selectedIds,
  }) = _SentAlbumState;
}

/// おくったアルバム画面のViewModel
class SentAlbumViewModel extends StateNotifier<SentAlbumState> {
  final AlbumRepository _albumRepository;

  SentAlbumViewModel(this._albumRepository) : super(const SentAlbumState()) {
    loadAlbum();
  }

  /// アルバムを読み込む
  Future<void> loadAlbum({bool refresh = false}) async {
    if (state.isLoading) return;

    if (refresh) {
      state = state.copyWith(
        currentPage: 1,
        hasMore: true,
        pixelArts: [],
      );
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _albumRepository.getAlbum(
        page: state.currentPage,
        limit: 20,
      );

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          logger.e('Failed to load sent album: ${failure.message}');
        },
        (album) {
          // 自分で送ったもの（local）のみをフィルタリング
          final sentArts = album.pixelArts
              .where((art) => art.source == PixelArtSource.local)
              .toList();
          final sortedArts = _sortPixelArts(sentArts);
          final hasMoreData = album.pixelArts.length >= 20;
          state = state.copyWith(
            isLoading: false,
            pixelArts:
                refresh ? sortedArts : [...state.pixelArts, ...sortedArts],
            hasMore: hasMoreData,
          );
          logger.i('Sent album loaded: ${sentArts.length} sent items');

          // フィルタリング後のアイテムが0件で、まだデータがある場合は
          // 自動で次のページをロード
          if (sentArts.isEmpty && hasMoreData) {
            loadMore();
          }
        },
      );
    } catch (e, stackTrace) {
      logger.e('Sent album load error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'アルバムの読み込みに失敗しました',
      );
    }
  }

  /// さらに読み込む
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(currentPage: state.currentPage + 1);
    await loadAlbum();
  }

  /// ソート順を変更
  void setSortOrder(SentAlbumSortOrder order) {
    if (state.sortOrder == order) return;

    state = state.copyWith(
      sortOrder: order,
      pixelArts: _sortPixelArts(state.pixelArts),
    );
  }

  /// ドット絵をソート
  List<PixelArt> _sortPixelArts(List<PixelArt> arts) {
    final sorted = List<PixelArt>.from(arts);
    switch (state.sortOrder) {
      case SentAlbumSortOrder.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SentAlbumSortOrder.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return sorted;
  }

  /// ドット絵を削除
  Future<void> deletePixelArt(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _albumRepository.removeFromAlbum(id);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          logger.e('Failed to delete pixel art: ${failure.message}');
        },
        (_) {
          state = state.copyWith(
            isLoading: false,
            pixelArts: state.pixelArts.where((art) => art.id != id).toList(),
          );
          logger.i('Pixel art deleted: $id');
        },
      );
    } catch (e, stackTrace) {
      logger.e('Delete error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: '削除に失敗しました',
      );
    }
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  // ========== 複数選択機能 ==========

  /// 選択モードを開始
  void startSelectionMode() {
    state = state.copyWith(
      isSelectionMode: true,
      selectedIds: {},
    );
  }

  /// 選択モードを終了
  void endSelectionMode() {
    state = state.copyWith(
      isSelectionMode: false,
      selectedIds: {},
    );
  }

  /// ドット絵の選択をトグル
  void toggleSelection(String id) {
    final selectedIds = Set<String>.from(state.selectedIds);
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    state = state.copyWith(selectedIds: selectedIds);
  }

  /// 全て選択
  void selectAll() {
    final allIds = state.pixelArts.map((art) => art.id).toSet();
    state = state.copyWith(selectedIds: allIds);
  }

  /// 全て選択解除
  void deselectAll() {
    state = state.copyWith(selectedIds: {});
  }

  /// 選択したドット絵を一括削除
  Future<void> deleteSelectedPixelArts() async {
    if (state.selectedIds.isEmpty) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final idsToDelete = List<String>.from(state.selectedIds);
      var successCount = 0;

      for (final id in idsToDelete) {
        final result = await _albumRepository.removeFromAlbum(id);
        result.fold(
          (failure) {
            logger.e('Failed to delete pixel art: $id - ${failure.message}');
          },
          (_) {
            successCount++;
          },
        );
      }

      // 削除成功したものをリストから除去
      state = state.copyWith(
        isLoading: false,
        pixelArts: state.pixelArts
            .where((art) => !idsToDelete.contains(art.id))
            .toList(),
        selectedIds: {},
        isSelectionMode: false,
      );

      logger.i('Deleted $successCount/${idsToDelete.length} pixel arts');
    } catch (e, stackTrace) {
      logger.e('Delete selected error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: '削除に失敗しました',
      );
    }
  }
}

/// おくったアルバムViewModelプロバイダー
final sentAlbumViewModelProvider =
    StateNotifierProvider.family<SentAlbumViewModel, SentAlbumState, String>(
  (ref, userId) {
    final albumRepository = ref.watch(albumRepositoryProvider(userId));
    return SentAlbumViewModel(albumRepository);
  },
);
