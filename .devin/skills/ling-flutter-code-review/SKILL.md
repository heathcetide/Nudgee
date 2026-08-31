---
name: ling-flutter-code-review
description: Nudgee Flutter 代码审查清单。在 PR 或代码改动后逐项检查性能、规范、内存、安全、可维护性。
---

# Nudgee Flutter 代码审查 Skill

本 skill 用于审查 Nudgee 项目的代码改动，确保符合性能规范和项目约定。

## 审查流程

1. 先跑 `flutter analyze` 确认零 error
2. 按 below 清单逐项检查
3. 标记 ✅ 通过 / ❌ 需修复 / ⚠️ 建议优化

## 1. 性能审查

### 1.1 Widget 重建
- [ ] 静态 Widget 是否加了 `const`
- [ ] build() 内是否创建了可提取的对象（TextStyle/EdgeInsets/Decoration）
- [ ] build() 内是否做了计算/过滤/排序
- [ ] StatefulWidget 是否过大，可否拆分
- [ ] Riverpod watch 是否用了 `.select()` 精准监听
- [ ] Provider 是否加了 `autoDispose`

### 1.2 渲染
- [ ] 动画/高频刷新组件是否包了 `RepaintBoundary`
- [ ] 是否滥用 `Opacity` / `ClipRRect` / `BackdropFilter`
- [ ] 布局嵌套是否 ≤4 层
- [ ] 动画回调里是否调了 `setState`

### 1.3 列表
- [ ] 是否用了 `ListView.builder` 而非 `ListView(children:[])`
- [ ] 固定高度列表是否设了 `itemExtent`
- [ ] 列表 item 是否拆分组件 + const
- [ ] 图片是否设了 `cacheWidth`/`cacheHeight`
- [ ] 是否分页加载

### 1.4 内存
- [ ] `StreamSubscription` 是否在 dispose() cancel
- [ ] `Timer` 是否在 dispose() cancel
- [ ] `AnimationController` 是否在 dispose() dispose
- [ ] 全局单例是否持有 context/State
- [ ] 图片缓存是否有上限配置

### 1.5 启动
- [ ] main.dart 是否堆了过多 await
- [ ] DI 是否用 lazySingleton
- [ ] 首屏是否并发大量请求

## 2. 规范审查

### 2.1 命名
- [ ] Widget 类名是否用 `Ling` 前缀
- [ ] 文件名是否用 `ling_` 前缀 + snake_case
- [ ] Service/Controller 命名是否正确

### 2.2 导入
- [ ] 项目内导入是否用 `package:nudgee/`
- [ ] 是否有相对路径导入
- [ ] 导入顺序是否正确（dart → 第三方 → 项目）

### 2.3 架构
- [ ] 基础设施是否在 `core/`
- [ ] 业务功能是否在 `features/`
- [ ] `core/` 是否引入了业务逻辑
- [ ] 是否过早引入业务抽象

### 2.4 状态管理
- [ ] 是否用 Riverpod
- [ ] 是否精准监听
- [ ] 是否在 build() 修改 provider

### 2.5 DI
- [ ] 是否从 `sl` 获取服务而非直接 new
- [ ] 新服务是否注册到 injector.dart
- [ ] 是否用 `_safeRegister`

## 3. 安全审查

- [ ] token/密钥是否存入 SecureStorage 而非 SharedPreferences
- [ ] 是否硬编码 URL/密钥
- [ ] 是否有敏感信息日志
- [ ] 网络请求是否走 ApiClient + AuthInterceptor

## 4. 错误处理审查

- [ ] 是否用具体异常类型（AppException 子类）
- [ ] 是否裸 `throw Exception()`
- [ ] UI 是否用 LingErrorView/LingEmptyState
- [ ] 是否有过度的 try/catch（每个方法都包）

## 5. 国际化审查

- [ ] 用户可见文字是否走 AppLocalizations
- [ ] 是否有硬编码中文

## 6. 主题审查

- [ ] 颜色是否用 AppColors
- [ ] 样式是否用 AppTextStyles
- [ ] 间距是否用 AppConstants
- [ ] 是否硬编码 Color/FontSize

## 7. 组件审查

- [ ] 新组件是否加到 widgets.dart barrel
- [ ] 是否有重复导出同名类
- [ ] 组件是否可复用、参数是否合理

## 8. 测试审查

- [ ] 新功能是否有测试
- [ ] 测试是否用 TestHelpers/MockDio
- [ ] 是否能独立运行

## 9. 文档审查

- [ ] 公共 API 是否有 dartdoc 注释
- [ ] 复杂逻辑是否有说明注释
- [ ] 不添加无用注释

## 常见问题速查

| 症状 | 可能原因 | 修复 |
|------|---------|------|
| ambiguous_export | barrel 重复导出同名类 | 合并到一处定义 |
| ParentDataWidget error | Positioned 不在 Stack 内 | 包裹 Stack |
| ExoPlayer 403 | demo 用了无效 URL | 换本地/有效资源 |
| BLE Gradle 失败 | flutter_blue_plus 版本过高 | 降到 1.31.4 |
| 内存持续上涨 | Stream/Timer 未 cancel | dispose 中 cancel |
| 列表卡顿 | 用了 ListView(children:) | 改 ListView.builder + itemExtent |
