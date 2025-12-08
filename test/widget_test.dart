import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pixeldiary/app.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PixelDiaryApp(),
      ),
    );

    // アプリが正常にビルドされることを確認
    expect(find.text('いまのきぶん'), findsOneWidget);
  });
}
