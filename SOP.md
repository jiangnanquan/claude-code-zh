# SOP — 升级与维护流程

## 场景零：例行检查（「检查cc版本」「cc更新」）

```bash
bash scripts/check_update.sh
# 输出: CC 当前/最新版本（npm + GitHub 双来源）、安装形态、
#       汉化状态（上次 patch 版本 vs 当前）、翻译表上游对比、平台窗口
# 只读检查，不改动任何东西；结论里会给出下一步动作指引
```

## 场景一：Claude Code 官方升级后重新汉化

```bash
# 1. 确认新版本（升级后二进制变化，旧 patch 可能部分失效）
bash scripts/check_update.sh   # 或直接 claude --version

# 2. 迁移最新翻译表（合并 i18n/patches.json 本地补丁，保留 skipPatch）
python3 scripts/migrate_i18n.py

# 3. 应用（自动处理：备份恢复 → extract → patch → repack → 验证 → 冒烟 → 状态）
bash scripts/apply_patch.sh
# 预期输出: patch 完成 ok/partial + 冒烟通过

# 4. 甄别残留（引擎报 partial 或用户发现英文残留时）
python3 scripts/check_residue.py
#   残留条目 → 甄别：
#   - skipPatch 标记 → 有意保留，跳过
#   - 非字面量位置（模板拼接/代码字典）→ patch 不替换，保持英文
#   - 确认为真 UI 字面量 → 修正 i18n/patches.json 后重跑 2-3
```

## 场景五：CC 版本跨度或容器形态变化（2.1.242+ Bytecode 容器）

```bash
# 1. 升级 CC 本体（npm install -g @anthropic-ai/claude-code@latest）
# 2. 检查更新状态与容器形态：
bash scripts/check_update.sh
# 3. 运行 apply_patch.sh（自动识别容器：若为 bytecode 容器则自动旁路 Layer 4 patch，安全保护二进制）
bash scripts/apply_patch.sh
# 4. 如需强制完整底层 UI 汉化，可指定安装支持明文 Patch 的最高版本：
#    npm install -g @anthropic-ai/claude-code@2.1.241
```

## 场景二：翻译表来自上游插件的更新

claude-code-zh-cn 发布新版（`~/.claude/plugins/` 下 cli-translations.json 更新）：

```bash
python3 scripts/migrate_i18n.py --source <新表路径>
bash scripts/apply_patch.sh
```

## 场景三：汉化不生效 / 界面变英文

```bash
# 1. 检查状态
bash scripts/apply_patch.sh --status

# 2. 检查 CLI 是否升级了（版本与状态记录不一致 → 重跑场景一）
claude --version

# 3. 检查备份是否被清理（npm 重装会清 bin 目录 → 备份重建即可）
ls -la <claude.exe>.zh-cn-backup
```

## 场景四：回滚

```bash
bash scripts/apply_patch.sh --restore
```

## 验证清单（每次汉化后）

- [ ] `claude --version` 正常输出
- [ ] `claude --help` 头部为「用法：claude」（中文）
- [ ] 交互会话正常启动（冒烟测试 `-p "hi"` 覆盖）
- [ ] `.state/patch-status.txt` 记录 smoke=PASS
- [ ] `check_residue.py` 残留条目均为已知类型（skipPatch/非字面量）
