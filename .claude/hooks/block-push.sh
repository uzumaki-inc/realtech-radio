#!/bin/bash
# push ガード hook（PreToolUse）
#
# 公開（git push・GitHub への直接書き込み）を、編集者の明示的な承認なしに
# 実行させないための強制層。CLAUDE.md のルールは助言にすぎず、権限の ask も
# 「常に許可」で無効化できるため、機械的に止めるのはこの hook だけ。
#
# 仕組み: .claude/.push-approved マーカーが存在するときだけ push を 1 回通し、
# マーカーを消費（削除）する。無ければブロックし、Claude に承認手順を伝える。

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_name",""))' 2>/dev/null)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
MARKER="$PROJECT_DIR/.claude/.push-approved"

deny() {
  echo "$1" >&2
  exit 2
}

approve_or_deny() {
  if [ -f "$MARKER" ]; then
    rm -f "$MARKER"   # 承認は 1 回の push で使い切り
    exit 0
  fi
  deny "⛔ 公開（push）は編集者の承認が必要です。編集者に内容を見せて明示的な「OK」をもらってから、touch \"$MARKER\" を実行し、そのうえで push を再実行してください。編集者の OK なしにマーカーを作ってはいけません。"
}

if [ "$TOOL" = "Bash" ]; then
  CMD=$(printf '%s' "$INPUT" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
  # git push のあらゆる表記（git -C <path> push、cd && git push 等）を検知する
  if printf '%s' "$CMD" | grep -qE '(^|[^[:alnum:]_])git([[:space:]]+(-C[[:space:]]+[^[:space:]]+|--?[^[:space:]]+))*[[:space:]]+push([[:space:]]|$)'; then
    approve_or_deny
  fi
  exit 0
fi

# Bash 以外（GitHub MCP の書き込みツール等）は matcher 経由でここに来る
approve_or_deny
