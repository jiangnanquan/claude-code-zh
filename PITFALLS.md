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

## 5. skill 描述汉化（2026-08-11 已验证可行）

内置 skill 的 description 大多在**提取的 JS 源码字面量**里（`var Q$v='...'` 或
`description:'...'` 或 SKILL.md 模板字符串内）——**可以 patch**，前提是：

- en 不得含单引号 `'`（needle 会被转义成 `\'` 导致不匹配）→ **含 `'` 的整段拆成多个无 `'` 片段**分别替换
- en 片段不得以反斜杠结尾（`\'` 的前半）→ 拆分点避开
- dataviz 的描述被 minifier 拆成两个相邻字面量 → 同样按片段处理

已验证 11 条 skill 描述补丁全部生效（dataviz、keybindings-help、update-config、
loop、claude-api、verify、dataviz-menu）。**fewer-permission-prompts 的说明不在
提取 JS 内**（原生数据区），保持英文。

## 6. 两遍 patch（apply_patch.sh 内置）

部分字面量（如 keybindings-help 的 description）在**干净英文版**文本上会被扫描器
状态跳过，但在**已汉化版**文本上能扫到 → 第一遍 patch 未命中，第二遍（幂等）
补命中。apply_patch.sh 已内置两遍运行，无需人工干预。

## 7. 验证方法坑

- **extract 输出 ≠ 二进制内容**：部分字符串在 extract 时被转义（`\uXXXX`）或模板拼接
  （如 help 头「用法：claude」是 `用法：` + 变量拼接，二进制里无连续字节）→
  **验证用「实际运行」（--help 输出）或二进制 UTF-8 find，不要用 re-extract 文本 find**
- check_residue.py 的 en 检测在二进制上做（UTF-8 find），结果可信

## 8. 已知英文残留清单（2.1.227，均不影响功能）

- `You have been invoked in the following environment: `（系统提示，skipPatch 保护）
- `Your responses should be short and concise.`（系统提示，skipPatch 保护）
- `Saving a memory is a two-step process:`（记忆提示，skipPatch 保护）
- fewer-permission-prompts 的 skill 说明（原生数据区，patch 不可达）
- 压缩通知 `(for history)` / `(to see full summary)`（模板拼接）
- `[hidden]`、`Not working` 等少量标签（位置待查，影响极小）

新版本残留以 `check_residue.py` 输出为准，对照本表甄别。

## 9. Bun 2.1.24x+ Bytecode 编译容器与安全旁路

- 从 Claude Code `2.1.238` / `2.1.24x` 开始，官方构建启用了 Bun 的 bytecode 编译与 chunk 代码拆分。
- 在此形态下，入口模块（如 `/$bunfs/root/cli`）只剩 19KB 的引导 stub，真实 UI 字符串被打包进 compiled bytecode chunk。
- 对 bytecode 编译容器强制执行 `extract -> patch -> repack` 会导致 bytecode 指针错位，运行时报 `Segmentation fault` 或 `parseFromSourceCode failed`。
- 本项目工具链已内置安全检测（`bun-binary-io.js probe`）：对 `bytecode` 容器形态自动安全旁路 Layer 4 二进制 patch，杜绝损坏二进制。
- **推荐策略**：
  - 维持当前新版（2.1.248+）：通过 Prompt/Rules/Skills 保持交互中文，底层 CLI 保持官方原版稳定运行。
  - 需要完整的底层 UI 汉化（Layer 4）：可锁定为已验证的 2.1.237 版本（`npm install -g @anthropic-ai/claude-code@2.1.237`）。
