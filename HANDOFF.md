# HANDOFF — 续作入口（新会话先读本文）

| 属性 | 值 |
| :--- | :--- |
| 版本 | v1 · 2026-10-12 |
| 用途 | 上一会话（2026-10-12）建立了 B 线（mods 汉化）首个实验插件后交接。**新会话以本文为唯一续作入口**，读完即可继续操作 |
| 仓库 | `/Users/jnq/Dev/Private/claude-code-zh` |
| 上游任务 | PKM `tasks/20261011_ClaudeCode汉化_mods路线可行性/`（状态 **`已毕业`**，`graduated_to: /Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh`；只留结论与证据链，**勿在那边重启工程活动**） |
| 明细 | 覆盖面与设计 → `mods/cc-zh/README.md`；两线对照 → `./00_状态.md` |

---

## 一、先认清这个仓有两条线（否则会走错路）

| | **A 线：二进制补丁（冻结）** | **B 线：mods（活跃）** |
| :--- | :--- | :--- |
| 载体 | `i18n/` `tools/` `scripts/` `patches/` | **`mods/cc-zh/`** |
| 状态 | **已死，勿复活**：官方自 CC **2.1.24x** 起改 **Bun bytecode 编译**，UI 文字进了 JSC 字节码；`extract` 只能拿到 20KB stub，`repack` 会 segfault | 实验中 |
| 可用版本 | ≤ **2.1.241**（最后可汉化版本） | ≥ **2.1.287** |
| 本机现状 | 原 2.1.241 已汉化版**已被替换**（见 §四 如何复原） | 本机 CC 现为 **2.1.296** |

> A 线的**唯一剩余价值是词典来源**（`i18n/translations.json`，1905 条扁平 en→zh）。**不要再改 A 线的代码**。
>
> ⚠️ **防误导**：根 `README.md` 顶部那条「重大公告：官方 bytecode 改动导致底层 UI 汉化**终止**」写于 **2026-08-28**，
> 说的是 **A 线**（提取-重打包路线）终止 —— 它**不代表汉化结束**：B 线（mods）正是 bytecode 化之后的官方替代路径。
> README / SOP / SKILL 尚未改写（属待拍板提案，见 §五 步骤 4）；**以本文与 `00_状态.md` 为准**。

---

## 二、当前状态速览（截至 2026-10-12）

### 已完成 ✅

1. **本机 CC 升级到 2.1.296**（mods 门槛 2.1.287 之上）。
2. **B 线首个实验插件 `mods/cc-zh` 0.1.0 已建成**，5 个文件 ≈178 KB：

   | 文件 | 大小 | 说明 |
   | :--- | ---: | :--- |
   | `.claude-plugin/plugin.json` | 394 B | 清单 |
   | `hooks/hooks.json` | 34 B | `{ "modules": ["./register.tsx"] }` |
   | `hooks/register.tsx` | 11,979 B | **13 个钩子**（见 §三） |
   | `dict.json` | 166,930 B | `exact` **1898 条** + `spinner` + `modes`(空) + `patterns` |
   | `tests/register.test.ts` | 2,985 B | 9 项运行时测试 |

3. **两项验证已通过**：
   - `claude plugin validate .` → **Validation passed**，并逐项列出 13 个钩子与 8 个 `$` 调用。
   - `claude plugin test .` → **9 pass / 0 fail**（跑在真实 mod 运行时里）。
4. 新增仓库级 **`./00_状态.md`**（两线对照状态卡，对齐 `pi-zh` 的「零工具档」格式：有 frontmatter、无 `source_hash`）。
5. **修掉一个真实缺陷**（由测试发现）：`trWhole()` 的「半译即放弃」守卫最初只豁免键位词，会把 `CLI`/`API`/`MCP` 等**全大写缩写**与 `Claude`/`GitHub` 等**专有名词**误判为「未译完」⇒ **含它们的提示行永远不会被替换**。已加 `ACRONYM` + `PROPER` 豁免并补测试。

### 未完成 / 未验证 ⚠️（这就是你要接着做的）

