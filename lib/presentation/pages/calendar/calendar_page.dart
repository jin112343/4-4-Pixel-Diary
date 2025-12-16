import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/color_constants.dart';
import '../../../domain/entities/pixel_art.dart';
import '../../../providers/app_providers.dart';
import 'calendar_view_model.dart';

/// カレンダー画面
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userIdAsync = ref.watch(currentUserIdProvider);

    return userIdAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('エラー: $error'))),
      data: (userId) => _CalendarContent(userId: userId),
    );
  }
}

/// カレンダーコンテンツ
class _CalendarContent extends ConsumerStatefulWidget {
  const _CalendarContent({required this.userId});

  final String userId;

  @override
  ConsumerState<_CalendarContent> createState() => _CalendarContentState();
}

class _CalendarContentState extends ConsumerState<_CalendarContent>
    with RouteAware {
  /// カレンダーの展開状態
  bool _isCalendarExpanded = true;

  @override
  void initState() {
    super.initState();
    // 初回表示時にリフレッシュ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarViewModelProvider(widget.userId).notifier).refresh();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 画面に戻ってきた時にリフレッシュ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(calendarViewModelProvider(widget.userId).notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarViewModelProvider(widget.userId));

    // エラー監視
    ref.listen<CalendarState>(calendarViewModelProvider(widget.userId), (
      previous,
      next,
    ) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref
            .read(calendarViewModelProvider(widget.userId).notifier)
            .clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: Column(
        children: [
          // カレンダー部分（折りたたみ可能）
          _CollapsibleCalendarSection(
            userId: widget.userId,
            state: state,
            isExpanded: _isCalendarExpanded,
            onToggle: () {
              setState(() {
                _isCalendarExpanded = !_isCalendarExpanded;
              });
            },
          ),

          const Divider(height: 1),

          // 選択日のドット絵リスト
          Expanded(
            child: _SelectedDatePixelArts(userId: widget.userId, state: state),
          ),
        ],
      ),
    );
  }
}

/// 折りたたみ可能なカレンダーセクション
class _CollapsibleCalendarSection extends ConsumerWidget {
  const _CollapsibleCalendarSection({
    required this.userId,
    required this.state,
    required this.isExpanded,
    required this.onToggle,
  });

  final String userId;
  final CalendarState state;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年M月', 'ja_JP');

    return Column(
      children: [
        // ヘッダー（タップで展開/折りたたみ）
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(state.focusedMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: isExpanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        // カレンダー本体（アニメーション付き展開/折りたたみ）
        AnimatedCrossFade(
          firstChild: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CalendarDatePicker(
              initialDate: state.selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              currentDate: DateTime.now(),
              onDateChanged: (date) {
                ref
                    .read(calendarViewModelProvider(userId).notifier)
                    .selectDate(date);
              },
              selectableDayPredicate: (date) => true,
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}

/// 選択日のドット絵リスト
class _SelectedDatePixelArts extends ConsumerStatefulWidget {
  const _SelectedDatePixelArts({required this.userId, required this.state});

  final String userId;
  final CalendarState state;

  @override
  ConsumerState<_SelectedDatePixelArts> createState() =>
      _SelectedDatePixelArtsState();
}

class _SelectedDatePixelArtsState
    extends ConsumerState<_SelectedDatePixelArts> {
  /// スワイプ開始位置
  double? _dragStartX;

  /// スワイプ閾値
  static const double _swipeThreshold = 80.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年M月d日(E)', 'ja_JP');
    final state = widget.state;
    final userId = widget.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日付ヘッダー（左右矢印付き）
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // 前日ボタン
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _goToPreviousDay,
                tooltip: '前日',
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(state.selectedDate),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (state.selectedDatePixelArts.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${state.selectedDatePixelArts.length}件',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 翌日ボタン
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _canGoToNextDay() ? _goToNextDay : null,
                tooltip: '翌日',
              ),
            ],
          ),
        ),

        // もらった絵の表示/非表示トグル
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.card_giftcard,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                'もらった絵も表示',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              const Spacer(),
              Switch(
                value: state.showReceivedArts,
                onChanged: (value) {
                  ref
                      .read(calendarViewModelProvider(userId).notifier)
                      .toggleShowReceivedArts();
                },
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // コンテンツ（スワイプ対応）
        Expanded(
          child: Listener(
            onPointerDown: (event) {
              _dragStartX = event.position.dx;
            },
            onPointerUp: (event) {
              if (_dragStartX == null) return;

              final dragDistance = event.position.dx - _dragStartX!;

              // 右スワイプ → 前日
              if (dragDistance > _swipeThreshold) {
                _goToPreviousDay();
              }
              // 左スワイプ → 翌日
              else if (dragDistance < -_swipeThreshold && _canGoToNextDay()) {
                _goToNextDay();
              }

              _dragStartX = null;
            },
            onPointerCancel: (_) {
              _dragStartX = null;
            },
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.selectedDatePixelArts.isEmpty
                    ? _EmptyState(showReceivedArts: state.showReceivedArts)
                    : _PixelArtList(pixelArts: state.selectedDatePixelArts),
          ),
        ),
      ],
    );
  }

