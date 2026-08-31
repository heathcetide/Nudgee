---
name: ling-flutter-perf
description: Flutter 性能优化指南与代码改造清单（Nudgee 项目专用）。覆盖 Widget 重建、渲染、列表、启动、内存、网络、包体积、卡顿监控。
---

# Nudgee Flutter 性能优化 Skill

本 skill 用于在 Nudgee 项目中编写或修改 Flutter 代码时，自动应用性能优化规范。当涉及 UI/Widget/列表/动画/启动/网络/图片相关改动时必须遵循。

## 1. Widget 重建优化（最高优先级）

### 1.1 const 构造器
- 所有静态文字、图标、固定布局**必须**加 `const`。
- 编译期生成对象，父节点刷新时不重建。
- ❌ `Text('Hello', style: TextStyle(fontSize: 14))`
- ✅ `const Text('Hello', style: TextStyle(fontSize: 14))`

### 1.2 拆分 Widget，缩小刷新范围
- 不要在一个超大 Stateful 页面里写所有 UI。
- 可变 UI、不变 UI 拆成独立 Widget。
- `setState` 只刷新当前 State 下整棵子树，所以子树越小越好。

### 1.3 禁止在 build() 内创建对象/做计算
- ❌ 每次 build 新建 `TextStyle()`、`EdgeInsets()`、`Decoration()`
- ✅ 提取为 `static final` 常量或类成员
- ❌ build 内做 JSON 解析、过滤排序、网络请求
- ✅ 在 initState / 事件回调中处理，结果存为 State 字段

### 1.4 状态管理精准刷新
- Riverpod：使用 `.select()` 精准监听单个字段，`autoDispose` 自动释放
- 不要 `ref.watch(provider)` 监听整个 model，只监听需要的字段
- Provider 必须加 `autoDispose` 除非明确需要常驻

### 1.5 Builder 局部刷新
- 善用 `Builder` 包裹最小刷新范围

## 2. 渲染绘制优化

### 2.1 RepaintBoundary
- 动画、倒计时、滚动指示器、高频刷新组件**必须**包 `RepaintBoundary`
- 局部刷新不会带动整个页面重绘

### 2.2 减少嵌套层级
- 布局树深度 ≤4 层
- 能用 `Padding` 就不要用 `Container` 套一层
- 避免 `Container > Padding > Container > Padding` 链

### 2.3 慎用昂贵组件
- `Opacity`：优先 `AnimatedOpacity`；静态透明用 `Color(0xCCFFFFFF)`
- `ClipRRect`、`ClipOval`、`ShaderMask`、`BackdropFilter`：少用
- 圆角图片优先用 `DecoratedBox` + `BoxDecoration` 而非 `ClipRRect`

### 2.4 动画优化
- 优先 `AnimatedBuilder` / `AnimatedWidget`，不变 UI 作为 child 传入
- **禁止**在动画回调里 `setState`
- 长动画外层套 `RepaintBoundary`

### 2.5 Impeller 渲染引擎
- Android：`AndroidManifest.xml` 添加 `<meta-data android:name="io.flutter.embedding.android.EnableImpeller" android:value="true" />`
- iOS：默认已开启

## 3. 长列表优化

### 3.1 懒加载
- **永远**用 `ListView.builder` / `GridView.builder` / `SliverList`
- ❌ `ListView(children: [...])` 一次性渲染全部

### 3.2 itemExtent
- 固定高度列表**必须**加 `itemExtent`，跳过布局计算

### 3.3 AutomaticKeepAlive
- 非必要关闭 `addAutomaticKeepAlives: false`
- 需要常驻缓存才用 `AutomaticKeepAliveClientMixin`

### 3.4 cacheExtent
- 设置合理 `cacheExtent`（默认 250），预渲染屏幕外少量 item
- 不要设置过大，浪费内存

### 3.5 列表 item 优化
- item 内部同样拆分组件、加 const
- 图片指定 `cacheWidth`/`cacheHeight`，提前裁剪大图

## 4. 启动优化

### 4.1 启动任务编排
- 使用 `AppInitializer` 区分同步/异步任务
- 非首屏依赖放到 Splash 之后异步加载
- main.dart 不要堆 `await` 阻塞启动

### 4.2 懒加载 DI
- GetIt 使用 `registerLazySingleton`，不用的服务不立即实例化
- 已遵循：本项目 injector.dart 已全部使用 lazySingleton

### 4.3 首屏精简
- 首屏不要并发发起大量网络请求
- 用骨架屏占位提升感知速度

## 5. 内存优化

### 5.1 Stream/Timer/AnimationController 泄漏黑名单
- `StreamSubscription` **必须**在 dispose() 中 cancel
- `Timer` **必须**在 dispose() 中 cancel
- `AnimationController` **必须**在 dispose() 中 dispose
- 推荐 Riverpod `autoDispose` 自动释放

### 5.2 全局单例禁止持有 context/State
- 全局 service 不能持有 BuildContext 或 State 对象

### 5.3 图片缓存
- `cached_network_image` 配置最大缓存数量
- 大图用 `ResizeImage` 或 `cacheWidth`/`cacheHeight` 裁剪
- 优先 WebP 格式

### 5.4 Isolate 泄漏
- 后台线程用完及时关闭

## 6. 耗时计算优化

- JSON 大解析、大数据过滤排序、图片处理、加密运算 → **Isolate / compute**
- `compute` 适合一次性短任务；长期任务自建 Isolate
- 大量循环分批执行，用 `Future.delayed` 分片让出帧时间片

## 7. 网络优化

- 接口合并，并发请求 ≤5
- 使用 `ApiCacheService` 缓存，短时间相同请求不重复调用
- 防抖节流：用 `LingUtils.debounce` / `LingUtils.throttle`
- 弱网优先读本地缓存

## 8. 包体积优化

- 图片压缩，优先 webp，移除无用图片
- 清理 pubspec 废弃依赖
- Android release 开启 `minifyEnabled true` + `shrinkResources true`
- 分 ABI 打包：只打 arm64-v8a
- 字体裁剪

## 9. 卡顿监控基建

- 使用 `FrameTimingMonitorService`（本项目已提供）
- `SchedulerBinding.instance.addTimingsCallback` 监听每帧耗时
- 超过 16ms 判定卡顿，上报 `AnalyticsService.trackError()`
- 线上集成 Sentry / ARMS

## 10. 排查工作流

1. **profile 模式运行**：`flutter run --profile`（debug 性能不作数）
2. DevTools → Performance 面板
3. UI 线程红 → 火焰图找 build 耗时函数
4. GPU 线程红 → Highlight Repaints 找大面积重绘
5. 真机 Release 版本复测

## 落地优先级

1. const、拆分组件、build 禁止计算
2. 列表懒加载 + itemExtent + 图片裁剪
3. RepaintBoundary 动画隔离
4. Stream/Timer 泄漏治理
5. 耗时任务迁移 Isolate
6. 启动流程编排
7. Impeller 引擎
8. 卡顿监控基建