1. **⚠️ 中文实机排版未肉眼确认**：`validate` 只证明装配正确、`test` 只证明逻辑正确；**中文宽字符在 Ink 里的换行/表格/进度条对齐尚未验证**（社区有 mod 专做 CJK 表格对齐 `tessera`，说明这是已知风险点）。
2. **⚠️ `/cc-zh-dump` 的实跑输出未取得** —— 真实「仍为英文」清单要起会话才有。
3. **⚠️ `dict.json` 的 `modes` 故意留空**：不知道 2.1.296 页脚模式标签的确切英文值，**不猜**，等 dump 结果。
4. 仓库根 `README.md` / `SOP.md` / `SKILL.md` **尚未更新**为「两线说明」（只有 `00_状态.md` 说明了）—— 属提案，未执行。
5. **两仓均已提交并推送**（2026-10-12，见 §六）。

---

## 三、B 线的设计契约（改动前必须理解，否则会破坏它）

### 3.1 核心设计：以「引擎给的英文原文」为查表键

```
引擎的英文描述 ──(command.describe 的 next(e) 返回)──► 查 dict.json 的 exact ──► 中文
```

**不要退化成「按命令名枚举」**（韩文先例 `ko-ui` 的做法）。本设计的三个好处：

1. 存量扁平表（`i18n/translations.json`）**可原样复用**，无需重编结构；
2. 版本升级把英文改了 ⇒ 只是「命不中、放行原文」，**不会译错**；
3. 未命中项由 `/cc-zh-dump` 汇总 ⇒ 词典增量攒，不靠猜。

### 3.2 两种改写方式，优先用第一种

| 方式 | 写法 | 何时用 |
| :--- | :--- | :--- |
| **A. props 透传改写（首选）** | `return next({ ...e, props: { ...e.props, text: 译 } })` | 引擎自绘的组件。**布局/配色/键位/交互全部保持原样** |
| **B. 自绘替换** | `const { Box, Text } = $.ui.resolve(e); return <Box>…</Box>` | 引擎排版表达不了译文时（如折叠工具摘要、中文时长）。成本高、易随版本错位 |

现有 13 个钩子中，只有 `ToolGroup` 与 `TurnDuration` 用了方式 B。

### 3.3 ⛔ 官方只读字段（改写会被拒绝，引擎按原文绘制）

| 字段 | 为什么 |
| :--- | :--- |
| `CommandOutput.command` / `.args` | 命令与参数须**可审计**（`(***)` 表示被标记为敏感） |
| `ToolResult.tool` | 工具身份 |
| `ToolUse.tool_use_id`、`UserMessage.origin`/`from`/`onScreen`、各类 `isExpanded`/`isRunning`/`isErrored`/`view`/`scroll` | 视图与状态事实 |

**注意**：`ToolUse.tool` 是**可写**的（`Bash`/`Read` 这类标签可汉化），但 `ToolResult.tool` 是**只读**的 —— 两者不对称，容易搞错。

### 3.4 ⛔ 按官方设计不可汉化（**不是**本 mod 的缺陷，别去试）

`ui.render` 只覆盖 15 个渲染点，且**权限确认对话框由引擎独占绘制**（官方注释：*"The permission dialog is drawn by the engine alone, since its answer authorises an action"*）：

- **权限确认窗口** · 欢迎屏幕 · `/config`、`/model` 的**子选择屏**与选项值（`auto`/`dark`/`plan`）
- 错误信息 · tips · 提示行下方的 pills（`auto mode on`、`(shift+tab to cycle)`）
- 工具调用行本身（`Bash(ls)`、`Interrupted`）与运行中的 `(12s, 300 tokens)`
- **`claude --help`**（CLI 参数层输出，非会话内渲染）

### 3.5 红线

1. **不碰官方产物**：不动二进制、不改字节码；验证期一律 `claude --plugin-dir`，**不写 `~/.claude/settings.json`**。
2. **不猜词条**：命不中一律放行原文并记录，**绝不写「大概意思」的中文**。
3. **不改 A 线**（`i18n/` `tools/` `scripts/` `patches/`）。
4. **不发布、不对外提交 issue/PR**（对外动作须人类拍板）。

