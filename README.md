# claude-code-zh — Claude Code 简体中文汉化（自管版）

> [!IMPORTANT]
> ## ⚠️ 重大公告（2026-08-28）：官方改动，底层 UI 汉化已无法继续
>
> Anthropic 自 Claude Code **2.1.24x** 起将 npm 包改为 **Bun bytecode 编译 + 模块 chunk 拆分**：
> UI 文字被编译进 JSC 字节码，不再存在于可提取的 JS 源码中。
>
> **影响**：提取-重打包路线（本项目与上游 [taekchef/claude-code-zh-cn](https://github.com/taekchef/claude-code-zh-cn)）已无法继续——`extract` 只能拿到约 20KB 的 `// @bun @bytecode` stub，强行 `repack` 会损坏二进制（实测体积缩水约 10MB、启动即 segfault）。上游已于 [PR #235](https://github.com/taekchef/claude-code-zh-cn/pull/235) 正式放弃该路线；本项目的 patch 工具同步转为**安全旁路模式**（probe 检测到 bytecode 容器自动跳过，绝不改动二进制）。
>
> **现阶段状态**：如需完整底层 UI 汉化，可锁定最后可汉化版本 **2.1.237 / 2.1.241**：`npm install -g @anthropic-ai/claude-code@2.1.237`。

> 一个完全自管的 **Claude Code CLI 汉化项目**：自己的翻译表、自己的 patch 工具、
> 自己的甄别与冒烟测试。**只做 UI 文字汉化，不碰任何功能逻辑**。
> 与 `claude-code-zh-cn` 插件（taekchef，MIT）同思路但独立维护——翻译表随插件更新迁移，工具与流程自管。

## 这是什么

Claude Code（`@anthropic-ai/claude-code`）是 bun 编译的 Mach-O 二进制（约 285MB），
UI 文字以 UTF-8 字符串字面量内联其中。本项目做的事：

- **翻译表**：`i18n/translations.json`（1894 条 en→zh，源自 claude-code-zh-cn 插件，MIT 开源）
- **Patch 工具**：`tools/patch-cli.js`（沿用 claude-code-zh-cn 的成熟实现，MIT）——扫描二进制中的真实字符串字面量 token，逐条替换，单条不匹配自动跳过
- **甄别工具**：`scripts/check_residue.py` —— patch 后列出未命中的条目，驱动翻译表更新
- **冒烟测试**：`scripts/smoke_test.sh` —— patch 后验证 `--version` / `--help` 正常且界面为中文
- **安全机制**：patch 前自动备份（`.zh-cn-backup`）、从干净基底恢复重 patch（杜绝叠 patch）、替换后校验、失败不落盘

## 依赖

- `node`（patch 引擎）
- `node-lief`（Mach-O 结构解析，npm 全局）：`npm install -g node-lief`

## 快速开始

```bash
# 应用汉化到当前安装的 Claude Code（自动定位二进制、备份、extract→patch→repack、冒烟）
bash scripts/apply_patch.sh

# 查看应用状态
cat .state/patch-status.txt

# 回滚（从备份恢复原始英文版）
bash scripts/apply_patch.sh --restore
```

## 更新流程（官方发布新版后）

```bash
# 1. 确认新版本
claude --version

# 2. 重新生成翻译表（从 claude-code-zh-cn 迁移，合并本地补丁 i18n/patches.json）
python3 scripts/migrate_i18n.py

# 3. 应用汉化
bash scripts/apply_patch.sh

# 4. 甄别残留 → 需要补的写进 i18n/patches.json，重新走 2-3
python3 scripts/check_residue.py
```

详见 [SOP.md](SOP.md)。

## 安全设计（不影响功能使用）

| 机制 | 说明 |
|------|------|
| 备份/恢复 | patch 前同目录保存 `.zh-cn-backup`，`--restore` 一键还原 |
| 干净基底 | 每次 patch 从备份恢复原文再替换，杜绝「patch 叠 patch」 |
| 只改字面量 | 扫描器只识别 `"..."` `'...'` `` `...` `` 字符串 token，不碰对象键、标识符、注释、错误码字典 |
| 优雅降级 | 单条匹配不上只跳过该条（新版本改了文字 = 那条保持英文），不影响其余 |
| 校验保护 | patch 后结果通过校验才落盘；任何异常按「未改动」退出，绝不落半成品 |
| skipPatch 契约 | 上游标记 `model-prompt-contract` 的 10 条（系统提示注入、记忆提示、输出风格等）**有意不替换**，避免改动模型提示词契约 |
| 冒烟测试 | patch 后自动跑 `--version` / `--help`，输出异常即失败标记 |

## 已知限制（v1）

- **skill 描述无法 patch**：内置 skill（dataviz、run、verify 等）的元数据存在 bun 字符串表（非 JS 字面量），patch 工具扫不到。其中 run/simplify/init 等由 CC 2.1.227 **原生中文**兜底；dataviz、keybindings-help、fewer-permission-prompts、verify 保持英文。见 [PITFALLS.md](PITFALLS.md)
- **模板拼接串**：minifier 拆开的片段、`` `${...}` `` 模板内的文本（如压缩通知 `(for history)`）无法整体匹配，保持英文
- 已知英文残留均为上述两类或非 UI 位置，**不影响功能使用**

## 与 claude-code-zh-cn 插件的关系

- 本项目翻译表**定期从插件迁移**（`migrate_i18n.py`），插件更新翻译时跟进
- 迁移保留上游的 `skipPatch` 安全标记
- 成熟后可在 `~/.claude/settings.json` 停用插件 `claude-code-zh-cn@claude-code-zh-cn`，完全由本项目接管

## 目录结构

```
claude-code-zh/
├── i18n/
│   ├── translations.json    # 主翻译表（迁移自 claude-code-zh-cn + 本地补丁）
│   └── patches.json         # 本地补丁（甄别后手写，格式 [{en, zh, note}]）
├── tools/
│   ├── patch-cli.js         # patch 引擎（MIT，源自 claude-code-zh-cn）
│   ├── patch-cli.sh         # patch 入口
│   └── bun-binary-io.js     # bun 二进制 I/O 辅助
├── scripts/
│   ├── migrate_i18n.py      # 迁移/合并翻译表
│   ├── apply_patch.sh       # 应用汉化（定位/备份/patch/冒烟/状态）
│   ├── check_residue.py     # 残留检测
│   └── smoke_test.sh        # 冒烟测试
├── patches/
│   └── claude-hud-ascii-bar.patch  # 第三方插件本地定制：claude-hud 状态栏进度条 ASCII 化
├── SOP.md                   # 升级与维护流程
├── PITFALLS.md              # 已知坑
└── SKILL.md                 # skill 入口（/claude-code-zh）
```

## License

MIT（翻译表与 patch 引擎沿用 `claude-code-zh-cn`，原作者 taekchef）。
