#!/usr/bin/env python3
"""残留检测 — patch 后核对翻译表在目标二进制中的应用程度。

输出三类：
  - 已应用：zh 已存在于二进制
  - 残留：en 仍在而 zh 不在（可能真 UI 未汉化，也可能是有意保留/非字面量位置）
  - 不存在：本版本已无此串（历史条目，翻译表可清理）

用法:
  python3 scripts/check_residue.py [--cli <二进制路径>] [--translations <表路径>] [--json]
"""
import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
DEFAULT_CLI = (
    Path.home()
    / ".local/share/fnm/node-versions"
)
# 自动探测：npm prefix 下找 claude.exe
import subprocess


def find_cli():
    try:
        prefix = subprocess.run(
            ["npm", "prefix", "-g"], capture_output=True, text=True, check=True
        ).stdout.strip()
        for tail in [
            "lib/node_modules/@anthropic-ai/claude-code/bin/claude.exe",
            "node_modules/@anthropic-ai/claude-code/bin/claude.exe",
        ]:
            p = Path(prefix) / tail
            if p.exists():
                return p
    except Exception:
        pass
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cli")
    ap.add_argument("--translations", default=str(ROOT / "i18n/translations.json"))
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    cli = Path(args.cli) if args.cli else find_cli()
    if not cli or not cli.exists():
        sys.exit(f"未找到 CLI 二进制（{cli}），用 --cli 指定")
    trans = json.load(open(args.translations, encoding="utf-8"))

    data = cli.read_bytes()
    applied, residue, absent = [], [], []
    for item in trans:
        en, zh = item["en"], item["zh"]
        has_zh = data.find(zh.encode()) != -1
        has_en = data.find(en.encode()) != -1
        if has_zh:
            applied.append(item)
        elif has_en:
            residue.append(item)
        else:
            absent.append(item)

    print(f"二进制: {cli} ({len(data):,} 字节)")
    print(f"翻译表: {len(trans)} 条 → 已应用 {len(applied)} | 残留 {len(residue)} | 不存在 {len(absent)}")

    if args.json:
        print(json.dumps({"applied": len(applied), "residue": residue, "absent": len(absent)}, ensure_ascii=False))
        return

    if residue:
        print("\n=== 残留（en 仍在、zh 不在）——甄别后决定是否补翻译表 ===")
        for item in residue:
            tag = " [skipPatch 有意保留]" if item.get("skipPatch") else ""
            print(f"  {item['en']!r} => {item['zh']!r}{tag}")
        print("\n提示: 残留多为非字面量位置（代码字典/模板拼接/字符串表）或上游有意保护；")
        print("      确认为真 UI 且可替换的，改 i18n/patches.json 覆盖后重新 apply。")
    if absent:
        print(f"\n=== 不存在 {len(absent)} 条（本版本无此串，不影响使用）===")


if __name__ == "__main__":
    main()
