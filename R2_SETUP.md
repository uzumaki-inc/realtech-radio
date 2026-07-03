# Cloudflare R2 セットアップガイド

このドキュメントでは、Cloudflare R2にリアルテックラジオの音声ファイルをホストするための設定手順を説明します。

## Cloudflareアカウントについて

Cloudflareアカウントがない場合は、https://dash.cloudflare.com/ で作成してください（無料プランで十分です）。

## Cloudflareダッシュボードへのアクセス

1. **ダッシュボードにログイン**
   - https://dash.cloudflare.com/ にアクセス
   - メールアドレスとパスワードで ログイン

2. **R2へのナビゲーション**
   - ログイン後、左メニューの「Storage & databases」を展開
   - 「R2 object storage」をクリック

3. **初回アクセスの場合**
   - セットアップウィザードが表示される場合がある
   - 不要なら「Skip」をクリック
   - 左メニューから「Overview」をクリック
   - R2のダッシュボードに進む

## R2バケットの作成

1. **R2 ダッシュボードに進む**
   - 左メニューの「R2 object storage」を展開
   - 「Overview」をクリック

2. **バケットを作成**
   - 「Create bucket」ボタンをクリック
   - バケット名を入力（例：`realtech-radio-audio`）
   - リージョンは「自動（APAC）」でOK
   - 「Create bucket」をクリック

4. **バケット内のフォルダ構成**
   ```
   realtech-radio-audio/
   └── episodes/
       ├── 001.mp3
       ├── 002.mp3
       └── ...
   ```

## R2のパブリックアクセス設定

デフォルトではR2は非公開なので、リスナーが音声を再生できるように設定します。

1. **バケット設定を開く**
   - 作成したバケット（`realtech-radio-audio`）をクリック
   - 「Settings」タブをクリック

2. **パブリックアクセスを有効化**
   - 「Public Development URL」セクションの右にある「Enable」をクリック
   - 確認ダイアログが表示される
   - テキストフィールドに `allow` と入力
   - 「Allow」ボタンをクリック
   - 有効化されると、`*.r2.dev` 形式のパブリックURLが表示される
   - ※ このURLはレート制限あり。リスナーが増えたら「Custom Domains」に移行推奨

3. **CORS設定（必須）**
   - 「CORS Policy」セクションの「+ Add」をクリック
   - JSONエディタが開くので、以下の内容に書き換える：
     ```json
     [
       {
         "AllowedOrigins": ["*"],
         "AllowedMethods": ["GET", "HEAD"],
         "AllowedHeaders": ["*"]
       }
     ]
     ```
   - 保存する

## アップロード用の認証情報を取得

音声ファイルをアップロードするには、R2 API トークンが必要です。

1. **API トークンを作成**
   - Cloudflareダッシュボード → アカウント設定
   - 左メニューから「API Tokens」を選択
   - 「Create Token」をクリック

2. **トークンの権限を設定**
   - テンプレート: 「Edit Cloudflare Workers」を選択（カスタム可）
   - または、以下の権限で新規作成：
     - Account > R2 > All buckets > All operations
   - 「Continue to summary」をクリック

3. **トークンを保存**
   - 生成されたトークンをコピー
   - 安全に保管（GitHub Secrets に登録する場合もある）

## R2 API用の認証情報

アップロード用に以下も取得します。

1. **Account ID を確認**
   - ダッシュボード右上のプロフィール → Account details
   - Account ID をコピー

2. **Access Key ID と Secret Access Key を生成**
   - R2 → Settings → API tokens
   - 「Create API token」をクリック
   - トークン種別: 「S3 Compatible」を選択
   - 権限: R2 Object Read & Write を選択
   - 「Create API token」をクリック
   - Access Key ID と Secret Access Key を保存

## 編集者共有用トークンの発行と受け渡し（管理者向け）

エピソード公開作業を編集者に共有する場合の手順です。

### 専用トークンを発行する

**既存のキー（`realtech-radio-upload` など自分用のトークン）は使い回さず、共有用に専用のトークンを発行します。**
共有用トークンの更新・失効を、自分用のキーに影響を与えずに行えるようにするためです。

