#!/bin/bash

# リアルテックラジオ 新エピソード公開スクリプト
# Usage: ./scripts/publish.sh [--skip-transcribe] <episode_number> <m4a_file_path>
# Example: ./scripts/publish.sh 0002 ~/Downloads/realtech_radio_2.m4a
#
# --skip-transcribe: WhisperKitによる文字起こしをスキップする（未導入マシン・急ぎの場合向け）

set -e

# === 設定 ===
# Cloudflare R2 のアカウント ID 等はリポジトリに含めない。
# ~/.config/realtech-radio/config から読み込む（作り方は ONBOARDING.md を参照）。
# ※ PUBLIC_BASE_URL は podcast.yaml や配信済み feed.xml にも載る公開情報なので、ここに直書きする。
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/realtech-radio/config"
PUBLIC_BASE_URL="https://pub-2723121c04be418c8520405cedf4afee.r2.dev"
WHISPER_MODEL="large-v3"
PROFILE="r2"

# === オプション・引数の解析 ===
SKIP_TRANSCRIBE=false
ARGS=()

for arg in "$@"; do
  case "$arg" in
    --skip-transcribe)
      SKIP_TRANSCRIBE=true
      ;;
    *)
      ARGS+=("$arg")
      ;;
  esac
done

if [ "${#ARGS[@]}" -ne 2 ]; then
  echo "Usage: $0 [--skip-transcribe] <episode_number> <m4a_file>"
  echo "Example: $0 0002 ~/Downloads/realtech_radio_2.m4a"
  exit 1
fi

EPISODE_NUM="${ARGS[0]}"
M4A_FILE="${ARGS[1]/#\~/$HOME}"  # ~ を展開
MP3_FILE="${M4A_FILE%.m4a}.mp3"
EPISODE_DIR="episodes/$EPISODE_NUM"
DOWNLOAD_DIR=$(dirname "$M4A_FILE")

# === 実行前チェック（環境がそろっているか） ===
die_setup() {
  echo "❌ $1"
  echo "   先に ./scripts/setup.sh を実行してください。"
  exit 1
}

check_command() {
  command -v "$1" > /dev/null 2>&1 || die_setup "$1 が見つかりません。"
}

if [ ! -f "$CONFIG" ]; then
  die_setup "設定ファイルが見つかりません: $CONFIG"
fi

# shellcheck source=/dev/null
. "$CONFIG"

if [ -z "$R2_ACCOUNT_ID" ]; then
  die_setup "設定ファイルに R2_ACCOUNT_ID が設定されていません: $CONFIG"
fi

BUCKET="${R2_BUCKET:-realtech-radio-audio}"
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

check_command ffmpeg
check_command aws

if ! aws configure list --profile $PROFILE > /dev/null 2>&1; then
  die_setup "AWS CLI の $PROFILE プロファイルが未設定です。"
fi

if [ "$SKIP_TRANSCRIBE" = false ]; then
  if ! command -v whisperkit-cli > /dev/null 2>&1; then
    echo "❌ whisperkit-cli が見つかりません。"
    echo "   ./scripts/setup.sh を実行して導入するか、"
    echo "   --skip-transcribe を付けて文字起こしを飛ばすこともできます（別マシン・別ツールで文字起こしする場合）。"
    exit 1
  fi
  check_command jq
fi

echo "🎙️  エピソード $EPISODE_NUM の公開処理を開始します..."
echo ""

# === Step 1: m4a → mp3 変換 ===
echo "▶ Step 1/4: mp3に変換中..."
ffmpeg -i "$M4A_FILE" -codec:a libmp3lame -qscale:a 2 "$MP3_FILE" -y
echo "✅ 変換完了: $MP3_FILE"
echo ""

# === Step 2: WhisperKit文字起こし ===
TRANSCRIPT_FILE="${MP3_FILE%.mp3}.txt"
if [ "$SKIP_TRANSCRIBE" = true ]; then
  echo "▶ Step 2/4: 文字起こしをスキップしました（--skip-transcribe）"
  echo ""
