import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/repositories/album_repository.dart';
import '../../../providers/app_providers.dart';

part 'album_view_model.freezed.dart';

/// アルバム画面のソート順
enum AlbumSortOrder {
  /// 新しい順
  newest,

  /// 古い順
  oldest,
}

/// アルバム画面の状態
@freezed
class AlbumState with _$AlbumState {
  const factory AlbumState({
    /// ドット絵リスト
    @Default([]) List<PixelArt> pixelArts,

    /// ローディング中かどうか
    @Default(false) bool isLoading,

    /// エラーメッセージ
    String? errorMessage,

    /// ソート順
    @Default(AlbumSortOrder.newest) AlbumSortOrder sortOrder,

    /// 現在のページ
    @Default(1) int currentPage,

    /// さらに読み込み可能か
    @Default(true) bool hasMore,

    /// 選択中のドット絵ID（削除用）
    String? selectedPixelArtId,

    /// 選択モードかどうか
    @Default(false) bool isSelectionMode,

    /// 複数選択中のドット絵IDセット
    @Default({}) Set<String> selectedIds,
  }) = _AlbumState;
}

/// アルバム画面のViewModel
class AlbumViewModel extends StateNotifier<AlbumState> {
  final AlbumRepository _albumRepository;

  AlbumViewModel(this._albumRepository) : super(const AlbumState()) {
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
          logger.e('Failed to load album: ${failure.message}');
        },
        (album) {
          // 届いたもの（server, bluetooth）のみをフィルタリング
          final receivedArts = album.pixelArts
              .where((art) => art.source != PixelArtSource.local)
              .toList();
          final sortedArts = _sortPixelArts(receivedArts);
          final hasMoreData = album.pixelArts.length >= 20;
          state = state.copyWith(
            isLoading: false,
            pixelArts: refresh ? sortedArts : [...state.pixelArts, ...sortedArts],
            hasMore: hasMoreData,
          );
          logger.i('Album loaded: ${receivedArts.length} received items');

          // フィルタリング後のアイテムが0件で、まだデータがある場合は
          // 自動で次のページをロード
          if (receivedArts.isEmpty && hasMoreData) {
            loadMore();
          }
        },
      );
    } catch (e, stackTrace) {
      logger.e('Album load error', error: e, stackTrace: stackTrace);
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
  void setSortOrder(AlbumSortOrder order) {
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
      case AlbumSortOrder.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case AlbumSortOrder.oldest:
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return sorted;
  }

  /// ドット絵を選択
  void selectPixelArt(String? id) {
    state = state.copyWith(selectedPixelArtId: id);
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
            selectedPixelArtId: null,
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

  /// 日付でフィルタリング
  Future<void> filterByDate(DateTime date) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _albumRepository.getByDate(date);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
        },
        (arts) {
          // 届いたもの（server, bluetooth）のみをフィルタリング
          final receivedArts = arts
              .where((art) => art.source != PixelArtSource.local)
              .toList();
          state = state.copyWith(
            isLoading: false,
            pixelArts: _sortPixelArts(receivedArts),
            hasMore: false,
          );
        },
      );
    } catch (e, stackTrace) {
      logger.e('Filter error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'フィルタリングに失敗しました',
      );
    }
  }
}

/// アルバムViewModelプロバイダー
final albumViewModelProvider =
    StateNotifierProvider.family<AlbumViewModel, AlbumState, String>(
  (ref, userId) {
    final albumRepository = ref.watch(albumRepositoryProvider(userId));
    return AlbumViewModel(albumRepository);
  },
);

/// 現在のユーザーIDプロバイダー
final currentUserIdProvider = FutureProvider<String>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final user = await authService.initialize();
  return user.deviceId;
});
