import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../services/pingcode_service.dart';
import '../services/tray_service.dart';

/// PingCode 通知监控页面
/// 提供任务提醒监控配置功能
class PingCodeNotifyPage extends StatefulWidget {
  /// 构造函数
  const PingCodeNotifyPage({super.key});

  @override
  State<PingCodeNotifyPage> createState() => _PingCodeNotifyPageState();
}

class _PingCodeNotifyPageState extends State<PingCodeNotifyPage> with WindowListener {
  /// 存储服务
  final StorageService _storageService = StorageService();

  /// PingCode 服务
  final PingCodeService _pingCodeService = PingCodeService();

  /// 托盘服务
  final TrayService _trayService = TrayService();

  /// Token 输入控制器
  final TextEditingController _tokenController = TextEditingController();

  /// 域名输入控制器
  final TextEditingController _domainController = TextEditingController();

  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否正在监控
  bool _isMonitoring = false;

  /// 未读消息通知开关
  bool _enableUnreadNotification = true;

  /// 任务到期通知开关
  bool _enableTaskDueNotification = true;

  /// 是否使用 HTTPS
  bool _useHttps = false;

  /// 窗口是否已隐藏到托盘
  bool _isWindowHidden = false;

  @override
  void initState() {
    super.initState();
    // 添加窗口监听器
    windowManager.addListener(this);
    _initialize();
  }

  @override
  void dispose() {
    // 移除窗口监听器
    windowManager.removeListener(this);
    _tokenController.dispose();
    _domainController.dispose();
    _pingCodeService.stop();
    _trayService.dispose();
    super.dispose();
  }

  /// 初始化方法
  Future<void> _initialize() async {
    // 初始化存储服务
    await _storageService.init();

    // 加载保存的配置
    _tokenController.text = _storageService.getToken();
    _domainController.text = _storageService.getDomain();
    _useHttps = _storageService.getUseHttps();
    _enableUnreadNotification = _storageService.getUnreadNotificationEnabled();
    _enableTaskDueNotification = _storageService.getTaskDueNotificationEnabled();

    // 设置通知回调
    _pingCodeService.onNotification = (title, body) {
      _showNotificationDialog(title, body);
    };

    // 初始化托盘服务
    await _trayService.init(
      onWindowClose: _exitApp,
      onTrayDoubleClick: _showWindow,
    );

    setState(() {
      _isInitialized = true;
    });
  }

  /// 窗口关闭回调
  @override
  void onWindowClose() async {
    // 阻止直接关闭，改为隐藏到托盘
    bool isPreventClose = true;
    if (isPreventClose) {
      _hideToTray();
    }
  }

  /// 隐藏窗口到托盘
  Future<void> _hideToTray() async {
    await windowManager.hide();
    setState(() {
      _isWindowHidden = true;
    });
  }

  /// 显示窗口
  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    setState(() {
      _isWindowHidden = false;
    });
  }

  /// 退出应用
  Future<void> _exitApp() async {
    await _trayService.dispose();
    _pingCodeService.stop();
    // 允许窗口关闭
    await windowManager.destroy();
    exit(0);
  }

  /// 显示通知对话框
  void _showNotificationDialog(String title, String body) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    await _storageService.saveToken(_tokenController.text.trim());
    await _storageService.saveDomain(_domainController.text.trim());
    await _storageService.saveUseHttps(_useHttps);
    await _storageService.saveUnreadNotificationEnabled(_enableUnreadNotification);
    await _storageService.saveTaskDueNotificationEnabled(_enableTaskDueNotification);
  }

  /// 启动监控
  Future<void> _startMonitoring() async {
    final token = _tokenController.text.trim();
    final domain = _domainController.text.trim();

    if (token.isEmpty) {
      _showSnackBar('请输入鉴权 Token');
      return;
    }

    if (domain.isEmpty) {
      _showSnackBar('请输入 PingCode 域名');
      return;
    }

    await _saveConfig();

    await _pingCodeService.start(
      token: token,
      domain: domain,
      useHttps: _useHttps,
      enableUnreadNotification: _enableUnreadNotification,
      enableTaskDueNotification: _enableTaskDueNotification,
    );

    setState(() {
      _isMonitoring = true;
    });

    _showSnackBar('监控已启动');
  }

  /// 停止监控
  void _stopMonitoring() {
    _pingCodeService.stop();
    setState(() {
      _isMonitoring = false;
    });
    _showSnackBar('监控已停止');
  }

  /// 显示 SnackBar 消息
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 测试通知
  void _testNotification() {
    _showNotificationDialog('🔔 测试通知', '这是一条测试消息');
    _showSnackBar('测试通知已发送');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 如果窗口已隐藏到托盘，返回空容器
    if (_isWindowHidden) {
      return const Scaffold(
        body: Center(
          child: Text(
            '已最小化到托盘\n双击托盘图标可恢复窗口',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('PingCode 任务监控'),
        centerTitle: true,
       
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 状态指示器
            _buildStatusIndicator(),
            const SizedBox(height: 32),

            // 鉴权信息区域
            _buildAuthSection(),
            const SizedBox(height: 24),

            // 通知开关区域
            _buildNotificationSwitches(),
            const SizedBox(height: 24),

            // 操作按钮区域
            _buildActionButtons(),
            const Spacer(),

            // 说明信息
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  /// 构建状态指示器
  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isMonitoring
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isMonitoring ? Colors.green : Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isMonitoring ? Icons.check_circle : Icons.circle_outlined,
            color: _isMonitoring ? Colors.green : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            _isMonitoring ? '监控服务运行中' : '监控服务已停止',
            style: TextStyle(
              color: _isMonitoring ? Colors.green : Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isMonitoring) ...[
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建鉴权信息区域
  Widget _buildAuthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '鉴权信息',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _domainController,
          decoration: InputDecoration(
            labelText: 'PingCode 域名',
            hintText: '例如：pingcode.example.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.language),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _tokenController,
          decoration: InputDecoration(
            labelText: 'Authorization Token',
            hintText: '请输入 PingCode Authorization Token',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            prefixIcon: const Icon(Icons.key),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 8),
        Text(
          '提示：Token 可以在 PingCode 开发者工具中获取',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// 构建通知开关区域
  Widget _buildNotificationSwitches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '通知开关',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('未读消息通知'),
                subtitle: const Text('当有未读消息时发送通知'),
                value: _enableUnreadNotification,
                onChanged: (value) {
                  setState(() {
                    _enableUnreadNotification = value;
                  });
                  if (_isMonitoring) {
                    _saveConfig();
                  }
                },
                secondary: const Icon(Icons.notifications),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('任务到期通知'),
                subtitle: const Text('当天任务在 18:00 后未完成发送通知'),
                value: _enableTaskDueNotification,
                onChanged: (value) {
                  setState(() {
                    _enableTaskDueNotification = value;
                  });
                  if (_isMonitoring) {
                    _saveConfig();
                  }
                },
                secondary: const Icon(Icons.task_alt),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮区域
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
            icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
            label: Text(_isMonitoring ? '停止监控' : '启动监控'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isMonitoring ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 18),
        OutlinedButton.icon(
          onPressed: _testNotification,
          icon: const Icon(Icons.notifications_active),
          label: const Text('测试通知'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
      ],
    );
  }

  /// 构建说明信息区域
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                '使用说明',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoItem('1. 输入 PingCode 域名 & Authorization Token'),
          _buildInfoItem('2. 开启需要监控的通知类型 & 监控间隔为 10 分钟'),
        ],
      ),
    );
  }

  /// 构建信息项
  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
