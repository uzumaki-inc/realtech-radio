#!/bin/bash

# リアルテックラジオ 新エピソード公開スクリプト
# Usage: ./scripts/publish.sh <episode_number> <m4a_file_path>
# Example: ./scripts/publish.sh 0002 ~/Downloads/realtech_radio_2.m4a

set -e

# === 設定 ===
# Cloudflare R2 のアカウント ID 等はリポジトリに含めない。
# ~/.config/realtech-radio/config から読み込む（無ければエラーで停止）。
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/realtech-radio/config"
[ -f "$CONFIG" ] && . "$CONFIG"
: "${R2_ACCOUNT_ID:?$CONFIG に R2_ACCOUNT_ID を設定してください}"

BUCKET="${R2_BUCKET:-realtech-radio-audio}"
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
PUBLIC_BASE_URL="https://pub-2723121c04be418c8520405cedf4afee.r2.dev"
WHISPER_PATH="$HOME/Library/Python/3.9/bin/whisper"
PROFILE="r2"

# === 引数チェック ===
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <episode_number> <m4a_file>"
  echo "Example: $0 0002 ~/Downloads/realtech_radio_2.m4a"
  exit 1
fi

EPISODE_NUM=$1
M4A_FILE="${2/#\~/$HOME}"  # ~ を展開
MP3_FILE="${M4A_FILE%.m4a}.mp3"
EPISODE_DIR="episodes/$EPISODE_NUM"
DOWNLOAD_DIR=$(dirname "$M4A_FILE")

echo "🎙️  エピソード $EPISODE_NUM の公開処理を開始します..."
echo ""

# === Step 1: m4a → mp3 変換 ===
echo "▶ Step 1/4: mp3に変換中..."
ffmpeg -i "$M4A_FILE" -codec:a libmp3lame -qscale:a 2 "$MP3_FILE" -y
echo "✅ 変換完了: $MP3_FILE"
echo ""

# === Step 2: Whisper文字起こし ===
echo "▶ Step 2/4: Whisperで文字起こし中（数分〜十数分かかります）..."
$WHISPER_PATH "$MP3_FILE" --language ja --model medium --output_format txt --output_dir "$DOWNLOAD_DIR"
TRANSCRIPT_FILE="${MP3_FILE%.mp3}.txt"
echo "✅ 文字起こし完了: $TRANSCRIPT_FILE"
echo ""

# === Step 3: R2にアップロード ===
echo "▶ Step 3/4: R2にアップロード中..."
aws s3 cp "$MP3_FILE" \
  "s3://$BUCKET/episodes/$EPISODE_NUM.mp3" \
  --profile $PROFILE \
  --endpoint-url $R2_ENDPOINT
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
echo "1. 文字起こしを確認："
echo "   open \"$TRANSCRIPT_FILE\""
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
