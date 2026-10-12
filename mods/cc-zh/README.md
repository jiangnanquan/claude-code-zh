# cc-zh — Claude Code 简体中文 UI mod（0.1.0）

> **B 线**：2.1.287+ 的官方扩展点（mods）。**不碰官方产物**——不改二进制、不改字节码；
> 失效时退回英文原文，不会把 CLI 改崩。零 token、零网络。

A 线（二进制补丁）因官方 bytecode 化已冻结在 2.1.241，详见仓库根 `00_状态.md`。

## 它做什么

以**静态词典**把下列界面显示为中文。全部走「props 透传改写」——由引擎用自己的组件绘制，
因此布局、配色、键位、交互一律不变。

| # | 界面 | 实现钩子 | 状态 |
| :-- | :--- | :--- | :--- |
| 1 | `/` 弹出的**斜杠命令说明**（内置命令、skills、插件） | `command.describe` | 已实现 |
| 2 | **`/config` 行**的 label 与说明 | `config.describe` | 已实现 |
| 3 | 工作态 **Spinner** 词与附带文案 | `ui.render` `Spinner` | 已实现（仅 terminal surface） |
| 4 | **提示行**（整句译到才替换） | `ui.render` `PromptHint` | 已实现 |
| 5 | **通知条** | `ui.render` `InfoNotice` | 已实现 |
| 6 | **页脚模式标签** | `ui.render` `SessionMode` | 已接线（词典待 dump 补） |
| 7 | `(ctrl+b to run in background)` | `ui.render` `ToolProgress` | 已实现 |
| 8 | **命令输出行** | `ui.render` `CommandOutput` | 已实现（仅精确命中/正则，不猜） |
| 9 | **后台任务通知** | `ui.render` `UserMessage`{origin=task-notification} | 已实现 |
| 10 | **折叠的工具调用摘要**（`Read 3 files`） | `ui.render` `ToolGroup` | 已实现（自绘） |
| 11 | **轮次结束行**（`Baked for 3s`） | `ui.render` `TurnDuration` | 已实现（自绘，中文时长） |

### 不可汉化（官方设计，非本 mod 缺陷）

`mods` 的 `ui.render` 只覆盖 15 个渲染点，且**权限确认对话框由引擎独占绘制**
（官方注释：*"The permission dialog is drawn by the engine alone, since its answer authorises an action"*）。
以下均为覆盖范围外：

- 权限确认窗口 · 欢迎屏幕 · `/config`、`/model` 的**子选择屏**与选项值（`auto`/`dark`/`plan`）
- 错误信息 · tips · 提示行下方的 pills（`auto mode on`、`(shift+tab to cycle)`）
- 工具调用行本身（`Bash(ls)`、`Interrupted`）与运行中的 `(12s, 300 tokens)`
- `claude --help`（CLI 参数层输出，非会话内渲染）

## 设计要点：以「引擎英文原文」为键

与社区先例 `ko-ui`（韩文）的关键差异——**不需要按命令名/配置键枚举**：

```
引擎的英文描述  ──(command.describe 的 next(e) 返回)──►  查 dict.json 的 exact 表  ──►  中文
```

好处：

1. 存量扁平表（`../../i18n/translations.json` 1905 条）**可原样复用**，无需重编；
2. 版本升级把英文改了 ⇒ 只是「命不中、放行原文」，**不会译错**；
3. 未命中的字符串由 **`/cc-zh-dump`** 汇总 ⇒ 词典增量攒，不靠猜。

## 目录

```
mods/cc-zh/
├── .claude-plugin/plugin.json   清单
├── hooks/hooks.json             指向 ./register.tsx
├── hooks/register.tsx           全部 13 个钩子（含 /cc-zh-dump）
├── dict.json                    词典：exact(1898) + spinner + modes + patterns
└── tests/register.test.ts       9 项运行时测试
```

## 用法

```bash
# 单会话试装（先不写全局 settings）
claude --plugin-dir /Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh

# 会话内：列出词典里还没有中文的命令/配置项/屏幕文案
/cc-zh-dump

# 校验与测试
claude plugin validate .
claude plugin test .
```

## 补词条的方法

1. 会话里跑 `/cc-zh-dump`，拿到英文原文清单；
2. 把**英文原文逐字**作为 key 写进 `dict.json` 的 `exact`，值填中文；
3. 新会话生效（词典每次会话读一次）。

**红线**：命不中一律放行原文，**绝不写「大概意思」的中文**；`CommandOutput.command/args`、
`ToolResult.tool` 等官方只读字段不得改写。

## 已知限制

- 需 **Claude Code ≥ 2.1.287**；mods API 官方明示「can change between releases」⇒ 跟随版本维护。
- 中文（宽字符）在 Ink 中的**表格/进度条对齐**尚未实机确认（社区有 mod 专做 CJK 对齐，说明是已知风险）。
- 翻译只改**绘制**，不改存储：`ctrl+o` 展开视图下部分内容可能仍为原文（引擎语义如此）。
