# claude-code-zh — Claude Code Simplified Chinese Localization (mods)

**Language:** [English](#english) · [简体中文](#简体中文)

A self-managed **Claude Code CLI localization project**: our own dictionary, our own hooks
plugin, our own sampler and TTY verification tools. **UI text only — no functional logic,
no modification of official artifacts.**

> ✅ **Localization works again.** The old "patch the official binary" route died with the
> official bytecode switch in 2026-08. This repo was **rebooted on 2026-10-12** around the
> official **mods** extension point (Claude Code **2.1.287+**). It is verified green on
> **CC 2.1.296**.

<a id="english"></a>

## English

### Current verified status (CC 2.1.296, 2026-10-12)

| Item | Value |
| :--- | :--- |
| Plugin | [`mods/cc-zh/`](mods/cc-zh/README.md) 0.1.0, 13 hooks |
| Dictionary | `dict.json`: `exact` **1950** entries + `patterns` **4** + `spinner` 5 |
| Assembly check | `claude plugin validate .` → **Validation passed** (13 hooks + 8 `$` calls) |
| Runtime tests | `claude plugin test .` → **11 pass / 0 fail** |
| Live TTY check | 100×300 screen snapshot: Chinese renders correctly, **0 overflow rows**, **0** UTF-8 replacement chars |
| Untranslated | `/cc-zh-dump` → **0 commands, 0 config items, 0 screen strings** |

### Quick start

Daily use is already installed globally (since 2026-10-12): `~/.claude/settings.json` has

```jsonc
"CLAUDE_CODE_PLUGIN_DIRS": "/Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh"
```

Just run `claude` and the UI is localized. Edits to the dictionary or hooks in this repo take
effect immediately — no reinstall. Delete that line to restore the original English UI.
For one-off testing or A/B comparison use `claude --plugin-dir <plugin dir>` (session only).

### What it localizes

A static dictionary rewrites engine-rendered output across 11 surfaces. All rewrites are
**props pass-through** — the engine still draws with its own components, so layout, colors,
keybindings and interactions are unchanged:

| Surface | Hook |
| :--- | :--- |
| `/` slash-command descriptions (built-ins, skills, plugins) | `command.describe` (exact → patterns) |
| `/config` labels and descriptions | `config.describe` |
| Spinner word and attached message | `ui.render Spinner` (only replaces still-English words) |
| Prompt hint line (all-or-nothing translation) | `ui.render PromptHint` |
| Info notices | `ui.render InfoNotice` |
| `(ctrl+b to run in background)` | `ui.render ToolProgress` |
| Command output lines | `ui.render CommandOutput` |
| Background task notifications | `ui.render UserMessage{task-notification}` |
| Collapsed tool-call summary (`Read 3 files`) | `ui.render ToolGroup` (custom draw) |
| Turn duration line (`Baked for 3s`) | `ui.render TurnDuration` (custom draw, Chinese duration) |
| Footer mode labels | `ui.render SessionMode` (`modes` is always empty on 2.1.296; the pill is engine-drawn) |

### Verify

```bash
cd mods/cc-zh

# Assembly and logic (run after every change)
claude plugin validate .     # expect: 13 hooks + 8 $ calls, Validation passed
claude plugin test .         # expect: 11 pass / 0 fail

# Live TTY layout check (turns "eyeballing" into reproducible evidence)
P=~/.workbuddy/binaries/python/envs/default/bin/python
$P tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9" --cwd "$(git rev-parse --show-toplevel)"
# pass line: 0 overflow rows + 0 UTF-8 replacement chars
```

### Adding entries

1. Run **`/cc-zh-dump`** in a session to list still-English commands / config items / strings;
2. Use the **runtime-sampler** in [`mods/cc-zh/tools/`](mods/cc-zh/tools/README.md) to obtain the
   authoritative English originals;
3. Put the exact English string into `dict.json` under `exact` (value = Chinese); strings with
   runtime variables go into `patterns`;
4. Re-run validate + test + TTY check above; takes effect in a new session.

> ⛔ **Never use `/cc-zh-dump`'s rendered screen output as a key** — the renderer wraps lines
> and strips backticks. The exact table matches character-for-character, so a wrong character
> silently never matches. Never write guessed translations: miss = pass through English.

### Design

- **The key is the English string the engine hands you**, not a command/config name ⇒ when an
  upgrade changes English wording, the result is "miss and pass through", **never a wrong
  translation**;
- **Props pass-through first**; custom drawing only where engine layout can't express the
  translation (currently `ToolGroup` and `TurnDuration` only);
- **Zero tokens, zero network**: reads the static dictionary once via `$.fs.read` at startup;
- Misses are stored in `$.store` and summarized by `/cc-zh-dump`, so the dictionary grows
  incrementally from evidence, not guesses.

### Known boundaries

**Not yet hooked (extendable, not an official limit):** `ui.render` has 15 render points; we
currently hook 9. The unhooked ones are `AssistantMessage`, `ToolUse`, `ToolResult`,
`AskUserQuestion`, `AbovePrompt`, `Pane`. Visible leftovers today:

- `Thought for 1s (ctrl+o to expand)` (belongs to `AssistantMessage`)
- `(0s · thinking with max effort)` (Spinner footnote, not present in `props.message`)

**Unlocalizable by official design (not a bug, don't try):** the permission dialog is drawn by
the engine alone. Also out of mods scope: welcome screen, `/config` & `/model` sub-select
screens and option values (`auto`/`dark`/`plan`), error messages, tips, pills below the prompt
(`auto mode on`), tool-call lines themselves (`Bash(ls)`, `Interrupted`), running indicators
(`(12s, 300 tokens)`), and `claude --help`.

### Repository layout

```
claude-code-zh/
├── mods/cc-zh/                # the deliverable: self-contained mods plugin
│   ├── .claude-plugin/        # plugin.json (types/ is generated, ignored)
│   ├── hooks/                 # register.tsx (13 hooks, incl. /cc-zh-dump)
│   ├── dict.json              # dictionary: exact + patterns + spinner + modes
│   ├── tests/                 # runtime tests (11)
│   ├── tools/                 # verification & sampling tools (not shipped)
│   └── README.md              # coverage & design contract
├── README.md                  # this file
├── SOP.md                     # maintenance SOP (add entries / verify / upgrade / switches)
├── SKILL.md                   # skill entry (/claude-code-zh)
├── 00_状态.md                 # status card
└── HANDOFF.md                 # new-session handoff
```

### History: where the old "A route" went

This repo originally patched the official binary (the "A route"): scan JS string literals in
the bun-built binary and replace them with Chinese. Starting with Claude Code **2.1.24x**,
Anthropic switched to **Bun bytecode compilation + chunk splitting**; UI text moved into JSC
bytecode and that route is permanently dead (the upstream taekchef/claude-code-zh-cn also
retired it in PR #235).

On 2026-10-12 this repo **rebooted as a mods project**. The old `tools/`, `scripts/`,
`patches/`, `i18n/` and `PITFALLS.md` were deleted; the translation-table asset was fully
absorbed into `mods/cc-zh/dict.json` (1950 entries). Old files remain in Git history if needed.

### License

MIT. The dictionary foundation comes from the
[taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn) translation table
(MIT); this repo maintains and extends it independently.

---

<a id="简体中文"></a>

## 简体中文

### 当前实测状态（CC 2.1.296，2026-10-12）

| 项 | 值 |
| :--- | :--- |
| 插件 | [`mods/cc-zh/`](mods/cc-zh/README.md) 0.1.0，13 个钩子 |
| 词典 | `dict.json`：`exact` **1950** 条 + `patterns` **4** 条 + `spinner` 5 条 |
| 装配校验 | `claude plugin validate .` → **Validation passed**（13 钩子 + 8 个 `$` 调用） |
| 运行时测试 | `claude plugin test .` → **11 pass / 0 fail** |
| TTY 实机 | 100 列 × 300 行快照：中文正常显示，**溢出 0 行**，UTF-8 替换字符 **0** |
| 未译项 | `/cc-zh-dump` → **命令 0，配置 0，屏幕文案 0** |

### 快速开始

**日常使用已经装好**（2026-10-12 起）：`~/.claude/settings.json` 的 `env` 里有一行

```jsonc
"CLAUDE_CODE_PLUGIN_DIRS": "/Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh"
```

直接敲 `claude` 即带汉化；仓库里改完词典或 hooks **立即生效、无需重装**。
删掉这一行即完全还原英文。单次试装或 A/B 对比用 `claude --plugin-dir <插件目录>`（仅本次会话）。

### 它做什么

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

### 验证

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

### 补词条的方法

1. 会话里跑 **`/cc-zh-dump`**，拿到仍是英文的命令 / 配置 / 屏幕文案清单；
2. 用 [`mods/cc-zh/tools/`](mods/cc-zh/tools/README.md) 的 **runtime-sampler** 取权威英文原文；
3. 英文原文**逐字**作为 key 写进 `dict.json` 的 `exact`（值填中文）；带运行时变量的走 `patterns`；
4. 重跑上面的 validate + test + TTY 验收，新会话生效。

> ⛔ **不要拿 `/cc-zh-dump` 的屏幕输出当 key** —— 渲染器会折行并吞掉反引号，
> exact 表逐字匹配，错一个字符就静默失配。也不写「大概意思」的中文：命不中一律放行原文。

### 设计要点

- **以「引擎给的英文原文」为查表键**，不是按命令名/配置键枚举 ⇒ 版本升级把英文改了，
  只会「命不中、放行原文」，**不会译错**；
- **props 透传改写优先**，只有引擎排版表达不了译文时才自绘（现仅 `ToolGroup`、`TurnDuration` 两处）；
- **零 token、零网络**：启动时 `$.fs.read` 读一次静态词典；
- 未命中项写入 `$.store`，由 `/cc-zh-dump` 汇总，词典增量攒，不靠猜。

### 已知边界

**尚未接线的渲染点（未来可扩展，非官方限制）**：`ui.render` 共 15 个渲染点，目前钩了 9 个。
未钩：`AssistantMessage`、`ToolUse`、`ToolResult`、`AskUserQuestion`、`AbovePrompt`、`Pane`。
当前可见的英文残留：

- `Thought for 1s (ctrl+o to expand)`（属 `AssistantMessage`）
- `(0s · thinking with max effort)`（Spinner 附注，不在 `props.message` 里）

**按官方设计不可汉化（不是缺陷，别去试）**：权限确认窗口由引擎独占绘制；以下均在 mods
覆盖范围外：

- 权限确认窗口 · 欢迎屏幕 · `/config`、`/model` 的子选择屏与选项值（`auto`/`dark`/`plan`）
- 错误信息 · tips · 提示行下方的 pills（`auto mode on`）
- 工具调用行本身（`Bash(ls)`、`Interrupted`）与运行中的 `(12s, 300 tokens)`
- `claude --help`（CLI 参数层输出，非会话内渲染）

### 目录结构

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

### 历史：A 线为什么消失了

本仓原先是**二进制补丁路线（A 线）**：扫描 bun 编译产物里的 JS 字面量并替换成中文。
Anthropic 自 Claude Code **2.1.24x** 起改为 **Bun bytecode 编译 + chunk 拆分**，UI 文字进入
JSC 字节码，该路线永久失效（上游 taekchef/claude-code-zh-cn 亦在 PR #235 弃坑）。

2026-10-12 本仓**重启为 mods 路线**：旧路线的 `tools/`、`scripts/`、`patches/`、`i18n/` 与
`PITFALLS.md` 已全部删除；其**翻译表资产已完整并入** `mods/cc-zh/dict.json`（1950 条）。
如需考古，旧文件与旧文档都在 Git 历史里。

### License

MIT。词典底子来自 [taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn)
翻译表（MIT），本仓独立维护并持续增补。
