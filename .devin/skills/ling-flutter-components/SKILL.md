---
name: ling-flutter-components
description: Nudgee Flutter 组件库目录与使用指南。覆盖所有可复用 Widget、IM 组件、服务层、路由、主题，避免重复造轮子。
---

# Nudgee Flutter 组件库目录 Skill

本 skill 是 Nudgee 项目可复用组件的完整目录。**在创建新 Widget 或页面之前，必须先查阅此文档**，确认是否已有现成组件可用。

## 1. 组件导入方式

```dart
// 基础组件（buttons/inputs/feedback/layout）— barrel 导出
import 'package:nudgee/core/widgets/widgets.dart';

// IM 聊天组件 — barrel 导出
import 'package:nudgee/core/widgets/im/im.dart';

// 单独导入某个组件（按需）
import 'package:nudgee/core/widgets/feedback/ling_avatar.dart';
```

## 2. 基础组件目录

### 2.1 按钮 (`buttons/`)

| 组件 | 说明 | 关键参数 |
|------|------|---------|
| `LingButton` | 统一按钮，替代 Elevated/Outlined/Text/FilledButton | `label`, `icon`, `variant`(filled/outlined/text/tonal), `size`(small/medium/large), `loading`, `expanded` |
| `LingIconButton` | 图标按钮 | `icon`, `onPressed`, `variant` |
| `LingFab` | 悬浮 action 按钮 | `icon`, `label`, `onPressed` |

```dart
// ✅ 标准用法
LingButton(label: '保存', icon: Icons.save, variant: LingButtonVariant.filled, onPressed: _save)
LingButton(label: '删除', variant: LingButtonVariant.outlined, loading: _isDeleting)

// ❌ 不要直接用 Material 按钮
ElevatedButton(onPressed: _save, child: Text('保存'))  // 禁止
```

### 2.2 输入 (`inputs/`)

| 组件 | 说明 | 关键参数 |
|------|------|---------|
| `LingTextField` | 文本输入框 | `label`, `hint`, `errorText`, `prefixIcon`, `suffixIcon`, `obscureText`, `maxLines` |
| `LingTextArea` | 多行文本 | `label`, `hint`, `maxLines` |
| `LingSearchField` | 搜索框 | `hint`, `onChanged`, `onSubmitted` |
| `LingSwitch` | 开关 | `value`, `onChanged` |
| `LingSlider` | 滑块 | `value`, `min`, `max`, `onChanged` |
| `LingSegmentedControl` | 分段控件 | `segments`, `selected`, `onChanged` |
| `LingDropdown` | 下拉选择 | `items`, `value`, `onChanged` |
| `LingRating` | 评分 | `value`, `max`, `onChanged` |
| `LingStepper` | 步进器 | `value`, `min`, `max`, `onChanged` |
| `LingOtpInput` | OTP 验证码输入 | `length`, `onCompleted` |

```dart
LingTextField(
  label: '昵称',
  hint: '请输入昵称',
  prefixIcon: Icons.person_outline,
  errorText: _error,
  onSubmitted: _submit,
)
```

### 2.3 反馈 (`feedback/`)

| 组件 | 说明 | 关键参数 |
|------|------|---------|
| `LingAvatar` | 头像（图片/首字母/图标 fallback） | `imageUrl`, `name`, `size`(xs/sm/md/lg/xl/xxl), `showOnlineStatus`, `showRing` |
| `LingCard` | 卡片 | `title`, `subtitle`, `trailing`, `onTap`, `bordered` |
| `LingBadge` | 徽章 | `text`, `variant` |
| `LingChip` | 标签 | `label`, `selected`, `onTap` |
| `LingEmptyState` | 空状态 | `icon`, `title`, `message`, `action` |
| `LingErrorView` | 错误状态 | `error`(AppException), `onRetry` |
| `LingLoadingIndicator` | 加载指示器 | `message`, `size` |
| `LingSkeleton` | 骨架屏 | `width`, `height`, `borderRadius` |
| `LingProgress` | 进度条 | `value`, `type`(linear/circular) |
| `LingSnackbar` | Snackbar | `show(context, message, severity)` |
| `LingDialog` | 对话框 | `confirm(context, title, content)`, `alert(context, title, content)` |
| `LingBottomSheet` | 底部弹窗 | `show(context, title, child)`, `showPersistent()` |
| `LingBanner` | 横幅通知 | `message`, `severity`, `action` |
| `LingTooltip` | 工具提示 | `message`, `child` |
| `LingCountdown` | 倒计时 | `duration`, `onComplete` |
| `LingMarquee` | 跑马灯 | `text`, `speed` |
| `LingImageBox` | 图片容器 | `imageUrl`, `fit`, `borderRadius` |
| `LingImageViewer` | 图片查看器（全屏） | `images`, `initialIndex` |
| `LingImageCropper` | 图片裁剪 | `image`, `aspectRatio`, `onCrop` |
| `LingAudioPlayer` | 音频播放器 | `url`, `autoPlay` |
| `LingVideoPlayer` | 视频播放器 | `url`, `autoPlay` |
| `LingWaveform` | 波形显示 | `data`, `onSeek` |
| `LingUploadProgress` | 上传进度 | `progress`, `fileName` |
| `LingDownloadProgress` | 下载进度 | `progress`, `fileName` |
| `LingWebView` / `LingWebViewPage` | WebView | `url`, `title` |