---

## 四、环境事实与两个坑（**别再踩一遍**）

| 项 | 值 |
| :--- | :--- |
| 本机 CC | **2.1.296**，安装于 fnm node **v22.21.1** 的全局目录 |
| 安装路径 | `~/.local/share/fnm/node-versions/v22.21.1/installation/lib/node_modules/@anthropic-ai/claude-code` |
| **复原 A 线（≤2.1.241 汉化版）** | `npm i -g @anthropic-ai/claude-code@2.1.241`（**该版本仍在 npm 上**）→ 再跑 `bash scripts/apply_patch.sh` |

### 坑 1：`npm install -g` 会装到 WorkBuddy 托管运行时

原因叠加：① 会话 PATH 里 WorkBuddy 托管 node 优先；② **`$F/bin/npm` 的 shebang 是 `#!/usr/bin/env node`，会再走 PATH 取托管 node** ⇒ `npm config get prefix` 指向托管运行时。

**正解（必须显式带 node）**：

```bash
F="$HOME/.local/share/fnm/node-versions/v22.21.1/installation"
"$F/bin/node" "$F/lib/node_modules/npm/bin/npm-cli.js" config get prefix   # 应为 $F
"$F/bin/node" "$F/lib/node_modules/npm/bin/npm-cli.js" install -g @anthropic-ai/claude-code@latest
```

### 坑 2：上游 `install.cjs` 在 darwin-arm64 有缺陷 → `EEXIST`

npm 先落一个 **500 字节占位脚本**到 `bin/claude.exe`，postinstall 再 `fs.linkSync(平台二进制 → bin/claude.exe)` ⇒ **必然 EEXIST，全新安装也失败**。平台二进制其实已下载好（`node_modules/@anthropic-ai/claude-code-darwin-arm64/claude`，约 240 MB）。

**正解**（占位脚本自己也这么提示）：

```bash
P="$F/lib/node_modules/@anthropic-ai/claude-code"
rm -f "$P/bin/claude.exe" && cd "$P" && "$F/bin/node" install.cjs
```

### 坑 3：写 mod 测试时的两条约束（费了好几轮才摸清）

1. **测试层的 `on()` 不能注册「mod 自身也注册了的事件」** —— 会报
   `HooksError: hooks module did not load: on("X") registered twice`。
   ⇒ 想断言某钩子的行为，**改为导出纯函数、直接断言**（本仓 `register.tsx` 已导出 `tr` / `trWhole` / `groupLine` / `duration`）。
2. **测试环境里 `$.fs` 不可用** ⇒ **无法在测试里读 `dict.json`**。装配正确性交给 `claude plugin validate`。

---

## 五、接着做什么（按顺序，可直接复制）

### 步骤 1：起一个真实会话，肉眼验收（**最高优先**）

```bash
cd /Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh
claude --plugin-dir "$PWD"
```

依次看：

| # | 动作 | 期望 | 若不符 |
| :-- | :--- | :--- | :--- |
| 1 | 输入 `/` | 命令说明出现中文 | 检查 `dict.json` 是否被读取（见步骤 3） |
| 2 | 打开 `/config` | label 为中文 | `config.describe` 钩子或 `exact` 未命中 |
| 3 | 让它干活，看工作态 | Spinner 词为中文（思考中/请求中/…） | 检查 `spinner` 段与 `e.surface` |
| 4 | **重点看排版** | 中文未撑破行宽、未与右侧重叠；表格对齐正常 | ⚠️ 若破损 ⇒ 记录并考虑改用方式 B 自绘 |
| 5 | 按 `ctrl+o` 展开 | 部分内容可能仍是英文（引擎语义：改写只改绘制、不改存储） | 符合预期，非缺陷 |

### 步骤 2：采集真实未译清单

会话内输入 **`/cc-zh-dump`** ⇒ 会输出三类未译项（命令说明 / 配置项 / 屏幕文案）。

