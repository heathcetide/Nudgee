# Nudgee 项目指南

## 项目简介
Nudgee — 自律 · 记账 · AI 陪伴 客户端

## 构建命令
- `flutter pub get` — 安装依赖
- `flutter analyze` — 代码分析
- `flutter run -d <device>` — 运行
- `flutter build apk --release` — 构建 APK

## 验证步骤
1. flutter analyze 无错误
2. flutter test 通过
3. 设备运行无异常

## 代码规范
- 使用 package:nudgee/ 导入，禁止相对路径
- 组件用 Nudgee 前缀（如 NudgeeButton）
- 遵循 Conventional Commits

## 目录结构
```
lib/
├── app/              # 应用层（router, theme, app.dart）
├── core/             # 核心基础设施
│   ├── config/       # 环境配置
│   ├── constants/    # 常量
│   ├── extensions/   # 扩展方法
│   ├── utils/        # 工具类
│   └── widgets/      # 基础组件
├── features/         # 业务功能模块
│   ├── auth/         # 登录/注册
│   ├── home/         # 首页
│   ├── habits/       # 自律/习惯打卡
│   ├── finance/      # 记账
│   ├── chat/         # AI 聊天
│   └── profile/      # 个人中心
└── l10n/             # 国际化
```

## 技术栈（待接入）
- 状态管理：Riverpod
- 路由：go_router
- 本地数据库：待定（Isar / drift）
- AI：待定（OpenAI / Claude API）
- 后端：待定（Supabase）
