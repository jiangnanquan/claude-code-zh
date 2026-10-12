# SOP — mods 汉化维护流程

> 适用：Claude Code **≥ 2.1.287** 的 [`mods/cc-zh/`](mods/cc-zh/README.md) 路线（唯一活跃路线）。
> 旧二进制补丁路线已于 2026-10-12 清退，文件与文档保留在 Git 历史中。
> 新会话接手先读 [`HANDOFF.md`](HANDOFF.md)，现状看 [`00_状态.md`](00_状态.md)。

---

## B0：自检（改动后必跑）

```bash
cd mods/cc-zh
claude plugin validate .   # 装配正确性：应列出 13 个钩子 + 8 个 $ 调用
claude plugin test .       # 纯逻辑：应 11 pass / 0 fail
```

`validate` 只证明**装配**对，`test` 只证明**逻辑**对——两者都**不覆盖**「中文有没有
撑破终端行宽」。排版必须另跑 TTY 验收（B2）。

## B1：补词条（最高频的动作）

```
① 起会话跑 /cc-zh-dump  →  看还剩哪些英文
② 取「权威英文原文」   →  用 tools/runtime-sampler/ 采样，**不要**用 dump 的屏幕输出
③ 英文原文（逐字）作为 key 写进 dict.json 的 exact，值填中文
④ 重跑 B0 自检 + B2 验收；新会话生效（词典每会话读一次）
```

> ⛔ **红线：不猜词条**。命不中一律放行原文并记录，**绝不写「大概意思」的中文**。
>
> ⛔ **为什么不能用 dump 的屏幕输出当 key**：渲染器会折行，并**吞掉反引号**——
> 实测 `` `claude doctor` ``、`` `anthropic` ``、`` `references/palette.md` `` 的反引号在界面上
> 是不显示的。exact 表逐字匹配，错一个字符就**永远命中不了，而且不报错**。
> 取权威原文的方法见 [`mods/cc-zh/tools/README.md`](mods/cc-zh/tools/README.md)。

带**运行时变量**的描述（`/model` 的当前模型名、`/fast` 的模式、`/sandbox` 的状态）
静态 `exact` 表结构性无解，写进 `dict.json` 的 **`patterns`** 正则段。
注意 `command.describe` 走 `trDesc()`（exact → patterns），若不生效先确认该函数存在。

## B2：TTY 验收（把「肉眼看看」变成可复算证据）

```bash
cd mods/cc-zh
P=~/.workbuddy/binaries/python/envs/default/bin/python
ROOT="$(git rev-parse --show-toplevel)"

# 打开斜杠面板：同时给出「多少行变中文」与「有没有行撑破行宽」
$P tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9" --cwd "$ROOT"

# 跑 /cc-zh-dump：应报「命令 0，配置 0，屏幕文案 0」
$P tools/tty-probe.py . /tmp/probe "wait:16,esc,ctrl-u,wait:1,/cc-zh-dump,wait:3,enter,wait:9" --cwd "$ROOT"
```

达标线：**溢出 0 行** + **UTF-8 替换字符 0 个**（非 0 说明探针自身把多字节字符切断了，快照不可信）。

> `/cc-zh-dump` 的「屏幕文案」计数读的是 `$.store` 里的**历史累积**记录，
> 词典补完后旧记录不会自动消失。要拿干净读数，先清 `~/.claude/plugins/store/` 下
> 本插件的 `<plugin>_*.json` 里的 `missing` 键（**先备份**）。

## B3：CC 官方升级后（汉化部分失效）

按此顺序排查，**不要**一上手就猜 API 变了：

```bash
cd mods/cc-zh
claude plugin validate .              # ① 钩子还装配得上吗
claude plugin test .                  # ② 纯逻辑还过吗
# ③ 起了会话跑 /cc-zh-dump —— 若英文**变了**，是词条漂移，补 key（B1）
# ④ 若 validate 报未知钩子/字段，是 mods API 变了 —— 查权威类型（见下）
```

**权威类型声明**由 CLI 每次加载 mod 时写入 `.claude-plugin/types/claude-code/index.d.ts`
（**该目录才是你那个版本的权威**）；官方明示 *"The API can change between releases"*。
另有官方公开仓 `anthropics/claude-code` 的 `mods/types/claude-code.d.ts` 可对照。

## B4：启用 / 停用（让日常 `claude` 带汉化）

