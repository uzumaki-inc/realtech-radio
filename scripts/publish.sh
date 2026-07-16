#!/bin/bash

# リアルテックラジオ 新エピソード公開スクリプト
# Usage: ./scripts/publish.sh <episode_number> <m4a_file> [mp4_file]
# Example: ./scripts/publish.sh 0007 ~/Downloads/<編集後の音声>.m4a ~/Downloads/<動画>.mp4
#
# m4a: 編集後の音声。mp3 に変換して R2 にアップロードします
#      （Podcast アプリの互換性が最も高い mp3 を配信フォーマットに揃えるため）。
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
  echo "Example: $0 0007 ~/Downloads/<編集後の音声>.m4a ~/Downloads/<動画>.mp4"
  exit 1
fi

# エピソード番号は4桁ゼロ埋めに正規化する（例: 7 → 0007）
EPISODE_NUM="$1"
if [[ "$EPISODE_NUM" =~ ^[0-9]{1,4}$ ]]; then
  EPISODE_NUM=$(printf '%04d' "$((10#$EPISODE_NUM))")
else
  echo "❌ エピソード番号は数字4桁までで指定してください（例: 0007）"
  exit 1
fi

M4A_FILE="${2/#\~/$HOME}"          # ~ を展開
MP4_FILE="${3:-}"
MP4_FILE="${MP4_FILE/#\~/$HOME}"   # ~ を展開（未指定なら空のまま）

# どこから実行しても episodes/ がリポジトリ直下にできるよう、絶対パスで扱う
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EPISODE_REL="episodes/$EPISODE_NUM"          # 表示用（読みやすい相対表記）
EPISODE_DIR="$REPO_ROOT/$EPISODE_REL"
DOWNLOAD_DIR=$(dirname "$M4A_FILE")
FRAMES_DIR="$DOWNLOAD_DIR/realtech-frames-$EPISODE_NUM"

# 配信音声の置き場所は一度だけ決める。アップロード先（R2）と meta.yaml に書く公開 URL が
# ここから両方派生するので、片方だけズレて feed.xml が 404 を指す事故が起きない
AUDIO_KEY="episodes/$EPISODE_NUM.mp3"
AUDIO_URL="$PUBLIC_BASE_URL/$AUDIO_KEY"

# 変換した mp3 はアップロードすれば用済みなので、一時フォルダに作って終了時に消す
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
MP3_FILE="$TMP_DIR/$EPISODE_NUM.mp3"

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

# プロファイルの存在だけでなく、Access Key が実際に登録されているかまで確認する
if [ -z "$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null)" ]; then
  die_setup "AWS CLI の $PROFILE プロファイルが未設定です。"
fi

# ffmpeg（mp3 への変換・静止画切り出し）と同梱の ffprobe（再生時間の自動計算）は常に必要
if ! command -v ffmpeg > /dev/null 2>&1 || ! command -v ffprobe > /dev/null 2>&1; then
  die_setup "ffmpeg が見つかりません。"
fi

if [ -n "$MP4_FILE" ] && [ ! -f "$MP4_FILE" ]; then
  echo "❌ mp4 ファイルが見つかりません: $MP4_FILE"
  exit 1
fi

echo "🎙️  エピソード $EPISODE_NUM の公開処理を開始します..."
echo ""

# === Step 1: m4a を mp3 に変換して R2 にアップロード ===
echo "▶ Step 1/3: 音声を mp3 に変換して R2 にアップロード中..."
ffmpeg -i "$M4A_FILE" -c:a libmp3lame -q:a 2 "$MP3_FILE" -y -loglevel error
aws s3 cp "$MP3_FILE" \
  "s3://$BUCKET/$AUDIO_KEY" \
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

# ファイルサイズ取得（配信する mp3 のバイト数。RSS の enclosure length になる）
FILE_SIZE=$(wc -c < "$MP3_FILE" | tr -d ' ')

# 再生時間（duration）を元音源から自動計算する（ffprobe は ffmpeg に同梱）
DURATION="00:00:00"
DURATION_SECS=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$M4A_FILE" 2>/dev/null | cut -d. -f1)
if [[ "$DURATION_SECS" =~ ^[0-9]+$ ]]; then
  DURATION=$(printf '%02d:%02d:%02d' \
    $((DURATION_SECS / 3600)) $((DURATION_SECS % 3600 / 60)) $((DURATION_SECS % 60)))
else
  echo "⚠️  再生時間を自動計算できませんでした。meta.yaml の duration を手入力してください"
fi

# meta.yaml 作成。既にある場合は、人が記入する欄（title / description など）を守りつつ、
# 音声の差し替えに備えて機械が計算する欄だけ今回の音声に合わせて更新する
if [ -f "$EPISODE_DIR/meta.yaml" ]; then
  sed -i '' \
    -e "s|^duration: .*|duration: \"$DURATION\"|" \
    -e "s|^audio_url: .*|audio_url: \"$AUDIO_URL\"|" \
    -e "s|^file_size: .*|file_size: $FILE_SIZE|" \
    "$EPISODE_DIR/meta.yaml"
  echo "⚠️  meta.yaml は既にあるため、記入済みの内容（title / description など）は保持しました"
  echo "   （duration / audio_url / file_size は今回の音声に合わせて更新済み）"
else
  cat > "$EPISODE_DIR/meta.yaml" << EOF
title: ""
date: $(date +%Y-%m-%d)
duration: "$DURATION"
audio_url: "$AUDIO_URL"
file_size: $FILE_SIZE
description: ""
explicit: false
EOF
fi

# shownotes.md テンプレート作成（丸ごと人が記入するファイルなので、既にあれば上書きしない）
if [ -f "$EPISODE_DIR/shownotes.md" ]; then
  echo "⚠️  shownotes.md は既にあるため上書きしません（記入済みの内容を守るため）"
else
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
fi

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
echo "   → 生成結果を $EPISODE_REL/shownotes.md に貼り付ける"
echo ""
echo "2. 仕上げと公開は Claude Code に自然言語で頼めばOKです。たとえば："
echo ""
echo "   「ep$EPISODE_NUM を公開したい。タイトルは「〇〇」、登壇者は〇〇。"
echo "     meta.yaml と shownotes を仕上げて、コミットして push して」"
echo ""
echo "   （足りない情報は Claude Code のほうから聞いてくれます）"
echo ""
echo "→ push されると GitHub Actions が自動起動して feed.xml が更新されます"
if [ -n "$MP4_FILE" ]; then
  echo ""
  echo "3. まとめが終わったら、切り出した静止画をローカルから削除してください"
  echo "   （PCにノイズを溜めないため）："
  echo "   rm -rf \"$FRAMES_DIR\""
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
