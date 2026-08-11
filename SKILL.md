---
name: claude-code-zh
description: Claude Code CLI 简体中文汉化（自管项目）——自己的翻译表 + patch 工具，只改 UI 文字不影响功能。适用场景：「汉化cc」「重新汉化」「汉化不生效」「cc升级后重汉化」「回滚汉化」。维护 ~/Dev/Private/claude-code-zh，与 claude-code-zh-cn 插件同思路但独立维护。
allowed-tools: Bash
---

# Claude Code 汉化（自管版）

只做一件事：把 Claude Code CLI 的 UI 文字汉化为简体中文，**不碰功能逻辑**。
与 opencode-zh 同模式（翻译表 + 工具 + 甄别 + 冒烟），但 Claude Code 是二进制，
patch 方式为「扫描字符串字面量 token 逐条替换」（`tools/patch-cli.js`）。

## 快速开始

```bash
# 应用汉化（定位二进制 → 备份 → patch → 冒烟 → 记录状态）
bash scripts/apply_patch.sh

# 查看状态
bash scripts/apply_patch.sh --status

# 回滚英文原版
bash scripts/apply_patch.sh --restore
```

## 更新流程（官方发布新版 / 汉化不生效时）

```bash
# 1. 确认新版本号（CLI 升级后需重新汉化）
claude --version

# 2. 从 claude-code-zh-cn 插件迁移最新翻译表（合并本地补丁 i18n/patches.json）
python3 scripts/migrate_i18n.py

# 3. 应用
bash scripts/apply_patch.sh

# 4. 残留甄别（可选，发现英文残留时）
python3 scripts/check_residue.py
```

## 安全原则（必须遵守）

1. **只改字符串字面量**，patch 引擎自动跳过对象键/标识符/注释/代码字典
2. **从不删备份**：`<claude.exe>.zh-cn-backup` 是回滚保险，`--restore` 一键还原
3. **skipPatch 保护不能去掉**：`migrate_i18n.py` 保留上游 `model-prompt-contract`
   标记的 10 条（系统提示/记忆提示/输出风格），改动会影响模型行为契约
4. **不手动改翻译表格式**：只通过 `i18n/patches.json` 补条目（`[{en, zh, note}]`），
   主表由迁移脚本重新生成
5. **不保证的**：bun 字符串表内的 skill 描述（dataviz/verify 等）patch 扫不到，
   保持英文——不是 bug，见 PITFALLS.md

## 项目位置与状态

- 项目本体：`~/Dev/Private/claude-code-zh`（本 skill 通过软链接指向）
- 状态记录：`.state/patch-status.txt`（cli 版本、引擎状态、翻译表 sha256、冒烟结果）
- 翻译表来源：claude-code-zh-cn 插件（MIT，taekchef），`migrate_i18n.py` 定期迁移

详细流程见 [SOP.md](SOP.md)，坑见 [PITFALLS.md](PITFALLS.md)。
