#!/bin/bash

# リアルテックラジオ 配信作業のセットアップスクリプト
# Usage: ./scripts/setup.sh
#
# 配信作業に必要な道具（ffmpeg / AWS CLI / WhisperKit / jq）を揃え、
# 認証情報の設定状況を確認します。
# 何度実行しても安全です（導入済みのものはスキップします）。

set -e

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/realtech-radio/config"

# あとで対応が必要な項目をためておく
TODO_LIST=()

echo "🔧 リアルテックラジオ 配信環境のセットアップを開始します..."
echo ""

# === Step 1: Homebrew の確認 ===
echo "▶ Step 1/4: Homebrew を確認中..."
if ! command -v brew > /dev/null 2>&1; then
  echo "❌ Homebrew が見つかりません。"
  echo ""
  echo "Homebrew は Mac にソフトウェアを入れるための道具です。"
  echo "以下の公式ページの手順でインストールしてから、もう一度このスクリプトを実行してください："
  echo ""
  echo "  https://brew.sh/ja/"
  echo ""
  exit 1
fi
echo "✅ Homebrew は導入済みです"
echo ""

# === Step 2: 必要なツールの導入 ===
# $1 = コマンド名, $2 = brew のパッケージ名
install_if_missing() {
  if command -v "$1" > /dev/null 2>&1; then
    echo "✅ $1 は導入済みです"
  else
    echo "⏳ $2 をインストールします（数分かかることがあります）..."
    brew install "$2"
    echo "✅ $2 のインストールが完了しました"
  fi
}

echo "▶ Step 2/4: 必要なツールを確認中..."
install_if_missing ffmpeg ffmpeg                  # 音声変換
install_if_missing aws awscli                     # R2へのアップロード
install_if_missing whisperkit-cli whisperkit-cli  # 文字起こし
install_if_missing jq jq                          # 文字起こし結果の抽出（新しいmacOSは標準同梱）
echo ""
echo "   ※ WhisperKit は初回の文字起こし時にモデル（数GB）を自動ダウンロードします。"
echo ""

# === Step 3: 設定ファイルの確認 ===
# publish.sh と同じ基準（R2_ACCOUNT_ID が入っているか）まで確認する
echo "▶ Step 3/4: 設定ファイルを確認中..."
# shellcheck source=/dev/null
if [ -f "$CONFIG_FILE" ] && (. "$CONFIG_FILE"; [ -n "$R2_ACCOUNT_ID" ]); then
  echo "✅ 設定ファイルがあります: $CONFIG_FILE"
else
  if [ -f "$CONFIG_FILE" ]; then
    echo "⚠️  設定ファイルはありますが、中身が不足しています: $CONFIG_FILE"
    echo "   （R2_ACCOUNT_ID の行が必要です）"
  else
    echo "⚠️  設定ファイルがありません: $CONFIG_FILE"
  fi
  echo ""
  echo "   1Password の「realtech-radio 配信用」を見ながら、"
  echo "   ONBOARDING.md の手順どおりに $CONFIG_FILE を作成してください。"
  echo "   （書くのは R2_ACCOUNT_ID の1行だけです）"
  TODO_LIST+=("設定ファイルの作成（ONBOARDING.md と 1Password「realtech-radio 配信用」を参照）")
fi
echo ""

# === Step 4: AWS CLI の認証設定（r2 プロファイル）の確認 ===
echo "▶ Step 4/4: R2 の認証設定を確認中..."
if aws configure list --profile r2 > /dev/null 2>&1; then
  echo "✅ r2 プロファイルは設定済みです"
else
  echo "⚠️  r2 プロファイルが未設定です。"
  echo ""
  echo "   1Password の「realtech-radio 配信用」を見ながら、以下のコマンドを実行してください："
  echo ""
  echo "   aws configure --profile r2"
  echo ""
  echo "   聞かれる項目には次のように答えます："
  echo "   - AWS Access Key ID     → 1Password の「Access Key ID」"
  echo "   - AWS Secret Access Key → 1Password の「Secret Access Key」"
  echo "   - Default region name   → auto と入力"
  echo "   - Default output format → json と入力"
  TODO_LIST+=("aws configure --profile r2 の実行（1Password「realtech-radio 配信用」を参照）")
fi
echo ""

# === まとめ ===
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "${#TODO_LIST[@]}" -eq 0 ]; then
  echo "🎉 セットアップは完了しています！"
  echo ""
  echo "エピソードの公開は OPERATION.md の手順に沿って進めてください。"
else
  echo "🔔 あと少しです！ 以下の項目を対応してください："
  echo ""
  for item in "${TODO_LIST[@]}"; do
    echo "  - $item"
  done
  echo ""
  echo "対応が終わったら、もう一度 ./scripts/setup.sh を実行して"
  echo "すべて ✅ になることを確認してください。"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
