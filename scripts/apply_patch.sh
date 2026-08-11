#!/usr/bin/env bash
# apply_patch.sh — 应用/回滚 Claude Code 汉化（自管版）
#
# 流程：定位二进制 → 版本检测 → 备份/恢复干净基底 → patch → 冒烟测试 → 记录状态
# 安全：任何一步失败都不会留下半成品；patch 引擎（tools/patch-cli.js）自带优雅降级与校验
#
# 用法:
#   bash scripts/apply_patch.sh            # 应用汉化
#   bash scripts/apply_patch.sh --restore  # 从备份回滚英文原版
#   bash scripts/apply_patch.sh --status   # 查看上次状态
#
# 环境变量:
#   CLAUDE_CODE_ZH_CLI   覆盖 CLI 二进制路径（默认自动探测 npm 全局安装）

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STATE_DIR="$ROOT/.state"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/apply.log"
STATUS="$STATE_DIR/patch-status.txt"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

# --- 探测 CLI 二进制 -----------------------------------------------------
find_cli() {
    if [ -n "${CLAUDE_CODE_ZH_CLI:-}" ]; then
        [ -f "$CLAUDE_CODE_ZH_CLI" ] || { log "错误: CLAUDE_CODE_ZH_CLI 不存在"; exit 1; }
        echo "$CLAUDE_CODE_ZH_CLI"; return
    fi
    # npm 全局（含 fnm/nvm 管理）典型路径
    local candidates=(
        "$(npm prefix -g 2>/dev/null)/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
        "$(npm prefix -g 2>/dev/null)/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
        "/usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
        "/opt/homebrew/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
    )
    for c in "${candidates[@]}"; do
        if [ -f "$c" ]; then echo "$c"; return; fi
    done
    # 兜底：which 反查真实路径（去 alias）
    local cmd
    cmd="$(command -v claude 2>/dev/null || true)"
    if [ -n "$cmd" ] && [ -x "$cmd" ]; then echo "$cmd"; return; fi
    log "错误: 未找到 Claude Code 二进制，可设置 CLAUDE_CODE_ZH_CLI"
    exit 1
}

# --- 版本与 patch 状态检测 ----------------------------------------------
CLI_BIN="$(find_cli)"
BACKUP="$CLI_BIN.zh-cn-backup"
log "CLI 二进制: $CLI_BIN"

if [ "${1:-}" = "--status" ]; then
    cat "$STATUS" 2>/dev/null || echo "尚无 patch 记录"
    exit 0
fi

if [ "${1:-}" = "--restore" ]; then
    if [ -f "$BACKUP" ]; then
        cp "$BACKUP" "$CLI_BIN"
        log "已从备份恢复英文原版: $BACKUP"
        echo "restored" > "$STATUS"
        exit 0
    fi
    log "错误: 备份不存在（${BACKUP}），无法回滚"
    exit 1
fi

CLI_DIR="$(dirname "$CLI_BIN")"
CUR_VERSION="$("$CLI_BIN" --version 2>/dev/null || claude --version 2>/dev/null || echo unknown)"
log "当前版本: $CUR_VERSION"

# 已 patch 探测：help 头部是否已是中文
is_patched() {
    "$CLI_BIN" --help 2>/dev/null | grep -q "用法：claude"
}

# --- 备份托管：保证每次 patch 基于干净英文原文 --------------------------
if [ -f "$BACKUP" ]; then
    log "恢复干净基底: $BACKUP"
    cp "$BACKUP" "$CLI_BIN"
elif is_patched; then
    log "警告: 已 patch 且无备份——无干净基底，继续就地增量 patch（幂等），建议重装后重新汉化"
else
    log "创建备份: $BACKUP"
    cp "$CLI_BIN" "$BACKUP"
fi

# --- patch（bun 原生流程：extract → patch 文本 → repack → 验证） -----------
# 绝不能直接对二进制跑 patch-cli.js（UTF-8 读写会破坏非 UTF-8 字节）。
# 正确流程与 claude-code-zh-cn 插件一致：
#   bun-binary-io.js extract  从 Mach-O 提取 claude 模块 JS 文本
#   patch-cli.js              对文本做安全替换（字面量 token 扫描 + 优雅降级）
#   bun-binary-io.js repack   塞回二进制（处理结构 + 重签名）
# 依赖: node-lief（npm 全局），先跑 check-deps 确认
BUN_IO="$ROOT/tools/bun-binary-io.js"
if ! node "$BUN_IO" check-deps 2>/dev/null | grep -q "ok"; then
    log "错误: node-lief 不可用，先安装: npm install -g node-lief"
    exit 1
fi

