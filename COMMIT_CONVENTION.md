# 代码提交规范 (Conventional Commits)

本项目遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范。

## 提交格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Type 类型

| type     | 说明                                           |
|----------|------------------------------------------------|
| feat     | 新功能                                         |
| fix      | Bug 修复                                       |
| docs     | 文档变更                                       |
| style    | 代码格式（不影响功能）                         |
| refactor | 重构（既不是新功能也不是修 Bug）               |
| test     | 测试相关                                       |
| chore    | 构建、工具、依赖等杂项                         |
| perf     | 性能优化                                       |
| build    | 构建系统或外部依赖变更                         |
| ci       | CI 配置变更                                    |

## Scope（可选）

受影响的模块，例如：`auth`、`router`、`ble`、`theme`。

## Subject（必填）

- 使用祈使语气（imperative mood）：`add` 而非 `added`
- 不加句号
- 不超过 50 个字符

## Body（可选）

- 解释 **what** 和 **why**，不解释 **how**
- 每行不超过 72 个字符

## Footer（可选）

- `BREAKING CHANGE:` 描述破坏性变更
- `Closes #123` 关联 issue

## 示例

```
feat(ble): add device scanning with RSSI display

Supports filtering by device name and shows signal strength.
Closes #42
```

```
fix(auth): handle token refresh on 401 response

The refresh logic was not triggered when the access token expired.
```

```
chore(deps): upgrade go_router to 14.2.0
```

## 配置 Git 模板

```bash
git config commit.template .gitmessage
```

或全局配置：

```bash
git config --global commit.template "$(pwd)/.gitmessage"
```
