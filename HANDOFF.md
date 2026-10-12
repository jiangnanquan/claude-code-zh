# HANDOFF — 续作入口（新会话先读本文）

| 属性 | 值 |
| :--- | :--- |
| 版本 | v2 · 2026-10-12 |
| 用途 | 项目已**重启为 mods 路线**，旧二进制补丁路线已清退。新会话以本文 + [`00_状态.md`](00_状态.md) 为续作入口 |
| 仓库 | `/Users/jnq/Dev/Private/claude-code-zh` |
| 插件 | [`mods/cc-zh/`](mods/cc-zh/README.md)（唯一活跃路线） |
| 本机 CC | **2.1.296**（mods 门槛 2.1.287 之上） |

---

## 一、当前状态速览（截至 2026-10-12）

### 已完成 ✅

1. **mods 汉化插件 `mods/cc-zh` 0.1.0**：13 个钩子 + `dict.json`（`exact` 1950 条、
   `patterns` 4 条、`spinner` 5 条、`modes` 空为终态）。
2. **验收全绿**：
   - `claude plugin validate .` → Validation passed（13 钩子 + 8 个 `$` 调用）
   - `claude plugin test .` → **11 pass / 0 fail**
   - TTY 实机（100 列 × 300 行）：中文正常、**溢出 0 行**、UTF-8 替换字符 **0**
   - `/cc-zh-dump` → **命令 0，配置 0，屏幕文案 0**（store 历史记录已清，备份为
     `cc-zh_inline-*.json.bak-20261012`）
3. **已装全局**：`~/.claude/settings.json` 的 `env` 有一行
   `"CLAUDE_CODE_PLUGIN_DIRS": "/Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh"`。
   直接敲 `claude` 即带汉化；仓库改完立即生效；删掉该行即还原。
4. **验收工具已入库**：`mods/cc-zh/tools/tty-probe.py`（TTY 排版验收）与
   `tools/runtime-sampler/`（取权威英文 key），用法见 `tools/README.md`。
5. **项目清理完成**：旧二进制补丁路线的 `tools/`、`scripts/`、`patches/`、`i18n/`、
   `PITFALLS.md` 已删除；翻译表资产已并入 `dict.json`，考古走 Git 历史。

### 可选的下一步 ⚠️

1. **扩展覆盖面**：`ui.render` 还剩 6 个渲染点未接线（`AssistantMessage`、`ToolUse`、
   `ToolResult`、`AskUserQuestion`、`AbovePrompt`、`Pane`）。当前可见英文：
   `Thought for 1s (ctrl+o to expand)` 与 `(0s · thinking with max effort)`。
   接线前先读 `mods/cc-zh/README.md` 的「未接线的渲染点」一节。
2. **CC 升级后**按 [SOP.md](SOP.md) B3 顺序排查：validate → test → `/cc-zh-dump`。

---

## 二、B 线设计契约（改动前必须理解）

1. **以「引擎给的英文原文」为查表键**，不是按命令名枚举。`command.describe` 走
   `trDesc()`（`exact` → `patterns`，未命中返回 `undefined`）。
2. **props 透传改写优先**：由引擎自绘，布局/配色/键位不变。仅 `ToolGroup`、
   `TurnDuration` 两处自绘。
3. **不猜词条**：命不中一律放行英文原文并记录，绝不写「大概意思」的中文。
4. **官方只读字段**：`CommandOutput.command/args`、`ToolResult.tool`、各类 id 与视图状态
   不得改写（`ToolUse.tool` 是可写的，二者不对称，易搞错）。
5. **官方本地化开关优先**：`spinnerVerbs` 已含中文时 `spinnerWord()` 原样放行。

按官方设计不可汉化（别去试）：权限确认窗口、欢迎屏、`/config` `/model` 子选择屏与
选项值、错误信息、tips、`auto mode on` pill、工具调用行本身、`claude --help`。

---

## 三、环境事实与已踩过的坑

| 项 | 值 |
| :--- | :--- |
| 本机 CC | **2.1.296**，fnm node **v22.21.1** 全局安装 |
| 安装路径 | `~/.local/share/fnm/node-versions/v22.21.1/installation/lib/node_modules/@anthropic-ai/claude-code` |
| 全局启用 | `~/.claude/settings.json` → `env.CLAUDE_CODE_PLUGIN_DIRS`（改前备份） |

- **坑 1：`npm install -g` 会装到 WorkBuddy 托管运行时**。升级 CC 必须显式带 fnm node：
  `F="$HOME/.local/share/fnm/node-versions/v22.21.1/installation"; "$F/bin/node" "$F/lib/node_modules/npm/bin/npm-cli.js" install -g @anthropic-ai/claude-code@latest`
- **坑 2：darwin-arm64 上游 `install.cjs` 有 EEXIST 缺陷**。正解：
  `P="$F/lib/node_modules/@anthropic-ai/claude-code"; rm -f "$P/bin/claude.exe" && cd "$P" && "$F/bin/node" install.cjs`
- **坑 3：TTY 探针的 `--cwd` 必须是 CC 已信任目录**，否则卡在「信任此文件夹」。
- **坑 4：不能用 `/cc-zh-dump` 的屏幕输出当 key**——渲染器折行并吞反引号；用
  `tools/runtime-sampler/` 取权威原文（`describe.json` 与 `list()` 可能不同，以 describe 为准）。
- **坑 5：写 mod 测试时**，测试层的 `on()` 不能注册 mod 自身已注册的事件（会报
  `registered twice`）；测试环境里 `$.fs` 不可用 ⇒ 词典读取交给 `plugin validate`。

---

## 四、每次改完的验收（按顺序）

```bash
cd /Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh
claude plugin validate .     # 13 钩子 + 8 个 $ 调用
claude plugin test .         # 11 pass / 0 fail

P=~/.workbuddy/binaries/python/envs/default/bin/python
$P tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9" --cwd /Users/jnq/Dev/Private/claude-code-zh
# 达标：溢出 0 行 + UTF-8 替换字符 0
```

---

## 五、已锁定的决策（**不要重新讨论**）

1. **走 mods 路线**（不复活二进制补丁）。
2. **B 线落在本仓 `mods/cc-zh/`**，不新开仓库；SKILL 入口只有一个。
3. **以「引擎英文原文」为查表键**（非按命令名枚举）。
4. **词典不自动跟随上游翻译表**：`dict.json` 是唯一词典，上游新词人工甄别后补入。
5. **本机 CC 用最新版做实验**；旧二进制补丁路线只存于 Git 历史，本仓文件已删除。

---

## 六、权威参考（要查 mods API 时看这里）

| 用途 | 位置 |
| :--- | :--- |
| **mods API 权威类型** | CLI 每次加载 mod 时写入 `.claude-plugin/types/claude-code/index.d.ts`（以本机版本为准） |
| 官方公开类型 | `anthropics/claude-code` 仓 `mods/types/claude-code.d.ts` |
| 15 个可钩渲染点 | 类型文件搜 `export type RenderComponent` |
| 官方内置 mod 源码（可抄） | 同仓 `mods/{diff,sec-default,telemetry,agents-md}` |
| 社区先例（韩文 i18n mod） | `moduvoice/claude-code-ko-ui` |

**⚠️ API 时效性**：官方明示 *"The API can change between releases"*。升级 CC 后若汉化失效，
先跑 validate + test，再跑 `/cc-zh-dump` 看英文是否变了；不要一上手就猜 API 变了。