**当前做法（2026-10-12 起）**：在 `~/.claude/settings.json` 的 `env` 里加一行：

```jsonc
"CLAUDE_CODE_PLUGIN_DIRS": "/Users/jnq/Dev/Private/claude-code-zh/mods/cc-zh"
```

`CLAUDE_CODE_PLUGIN_DIRS` 是官方支持的变量，CLI 启动时按 `--plugin-dir` 的**同一条路径内联加载**
（二进制内记作 `preAction: CLAUDE_CODE_PLUGIN_DIRS inline plugins`）。⇒ 直接敲 `claude` 即带汉化，
**仓库里改完立即生效、无需重装**；删掉这一行即完全还原。已实测（CC 2.1.296）。

| 手段 | 生命周期 | 适用 |
| :--- | :--- | :--- |
| `claude --plugin-dir <路径>` | **仅本次会话** | 试装、A/B 对比、排查 |
| `settings.json` 的 `env.CLAUDE_CODE_PLUGIN_DIRS` | 每次启动 | **日常使用（当前采用）** |
| `claude plugin install`（marketplace） | 每次启动 | 正式分发；缺点：复制进 `~/.claude/plugins/cache`，仓库改动**不再自动生效** |

**停用**：删掉 `env` 里那一行即可（改前先 `cp ~/.claude/settings.json{,.bak}`）。

> ⚠️ 改 `~/.claude/settings.json` 前，可先用 JSON 往返验证「改动是否只增不减」：
> `json.dumps(json.load(f), ensure_ascii=False, indent=2)+"\n"` 若与原文**字节一致**，
> 就说明可用 json 方式安全改写（本机 2026-10-12 验证通过）。该文件含 API token，**务必先备份**。

## B5：与官方本地化开关的边界（**别覆盖用户已配好的中文**）

`settings.json` 已提供官方本地化开关，本 mod **必须让路**：

| 官方设置 | 本 mod 的纪律 |
| :--- | :--- |
| `spinnerVerbs`（自定义 Spinner 动词） | **只在 `props.word` 仍为英文时**才接替；含中文一律原样放行 |
| `spinnerTipsOverride`（自定义 tips） | 不碰（tips 不在覆盖范围内） |
| `language` | 与本 mod 正交，不冲突 |

实测证据：2.1.296 下 `Spinner.props.word` 就是 `spinnerVerbs` 里的随机中文词
（观察到「哈希中」「联网中」）。**无条件覆盖 = 把这些词换成固定的「应答中」，属体验退化**。
判定逻辑在 `spinnerWord()`，`tests/register.test.ts` 有回归用例。

## B6：red lines（改 mod 前必读）

1. **不碰官方产物**：不动二进制、不改字节码；插件只走官方 hooks。
2. **不猜词条**（见 B1）。
3. `CommandOutput.command/args`、`ToolResult.tool`、各类 id 与视图状态是**官方只读字段**，
   改写会被拒绝，且会破坏可审计性——别去试。
4. **不发布、不对外提交 issue/PR**（对外动作须人拍板）。

## B7：词典与上游翻译表的关系（历史包袱已了断）

`dict.json` 的 `exact` 底子迁移自 claude-code-zh-cn 翻译表（1905 条，2026-10-12 已全部吸收并
增补到 1950 条）。清退 A 线后，**`dict.json` 是唯一词典，不再自动跟随上游**：

- 上游插件若出了值得吸收的新词：用 `tools/runtime-sampler/` 或上游 `cli-translations.json`
  对比后**人工补进** `dict.json`，不要整表覆盖；
- 旧 `i18n/`、`migrate_i18n.py` 已删除，需要考古从 Git 历史取。

---

## 验证清单（每次改 dict / register 后）

- [ ] `claude plugin validate .` → Validation passed（13 钩子 + 8 个 `$` 调用）
- [ ] `claude plugin test .` → **11 pass / 0 fail**
- [ ] TTY 验收：斜杠面板**溢出 0 行**、UTF-8 替换字符 **0**
- [ ] `/cc-zh-dump` → **命令 0，配置 0，屏幕文案 0**（先清 `$.store` 历史记录）
- [ ] 页脚提示行已中文：`⏵⏵ auto mode on · （shift+tab 切换）· ← 查看代理`
      （`auto mode on` 是引擎独占绘制的 pill，按设计保持英文）
