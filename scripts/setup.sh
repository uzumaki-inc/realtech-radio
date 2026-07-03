#!/bin/bash

# リアルテックラジオ 配信作業のセットアップスクリプト
# Usage: ./scripts/setup.sh
#
# 配信作業に必要な道具（ffmpeg / AWS CLI / GitHub CLI）を揃え、
# 認証情報の設定状況と R2 への接続まで確認します。
# 何度実行しても安全です（導入済みのものはスキップします）。

set -e

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/realtech-radio/config"
PROFILE="r2"   # publish.sh と同じ AWS CLI プロファイル名

# あとで対応が必要な項目をためておく
TODO_LIST=()

echo "🔧 リアルテックラジオ 配信環境のセットアップを開始します..."
echo ""

# === Step 1: Homebrew の確認 ===
echo "▶ Step 1/6: Homebrew を確認中..."
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

echo "▶ Step 2/6: 必要なツールを確認中..."
install_if_missing ffmpeg ffmpeg  # mp4からの静止画切り出し・再生時間の自動計算
install_if_missing aws awscli     # R2へのアップロード
install_if_missing gh gh          # GitHub の認証（公開時の git push 用）
echo ""

# === Step 3: 設定ファイルの確認 ===
# publish.sh と同じ基準（R2_ACCOUNT_ID が入っているか）まで確認する
echo "▶ Step 3/6: 設定ファイルを確認中..."
CONFIG_OK=0
# shellcheck source=/dev/null
if [ -f "$CONFIG_FILE" ] && (. "$CONFIG_FILE"; [ -n "$R2_ACCOUNT_ID" ]); then
  echo "✅ 設定ファイルがあります: $CONFIG_FILE"
  CONFIG_OK=1
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
echo "▶ Step 4/6: R2 の認証設定を確認中..."
PROFILE_OK=0
# プロファイルの存在だけでなく、Access Key が実際に登録されているかまで確認する
# （publish.sh の実行前チェックと同じ基準。変えるときは両方揃えること）
if [ -n "$(aws configure get aws_access_key_id --profile "$PROFILE" 2>/dev/null)" ]; then
  echo "✅ r2 プロファイルは設定済みです"
  PROFILE_OK=1
else
  echo "⚠️  r2 プロファイルが未設定です。"
  echo ""
  echo "   1Password の「realtech-radio 配信用」を見ながら、次の3行の"
  echo "   （1Passwordの値）を実際の値に置き換えて、まとめて貼り付けてください："
  echo ""
  echo "   aws configure set aws_access_key_id \"（1Passwordの値）\" --profile r2"
  echo "   aws configure set aws_secret_access_key \"（1Passwordの値）\" --profile r2"
  echo "   aws configure set region auto --profile r2"
  echo ""
  echo "   詳しい手順は ONBOARDING.md の「4. 認証情報を設定する」を参照。"
  TODO_LIST+=("r2 プロファイルの設定（ONBOARDING.md と 1Password「realtech-radio 配信用」を参照）")
fi
echo ""

# === Step 5: GitHub の認証（git push 用）の確認 ===
echo "▶ Step 5/6: GitHub の認証を確認中..."
if gh auth status > /dev/null 2>&1; then
  echo "✅ GitHub にログイン済みです"
else
  echo "⚠️  GitHub に未ログインです。"
  echo ""
  echo "   次の1行を実行して、ブラウザでログインしてください（自分の GitHub アカウントを使用）："
  echo ""
  echo "   gh auth login"
  echo ""
  echo "   質問には「GitHub.com」→「HTTPS」→「Login with a web browser」の順に答えます。"
  TODO_LIST+=("GitHub へのログイン（gh auth login を実行してブラウザで承認）")
fi
echo ""

# === Step 6: R2 への接続確認 ===
# 設定ファイルと r2 プロファイルが揃っているときだけ、実際につながるかを確認する
echo "▶ Step 6/6: R2 への接続を確認中..."
if [ "$CONFIG_OK" = "1" ] && [ "$PROFILE_OK" = "1" ]; then
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
  # publish.sh と同じ形で接続先を組み立てる（バケット標準値・エンドポイント形式を揃える）
  BUCKET="${R2_BUCKET:-realtech-radio-audio}"
  R2_ENDPOINT="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
  if aws s3 ls "s3://$BUCKET/episodes/" \
       --profile "$PROFILE" \
       --endpoint-url "$R2_ENDPOINT" > /dev/null 2>&1; then
    echo "✅ R2 に接続できました（アップロードの準備OK）"
  else
    echo "⚠️  R2 に接続できませんでした。"
    echo "   設定した値（Account ID / Access Key / Secret）を 1Password と見比べて見直してください。"
    TODO_LIST+=("R2 接続の見直し（設定値を 1Password「realtech-radio 配信用」と見比べる）")
  fi
else
  echo "⏭️  設定が未完了のためスキップしました（上の ⚠️ を先に対応してください）"
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
