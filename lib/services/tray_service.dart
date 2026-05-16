import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';

/// 系统托盘服务
/// 负责管理窗口最小化到托盘和托盘菜单
class TrayService {
  /// 单例模式
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  /// SystemTray 实例
  final SystemTray _systemTray = SystemTray();

  /// 托盘是否已初始化
  bool _isInitialized = false;

  /// 窗口关闭回调
  VoidCallback? onWindowClose;

  /// 托盘双击回调
  VoidCallback? onTrayDoubleClick;

  /// 初始化系统托盘
  Future<void> init({
    VoidCallback? onWindowClose,
    VoidCallback? onTrayDoubleClick,
  }) async {
    if (_isInitialized) {
      return;
    }

    this.onWindowClose = onWindowClose;
    this.onTrayDoubleClick = onTrayDoubleClick;

    try {
      // 初始化系统托盘 - 只显示图标，不显示文本
      await _systemTray.initSystemTray(
        iconPath: _getIconPath(),
        toolTip: 'PingCode 任务监控',
      );

      // 创建托盘菜单
      final menu = Menu();
      await menu.buildFrom([
        MenuItemLabel(
          label: '显示窗口',
          onClicked: (menuItem) {
            this.onTrayDoubleClick?.call();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '退出',
          onClicked: (menuItem) {
            this.onWindowClose?.call();
          },
        ),
      ]);

      await _systemTray.setContextMenu(menu);

      // 注册双击事件
      _systemTray.registerSystemTrayEventHandler((eventName) {
        if (eventName == kSystemTrayEventClick) {
          this.onTrayDoubleClick?.call();
        } else if (eventName == kSystemTrayEventRightClick) {
          _systemTray.popUpContextMenu();
        }
      });

      _isInitialized = true;
    } catch (e) {
      // 如果托盘初始化失败，打印错误但不阻止应用运行
      print('Warning: Failed to initialize system tray: $e');
      // 即使托盘初始化失败，也标记为已初始化以避免重复尝试
      _isInitialized = true;
    }
  }

  /// 获取图标路径
  String _getIconPath() {
    if (Platform.isMacOS) {
      return 'assets/app_icon.png';
    } else if (Platform.isWindows) {
      // Windows 平台优先尝试 .ico，如果不存在则使用 .png
      final icoPath = 'assets/app_icon.ico';
      if (File(icoPath).existsSync()) {
        return icoPath;
      }
      return 'assets/app_icon.png';
    } else {
      return 'assets/app_icon.png';
    }
  }

  /// 销毁托盘
  Future<void> dispose() async {
    if (_isInitialized) {
      try {
        await _systemTray.destroy();
      } catch (e) {
        print('Warning: Failed to destroy system tray: $e');
      }
      _isInitialized = false;
    }
  }
}