作成手順は上の「[R2 API用の認証情報](#r2-api用の認証情報)」と同じ（トークン種別: S3 Compatible、権限: **Object Read & Write**）。以下の 2 点だけ変えます：

- Token name: `realtech-radio-backoffice`（用途が分かる名前にする）
- Specify bucket: **`realtech-radio-audio` のみ**に限定（「Apply to all buckets」にしない）

表示された **Access Key ID / Secret Access Key** をメモします（この画面を離れると再表示不可）。

### 1Password に登録する

発行したキーは、共有 Vault に以下の内容で登録します：

- **アイテム名**: `realtech-radio 配信用`
- **登録する 3 点**: R2 Account ID ／ Access Key ID ／ Secret Access Key
  - バケット名（`realtech-radio-audio`）は 1Password には入れない（publish.sh に標準値があるため不要）
- **メモ欄に「コピペ一発で設定できる手順」を実際の値を埋めて書く**（編集者は ONBOARDING.md の手順 4 で、このメモをそのまま貼り付けて設定します）:

  ```bash
  # ① 設定ファイル（R2 Account ID を実値に）
  mkdir -p ~/.config/realtech-radio
  echo 'R2_ACCOUNT_ID="＜実際のR2 Account ID＞"' > ~/.config/realtech-radio/config
  chmod 600 ~/.config/realtech-radio/config

  # ② アップロード認証（Access Key ID / Secret を実値に）
  aws configure set aws_access_key_id "＜実際のAccess Key ID＞" --profile r2
  aws configure set aws_secret_access_key "＜実際のSecret Access Key＞" --profile r2
  aws configure set region auto --profile r2
  ```

  - あわせて「用途: `publish.sh` での音声アップロード用」「詳しい流れ: ONBOARDING.md」も書いておく

メンバーには Vault 共有で渡し、Slack やメールでは送らない運用とします。

### メンバーが離れるとき

トークンは共有制のため、**失効だけでなく更新（ローテーション）までがセット**です。失効したまま放置すると、残りのメンバー全員の publish.sh が動かなくなります。

1. 1Password の Vault 共有を解除する
2. 共有トークンをローテーションする：
   - Cloudflare → R2 → API Tokens → `realtech-radio-backoffice` を「Roll」（または Delete して再発行）
   - 新しい Access Key ID / Secret Access Key を 1Password のアイテムに上書き登録する
   - 残りのメンバーに `aws configure --profile r2` の再実行を依頼する（設定ファイルの変更は不要）

## 音声ファイルのアップロード方法

### 方法1: Cloudflare ダッシュボード（手動）

1. バケット（`realtech-radio-audio`）をクリック
2. 「Upload」をクリック
3. ファイルを選択してアップロード

### 方法2: AWS CLI（推奨・自動化向け）

> 💡 ツールの導入とプロファイル設定は `./scripts/setup.sh` でまとめて行えます。

AWS CLI をインストール後：

```bash
# AWS 認証情報を設定
aws configure --profile r2
# Access Key ID と Secret Access Key を入力

# ファイルをアップロード
aws s3 cp episodes/001.mp3 \
  s3://realtech-radio-audio/episodes/001.mp3 \
  --profile r2 \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

### 方法3: AWS SDK（Python）

```python
import boto3

# R2 クライアントを初期化
s3 = boto3.client(
    's3',
    endpoint_url='https://<ACCOUNT_ID>.r2.cloudflarestorage.com',
    aws_access_key_id='<ACCESS_KEY_ID>',
    aws_secret_access_key='<SECRET_ACCESS_KEY>'
)

# ファイルをアップロード
with open('episodes/001.mp3', 'rb') as f:
    s3.upload_fileobj(f, 'realtech-radio-audio', 'episodes/001.mp3')

# ファイルサイズを取得
response = s3.head_object(Bucket='realtech-radio-audio', Key='episodes/001.mp3')
file_size = response['ContentLength']
print(f"Uploaded: {file_size} bytes")
```

## パブリックURLの確認

アップロードされたファイルには、以下の形式でアクセスできます。

```
https://<ACCOUNT_ID>.r2.cloudflarestorage.com/episodes/001.mp3
```

または、カスタムドメインを設定している場合：

```
https://media.uzumaki-inc.jp/episodes/001.mp3
```

**このURLを `episodes/*/meta.yaml` の `audio_url` に記載します。**

例：

```yaml
title: "声でPC操作！でも落とし穴は？音声認識サービスの裏側"
date: 2026-03-07
duration: "00:30:00"
audio_url: "https://<ACCOUNT_ID>.r2.cloudflarestorage.com/episodes/001.mp3"
file_size: 38654321
description: "音声認識でPCを操作するサービスの裏側を、エンジニアの視点から深掘りします。"
```

## ファイルサイズの確認方法

meta.yaml に `file_size` を記載する必要があります。以下で確認できます。

**Cloudflare ダッシュボード**

- バケット → Files
- ファイルをクリック → Size を確認

**コマンドライン**

```bash
# ローカルファイルのサイズ
ls -lh episodes/001.mp3
# または
stat episodes/001.mp3

# R2 にアップロードされたファイルのサイズ（AWS CLI）
aws s3api head-object \
  --bucket realtech-radio-audio \
  --key episodes/001.mp3 \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com | jq '.ContentLength'
```

## カスタムドメインの設定（オプション・後で可能）

将来的に `media.uzumaki-inc.jp` 経由でアクセスしたい場合：

1. R2 バケット → Settings
2. Custom Domains → Add domain
3. `media.uzumaki-inc.jp` を入力
4. Squaspace で DNS CNAME を設定
   - `media` → `<ACCOUNT_ID>.r2.cloudflarestorage.com`

ただし、これは必須ではなく、Cloudflare のデフォルト URL でも問題ありません。

## まとめ

Step 4 で完了する設定：
1. ✅ R2 バケット作成（`realtech-radio-audio`）
2. ✅ Public Access 有効化
3. ✅ CORS 設定

初回アップロード時（Step 7）に対応する設定：
4. API トークン取得（ダッシュボードから手動アップロードする場合は不要）
5. ✅ 音声ファイルをアップロード
6. ✅ `meta.yaml` に `audio_url` を記載

これで `generate_feed.py` が RSS フィードを生成する際に、正しい URL が含まれます。