TARGET_VERSION="$CUR_VERSION"
log "开始 patch（版本 ${TARGET_VERSION}）..."
TMP_JS="${TMPDIR:-/tmp}/claude-code-zh-extract.$$.js"
PATCH_STATUS_FILE="$STATE_DIR/patch-engine-status.txt"

log "extract: 从二进制提取 JS 文本..."
if ! node "$BUN_IO" extract "$CLI_BIN" "$TMP_JS" 2>>"$LOG"; then
    log "错误: extract 失败"; rm -f "$TMP_JS"; exit 1
fi

log "patch: 对提取文本应用翻译表..."
# 跑两遍：第二遍幂等（已替换的规则不命中），但能让第一遍被扫描器
# 状态跳过的字面量（如部分 skill 描述，干净版文本上扫描异常）补命中
PATCH_COUNT="$(node "$ROOT/tools/patch-cli.js" "$TMP_JS" "$ROOT/i18n/translations.json" \
    --status "$PATCH_STATUS_FILE" --log "$LOG" 2>&1 | tail -1 || true)"
PATCH_COUNT_2="$(node "$ROOT/tools/patch-cli.js" "$TMP_JS" "$ROOT/i18n/translations.json" \
    --status "$PATCH_STATUS_FILE" --log "$LOG" 2>&1 | tail -1 || true)"
ENGINE_STATUS="$(cat "$PATCH_STATUS_FILE" 2>/dev/null || echo unknown)"
log "patch 引擎: ${ENGINE_STATUS}（第一遍替换 ${PATCH_COUNT} 处，第二遍 ${PATCH_COUNT_2} 处）"

case "$ENGINE_STATUS" in
    ok)        log "patch 完成: ok（全部命中）" ;;
    partial)   log "patch 完成: partial（部分条目未命中，运行 check_residue.py 甄别）" ;;
    noop)      log "patch 未执行: noop" ;;
    *)         log "警告: patch 引擎异常状态 ${ENGINE_STATUS}——检查 $LOG" ;;
esac

if [ "$ENGINE_STATUS" = "noop" ] || [ "$PATCH_COUNT" = "0" ]; then
    log "跳过 repack（无替换）"; rm -f "$TMP_JS"
else
    log "repack: 塞回二进制（含结构修复与重签名）..."
    if ! node "$BUN_IO" repack "$CLI_BIN" "$TMP_JS" 2>>"$LOG"; then
        log "错误: repack 失败——二进制可能已损坏，立即从备份恢复"
        cp "$BACKUP" "$CLI_BIN"
        rm -f "$TMP_JS"; exit 1
    fi
    rm -f "$TMP_JS"
    log "验证: 执行二进制确认版本..."
    VERIFIED="$("$CLI_BIN" --version 2>&1 | head -1 || true)"
    log "repack 后版本: ${VERIFIED}"
    if [ -z "$VERIFIED" ] || [ "$VERIFIED" != "$TARGET_VERSION" ]; then
        log "错误: repack 后版本异常——立即从备份恢复"
        cp "$BACKUP" "$CLI_BIN"
        exit 1
    fi
fi

# --- 冒烟测试 -----------------------------------------------------------
log "冒烟测试..."
SMOKE_OK=1
if "$CLI_BIN" --version >/dev/null 2>&1; then
    log "  --version ✓"
else
    log "  --version ✗ 失败！"; SMOKE_OK=0
fi
if "$CLI_BIN" --help 2>&1 | head -3 | grep -q "用法：claude"; then
    log "  --help 中文 ✓"
else
    log "  --help 中文 ✗ 未汉化或输出异常"; SMOKE_OK=0
fi
if "$CLI_BIN" --help 2>&1 | head -3 | grep -q "Usage: claude"; then
    log "  --help 仍有英文头部 ✗"; SMOKE_OK=0
else
    log "  --help 无英文残留 ✓"
fi

# --- 记录状态 -----------------------------------------------------------
TRANS_SHA="$(shasum -a 256 "$ROOT/i18n/translations.json" | cut -d' ' -f1)"
{
    echo "time:        $(date '+%Y-%m-%d %H:%M:%S')"
    echo "cli_version: $CUR_VERSION"
    echo "engine:      $ENGINE_STATUS"
    echo "translations: sha256=$TRANS_SHA"
    echo "smoke:       $([ "$SMOKE_OK" = 1 ] && echo PASS || echo FAIL)"
} > "$STATUS"

if [ "$SMOKE_OK" = 1 ]; then
    log "✅ 汉化应用完成，冒烟测试通过"
else
    log "❌ 冒烟测试失败——请检查 ${LOG}；可用 --restore 回滚"
    exit 1
fi