把它**原样作为 key** 写进 `dict.json` 的 `exact`，值填中文 ⇒ 新会话生效（词典每会话读一次）。

`modes`（页脚模式标签）目前为空，**dump 的 `[mode]` 行就是要填的值**。

### 步骤 3：改动后的自检

```bash
cd /Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh
claude plugin validate .     # 装配：应列出 13 钩子 + 8 个 $ 调用
claude plugin test .         # 逻辑：应 9 pass / 0 fail
```

### 步骤 4（提案，待人类拍板）

- 是否更新根 `README.md` / `SOP.md` / `SKILL.md`，把「两线边界」写进前门文档。
- 是否把 `mods/cc-zh` 装进全局（`~/.claude/settings.json` 的 `env.CLAUDE_CODE_PLUGIN_DIRS`）。
- 是否在 `i18n/translations.json` 之上另建「B 线专用增补表」，避免两条线共用一个文件。

---

## 六、入库状态（2026-10-12，**均已提交并推送**）

| 仓库 | 提交 | 远端 |
| :--- | :--- | :--- |
| `~/Dev/Private/claude-code-zh` | `c8cab12` feat(mods): B 线 cc-zh 0.1.0 …（含 `00_状态.md`、`HANDOFF.md`、`mods/` 全部 8 个文件） | `origin/main` ✅ 已推 |
| `~/Dev/Private/Pkm` | `73a1efe` 任务[已毕业]: techblog#4 派生调研毕业 …（含任务目录 4 文件 + 钩子产物） | `origin/master` ✅ 已推 |

> PKM 那次推送是 `e04a386..73a1efe`，**一并推出了 14 个提交** —— 其中 13 个是当日其他并发会话
> （`sanchofeed_情报巡检`、`github_生态巡检`、`qPKM治理` 等）已完成并等待推送的提交，
> 属 `git push` 的固有语义，非本次擅动。

**⚠️ 本文件自身的后续改动也要提交** —— 若你按本文件修改了代码或文档，记得
`git add -A && git commit` 并推送；新会话接手前先 `git log --oneline -3` 确认起点。

---

## 七、权威参考（要查 mods API 时看这里）

| 用途 | 位置 |
| :--- | :--- |
| **mods API 权威类型**（507 KB / 13,186 行） | 官方公开仓 `anthropics/claude-code` 的 `mods/types/claude-code.d.ts` |
| 取法 | `gh api repos/anthropics/claude-code/contents/mods/types/claude-code.d.ts --jq .content \| base64 -d > claude-code.d.ts` |
| 15 个可钩渲染点 | 同文件搜 `export type RenderComponent` |
| 各组件的可写/只读字段 | 同文件搜 `export type RenderPropsOf`（逐字段看 `Read-only` 标注） |
| 官方内置 mod 源码（可抄） | 同仓 `mods/{diff,sec-default,telemetry,agents-md}` |
| 社区先例（韩文 i18n mod，可对照） | `moduvoice/claude-code-ko-ui` |
| mods 生态目录（3088 个，2026-10-10 扫描） | `karanb192/awesome-claude-code-mods` |

**⚠️ API 时效性**：官方明示 *"The API can change between releases"*，且类型声明由 CLI **每次加载 mod 时写入** `.claude-plugin/types/`（**该目录才是你那个版本的权威**）。⇒ 升级 CC 后若汉化失效，**先跑 `validate` + `test`，再跑 `/cc-zh-dump` 看英文是否变了**。

---

## 八、已锁定的决策（**不要重新讨论**）

1. **走 mods 路线**（不复活二进制补丁）。
2. **B 线落在本仓 `mods/cc-zh/`**，不新开第 6 个 `*-zh` 仓 —— 因为 `i18n/translations.json` 1894 条是最大存量资产，同仓才好写迁移脚本；且 SKILL 入口应只有一个。
3. **以「引擎英文原文」为查表键**（非按命令名枚举）。
4. **本机 CC 升到最新版做实验**（人类明确「现装已不使用」；2.1.241 可随时复原）。