```dart
// 对话框
final confirmed = await LingDialog.confirm(
  context,
  title: '确认删除',
  content: '此操作不可撤销',
  isDestructive: true,
);
if (confirmed == true) _delete();

// Snackbar
LingSnackbar.show(context, '保存成功', severity: LingSnackbarSeverity.success);

// 空状态
LingEmptyState(icon: Icons.inbox_outlined, title: '暂无消息', message: '开始聊天吧');

// 底部弹窗
LingBottomSheet.show(
  context: context,
  title: '选择操作',
  child: Column(children: [...]),
);
```

### 2.4 布局 (`layout/`)

| 组件 | 说明 | 关键参数 |
|------|------|---------|
| `LingScaffold` | 标准脚手架（替代 Scaffold + AppBar） | `title`, `body`, `actions`, `popupActions`, `floatingActionButton`, `showBackButton` |
| `LingTopBar` | 顶部栏 | `title`, `actions`, `showBackButton` |
| `LingLoadingOverlay` | 加载遮罩 | `isLoading`, `child`, `message` |
| `LingTabBar` | 标签栏 | `tabs`, `controller` |
| `LingListItem` | 列表行 | `leadingIcon`, `title`, `subtitle`, `trailing`, `onTap` |
| `LingRefreshList<T>` | 下拉刷新+上拉加载列表 | `items`, `itemBuilder`, `onRefresh`, `onLoadMore`, `hasMore` |
| `LingDivider` | 分隔线 | `indent`, `thickness` |
| `LingNineGrid` | 九宫格 | `items`, `itemBuilder` |
| `LingCarousel` | 轮播 | `items`, `itemBuilder`, `autoPlay` |
| `LingTimeline` | 时间轴 | `items`, `itemBuilder` |

```dart
// 标准页面结构
LingScaffold(
  title: '设置',
  body: ListView(children: [...]),
  popupActions: [
    LingPopupAction(key: 'edit', text: '编辑', icon: Icons.edit),
  ],
  onPopupActionSelected: (key) { ... },
)

// 列表行
LingListItem(
  leadingIcon: Icons.settings,
  title: '主题设置',
  trailing: Icon(Icons.chevron_right),
  onTap: () => _openSettings(),
)

// 刷新列表
LingRefreshList(
  items: _items,
  itemBuilder: (ctx, item, index) => LingListItem(title: item.name),
  onRefresh: _loadData,
  onLoadMore: _loadMore,
  hasMore: _hasMore,
)
```

## 3. IM 聊天组件 (`im/`)

IM 组件是完整的聊天模块，通过 barrel `package:nudgee/core/widgets/im/im.dart` 导出。

### 3.1 核心组件

| 组件 | 说明 |
|------|------|
| `LingChatScreen` | 完整聊天页面（消息列表 + 输入栏 + 转发/回复/表情等） |
| `LingConversationList` | 会话列表（置顶/免打扰/删除/搜索） |
| `LingMessageList` | 消息列表（分页加载/滚动到底部/typing indicator） |
| `LingMessageBubble` | 消息气泡（文本/图片/语音/视频/文件/联系人卡片） |
| `LingChatInput` | 输入栏（文本/语音/表情/图片/文件/位置/联系人） |
| `LingTypingIndicator` | 输入中指示器（三点跳动动画） |

### 3.2 控制器

| 控制器 | 说明 |
|--------|------|
| `LingConversationController` | 会话列表控制器（增删改查/置顶/免打扰/搜索过滤） |
| `LingChatController` | 聊天消息控制器（消息增删改/typing 状态/分页加载/reaction） |

