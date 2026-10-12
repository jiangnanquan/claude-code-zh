# claude-code-zh — Claude Code 简体中文汉化（mods 版）

一个完全自管的 **Claude Code CLI 汉化项目**：自己的词典、自己的 hooks 插件、
自己的采样与 TTY 验收工具。**只做 UI 文字汉化，不碰任何功能逻辑、不碰官方产物。**

> ✅ **现在可以汉化。** 旧的「改官方二进制」路线已于 2026-08 随官方 bytecode 化终止，
> 本仓在 **2026-10-12 重启**：改用 Claude Code **2.1.287+** 官方公开的 **mods**（函数式钩子插件）
> 作为唯一路线。当前版本在 **CC 2.1.296** 上实测全绿。

## 当前实测状态（CC 2.1.296，2026-10-12）

| 项 | 值 |
| :--- | :--- |
| 插件 | [`mods/cc-zh/`](mods/cc-zh/README.md) 0.1.0，13 个钩子 |
| 词典 | `dict.json`：`exact` **1950** 条 + `patterns` **4** 条 + `spinner` 5 条 |
| 装配校验 | `claude plugin validate .` → **Validation passed**（13 钩子 + 8 个 `$` 调用） |
| 运行时测试 | `claude plugin test .` → **11 pass / 0 fail** |
| TTY 实机 | 100 列 × 300 行快照：中文正常显示，**溢出 0 行**，UTF-8 替换字符 **0** |
| 未译项 | `/cc-zh-dump` → **命令 0，配置 0，屏幕文案 0** |

## 快速开始

**日常使用已经装好**（2026-10-12 起）：`~/.claude/settings.json` 的 `env` 里有一行

```jsonc
"CLAUDE_CODE_PLUGIN_DIRS": "/Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh"
```

直接敲 `claude` 即带汉化；仓库里改完词典或 hooks **立即生效、无需重装**。
删掉这一行即完全还原英文。单次试装或 A/B 对比用 `claude --plugin-dir <插件目录>`（仅本次会话）。

## 它做什么

以静态词典改写引擎绘制结果，覆盖 11 处界面。全部走 **props 透传改写**——由引擎用自己的
组件绘制，因此布局、配色、键位、交互一律不变：

| 界面 | 钩子 |
| :--- | :--- |
| `/` 斜杠命令说明（内置命令、skills、插件） | `command.describe`（exact → patterns） |
| `/config` 行的 label 与说明 | `config.describe` |
| 工作态 Spinner 词与附带文案 | `ui.render Spinner`（只在仍为英文时接替） |
| 提示行（整句译到才替换） | `ui.render PromptHint` |
| 通知条 | `ui.render InfoNotice` |
| `(ctrl+b to run in background)` | `ui.render ToolProgress` |
| 命令输出行 | `ui.render CommandOutput` |
| 后台任务通知 | `ui.render UserMessage{task-notification}` |
| 折叠的工具调用摘要（`Read 3 files`） | `ui.render ToolGroup`（自绘） |
| 轮次结束行（`Baked for 3s`） | `ui.render TurnDuration`（自绘中文时长） |
| 页脚模式标签 | `ui.render SessionMode`（2.1.296 下 `modes` 恒为空，引擎独占绘制 pill） |

## 验证

```bash
cd mods/cc-zh

# 装配与逻辑（改动后必跑）
claude plugin validate .     # 应：13 钩子 + 8 个 $ 调用，Validation passed
claude plugin test .         # 应：11 pass / 0 fail

# TTY 实机排版（把「肉眼看看」变成可复算证据）
P=~/.workbuddy/binaries/python/envs/default/bin/python
$P tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9" --cwd "$(git rev-parse --show-toplevel)"
# 达标线：溢出 0 行 + UTF-8 替换字符 0
```

## 补词条的方法

