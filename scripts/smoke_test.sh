#!/usr/bin/env bash
# smoke_test.sh — 汉化后功能冒烟测试
# 验证: --version 正常、--help 输出中文且可解析、基本命令不报错
# 用法: bash scripts/smoke_test.sh [<claude 可执行文件>]
set -euo pipefail
CLI="${1:-claude}"

pass=0; fail=0
check() { # check <名称> <命令...>
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ $name"; pass=$((pass+1))
    else
        echo "  ✗ $name"; fail=$((fail+1))
    fi
}

echo "冒烟测试: $CLI"
check "--version 输出" "$CLI" --version
HELP_OUT="$("$CLI" --help 2>&1 || true)"
if echo "$HELP_OUT" | grep -q "用法：claude"; then
    echo "  ✓ --help 为中文"; pass=$((pass+1))
else
    echo "  ✗ --help 非中文（未汉化或异常）"; fail=$((fail+1))
fi
if echo "$HELP_OUT" | grep -q "Usage: claude"; then
    echo "  ✗ --help 仍有英文头部"; fail=$((fail+1))
else
    echo "  ✓ --help 无英文残留"; pass=$((pass+1))
fi
check "--print 基本调用可启动" "$CLI" -p "hi" --max-turns 1
check "agents 列表命令" "$CLI" agents list

echo
echo "结果: $pass 通过 / $fail 失败"
[ "$fail" -eq 0 ] || exit 1
