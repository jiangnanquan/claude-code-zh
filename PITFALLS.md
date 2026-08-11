# PITFALLS — 已知坑与甄别经验

## 1. bun 二进制字符串的存储形态（决定 patch 边界）

Claude Code 2.1.x 是 bun 编译的 Mach-O 二进制（285MB）。字符串有三类存储形态：

| 形态 | patch 引擎能否替换 | 例子 |
|------|-------------------|------|
| JS 源码字符串字面量（`"..."`/`'...'`/`` `...` `` token） | ✅ 是 | help 界面、权限提示、spinner |
| bun 字符串表（`\x00` 前缀序列化数据，如 skill 元数据） | ❌ 否 | run/dataviz/verify 的 skill 描述 |
| 模板拼接 / minifier 拆开的片段 | ❌ 否（无法整体匹配） | 压缩通知 `(for history)`、`(to see full summary)` |

**甄别方法**：残留串在二进制中检查前导字节——`"`/`'` 包围 = 字面量（应可 patch，没命中才是问题）；
`\x00` 前缀 = 字符串表；其他 = 代码/拼接。

## 2. skipPatch 契约（10 条，故意不汉化）

上游 claude-code-zh-cn 对系统提示注入、记忆提示、输出风格相关 10 条标记
`skipPatch: "model-prompt-contract"`——改动会改变注入给模型的提示词契约。
**migrate 时保留这些标记，不要通过 patches.json 覆盖**（除非明确要改模型提示词）。

## 3. 已 patch 且无备份 = 没有干净基底

npm 重装/升级会清掉 bin 目录（备份一起消失）。此时新二进制是干净的，
`apply_patch.sh` 会重建备份。**禁止**对已 patch 文件「手动删备份」——
`--restore` 依赖备份文件存在。

## 4. 符号链接与 skill 加载

- 本项目通过 `~/.claude/skills/claude-code-zh -> ~/Dev/Private/claude-code-zh` 软链提供 skill 入口
- Claude Code 2.1.x 支持加载符号链接 skill（实测 opencode-zh 正常）
- 若某版本 CC 不再加载软链 skill：把 SKILL.md 复制进 `~/.claude/skills/`，保留项目本体在 Private

## 5. 已知英文残留清单（2.1.227，均不影响功能）

- `You have been invoked in the following environment: `（系统提示，skipPatch 保护）
- `Your responses should be short and concise.`（系统提示，skipPatch 保护）
- `Saving a memory is a two-step process:`（记忆提示，skipPatch 保护）
- run skill 描述（bun 字符串表；有 CC 原生中文兜底，实际显示中文）
- dataviz / keybindings-help / fewer-permission-prompts / verify 的 skill 描述（bun 字符串表，英文）
- 压缩通知 `(for history)` / `(to see full summary)`（模板拼接）
- `[hidden]`、`Not working` 等少量标签（位置待查，影响极小）

新版本残留以 `check_residue.py` 输出为准，对照本表甄别。

## 6. 翻译表更新纪律

- 主表 `i18n/translations.json` 只由 `migrate_i18n.py` 生成，**不要手改**
- 新增/修正条目写 `i18n/patches.json`（补丁优先于上游）
- 版本差异的旧条目（check_residue 报「不存在」）保留即可，不清理——
  旧版本回滚/不同安装方式（npm vs 安装器）时仍有用
