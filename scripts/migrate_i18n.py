#!/usr/bin/env python3
"""迁移/更新主翻译表。

从 claude-code-zh-cn 插件的 cli-translations.json（MIT 开源）迁移翻译条目，
并合并本项目维护的补充补丁（i18n/patches.json），输出 i18n/translations.json。

用法:
  python3 scripts/migrate_i18n.py [--source <插件翻译表路径>] [--dry-run]

默认 source 指向本机安装的 claude-code-zh-cn 插件；未安装时可通过
--source 显式指定。补丁文件结构:
  [{"en": "原文", "zh": "译文", "note": "来源说明（可选）"}]
"""
import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # scripts/
PROJECT_ROOT = HERE.parent
DEFAULT_SOURCE = Path.home() / ".claude/plugins/claude-code-zh-cn/cli-translations.json"
# marketplace 缓存版路径（新版插件安装位置）
CACHE_SOURCE = (
    Path.home()
    / ".claude/plugins/cache/claude-code-zh-cn/claude-code-zh-cn"
)
OUT = PROJECT_ROOT / "i18n/translations.json"
PATCHES = PROJECT_ROOT / "i18n/patches.json"


def pick_source(cli_source):
    if cli_source:
        p = Path(cli_source)
        if p.exists():
            return p
        print(f"指定路径不存在: {p}", file=sys.stderr)
    for cand in [DEFAULT_SOURCE] + sorted(CACHE_SOURCE.glob("*/cli-translations.json")):
        if cand.exists():
            return cand
    sys.exit("未找到 claude-code-zh-cn 翻译表，请用 --source 指定路径")


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source")
    ap.add_argument("--dry-run", action="store_true", help="只统计不写文件")
    args = ap.parse_args()

    src = pick_source(args.source)
    print(f"来源: {src}")
    base = load_json(src)
    if not isinstance(base, list) or not all("en" in x and "zh" in x for x in base):
        sys.exit("翻译表格式异常：期望 [{en, zh}, ...] 列表")

    patches = load_json(PATCHES) if PATCHES.exists() else []
    print(f"插件翻译条目: {len(base)}，项目补丁: {len(patches)}")

    # 合并：补丁优先（同 en 以补丁为准）
    # 保留上游安全字段 skipPatch（model-prompt-contract = 有意不改模型提示词契约）
    merged = {
        x["en"]: {
            "en": x["en"],
            "zh": x["zh"],
            "source": "upstream",
            **({"skipPatch": x["skipPatch"]} if x.get("skipPatch") else {}),
        }
        for x in base
    }
    for p in patches:
        en = p.get("en")
        if not en:
            continue
        merged[en] = {"en": en, "zh": p["zh"], "source": p.get("note", "patch")}

    result = sorted(merged.values(), key=lambda x: (-len(x["en"]), x["en"]))
    n_zh = sum(1 for x in result if any("一" <= c <= "鿿" for c in x["zh"]))
    print(f"合并后: {len(result)} 条（含中文译文 {n_zh} 条）")

    if args.dry_run:
        print("dry-run，未写文件")
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    print(f"已写入 {OUT}")


if __name__ == "__main__":
    main()