1. 会话里跑 **`/cc-zh-dump`**，拿到仍是英文的命令 / 配置 / 屏幕文案清单；
2. 用 [`mods/cc-zh/tools/`](mods/cc-zh/tools/README.md) 的 **runtime-sampler** 取权威英文原文；
3. 英文原文**逐字**作为 key 写进 `dict.json` 的 `exact`（值填中文）；带运行时变量的走 `patterns`；
4. 重跑上面的 validate + test + TTY 验收，新会话生效。

> ⛔ **不要拿 `/cc-zh-dump` 的屏幕输出当 key** —— 渲染器会折行并吞掉反引号，
> exact 表逐字匹配，错一个字符就静默失配。也不写「大概意思」的中文：命不中一律放行原文。

## 设计要点

- **以「引擎给的英文原文」为查表键**，不是按命令名/配置键枚举 ⇒ 版本升级把英文改了，
  只会「命不中、放行原文」，**不会译错**；
- **props 透传改写优先**，只有引擎排版表达不了译文时才自绘（现仅 `ToolGroup`、`TurnDuration` 两处）；
- **零 token、零网络**：启动时 `$.fs.read` 读一次静态词典；
- 未命中项写入 `$.store`，由 `/cc-zh-dump` 汇总，词典增量攒，不靠猜。

## 已知边界

### 尚未接线的渲染点（未来可扩展，非官方限制）

`ui.render` 共 15 个渲染点，目前钩了 9 个。未钩：`AssistantMessage`、`ToolUse`、
`ToolResult`、`AskUserQuestion`、`AbovePrompt`、`Pane`。当前可见的英文残留：

- `Thought for 1s (ctrl+o to expand)`（属 `AssistantMessage`）
- `(0s · thinking with max effort)`（Spinner 附注，不在 `props.message` 里）

### 按官方设计不可汉化（不是缺陷，别去试）

权限确认窗口由引擎独占绘制；以下均在 mods 覆盖范围外：

- 权限确认窗口 · 欢迎屏幕 · `/config`、`/model` 的子选择屏与选项值（`auto`/`dark`/`plan`）
- 错误信息 · tips · 提示行下方的 pills（`auto mode on`）
- 工具调用行本身（`Bash(ls)`、`Interrupted`）与运行中的 `(12s, 300 tokens)`
- `claude --help`（CLI 参数层输出，非会话内渲染）

## 目录结构

```
claude-code-zh/
├── mods/cc-zh/                # 唯一的汉化产物：自包含 mods 插件
│   ├── .claude-plugin/        # plugin.json（types/ 由 CLI 生成，已忽略）
│   ├── hooks/                 # register.tsx（13 个钩子，含 /cc-zh-dump）
│   ├── dict.json              # 词典：exact + patterns + spinner + modes
│   ├── tests/                 # 运行时测试（11 项）
│   ├── tools/                 # 验收与采样工具（非发布物）
│   └── README.md              # 覆盖面与设计契约
├── README.md                  # 本文（项目入口）
├── SOP.md                     # 日常维护 SOP（补词条 / 验收 / 升级 / 开关）
├── SKILL.md                   # skill 入口（/claude-code-zh）
├── 00_状态.md                 # 状态卡（当前版本、边界、下一步）
└── HANDOFF.md                 # 新会话续作入口
```

## 历史：A 线为什么消失了

本仓原先是**二进制补丁路线（A 线）**：扫描 bun 编译产物里的 JS 字面量并替换成中文。
Anthropic 自 Claude Code **2.1.24x** 起改为 **Bun bytecode 编译 + chunk 拆分**，UI 文字进入
JSC 字节码，该路线永久失效（上游 taekchef/claude-code-zh-cn 亦在 PR #235 弃坑）。

2026-10-12 本仓**重启为 mods 路线**：旧路线的 `tools/`、`scripts/`、`patches/`、`i18n/` 与
`PITFALLS.md` 已全部删除；其**翻译表资产已完整并入** `mods/cc-zh/dict.json`（1950 条）。
如需考古，旧文件与旧文档都在 Git 历史里。

## License

MIT。词典底子来自 [taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn)
翻译表（MIT），本仓独立维护并持续增补。
