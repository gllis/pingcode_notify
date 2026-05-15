import 'package:flutter_test/flutter_test.dart';
import 'package:pingcode_notify/main.dart';

void main() {
  testWidgets('PingCode Notify app smoke test', (WidgetTester tester) async {
    // 构建应用并触发一帧
    await tester.pumpWidget(const PingCodeNotifyApp());

    // 验证应用标题存在
    expect(find.text('PingCode 任务监控'), findsOneWidget);
  });
}