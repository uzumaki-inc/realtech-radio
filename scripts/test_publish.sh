#!/bin/bash
# publish.sh のスモークテスト（回帰検知用・編集者は使わない）
#
# R2 や実 ffmpeg には触れず、aws / ffmpeg / ffprobe をスタブに差し替えて
# 引数検証・--no-video 分岐・雛形生成・meta.yaml 保持だけを検証する。
# Usage: ./scripts/test_publish.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_EP="9999"
EP_DIR="$REPO_ROOT/episodes/$TEST_EP"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP" "$EP_DIR"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
ng()   { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
check() { if eval "$2"; then ok "$1"; else ng "$1"; fi; }

# --- スタブ環境の構築 ---
mkdir -p "$TMP/bin" "$TMP/config/realtech-radio"
export XDG_CONFIG_HOME="$TMP/config"
echo 'R2_ACCOUNT_ID=dummy' > "$TMP/config/realtech-radio/config"

cat > "$TMP/bin/aws" <<'EOF'
#!/bin/bash
[ "$1" = "configure" ] && { echo "dummy-key"; exit 0; }
exit 0
EOF
cat > "$TMP/bin/ffmpeg" <<'EOF'
#!/bin/bash
# 出力ファイル（.mp3）だけ作る
for a in "$@"; do case "$a" in *.mp3) : > "$a";; esac; done
exit 0
EOF
cat > "$TMP/bin/ffprobe" <<'EOF'
#!/bin/bash
echo "125.5"
EOF
chmod +x "$TMP/bin/"*
export PATH="$TMP/bin:$PATH"

M4A="$TMP/dummy.m4a"; : > "$M4A"

echo "▶ 1. 引数検証"
OUT=$("$REPO_ROOT/scripts/publish.sh" "$TEST_EP" "$M4A" 2>&1); RC=$?
check "第3引数なしはエラー終了する" '[ "$RC" -ne 0 ]'
check "エラーに --no-video の案内がある" 'printf "%s" "$OUT" | grep -q -- --no-video'
OUT=$("$REPO_ROOT/scripts/publish.sh" abc "$M4A" --no-video 2>&1); RC=$?
check "不正なエピソード番号はエラー終了する" '[ "$RC" -ne 0 ]'
OUT=$("$REPO_ROOT/scripts/publish.sh" "$TEST_EP" "$M4A" "$TMP/nonexistent.mp4" 2>&1); RC=$?
check "存在しない mp4 パスはエラー終了する" '[ "$RC" -ne 0 ]'

echo "▶ 2. --no-video での雛形生成"
OUT=$("$REPO_ROOT/scripts/publish.sh" "$TEST_EP" "$M4A" --no-video 2>&1); RC=$?
check "--no-video で正常終了する" '[ "$RC" -eq 0 ]'
check "静止画スキップの表示が出る" 'printf "%s" "$OUT" | grep -q "スキップ"'
check "meta.yaml が生成される" '[ -f "$EP_DIR/meta.yaml" ]'
check "duration が計算される（125s → 00:02:05）" 'grep -q "duration: \"00:02:05\"" "$EP_DIR/meta.yaml"'
check "shownotes.md が生成される" '[ -f "$EP_DIR/shownotes.md" ]'
check "shownotes にエピソード概要の節がある" 'grep -qF "## 💡 エピソード概要" "$EP_DIR/shownotes.md"'
check "shownotes にリンクの節がある" 'grep -qF "## 🔗 リンク" "$EP_DIR/shownotes.md"'
check "shownotes にクレジットの節がある" 'grep -qF "## 🎙 クレジット" "$EP_DIR/shownotes.md"'
check "shownotes に番組概要の節がある" 'grep -qF "## 📻 番組概要" "$EP_DIR/shownotes.md"'
DESC=$(sed -n 's/^description: "\(.*\)"$/\1/p' "$REPO_ROOT/podcast.yaml")
if grep -qF "$DESC" "$EP_DIR/shownotes.md"; then ok "番組概要が podcast.yaml と一致する"; else ng "番組概要が podcast.yaml と一致する"; fi

echo "▶ 3. 既存 meta.yaml の保持（回帰）"
sed -i '' 's/^title: ""/title: "テストタイトル"/' "$EP_DIR/meta.yaml"
"$REPO_ROOT/scripts/publish.sh" "$TEST_EP" "$M4A" --no-video > /dev/null 2>&1
check "再実行で title が保持される" 'grep -q "テストタイトル" "$EP_DIR/meta.yaml"'
check "再実行で shownotes が上書きされない" 'grep -q "TODO" "$EP_DIR/shownotes.md"'

echo ""
echo "結果: $PASS passed / $FAIL failed"
[ "$FAIL" -eq 0 ]
