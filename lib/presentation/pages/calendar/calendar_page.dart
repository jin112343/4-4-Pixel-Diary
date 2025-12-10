import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/color_constants.dart';
import '../../../domain/entities/pixel_art.dart';
import '../album/album_view_model.dart';
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
class _CalendarContent extends ConsumerWidget {
  const _CalendarContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calendarViewModelProvider(userId));

    // エラー監視
    ref.listen<CalendarState>(calendarViewModelProvider(userId), (
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
        ref.read(calendarViewModelProvider(userId).notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '今日',
            onPressed: () {
              final today = DateTime.now();
              ref.read(calendarViewModelProvider(userId).notifier)
                ..changeFocusedMonth(today)
                ..selectDate(today);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // カレンダー部分
          _CalendarSection(userId: userId, state: state),

          const Divider(height: 1),

          // 選択日のドット絵リスト
          Expanded(
            child: _SelectedDatePixelArts(userId: userId, state: state),
          ),
        ],
      ),
    );
  }
}

/// カレンダーセクション
class _CalendarSection extends ConsumerWidget {
  const _CalendarSection({required this.userId, required this.state});

  final String userId;
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CalendarDatePicker(
        initialDate: state.selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        currentDate: DateTime.now(),
        onDateChanged: (date) {
          ref.read(calendarViewModelProvider(userId).notifier).selectDate(date);
        },
        selectableDayPredicate: (date) => true,
      ),
    );
  }
}

/// 選択日のドット絵リスト
class _SelectedDatePixelArts extends ConsumerWidget {
  const _SelectedDatePixelArts({required this.userId, required this.state});

  final String userId;
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy年M月d日(E)', 'ja_JP');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日付ヘッダー
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.event, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(state.selectedDate),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (state.selectedDatePixelArts.isNotEmpty)
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
          ),
        ),

        // コンテンツ
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.selectedDatePixelArts.isEmpty
              ? _EmptyState()
              : _PixelArtList(pixelArts: state.selectedDatePixelArts),
        ),
      ],
    );
  }
}

/// 空の状態
class _EmptyState extends StatelessWidget {
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
            'この日のドット絵はありません',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
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
      PixelArtSource.server => ('こうかん', Icons.swap_horiz, Colors.green),
      PixelArtSource.bluetooth => ('すれちがい', Icons.bluetooth, Colors.purple),
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
