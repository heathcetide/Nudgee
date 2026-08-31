# iOS 多渠道打包 (Flavor / Build Configuration)

本项目使用 Flutter Flavor 机制支持 dev、staging、prod 三个渠道。
Android 端已在 `android/app/build.gradle` 中配置 `productFlavors`。
iOS 端需要在 Xcode 中手动配置对应的 Build Configuration 与 Scheme。

## 1. Xcode Build Configuration 设置

在 Xcode 中为每个 Flavor 创建对应的 Build Configuration（基于现有的 Debug/Release 复制）：

| Flavor   | Debug Configuration        | Release Configuration           |
|----------|----------------------------|---------------------------------|
| dev      | Debug-dev                  | Release-dev                     |
| staging  | Debug-staging              | Release-staging                 |
| prod     | Debug-prod                 | Release-prod                    |

### 步骤
1. 打开 `ios/Runner.xcworkspace`
2. 选中 Runner Project → Info → Configurations
3. 点 `+` → Duplicate "Debug" Configuration → 命名为 `Debug-dev`
4. 同理创建 `Debug-staging`、`Debug-prod`
5. 对 Release 重复上述操作

## 2. Bundle Identifier 与 App Name

为每个 Configuration 设置不同的 Bundle Identifier 和 Display Name：

| Flavor   | Bundle Identifier              | Display Name      |
|----------|--------------------------------|-------------------|
| dev      | com.nudgee.dev      | Nudgee Dev      |
| staging  | com.nudgee.staging  | Nudgee Staging  |
| prod     | com.nudgee          | Nudgee          |

### 在 Info.plist 中使用变量
将 `ios/Runner/Info.plist` 中的 `CFBundleDisplayName` 改为：
```xml
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```

然后在每个 Build Configuration 的 User-Defined Build Settings 中添加：
- `APP_DISPLAY_NAME` = `Nudgee Dev` / `Nudgee Staging` / `Nudgee`

## 3. Xcode Scheme 设置

为每个 Flavor 创建独立的 Scheme：

1. Xcode → Product → Scheme → Manage Schemes
2. 新建 Scheme 命名为 `dev`、`staging`、`prod`
3. 每个 Scheme 的 Build / Run / Archive 都选择对应的 Configuration

## 4. Flutter 构建命令

```bash
# Dev
flutter run --flavor dev -d <ios-device>
flutter build ios --flavor dev --debug

# Staging
flutter run --flavor staging -d <ios-device>
flutter build ios --flavor staging --release

# Prod
flutter run --flavor prod -d <ios-device>
flutter build ios --flavor prod --release
```

## 5. Fastlane 自动化打包（可选）

如需使用 Fastlane 自动化打包，在 `ios/fastlane/` 目录下创建 `Fastfile`：

```ruby
default_platform(:ios)

platform :ios do
  desc "Build dev IPA"
  lane :dev do
    build_app(
      scheme: "dev",
      export_method: "development"
    )
  end

  desc "Build staging IPA"
  lane :staging do
    build_app(
      scheme: "staging",
      export_method: "ad-hoc"
    )
  end

  desc "Build prod IPA and upload to TestFlight"
  lane :prod do
    build_app(
      scheme: "prod",
      export_method: "app-store"
    )
    upload_to_testflight
  end
end
```

### 使用 Fastlane
```bash
cd ios
fastlane dev       # 构建 dev
fastlane staging   # 构建 staging
fastlane prod      # 构建 prod 并上传 TestFlight
```
