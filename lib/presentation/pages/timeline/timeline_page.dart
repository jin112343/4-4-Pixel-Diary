import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// タイムライン画面
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('みんなの作品'),
      ),
      body: const Center(
        child: Text('タイムライン画面（準備中）'),
      ),
    );
  }
}
