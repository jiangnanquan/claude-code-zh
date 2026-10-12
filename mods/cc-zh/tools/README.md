# tools —— 验收与采样工具（非发布物）

这两个工具把「汉化到底生效没有」从**肉眼观察**变成**可复算证据**。
插件本体（`.claude-plugin/` `hooks/register.tsx` `dict.json`）不依赖它们。

## 1. `tty-probe.py` —— TTY 验收

用 pty 启动真实 `claude --plugin-dir <插件>`，把终端字节流喂给 pyte 重建**字符网格**，
逐行按「东亚宽字符 = 2 列」算列宽。一次运行同时回答两件事：

- **钩子生效了吗** —— 屏幕上有多少行变成了中文；
- **排版破了吗** —— 有没有行超出终端宽度（`0 溢出` 是达标线）。

```bash
P=~/.workbuddy/binaries/python/envs/default/bin/python

# 依赖（一次性）
$P -m venv ~/.workbuddy/binaries/python/envs/default 2>/dev/null
$P -m pip install pyte

# 打开斜杠面板并截图
$P tools/tty-probe.py . /tmp/probe "wait:16,/,wait:9" --cwd "$(git rev-parse --show-toplevel)"

# 跑 /cc-zh-dump 看还剩什么没译
$P tools/tty-probe.py . /tmp/probe "wait:16,esc,ctrl-u,wait:1,/cc-zh-dump,wait:3,enter,wait:9" \
   --cwd "$(git rev-parse --show-toplevel)"
```

两个**必须知道**的坑：

1. **`--cwd` 必须是 CC 已信任的目录**。cwd 指向新目录时 CC 会弹「信任此文件夹」，
   会话停在提示上，脚本只会抓到一个空屏。插件路径与 cwd 无关，所以通常直接填本仓根。
2. **快照只有在「UTF-8 替换字符 = 0」时才可信**。若每次 `os.read` 各自
   `decode('utf-8')`，跨包的多字节字符会被切断，屏幕上冒出 `��` ——
   看起来像 CC 的渲染缺陷，实际是探针自身的错。脚本会打印这个计数。

## 2. `runtime-sampler/` —— 运行时字符串采样（补词条的权威来源）

补词条时**不要**拿 `/cc-zh-dump` 的屏幕输出当 key。渲染器会折行、并且**吞掉反引号**：
实测 `` `claude doctor` ``、`` `anthropic` ``、`` `references/palette.md` `` 的反引号在界面上
是不显示的。exact 表逐字匹配，错一个字符就永远命中不了，而且**不报错**。

本采样插件把引擎给出的原值直接落盘到 `/tmp/cc-zh-sample/`：

| 文件 | 内容 |
| :--- | :--- |
| `describe.json` | **权威 key 来源**：`command.describe` / `config.describe` 在真实会话中给出的原值 |
| `runtime.json` | `$.command.list()` / `$.config.list()` 的全量快照 |
| `ui.json` | 各渲染点（`PromptHint` / `Spinner` / `InfoNotice` / `ToolProgress` / `SessionMode`）收到的 props |

```bash
P=~/.workbuddy/binaries/python/envs/default/bin/python
$P tools/tty-probe.py tools/runtime-sampler /tmp/probe "wait:16,/,wait:8,esc,ctrl-u,wait:1,/config,wait:3,enter,wait:9,esc,wait:3" \
   --cwd "$(git rev-parse --show-toplevel)"
```

> **为什么以 `describe.json` 为准而不是 `runtime.json`**：两者**可能不一致**。
> 实测 2.1.296 的 `/diff` —— `list()` 给 `View uncommitted changes and per-turn diffs`，
> 而 `describe` 给 `Toggle the diff panel showing uncommitted changes`；**界面显示的是后者**。
> 拿 `list()` 的值当 key 会静默失配。

已知采样结果（2.1.296，供参考）：

- `SessionMode.props.modes` 恒为 `[]` ⇒ 词典的 `modes` 段**无对象可填**；
  页脚的 `auto mode on` 是引擎独占绘制的 pills，按设计不可汉化。
- `config.list()` 的行**没有** `description` 字段，只有 `label`。