else
  echo "▶ Step 2/4: WhisperKit（$WHISPER_MODEL）で文字起こし中（初回はモデルDLで時間がかかります）..."
  whisperkit-cli transcribe \
    --audio-path "$MP3_FILE" \
    --model "$WHISPER_MODEL" \
    --language ja \
    --report \
    --report-path "$DOWNLOAD_DIR"
  JSON_FILE="${MP3_FILE%.mp3}.json"
  jq -r '.text' "$JSON_FILE" > "$TRANSCRIPT_FILE"
  echo "✅ 文字起こし完了: $TRANSCRIPT_FILE"
  echo ""
fi

# === Step 3: R2にアップロード ===
echo "▶ Step 3/4: R2にアップロード中..."
aws s3 cp "$MP3_FILE" \
  "s3://$BUCKET/episodes/$EPISODE_NUM.mp3" \
  --profile $PROFILE \
  --endpoint-url "$R2_ENDPOINT"
echo "✅ アップロード完了"
echo ""

# === Step 4: episodes/{num}/ を作成 ===
echo "▶ Step 4/4: エピソードファイルを作成中..."
mkdir -p "$EPISODE_DIR"

# ファイルサイズ取得
FILE_SIZE=$(wc -c < "$MP3_FILE" | tr -d ' ')
AUDIO_URL="$PUBLIC_BASE_URL/episodes/$EPISODE_NUM.mp3"

# meta.yaml テンプレート作成
cat > "$EPISODE_DIR/meta.yaml" << EOF
title: ""
date: $(date +%Y-%m-%d)
duration: "00:00:00"
audio_url: "$AUDIO_URL"
file_size: $FILE_SIZE
description: ""
explicit: false
EOF

# shownotes.md テンプレート作成
cat > "$EPISODE_DIR/shownotes.md" << 'SHOWNOTES'
## 番組概要

<!-- TODO: 文字起こしをClaudeに貼り付けて生成 -->

## 今回のポイント

<!-- TODO: 文字起こしをClaudeに貼り付けて生成 -->
-
-
-

## クレジット

- 工藤：株式会社UZUMAKI 代表取締役 ／ X([@ToraDady](https://x.com/ToraDady))
- <!-- TODO: 登壇者を手入力 -->

制作：[株式会社UZUMAKI](https://uzumaki-inc.jp)

## リンク

<!-- TODO: 文字起こしをClaudeに貼り付けて生成 -->
-
SHOWNOTES

echo "✅ ファイル作成完了"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 自動処理が完了しました！"
echo ""
echo "【次の手順】"
echo ""
if [ "$SKIP_TRANSCRIBE" = true ]; then
  echo "1. 文字起こしを別途行う（このマシンではスキップしました）："
  echo "   WhisperKitが使えるマシンで文字起こしするか、"
  echo "   他の文字起こしツールで $MP3_FILE を文字起こしする"
else
  echo "1. 文字起こしを確認："
  echo "   open \"$TRANSCRIPT_FILE\""
fi
echo ""
echo "2. 文字起こしをClaudeに貼り付けて以下を生成："
echo "   - 番組概要"
echo "   - 今回のポイント"
echo "   - リンク"
echo "   → $EPISODE_DIR/shownotes.md に貼り付ける"
echo ""
echo "3. 手入力で記入："
echo "   - $EPISODE_DIR/meta.yaml  → title / duration / description"
echo "   - $EPISODE_DIR/shownotes.md → クレジットの登壇者（工藤以外）"
echo ""
echo "4. 編集が終わったら："
echo "   git add $EPISODE_DIR"
echo "   git commit -m \"ep$EPISODE_NUM: publish\""
echo "   git push"
echo ""
echo "→ GitHub Actionsが自動起動してfeed.xmlが更新されます"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
