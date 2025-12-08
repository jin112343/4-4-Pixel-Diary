import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../domain/repositories/album_repository.dart';
import '../../../providers/app_providers.dart';

part 'calendar_view_model.freezed.dart';

/// カレンダー画面の状態
@freezed
class CalendarState with _$CalendarState {
  const factory CalendarState({
    /// 選択中の日付
    required DateTime selectedDate,

    /// 表示中の月
    required DateTime focusedMonth,

    /// 選択日のドット絵リスト
    @Default([]) List<PixelArt> selectedDatePixelArts,

    /// 月内のドット絵がある日付マップ（日 -> 作品数）
    @Default({}) Map<int, int> pixelArtDaysInMonth,

    /// ローディング中かどうか
    @Default(false) bool isLoading,

    /// エラーメッセージ
    String? errorMessage,
  }) = _CalendarState;
}

/// カレンダー画面のViewModel
class CalendarViewModel extends StateNotifier<CalendarState> {
  CalendarViewModel(this._albumRepository)
      : super(CalendarState(
          selectedDate: DateTime.now(),
          focusedMonth: DateTime.now(),
        )) {
    _loadMonthData();
    _loadSelectedDateData();
  }

  final AlbumRepository _albumRepository;

  /// 日付を選択
  Future<void> selectDate(DateTime date) async {
    state = state.copyWith(selectedDate: date);
    await _loadSelectedDateData();
  }

  /// 表示月を変更
  Future<void> changeFocusedMonth(DateTime month) async {
    state = state.copyWith(focusedMonth: month);
    await _loadMonthData();
  }

  /// 月のデータを読み込む
  Future<void> _loadMonthData() async {
    try {
      final startOfMonth = DateTime(
        state.focusedMonth.year,
        state.focusedMonth.month,
        1,
      );
      final endOfMonth = DateTime(
        state.focusedMonth.year,
        state.focusedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final result = await _albumRepository.getByDateRange(
        start: startOfMonth,
        end: endOfMonth,
      );

      result.fold(
        (failure) {
          logger.e('Failed to load month data: ${failure.message}');
        },
        (pixelArts) {
          // 日付ごとの作品数をカウント
          final daysMap = <int, int>{};
          for (final art in pixelArts) {
            final day = art.createdAt.day;
            daysMap[day] = (daysMap[day] ?? 0) + 1;
          }
          state = state.copyWith(pixelArtDaysInMonth: daysMap);
        },
      );
    } catch (e, stackTrace) {
      logger.e('Month data load error', error: e, stackTrace: stackTrace);
    }
  }

  /// 選択日のデータを読み込む
  Future<void> _loadSelectedDateData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _albumRepository.getByDate(state.selectedDate);

      result.fold(
        (failure) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: failure.message,
          );
          logger.e('Failed to load date data: ${failure.message}');
        },
        (pixelArts) {
          state = state.copyWith(
            isLoading: false,
            selectedDatePixelArts: pixelArts,
          );
          logger.i(
            'Loaded ${pixelArts.length} pixel arts for '
            '${state.selectedDate.year}/${state.selectedDate.month}/'
            '${state.selectedDate.day}',
          );
        },
      );
    } catch (e, stackTrace) {
      logger.e('Date data load error', error: e, stackTrace: stackTrace);
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'データの読み込みに失敗しました',
      );
    }
  }

  /// リフレッシュ
  Future<void> refresh() async {
    await _loadMonthData();
    await _loadSelectedDateData();
  }

  /// エラーをクリア
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

/// カレンダーViewModelプロバイダー
final calendarViewModelProvider =
    StateNotifierProvider.family<CalendarViewModel, CalendarState, String>(
  (ref, userId) {
    final albumRepository = ref.watch(albumRepositoryProvider(userId));
    return CalendarViewModel(albumRepository);
  },
);