### 3.3 数据模型

| 模型 | 说明 |
|------|------|
| `LingConversation` | 会话（单聊/群聊/频道） |
| `LingMessage` | 消息（文本/图片/语音/视频/文件/联系人/自定义） |
| `LingChatUser` | 聊天用户 |
| `LingMessageReaction` | 消息表情反应 |
| `LingReplyQuote` | 回复引用 |

### 3.4 使用模式

```dart
// 创建控制器
final convController = LingConversationController(initialConversations: conversations);
final chatController = LingChatController(
  conversationId: conv.id,
  currentUserId: 'me',
  initialMessages: messages,
);

// 打开聊天页
Navigator.push(context, MaterialPageRoute(
  builder: (_) => LingChatScreen(
    conversation: conv,
    controller: chatController,
    userMap: userMap,
    currentUserId: 'me',
    onSend: (text) => _onSend(conv, text),
    appBarLeading: IconButton(icon: Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
  ),
));

// AI 流式回复模式（LingEcho）
void _streamAiReply(LingConversation conv, String userText) {
  controller.isTyping = true;  // 显示对方 typing indicator
  final buffer = StringBuffer();
  String? aiMsgId;

  ai.streamChat(userText).listen((delta) {
    buffer.write(delta);
    if (aiMsgId == null) {
      aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      controller.addMessage(LingMessage(
        id: aiMsgId!, conversationId: conv.id,
        authorId: aiBuddyId, type: LingMessageType.text,
        text: buffer.toString(), status: LingMessageStatus.sent,
      ));
      controller.isTyping = false;
    } else {
      controller.updateMessage(aiMsgId!, (m) => m.copyWith(text: buffer.toString()));
    }
  });
}
```

## 4. 服务层 (`core/services/`)

通过 DI (`sl`) 获取，**禁止直接 new**。

| 服务 | 获取方式 | 说明 |
|------|---------|------|
| `AuthService` | `sl<AuthService>()` | 用户认证（登录/注册/token 管理） |
| `AiService` | `sl<AiService>()` | AI 聊天（流式/模型切换/上下文管理） |
| `LoggerService` | `sl<LoggerService>()` | 日志（文件+远程上报） |
| `FileStorageService` | `sl<FileStorageService>()` | 本地文件存储（avatars/cache/downloads/logs） |
| `QiniuStorageService` | `sl<QiniuStorageService>()` | 七牛云存储 |
| `SecureStorageService` | `sl<SecureStorageService>()` | 安全存储（token/密钥） |
| `SharedPrefsService` | `sl<SharedPrefsService>()` | 轻量 key/value 存储 |
| `LocalDatabaseService` | `sl<LocalDatabaseService>()` | Hive 本地数据库 |
| `ApiClient` | `sl<ApiClient>()` | 网络请求（封装 Dio） |
| `ConnectivityService` | `sl<ConnectivityService>()` | 网络连接状态 |
| `DownloadService` | `sl<DownloadService>()` | 文件下载 |
| `UploadService` | `sl<UploadService>()` | 文件上传 |
| `PushNotificationService` | `sl<PushNotificationService>()` | 推送通知 |
| `AnalyticsService` | `sl<AnalyticsService>()` | 数据统计 |
| `FrameTimingMonitorService` | `sl<FrameTimingMonitorService>()` | 卡顿监控 |

```dart
// ✅ 从 DI 获取
final ai = sl<AiService>();
if (!ai.isConfigured) return;
await for (final chunk in ai.streamChat(text)) { ... }

// ❌ 禁止直接 new
final ai = AiService();  // 禁止
```

## 5. 路由 (`app/router/`)

使用 **GoRouter**，路由常量在 `AppRouter` 类中。

```dart
// 路由常量
AppRouter.home      //  /home
AppRouter.settings  //  /settings
AppRouter.about     //  /about
AppRouter.login     //  /login
AppRouter.feedback  //  /feedback
AppRouter.changelog //  /changelog
AppRouter.myInformation //  /profile/myInformation

// 导航
GoRouter.of(context).push(AppRouter.about);
GoRouter.of(context).go(AppRouter.home);
context.push(AppRouter.settings);  // go_router extension

// 新增路由：在 app_router.dart 添加
// 1. 路由常量
static const String myPage = '/myPage';
// 2. GoRoute
GoRoute(path: myPage, name: 'myPage', builder: (ctx, state) => MyPage()),
// 3. 如需登录保护，加到 route_guard.dart 的 _protectedRoutes
```

