# Nudgee 项目指南

## 构建命令
- `flutter pub get` — 安装依赖
- `flutter analyze` — 代码分析
- `flutter run -d <device>` — 运行
- `flutter build apk --flavor dev` — 构建 dev APK
- `flutter build apk --flavor prod --release` — 构建生产 APK

## 验证步骤
1. flutter analyze 无错误
2. flutter test 通过
3. Android 设备运行无异常

## 代码规范
- 使用 package:nudgee/ 导入
- 组件用 Ling 前缀
- 遵循 Conventional Commits

## Flavor 多渠道打包

项目支持三个 Flavor：`dev`、`staging`、`prod`。

| Flavor   | Application ID                  | App Name        |
|----------|---------------------------------|-----------------|
| dev      | com.nudgee.dev       | Nudgee Dev    |
| staging  | com.nudgee.staging   | Nudgee Staging|
| prod     | com.nudgee           | Nudgee        |

### Android
- 配置位于 `android/app/build.gradle` 的 `productFlavors`
- 各 Flavor 资源目录：`android/app/src/{dev,staging,prod}/res/`

### iOS
- 配置说明见 `ios/fastlane/README.md`
- 需在 Xcode 中手动创建 Build Configuration 与 Scheme

## Git 钩子
- 运行 `scripts/setup_hooks.sh` 安装 pre-commit 钩子
- 钩子会在每次提交前运行 `flutter analyze`

## 提交规范
- 详见 `COMMIT_CONVENTION.md`
- 配置模板：`git config commit.template .gitmessage`
