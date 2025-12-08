import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// アルバム画面
class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アルバム'),
      ),
      body: const Center(
        child: Text('アルバム画面（準備中）'),
      ),
    );
  }
}
