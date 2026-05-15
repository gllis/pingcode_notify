import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// PingCode 通知监控服务
/// 负责定时检查未读消息和任务到期情况
class PingCodeService {
  /// 单例模式
  static final PingCodeService _instance = PingCodeService._internal();
  factory PingCodeService() => _instance;
  PingCodeService._internal();

  /// 监控间隔时间（秒）
  static const int _intervalSeconds = 600;

  /// 定时器
  Timer? _timer;

  /// 是否正在运行
  bool _isRunning = false;

  /// 通知回调函数
  void Function(String title, String body)? onNotification;

  /// 构建通知 API 地址
  String _getNotificationUrl(String domain, bool useHttps) {
    final protocol = useHttps ? 'https' : 'http';
    return '$protocol://$domain/api/iris/notifications';
  }

  /// 构建任务 API 地址
  String _getTaskUrl(String domain, bool useHttps) {
    final protocol = useHttps ? 'https' : 'http';
    return '$protocol://$domain/api/ladon/workspace/home/todo/works';
  }

  /// 启动监控服务
  Future<void> start({
    required String token,
    required String domain,
    required bool useHttps,
    required bool enableUnreadNotification,
    required bool enableTaskDueNotification,
  }) async {
    if (_isRunning) {
      return;
    }

    _isRunning = true;

    // 立即执行一次，然后开始定时循环
    await _checkNotifications(
      token: token,
      domain: domain,
      useHttps: useHttps,
      enableUnreadNotification: enableUnreadNotification,
      enableTaskDueNotification: enableTaskDueNotification,
    );

    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) async {
        await _checkNotifications(
          token: token,
          domain: domain,
          useHttps: useHttps,
          enableUnreadNotification: enableUnreadNotification,
          enableTaskDueNotification: enableTaskDueNotification,
        );
      },
    );
  }

  /// 停止监控服务
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  /// 检查通知和任务
  Future<void> _checkNotifications({
    required String token,
    required String domain,
    required bool useHttps,
    required bool enableUnreadNotification,
    required bool enableTaskDueNotification,
  }) async {
    final headers = {
      'Authorization': token,
    };

    // 检查未读消息
    if (enableUnreadNotification) {
      await _checkUnreadNotifications(headers, domain, useHttps);
    }

    // 检查任务到期
    if (enableTaskDueNotification) {
      await _checkTaskDue(headers, domain, useHttps);
    }
  }

  /// 检查未读通知
  Future<void> _checkUnreadNotifications(Map<String, String> headers, String domain, bool useHttps) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(_getNotificationUrl(domain, useHttps)).replace(
        queryParameters: {
          't': timestamp.toString(),
          'ps': '9999',
          'filter': 'unread',
        },
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 200) {
          final value = data['data']?['value'];

          if (value != null && value.length > 0) {
            _showNotification(
              title: '🔔 监控提醒',
              body: '你有未读消息，请登录PingCode查看',
            );
          }
        }
      }
    } catch (e) {
      // 静默处理异常，避免频繁错误提示
      print('检查未读通知失败: $e');
    }
  }

  /// 检查任务到期
  Future<void> _checkTaskDue(Map<String, String> headers, String domain, bool useHttps) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse(_getTaskUrl(domain, useHttps)).replace(
        queryParameters: {
          't': timestamp.toString(),
        },
      );

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final hour = now.hour;

        if (data['code'] == 200) {
          final tasks = data['data']?['value'] as List?;

          if (tasks != null) {
            for (final task in tasks) {
              final dueTimestamp = task['due']?['date'];

              if (dueTimestamp != null) {
                final dueDate = DateTime.fromMillisecondsSinceEpoch(
                  dueTimestamp is int ? dueTimestamp * 1000 : dueTimestamp,
                ).toLocal();
                final dueDateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);

                if (dueDateOnly == today) {
                  if (hour >= 16) {
                    _showNotification(
                      title: '🔔 监控提醒',
                      body: '发现今天的任务：${task['name']} 未完成，请查看',
                    );
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // 静默处理异常
      print('检查任务到期失败: $e');
    }
  }

  /// 显示通知
  void _showNotification({
    required String title,
    required String body,
  }) {
    // 调用通知回调
    onNotification?.call(title, body);
  }
}

/// 存储服务
/// 负责保存和加载用户配置
class StorageService {
  /// 单例模式
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// SharedPreferences 实例
  SharedPreferences? _prefs;

  /// 初始化
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// 保存 Token
  Future<void> saveToken(String token) async {
    await _prefs?.setString('pingcode_token', token);
  }

  /// 获取 Token
  String getToken() {
    return _prefs?.getString('pingcode_token') ?? '';
  }

  /// 保存域名
  Future<void> saveDomain(String domain) async {
    await _prefs?.setString('pingcode_domain', domain);
  }

  /// 获取域名
  String getDomain() {
    return _prefs?.getString('pingcode_domain') ?? '';
  }

  /// 保存是否使用 HTTPS
  Future<void> saveUseHttps(bool useHttps) async {
    await _prefs?.setBool('pingcode_use_https', useHttps);
  }

  /// 获取是否使用 HTTPS
  bool getUseHttps() {
    return _prefs?.getBool('pingcode_use_https') ?? false;
  }

  /// 保存未读通知开关状态
  Future<void> saveUnreadNotificationEnabled(bool enabled) async {
    await _prefs?.setBool('unread_notification_enabled', enabled);
  }

  /// 获取未读通知开关状态
  bool getUnreadNotificationEnabled() {
    return _prefs?.getBool('unread_notification_enabled') ?? true;
  }

  /// 保存任务到期通知开关状态
  Future<void> saveTaskDueNotificationEnabled(bool enabled) async {
    await _prefs?.setBool('task_due_notification_enabled', enabled);
  }

  /// 获取任务到期通知开关状态
  bool getTaskDueNotificationEnabled() {
    return _prefs?.getBool('task_due_notification_enabled') ?? true;
  }
}
