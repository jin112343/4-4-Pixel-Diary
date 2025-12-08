import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// すれ違い通信画面
class BluetoothPage extends ConsumerWidget {
  const BluetoothPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('すれ違い通信'),
      ),
      body: const Center(
        child: Text('すれ違い通信画面（準備中）'),
      ),
    );
  }
}
