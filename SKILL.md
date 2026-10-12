---
name: claude-code-zh
description: Claude Code CLI 简体中文汉化（自管 mods 插件）——静态词典 + 官方 hooks，只改 UI 显示文字，零 token、零网络、不碰官方产物。适用场景：「汉化cc」「重新汉化」「汉化不生效」「cc升级后重汉化」「还原英文」「检查汉化状态」「补词条」。维护 ~/Dev/Private/claude-code-zh/mods/cc-zh。
allowed-tools: Bash
---

# Claude Code 汉化（mods 版）

只做一件事：把 Claude Code 会话内 UI 文字显示为简体中文，**不碰功能逻辑、不碰官方产物**。
实现方式是官方 mods（Claude Code ≥ 2.1.287），失效时退回英文，不会把 CLI 改崩。

## 当前状态（2026-10-12，CC 2.1.296）

- 插件已装进全局 `~/.claude/settings.json`：`env.CLAUDE_CODE_PLUGIN_DIRS` 指向本仓 `mods/cc-zh`
- `claude plugin validate .` → 13 钩子 + 8 个 `$` 调用通过；`claude plugin test .` → 11 pass / 0 fail
- TTY 实机：中文排版正常、溢出 0 行；`/cc-zh-dump` → 命令 0，配置 0

## 快速开始

```bash
cd ~/Dev/Private/claude-code-zh/mods/cc-zh

# 自检（改完词典/hooks 后必跑）
claude plugin validate .   # 应：Validation passed
claude plugin test .       # 应：11 pass / 0 fail

# 单会话试装（不影响全局配置；日常使用已装全局，无需此步）
claude --plugin-dir "$PWD"
```

- 会话内输入 **`/cc-zh-dump`**：列出仍是英文的命令 / 配置 / 屏幕文案
- 还原英文：删掉 `~/.claude/settings.json` 的 `env.CLAUDE_CODE_PLUGIN_DIRS` 一行（先备份）

## 补词条（汉化不生效 / 发现英文残留时）

1. 跑 `/cc-zh-dump` 拿未译清单；
2. 用 `tools/runtime-sampler/` 取**权威英文原文**（不要用 dump 的屏幕输出——会折行、吞反引号）；
3. 原文逐字作为 key 写进 `dict.json` 的 `exact`；带运行时变量的写 `patterns`；
4. `claude plugin validate .` + `claude plugin test .` + `tools/tty-probe.py` TTY 验收；
5. 新会话生效。

## 安全原则（必须遵守）

1. **不碰官方产物**：不改二进制、不改字节码，只走官方 hooks
2. **不猜词条**：命不中一律放行英文原文并记录，绝不写「大概意思」的中文
3. **官方只读字段不碰**：`CommandOutput.command/args`、`ToolResult.tool`、各类 id 与视图状态
4. **给官方本地化开关让路**：`spinnerVerbs` 已含中文时原样放行，不覆盖用户配置
5. **按设计不可汉化**：权限确认窗口、欢迎屏、`/config` `/model` 子选择屏、错误信息、
   tips、`auto mode on` pill、`claude --help`——不是 bug，别去试

## 项目位置与入口

- 项目本体：`~/Dev/Private/claude-code-zh`（本 skill 通过软链接指向）
- 插件：`mods/cc-zh/`（README 有覆盖面与设计契约）
- 状态卡：[`00_状态.md`](00_状态.md)；续作入口：[`HANDOFF.md`](HANDOFF.md)
- 详细流程见 [SOP.md](SOP.md)，验收/采样工具见 [`mods/cc-zh/tools/README.md`](mods/cc-zh/tools/README.md)
