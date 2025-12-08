import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// カレンダー画面
class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
      ),
      body: const Center(
        child: Text('カレンダー画面（準備中）'),
      ),
    );
  }
}
