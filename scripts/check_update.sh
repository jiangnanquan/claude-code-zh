#!/usr/bin/env bash
# check_update.sh — 检查 Claude Code 与翻译表更新状态，给出升级建议（只检查，不改动）
#
# 移植自 cc升级 skill 的巧思：
#   1. 双来源版本验证（npm + GitHub API，防 npm 滞后）
#   2. 安装方式探测（npm 全局路径 → 升级/重汉化路径已知）
#   3. 主版本跨度提醒（2.x → 3.x 提示 breaking changes）
#   4. 平台版本窗口记录（native binary 已验证范围）
#   5. 汉化状态检测（当前二进制 vs 上次汉化记录 → 提示重汉化时机）
#
# 用法: bash scripts/check_update.sh [--json]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
STATE_DIR="$ROOT/.state"
STATUS="$STATE_DIR/patch-status.txt"
TRANS="$ROOT/i18n/translations.json"

# --- 辅助 ---------------------------------------------------------------
ver_gt() { # ver_gt <a> <b>：a > b（数字点分比较）
    [ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -1)" != "$1" ] && [ "$1" != "$2" ]
}
ver_major() { echo "$1" | cut -d. -f1; }

# --- 1. 当前版本与安装形态 ----------------------------------------------
CUR="$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo unknown)"
echo "== Claude Code 本体 =="
echo "  当前版本:      $CUR"

# 二进制形态探测（cc升级 巧思：2.1.113 起为 native binary，wrapper + ~250MB 原生二进制）
BIN=""
for c in "$(npm prefix -g 2>/dev/null)/lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe" \
         "$(npm prefix -g 2>/dev/null)/node_modules/@anthropic-ai/claude-code/bin/claude.exe"; do
    [ -f "$c" ] && BIN="$c" && break
done
if [ -n "$BIN" ]; then
    SIZE="$(stat -f%z "$BIN" 2>/dev/null || echo ?)"
    echo "  安装形态:      npm 全局（${BIN}，${SIZE} 字节）"
    [ "$SIZE" -gt 100000000 ] 2>/dev/null && echo "                  ↑ native binary 形态（≥100MB，wrapper + 原生二进制）"
else
    echo "  安装形态:      非 npm 全局路径（安装器/其他），升级请用官方安装渠道"
fi

# --- 2. 最新版本（双来源：npm 为主，GitHub API 备查） --------------------
LATEST_NPM="$(npm view @anthropic-ai/claude-code version 2>/dev/null || echo ?)"
echo "  最新版本(npm): ${LATEST_NPM}"
GH_TAG="$(curl -sL --max-time 8 https://api.github.com/repos/anthropics/claude-code/releases/latest 2>/dev/null \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('tag_name','?'))" 2>/dev/null || echo '?')"
[ -n "$GH_TAG" ] && [ "$GH_TAG" != "?" ] && echo "  最新版本(GitHub): ${GH_TAG}" || echo "  最新版本(GitHub): 查询失败（网络/限流，以 npm 为准）"

# --- 3. 版本判断（巧思：主版本跨度提醒 + 是否需要升级） ------------------
UPGRADE_NEEDED=false
if [ "$CUR" != "unknown" ] && [ "$LATEST_NPM" != "?" ]; then
    MAJ_CUR="$(ver_major "$CUR")"; MAJ_LATEST="$(ver_major "$LATEST_NPM")"
    if [ "$MAJ_CUR" != "$MAJ_LATEST" ]; then
        echo "  ⚠️ 主版本跨度: ${MAJ_CUR}.x → ${MAJ_LATEST}.x —— 涉及重大变更，升级前请关注官方 breaking changes"
    fi
    if ver_gt "$LATEST_NPM" "$CUR"; then
        echo "  ⬆️ 建议: npm install -g @anthropic-ai/claude-code@${LATEST_NPM}"
        UPGRADE_NEEDED=true
    else
        echo "  ✅ CC 本体已是最新"
    fi
fi

# --- 4. 汉化状态（上次 patch 记录 vs 当前版本） ---------------------------
echo ""
echo "== 汉化状态（claude-code-zh 自管）=="
PATCHED_VER=""
[ -f "$STATUS" ] && PATCHED_VER="$(grep '^cli_version:' "$STATUS" | awk '{print $2}')"
if [ -z "$PATCHED_VER" ]; then
    echo "  尚未应用过汉化（无状态记录）→ 运行 bash scripts/apply_patch.sh"
elif [ "$PATCHED_VER" = "$CUR" ]; then
    echo "  上次汉化版本: ${PATCHED_VER} = 当前版本 ✅ 汉化与二进制一致"
else
    echo "  ⚠️ 上次汉化版本: ${PATCHED_VER} ≠ 当前 ${CUR} —— CC 升级过，需重新汉化: bash scripts/apply_patch.sh"
    UPGRADE_NEEDED=true
fi
[ -f "$STATUS" ] && grep -E 'engine:|smoke:' "$STATUS" | sed 's/^/  /'

# --- 5. 翻译表上游更新提示（claude-code-zh-cn 插件目录仍存留时） ----------
UPSTREAM="/Users/jnq/.claude/plugins/claude-code-zh-cn/cli-translations.json"
if [ -f "$UPSTREAM" ]; then
    UP_MTIME="$(stat -f%m "$UPSTREAM")"
    OUR_MTIME="$(stat -f%m "$TRANS" 2>/dev/null || echo 0)"
    if [ "$UP_MTIME" -gt "$OUR_MTIME" ]; then
        echo "  📦 翻译表上游(claude-code-zh-cn)有新版本 → 运行 python3 scripts/migrate_i18n.py 后重跑 apply_patch.sh"
    else
        echo "  翻译表: 与上游一致（迁移时间不落后）"
    fi
else
    echo "  翻译表: 上游插件文件已不在（不影响使用，migrate 可用 --source 指定路径）"
fi

# --- 6. 平台窗口记录（巧思：macOS native binary 已验证窗口） --------------
echo ""
echo "== 平台记录 =="
echo "  macOS arm64 native binary 已验证窗口: 2.1.113 – 2.1.227（本项目自验证）"
echo "  超出窗口的版本：优先跑 apply_patch.sh + check_residue.py 甄别，残留清单见 PITFALLS.md"

# --- 汇总 ---------------------------------------------------------------
echo ""
if [ "$UPGRADE_NEEDED" = true ]; then
    echo "结论: 有更新动作可做（CC 升级或重新汉化），执行顺序: 升级 CC → bash scripts/apply_patch.sh"
else
    echo "结论: 一切最新，无需动作"
fi
