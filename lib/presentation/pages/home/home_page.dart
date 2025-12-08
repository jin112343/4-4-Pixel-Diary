import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_router.dart';
import 'widgets/pixel_canvas.dart';
import 'widgets/color_palette.dart';

/// ホーム画面（ドット絵作成）
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('いまのきぶん'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // キャンバス
              Expanded(
                flex: 3,
                child: Center(
                  child: PixelCanvas(),
                ),
              ),

              SizedBox(height: 16),

              // カラーパレット
              ColorPalette(),

              SizedBox(height: 16),

              // タイトル入力
              _TitleInput(),

              SizedBox(height: 24),

              // 交換ボタン
              _ExchangeButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// タイトル入力
class _TitleInput extends StatelessWidget {
  const _TitleInput();

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLength: 5,
      decoration: const InputDecoration(
        labelText: 'タイトル（5文字まで）',
        hintText: 'なにをかいた？',
        counterText: '',
      ),
    );
  }
}

/// 交換ボタン
class _ExchangeButton extends ConsumerWidget {
  const _ExchangeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // TODO: 交換処理
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: const Text(
          'こうかんする',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
