#!/bin/bash

# リアルテックラジオ 新エピソード公開スクリプト
# Usage: ./scripts/publish.sh <episode_number> <m4a_file> [mp4_file]
# Example: ./scripts/publish.sh 0007 ~/Downloads/realtech_radio_7.m4a ~/Downloads/realtech_radio_7.mp4
#
# 文字起こしは共有される話者分離済み VTT を使うため、このスクリプトでは行いません。
# m4a: R2 にアップロードする配信用音声。
# mp4: 任意。渡すと 10 秒ごとに静止画を切り出し、VTT とセットでまとめ生成の入力に使います。
#      切り出した画像はローカル一時フォルダに置き、まとめが終わったら削除してください
#      （次回このスクリプトを実行すると同じ番号の一時フォルダは自動で作り直します）。

set -e

# === 設定 ===
# Cloudflare R2 のアカウント ID 等はリポジトリに含めない。
# ~/.config/realtech-radio/config から読み込む（作り方は ONBOARDING.md を参照）。
# ※ PUBLIC_BASE_URL は podcast.yaml や配信済み feed.xml にも載る公開情報なので、ここに直書きする。
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/realtech-radio/config"
PUBLIC_BASE_URL="https://pub-2723121c04be418c8520405cedf4afee.r2.dev"
PROFILE="r2"
SNAPSHOT_INTERVAL=10  # 秒。mp4 から静止画を切り出す間隔

# === 引数の解析 ===
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <episode_number> <m4a_file> [mp4_file]"
  echo "Example: $0 0007 ~/Downloads/realtech_radio_7.m4a ~/Downloads/realtech_radio_7.mp4"
  exit 1
fi

EPISODE_NUM="$1"
M4A_FILE="${2/#\~/$HOME}"          # ~ を展開
MP4_FILE="${3:-}"
MP4_FILE="${MP4_FILE/#\~/$HOME}"   # ~ を展開（未指定なら空のまま）
EPISODE_DIR="episodes/$EPISODE_NUM"
DOWNLOAD_DIR=$(dirname "$M4A_FILE")
FRAMES_DIR="$DOWNLOAD_DIR/realtech-frames-$EPISODE_NUM"

# === 実行前チェック（環境がそろっているか） ===
die_setup() {
  echo "❌ $1"
  echo "   先に ./scripts/setup.sh を実行してください。"
  exit 1
}

if [ ! -f "$CONFIG" ]; then
  die_setup "設定ファイルが見つかりません: $CONFIG"
fi

# shellcheck source=/dev/null
. "$CONFIG"

if [ -z "$R2_ACCOUNT_ID" ]; then
  die_setup "設定ファイルに R2_ACCOUNT_ID が設定されていません: $CONFIG"
fi

if [ ! -f "$M4A_FILE" ]; then
  echo "❌ m4a ファイルが見つかりません: $M4A_FILE"
  exit 1
fi

BUCKET="${R2_BUCKET:-realtech-radio-audio}"
R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

command -v aws > /dev/null 2>&1 || die_setup "aws が見つかりません。"

if ! aws configure list --profile "$PROFILE" > /dev/null 2>&1; then
  die_setup "AWS CLI の $PROFILE プロファイルが未設定です。"
fi

if [ -n "$MP4_FILE" ]; then
  if [ ! -f "$MP4_FILE" ]; then
    echo "❌ mp4 ファイルが見つかりません: $MP4_FILE"
    exit 1
  fi
  command -v ffmpeg > /dev/null 2>&1 || die_setup "ffmpeg が見つかりません。"
fi

echo "🎙️  エピソード $EPISODE_NUM の公開処理を開始します..."
echo ""

# === Step 1: m4a を R2 にアップロード ===
echo "▶ Step 1/3: 音声（m4a）を R2 にアップロード中..."
aws s3 cp "$M4A_FILE" \
  "s3://$BUCKET/episodes/$EPISODE_NUM.m4a" \
  --profile "$PROFILE" \
  --endpoint-url "$R2_ENDPOINT"
echo "✅ アップロード完了"
echo ""

# === Step 2: mp4 から静止画を切り出す（任意） ===
if [ -n "$MP4_FILE" ]; then
  echo "▶ Step 2/3: mp4 から ${SNAPSHOT_INTERVAL} 秒ごとに静止画を切り出し中..."
  rm -rf "$FRAMES_DIR"          # 前回の切り出し画像が残っていれば作り直す（ノイズを溜めない）
  mkdir -p "$FRAMES_DIR"
  ffmpeg -i "$MP4_FILE" -vf "fps=1/${SNAPSHOT_INTERVAL}" -qscale:v 2 \
    "$FRAMES_DIR/frame_%04d.jpg" -y -loglevel error
  FRAME_COUNT=$(find "$FRAMES_DIR" -name 'frame_*.jpg' | wc -l | tr -d ' ')
  echo "✅ 静止画 ${FRAME_COUNT} 枚を切り出しました: $FRAMES_DIR"
  echo ""
else
  echo "▶ Step 2/3: mp4 未指定のため静止画の切り出しをスキップしました"
  echo "   （VTT だけでまとめを作る場合はこのままで問題ありません）"
  echo ""
fi

# === Step 3: episodes/{num}/ を作成 ===
echo "▶ Step 3/3: エピソードファイルを作成中..."
mkdir -p "$EPISODE_DIR"

# ファイルサイズ取得（配信する m4a のバイト数）
FILE_SIZE=$(wc -c < "$M4A_FILE" | tr -d ' ')
AUDIO_URL="$PUBLIC_BASE_URL/episodes/$EPISODE_NUM.m4a"

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

<!-- TODO: 話者分離VTT（＋静止画）をClaudeに渡して生成 -->

## 今回のポイント

<!-- TODO: 話者分離VTT（＋静止画）をClaudeに渡して生成 -->
-
-
-

## クレジット

- 工藤：株式会社UZUMAKI 代表取締役 ／ X([@ToraDady](https://x.com/ToraDady))
- <!-- TODO: 登壇者を手入力 -->

制作：[株式会社UZUMAKI](https://uzumaki-inc.jp)

## リンク

<!-- TODO: 話者分離VTT（＋静止画）をClaudeに渡して生成 -->
-
SHOWNOTES

echo "✅ ファイル作成完了"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 自動処理が完了しました！"
echo ""
echo "【次の手順】"
echo ""
echo "1. まとめ（番組概要・今回のポイント・リンク）を生成："
echo "   話者分離済みの VTT を Claude に渡す。"
if [ -n "$MP4_FILE" ]; then
  echo "   あわせて切り出した静止画（$FRAMES_DIR）も渡すと、"
  echo "   画面の情報も踏まえた精度の高いまとめになります。"
fi
echo "   → 生成結果を $EPISODE_DIR/shownotes.md に貼り付ける"
echo ""
echo "2. 手入力で記入："
echo "   - $EPISODE_DIR/meta.yaml  → title / duration / description"
echo "   - $EPISODE_DIR/shownotes.md → クレジットの登壇者（工藤以外）"
echo ""
echo "3. 編集が終わったら："
echo "   git add $EPISODE_DIR"
echo "   git commit -m \"ep$EPISODE_NUM: publish\""
echo "   git push"
echo ""
echo "→ GitHub Actionsが自動起動してfeed.xmlが更新されます"
if [ -n "$MP4_FILE" ]; then
  echo ""
  echo "4. まとめが終わったら、切り出した静止画をローカルから削除してください"
  echo "   （PCにノイズを溜めないため）："
  echo "   rm -rf \"$FRAMES_DIR\""
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