  /// 前日に移動
  void _goToPreviousDay() {
    final previousDay =
        widget.state.selectedDate.subtract(const Duration(days: 1));
    ref
        .read(calendarViewModelProvider(widget.userId).notifier)
        .selectDate(previousDay);
  }

  /// 翌日に移動
  void _goToNextDay() {
    final nextDay = widget.state.selectedDate.add(const Duration(days: 1));
    ref
        .read(calendarViewModelProvider(widget.userId).notifier)
        .selectDate(nextDay);
  }

  /// 翌日に移動可能か（未来の日付は不可）
  bool _canGoToNextDay() {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final selectedOnly = DateTime(
      widget.state.selectedDate.year,
      widget.state.selectedDate.month,
      widget.state.selectedDate.day,
    );
    return selectedOnly.isBefore(todayOnly);
  }
}

/// 空の状態
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.showReceivedArts = false});

  final bool showReceivedArts;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            showReceivedArts
                ? 'この日のドット絵はありません'
                : 'この日に描いたドット絵はありません',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          if (!showReceivedArts) ...[
            const SizedBox(height: 8),
            Text(
              '「もらった絵も表示」をONにすると\n受け取ったドット絵も確認できます',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }
}

/// ドット絵リスト
class _PixelArtList extends StatelessWidget {
  const _PixelArtList({required this.pixelArts});

  final List<PixelArt> pixelArts;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: pixelArts.length,
      itemBuilder: (context, index) {
        final pixelArt = pixelArts[index];
        return _PixelArtListItem(
          pixelArt: pixelArt,
          onTap: () => _showDetailDialog(context, pixelArt),
        );
      },
    );
  }

  void _showDetailDialog(BuildContext context, PixelArt pixelArt) {
    showDialog<void>(
      context: context,
      builder: (context) => _DetailDialog(pixelArt: pixelArt),
    );
  }
}

/// ドット絵リストアイテム
class _PixelArtListItem extends StatelessWidget {
  const _PixelArtListItem({required this.pixelArt, required this.onTap});

  final PixelArt pixelArt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ピクセルアートサムネイル
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ColorConstants.gridLineColor,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: CustomPaint(
                  painter: _PixelArtPainter(
                    pixels: pixelArt.pixels,
                    gridSize: pixelArt.gridSize,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // タイトルと時間
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pixelArt.title.isNotEmpty ? pixelArt.title : '無題',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeFormat.format(pixelArt.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _SourceChip(source: pixelArt.source),
                      ],
                    ),
                  ],
                ),
              ),

              // 矢印
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

/// ソースチップ
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final PixelArtSource source;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (source) {
      PixelArtSource.local => ('自分', Icons.person, Colors.blue),
      PixelArtSource.server ||
      PixelArtSource.bluetooth => ('こうかん', Icons.swap_horiz, Colors.green),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// 詳細ダイアログ
class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.pixelArt});

  final PixelArt pixelArt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/M/d HH:mm');

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ピクセルアート拡大表示
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ColorConstants.gridLineColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: CustomPaint(
                  painter: _PixelArtPainterWithGrid(
                    pixels: pixelArt.pixels,
                    gridSize: pixelArt.gridSize,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // タイトル
            Text(
              pixelArt.title.isNotEmpty ? pixelArt.title : '無題',
              style: theme.textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            // 日時
            Text(
              dateFormat.format(pixelArt.createdAt),
              style: TextStyle(color: Colors.grey[600]),
            ),

            // ソース表示
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SourceChip(source: pixelArt.source),
            ),

            const SizedBox(height: 16),

            // 閉じるボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('とじる'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ピクセルアートペインター(グリッドなし)
class _PixelArtPainter extends CustomPainter {
  _PixelArtPainter({required this.pixels, required this.gridSize});

  final List<int> pixels;
  final int gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;

    for (int i = 0; i < pixels.length; i++) {
      final row = i ~/ gridSize;
      final col = i % gridSize;
      final rect = Rect.fromLTWH(
        col * cellSize,
        row * cellSize,
        cellSize,
        cellSize,
      );

      final paint = Paint()
        ..color = Color(pixels[i] | 0xFF000000)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainter oldDelegate) {
    return oldDelegate.pixels != pixels || oldDelegate.gridSize != gridSize;
  }
}

/// ピクセルアートペインター(グリッドあり)
class _PixelArtPainterWithGrid extends CustomPainter {
  _PixelArtPainterWithGrid({required this.pixels, required this.gridSize});

  final List<int> pixels;
  final int gridSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridSize;

    // ピクセル描画
    for (int i = 0; i < pixels.length; i++) {
      final row = i ~/ gridSize;
      final col = i % gridSize;
      final rect = Rect.fromLTWH(
        col * cellSize,
        row * cellSize,
        cellSize,
        cellSize,
      );

      final paint = Paint()
        ..color = Color(pixels[i] | 0xFF000000)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, paint);
    }

    // グリッド線描画
    final gridPaint = Paint()
      ..color = ColorConstants.gridLineColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= gridSize; i++) {
      // 縦線
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        gridPaint,
      );
      // 横線
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PixelArtPainterWithGrid oldDelegate) {
    return oldDelegate.pixels != pixels || oldDelegate.gridSize != gridSize;
  }
}
