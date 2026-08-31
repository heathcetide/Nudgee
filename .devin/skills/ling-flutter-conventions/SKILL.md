---
name: ling-flutter-conventions
description: Nudgee Flutter 代码规范与命名约定。覆盖命名、目录结构、状态管理、DI、错误处理、国际化、提交规范。
---

# Nudgee Flutter 代码规范 Skill

本 skill 用于在 Nudgee 项目中编写或修改代码时，强制遵循项目约定。

## 1. 命名规范

### 1.1 组件前缀
- 所有自定义 Widget 类名**必须**用 `Ling` 前缀
  - ✅ `LingButton`、`LingMessageBubble`、`LingAvatar`
  - ❌ `AppButton`、`MyButton`、`CustomButton`
- 文件名用 `ling_` 前缀 + snake_case
  - ✅ `ling_button.dart`、`ling_message_bubble.dart`
  - ❌ `button.dart`、`message_bubble.dart`

### 1.2 Service / Controller
- Service 类名：`XxxService`（如 `AuthService`、`LoggerService`）
- Controller 类名：`XxxController`（如 `LingChatController`）
- Model 类名：`LingXxx`（如 `LingMessage`、`LingConversation`）

### 1.3 枚举
- 枚举名用 `Ling` 前缀，值用 camelCase
  - ✅ `LingMessageType.text`、`LingUserStatus.online`

## 2. 导入规范

- 项目内导入**必须**用 `package:nudgee/...`，禁止相对路径
  - ✅ `import 'package:nudgee/core/core.dart';`
  - ❌ `import '../../core/core.dart';`
- 第三方包导入用 `package:`
- Dart SDK 导入用 `dart:`
- 导入顺序：dart → 第三方 → 项目内，每组间空行分隔

## 3. 目录结构

```
lib/
├── app/              # 应用层（router, theme, app.dart）
├── core/             # 核心基础设施
│   ├── config/       # 环境配置
│   ├── constants/    # 常量
│   ├── controllers/  # 控制器（IM 等）
│   ├── di/           # 依赖注入
│   ├── errors/       # 异常定义
│   ├── extensions/   # 扩展方法
│   ├── models/       # 数据模型
│   ├── network/      # 网络层（Dio, 拦截器）
│   ├── services/     # 服务层
│   ├── utils/        # 工具类
│   └── widgets/      # 基础组件
├── features/         # 业务功能模块
│   ├── home/
│   ├── profile/
│   └── splash/
└── l10n/             # 国际化 ARB 文件
```

- 基础设施代码放 `core/`
- 业务功能放 `features/`
- **禁止**在 `core/` 引入业务逻辑
- **禁止**过早引入 ASR/LLM/TTS/多租户等业务抽象

## 4. 状态管理

- 使用 **Riverpod**（`flutter_riverpod`）
- Provider 命名：`xxxControllerProvider`、`xxxProvider`
- 精准监听：用 `.select()` 只监听需要的字段
- 自动释放：加 `autoDispose` 除非明确需要常驻
- 禁止在 build() 内修改 provider 状态

## 5. 依赖注入

- 使用 **GetIt**（`get_it`）
- 全局实例：`final GetIt sl = GetIt.instance;`
- 注册位置：`lib/core/di/injector.dart` 的 `initDependencies()`
- 优先 `registerLazySingleton`，需要立即初始化的用 `registerSingleton`
- 用 `_safeRegister()` 包裹，单个服务失败不影响其他

## 6. 错误处理

- 自定义异常继承 `AppException`（`lib/core/errors/app_exception.dart`）
- 网络错误用 `ApiException` / `NetworkException`
- 存储错误用 `StorageException`
- 蓝牙错误用 `BluetoothException`
- **禁止**裸 `throw Exception('xxx')`，用具体异常类型
- UI 层用 `LingErrorView` / `LingEmptyState` 展示错误

## 7. 网络请求

- 使用 `ApiClient`（封装 Dio）
- 响应模型：`ApiResponse<T>` / `ApiListResponse<T>`
- 拦截器链：Auth → Retry → Logging → Error → TokenRefresh
- 401 自动刷新 token（`TokenRefreshInterceptor`）
- 请求取消：用 Dio `CancelToken`
- **禁止**直接 `new Dio()`，从 DI 取 `ApiClient`

## 8. 存储

- 轻量 key/value：`SharedPrefsService`
- 敏感数据（token）：`SecureStorageService`
- 结构化数据：`LocalDatabaseService`（Hive）
- **禁止**把 token/密钥存入 SharedPreferences 明文

## 9. 日志

- 使用 `LoggerService`，**禁止** `print()` / `debugPrint()` 在业务代码
- 日志级别：verbose / debug / info / warning / error / fatal
- 带 tag：`logger.info('AuthService', 'login success')`
- 日志自动写文件 + 远程上报

## 10. 国际化

- 所有用户可见文字**必须**走 `AppLocalizations`
- ARB 文件：`lib/l10n/app_en.arb` + `lib/l10n/app_zh.arb`
- 生成：`flutter gen-l10n`
- ❌ 硬编码中文字符串在 Widget 中

## 11. 主题

- 颜色用 `AppColors`，**禁止**硬编码 `Color(0xFF...)`
- 文字样式用 `AppTextStyles`
- 间距用 `AppConstants.spacingXxx`
- 圆角用 `AppConstants.radiusXxx`
- 通过 `Theme.of(context)` 或 `context.theme` 获取

## 12. 组件规范

- 基础组件放 `lib/core/widgets/`，按类别子目录：
  - `buttons/`、`inputs/`、`feedback/`、`layout/`、`im/`
- barrel 导出：`lib/core/widgets/widgets.dart`
- **禁止**重复导出同名类（会导致 `ambiguous_export`）
- 新组件**必须**加到 barrel 导出

## 13. 提交规范

- 遵循 Conventional Commits（见 `COMMIT_CONVENTION.md`）
- 格式：`type(scope): description`
- type: feat / fix / refactor / perf / docs / test / chore
- pre-commit 钩子运行 `flutter analyze`

## 14. 测试

- 单元测试：`test/` 目录
- 用 `TestHelpers` + `MockDio` + `MockHttpClientAdapter`
- Widget 测试用 `testWidgets`
- **禁止**在测试中直接继承 Dio（工厂构造器无法继承）

## 15. 禁止事项

- ❌ 过早引入业务抽象（ASR/LLM/TTS/多租户/SIP外呼/AI插件）
- ❌ 在 `core/` 写业务逻辑
- ❌ 硬编码 URL / 密钥（用 `--dart-define` 或 flavor）
- ❌ `print()` 在业务代码
- ❌ 直接 `new Dio()`
- ❌ 相对路径导入
- ❌ 不加 `const` 的静态 Widget
