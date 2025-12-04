import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener {
  LocalNotification? _exampleNotification = LocalNotification(
    identifier: '_exampleNotification',
    title: 'Local Notifier 示例',
    subtitle: '展示操作按钮与事件回调',
    body: '点击通知或操作按钮后可在右侧日志面板查看回调。',
    actions: [
      LocalNotificationAction(text: '接受'),
      LocalNotificationAction(text: '忽略'),
    ],
  );

  final List<LocalNotification> _notificationList = [];
  final List<String> _logMessages = [];

  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();

    if (_exampleNotification != null) {
      _registerNotificationCallbacks(_exampleNotification!, showToast: true);
    }
    _initTray();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'images/tray_icon_original.ico'
          : 'images/tray_icon_original.png',
    );
    final Menu menu = Menu(
      items: [
        MenuItem(
          label: '显示窗口',
          onClick: (_) async {
            await windowManager.show();
            await windowManager.setSkipTaskbar(false);
          },
        ),
        MenuItem(
          label: '隐藏窗口',
          onClick: (_) async {
            await windowManager.hide();
            await windowManager.setSkipTaskbar(true);
          },
        ),
        MenuItem.separator(),
        MenuItem(
          label: '显示示例通知',
          onClick: (_) => _exampleNotification?.show(),
        ),
        MenuItem(
          label: '关闭示例通知',
          onClick: (_) => _exampleNotification?.close(),
        ),
        MenuItem(
          label: '新建动态通知',
          onClick: (_) => _handleNewLocalNotification(),
        ),
        MenuItem.separator(),
        MenuItem(
          label: '退出应用',
          onClick: (_) async {
            await windowManager.destroy();
          },
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
    setState(() {});
  }

  void _registerNotificationCallbacks(
    LocalNotification notification, {
    bool showToast = false,
  }) {
    notification.onShow = () {
      _log('onShow ${notification.identifier}', showToast: showToast);
    };
    notification.onClose = (closeReason) {
      _log(
        'onClose ${notification.identifier} - $closeReason',
        showToast: showToast,
      );
    };
    notification.onClick = () {
      _log('onClick ${notification.identifier}', showToast: showToast);
    };
    notification.onClickAction = (actionIndex) {
      _log(
        'onClickAction ${notification.identifier} - $actionIndex',
        showToast: showToast,
      );
    };
  }

  void _log(String message, {bool showToast = false}) {
    final String timestamp =
        DateTime.now().toLocal().toIso8601String().split('.').first;
    final String entry = '[$timestamp] $message';
    if (kDebugMode) {
      debugPrint(entry);
    }
    setState(() {
      _logMessages.insert(0, entry);
      if (_logMessages.length > 200) {
        _logMessages.removeLast();
      }
    });
    if (showToast) {
      BotToast.showText(text: message);
    }
  }

  Future<void> _handleDestroyExampleNotification() async {
    if (_exampleNotification == null) {
      return;
    }
    final String identifier = _exampleNotification!.identifier;
    await _exampleNotification!.destroy();
    setState(() {
      _exampleNotification = null;
    });
    _log('destroy $identifier', showToast: true);
  }

  void _handleRestoreExampleNotification() {
    if (_exampleNotification != null) {
      return;
    }
    setState(() {
      _exampleNotification = LocalNotification(
        identifier: '_exampleNotification',
        title: 'Local Notifier 示例',
        subtitle: '展示操作按钮与事件回调',
        body: '点击通知或操作按钮后可在右侧日志面板查看回调。',
        actions: [
          LocalNotificationAction(text: '接受'),
          LocalNotificationAction(text: '忽略'),
        ],
      );
    });
    _registerNotificationCallbacks(_exampleNotification!, showToast: true);
    _log('已重新创建示例通知', showToast: true);
  }

  Future<void> _handleNewLocalNotification() async {
    final int index = _notificationList.length + 1;
    final LocalNotification notification = LocalNotification(
      title: '动态通知 $index',
      subtitle: 'local_notifier_example',
      body: '这是一条演示用的通知，可在日志中查看回调。',
    );
    _registerNotificationCallbacks(notification);
    setState(() {
      _notificationList.add(notification);
    });
    _log('create ${notification.identifier}');
  }

  Future<void> _handleDestroyNotification(
      LocalNotification notification) async {
    await notification.destroy();
    setState(() {
      _notificationList.removeWhere(
        (item) => item.identifier == notification.identifier,
      );
    });
    _log('destroy ${notification.identifier}');
  }

  Future<void> _handleClearNotifications() async {
    for (final LocalNotification notification in _notificationList) {
      await notification.destroy();
    }
    setState(() {
      _notificationList.clear();
    });
    _log('已清空动态通知');
  }

  void _clearLogs() {
    setState(() {
      _logMessages.clear();
    });
  }

  Widget _buildBody(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget controls = _buildControlsArea();
        final Widget logs = _buildLogPanel();
        final bool isWide = constraints.maxWidth > 860;
        if (isWide) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(flex: 3, child: controls),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: logs),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(flex: 3, child: controls),
              const SizedBox(height: 16),
              Expanded(flex: 2, child: logs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsArea() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildIntroCard(),
        const SizedBox(height: 16),
        _buildExampleNotificationCard(),
        const SizedBox(height: 16),
        _buildDynamicNotificationsCard(),
      ],
    );
  }

  Widget _buildIntroCard() {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '使用说明',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('1. 左侧提供固定示例通知与动态通知两类演示。'),
            const Text('2. 右侧显示 LocalNotifier 的回调事件日志，便于调试。'),
            const Text('3. 也可以通过系统托盘菜单快速触发相同的操作。'),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleNotificationCard() {
    final bool hasNotification = _exampleNotification != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.push_pin_outlined),
                const SizedBox(width: 8),
                Text(
                  '固定示例通知',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasNotification
                  ? '当前示例 ID：${_exampleNotification!.identifier}'
                  : '示例通知已销毁，可点击下方按钮重新创建。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: hasNotification
                      ? () => _exampleNotification!.show()
                      : null,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('显示'),
                ),
                OutlinedButton.icon(
                  onPressed: hasNotification
                      ? () => _exampleNotification!.close()
                      : null,
                  icon: const Icon(Icons.close),
                  label: const Text('关闭'),
                ),
                TextButton.icon(
                  onPressed: hasNotification
                      ? () => _handleDestroyExampleNotification()
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('销毁'),
                ),
              ],
            ),
            if (!hasNotification) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _handleRestoreExampleNotification,
                icon: const Icon(Icons.refresh),
                label: const Text('重新创建示例通知'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicNotificationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_outlined),
                    const SizedBox(width: 8),
                    Text(
                      '动态通知列表',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                IconButton(
                  tooltip: '清空列表',
                  onPressed: _notificationList.isEmpty
                      ? null
                      : () => _handleClearNotifications(),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('每次点击“新建通知”都会生成一个独立的 LocalNotification 实例。'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _handleNewLocalNotification,
                icon: const Icon(Icons.add),
                label: const Text('新建通知'),
              ),
            ),
            const SizedBox(height: 16),
            if (_notificationList.isEmpty)
              _buildEmptyState('还没有创建任何动态通知。')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  final LocalNotification notification =
                      _notificationList[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(notification.title),
                    subtitle: Text(notification.identifier),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: '显示通知',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => notification.show(),
                        ),
                        IconButton(
                          tooltip: '关闭通知',
                          icon: const Icon(Icons.close),
                          onPressed: () => notification.close(),
                        ),
                        IconButton(
                          tooltip: '销毁通知',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _handleDestroyNotification(notification),
                        ),
                      ],
                    ),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: _notificationList.length,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogPanel() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.event_note_outlined),
            title: const Text('事件日志'),
            subtitle: const Text('展示 local_notifier 插件回调，方便调试。'),
            trailing: IconButton(
              tooltip: '清空日志',
              onPressed: _logMessages.isEmpty ? null : _clearLogs,
              icon: const Icon(Icons.clear_all),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _logMessages.isEmpty
                ? _buildEmptyState('暂无事件，请先触发通知。', center: true)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemBuilder: (context, index) {
                      final String entry = _logMessages[index];
                      return Text(
                        entry,
                        style: const TextStyle(fontFamily: 'monospace'),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _logMessages.length,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, {bool center = false}) {
    final Color iconColor = Colors.grey.shade500;
    final Widget content = center
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: iconColor),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.info_outline, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: center ? Center(child: content) : content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Notifier 示例'),
      ),
      body: _buildBody(context),
    );
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }
}
