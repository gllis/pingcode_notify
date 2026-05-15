import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/pingcode_notify_page.dart';

/// PingCode Notify 应用主入口
/// 
/// 这是一个跨平台桌面监控应用，支持 macOS、Windows、Linux
/// 主要功能：
/// 1. 监控 PingCode 未读消息
/// 2. 监控任务到期情况
/// 3. 系统托盘最小化运行
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化窗口管理器
  await windowManager.ensureInitialized();
  
  // 设置窗口初始大小
  WindowOptions windowOptions = WindowOptions(
    size: const Size(1200, 800),
    minimumSize: const Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'PingCode Notify',
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    
    // 设置窗口关闭拦截
    await windowManager.setPreventClose(true);
  });
  
  runApp(const PingCodeNotifyApp());
}

/// PingCode Notify 应用根组件
class PingCodeNotifyApp extends StatelessWidget {
  /// 构造函数
  const PingCodeNotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PingCode Notify',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      home: const PingCodeNotifyPage(),
    );
  }

  /// 构建深色主题配置
  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.blue,
      colorScheme: ColorScheme.fromSwatch(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF252525),
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF444444),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.blue;
          }
          return Colors.grey;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            // ignore: deprecated_member_use
            return Colors.blue.withOpacity(0.5);
          }
          // ignore: deprecated_member_use
          return Colors.grey.withOpacity(0.3);
        }),
      ),
    );
  }
}