### 路由保护规则
- **公开路由**（无需登录）：`/settings`, `/about`, `/feedback`, `/privacyPolicy`, `/userAgreement`, `/changelog`
- **保护路由**（需登录）：`/profile/myInformation`, `/profile/changeNickName`, `/profile/avatarUpload`, `/profile/personalHome`

## 6. 主题 (`app/theme/`)

- **FlexColorScheme** 生成 light/dark 主题
- 颜色常量：`AppColors`（primary, secondary, tertiary, error, lightBackground...）
- 文字样式：`AppTextStyles`
- 主题切换：`themeControllerProvider`（Riverpod）
- 语言切换：`localeControllerProvider`（Riverpod）

```dart
// ✅ 使用主题色
Theme.of(context).colorScheme.primary
Theme.of(context).colorScheme.surface
context.colorScheme.onSurfaceVariant  // via context_extensions

// ❌ 禁止硬编码颜色
Color(0xFF6750A4)  // 禁止
Colors.white       // 禁止（除非在彩色背景上的文字）
```

## 7. 扩展方法 (`core/extensions/`)

| 扩展 | 用法 | 说明 |
|------|------|------|
| `context.l10n` | `context.l10n.appTitle` | 国际化文本 |
| `context.theme` | `context.theme.colorScheme` | 主题 |
| `context.colorScheme` | `context.colorScheme.primary` | ColorScheme |
| `context.isDarkMode` | `if (context.isDarkMode)` | 暗色模式判断 |
| `context.screenWidth` | `context.screenWidth` | 屏幕宽度 |
| `context.isSmallScreen` | `context.isSmallScreen` | 小屏判断 (<600) |
| `context.pop()` | `context.pop()` | 返回 |

## 8. 国际化 (`l10n/`)

```dart
// ✅ 使用 l10n
Text(context.l10n.appTitle)

// ARB 文件
// lib/l10n/app_en.arb  — 英文
// lib/l10n/app_zh.arb  — 中文

// 新增 key
// 1. 在 app_en.arb 和 app_zh.arb 添加
"myNewKey": "My New Key",
// 2. 带参数
"greetingWithName": "Hello, {name}",
"@greetingWithName": {"placeholders": {"name": {"type": "String"}}},
// 3. 运行 flutter gen-l10n
```

## 9. 页面模板

### 9.1 标准列表页

```dart
class MyListPage extends StatefulWidget {
  const MyListPage({super.key});
  @override
  State<MyListPage> createState() => _MyListPageState();
}

class _MyListPageState extends State<MyListPage> {
  List<Item> _items = [];
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();  // 不在 initState 用 context.l10n
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _items = await sl<MyService>().fetchItems();
    } catch (e) {
      LingSnackbar.show(context, e.toString(), severity: LingSnackbarSeverity.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LingScaffold(
      title: context.l10n.myPageTitle,
      body: _isLoading
          ? const LingLoadingIndicator()
          : _items.isEmpty
              ? LingEmptyState(icon: Icons.inbox, title: context.l10n.empty)
              : LingRefreshList(
                  items: _items,
                  itemBuilder: (ctx, item, i) => LingListItem(
                    title: item.name,
                    onTap: () => _openDetail(item),
                  ),
                  onRefresh: _loadData,
                ),
    );
  }
}
```

### 9.2 表单页

```dart
// 使用 LingTextField + LingButton
LingScaffold(
  title: context.l10n.editProfile,
  body: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        LingTextField(label: context.l10n.nickname, controller: _nickController),
        const SizedBox(height: 24),
        LingButton(
          label: context.l10n.save,
          variant: LingButtonVariant.filled,
          expanded: true,
          loading: _isSaving,
          onPressed: _save,
        ),
      ],
    ),
  ),
)
```

## 10. 禁止事项

- ❌ 重复造轮子 — 先查此文档再写新组件
- ❌ 直接用 `ElevatedButton` / `TextField` / `Scaffold` — 用 `Ling` 前缀组件
- ❌ 硬编码颜色 / 字符串 — 用 `Theme.of(context)` / `context.l10n`
- ❌ 在 `initState` 访问 `context.l10n` / `Theme.of(context)` — 用 `didChangeDependencies`
- ❌ 直接 `new Service()` — 用 `sl<Service>()`
- ❌ 相对路径导入 — 用 `package:nudgee/...`
