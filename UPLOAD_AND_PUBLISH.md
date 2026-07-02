# Step 7 → Step 6: 音声アップロード〜プラットフォーム登録

## 現在地

| ステップ | 状態 |
|---|---|
| RSS生成スクリプト | ✅ 完成 |
| GitHub Actions | ✅ 動作確認済み |
| podcast.uzumaki-inc.jp | ✅ 公開済み |
| 音声ファイルのR2アップロード | ⬜ 未 |
| Spotify登録 | ⬜ 未 |
| Apple Podcasts登録 | ⬜ 未 |

---

## Step 7: 第1回エピソードをR2にアップロードする

### 1. Cloudflare Account IDを確認する

- https://dash.cloudflare.com/ にログイン
- 左メニュー「Storage & databases」→「R2 object storage」→「Overview」
- 画面下の「Account Details」セクションに **Account ID** が表示される（32文字の英数字）

### 2. R2 APIトークンを取得する（S3互換）

1. 同じ「Overview」画面下の「Account Details」セクションを確認
2. 「API Tokens」の右にある **「Manage」** をクリック
3. 「Create API Token」をクリック
4. 設定：
   - Token name: `realtech-radio-upload`
   - Permissions: **Object Read & Write**
   - Bucket: `realtech-radio-audio`（特定バケットのみに絞る）
5. 「Create API Token」をクリック
6. 表示される以下を必ずメモ（この画面を離れると再表示不可）：
   - **Access Key ID**
   - **Secret Access Key**
   - Endpoint URLは表示されるが、Account IDから組み立て可能なのでコピー不要
     （`https://<ACCOUNT_ID>.r2.cloudflarestorage.com`）

### 3. 音声ファイルをアップロードする

> 💡 ツールの導入（awscli 等）とプロファイル設定は `./scripts/setup.sh` でまとめて行えます。

```bash
# AWS CLIを使う（未インストールなら brew install awscli）
brew install awscli

# R2用のプロファイルを設定
aws configure --profile r2
# → Access Key ID: 上でコピーしたもの
# → Secret Access Key: 上でコピーしたもの
# → Default region: auto
# → Output format: json

# アップロード
aws s3 cp ~/Downloads/realtech_radio_1_20260218.mp3 \
  s3://realtech-radio-audio/episodes/001.mp3 \
  --profile r2 \
  --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
```

### 4. ファイルサイズを確認する（バイト数）

```bash
wc -c ~/Downloads/realtech_radio_1_20260218.mp3
```

表示された数字を `episodes/001/meta.yaml` の `file_size` に記入。

### 5. meta.yaml を更新してpushする

`episodes/001/meta.yaml` の以下を実際の値に書き換える：

```yaml
# audio_url は S3 API用URL（*.r2.cloudflarestorage.com）ではなく、公開URL（*.r2.dev）を使う
audio_url: "https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/001.mp3"
file_size: <バイト数>  # wc -c で確認した値
```

> **注意**: `*.r2.cloudflarestorage.com` はS3 API用（認証必須）。リスナー向けの公開URLは
> バケットの Settings → Public access に表示される `pub-xxxxx.r2.dev` 形式を使う。

書き換えたら：
```bash
git add episodes/001/meta.yaml
git commit -m "ep001: add audio URL and file size"
git push
```

→ GitHub Actionsが自動起動して `feed.xml` が更新される

### 6. RSSフィードを確認する

ブラウザで以下にアクセス：
```
https://podcast.uzumaki-inc.jp/feed.xml
```

XMLが表示されて `<enclosure url="https://...001.mp3"` があればOK。

---

## Step 6: SpotifyとApple PodcastsにRSSを登録する

### Spotify for Podcasters

1. https://podcasters.spotify.com/ にアクセス
2. 「Get Started」→ Spotifyアカウントでログイン
3. 「Add your podcast」→「I have an RSS feed」を選択
4. RSS URL: `https://podcast.uzumaki-inc.jp/feed.xml` を入力
5. 認証コードがRSSフィードのメールアドレス（kudo@uzumaki-inc.jp）に届く
6. コードを入力して登録完了

### Apple Podcasts Connect

1. https://podcastsconnect.apple.com/ にアクセス
2. Apple IDでログイン
3. 「+」ボタン → RSS URLを入力
4. `https://podcast.uzumaki-inc.jp/feed.xml` を入力
5. 審査（通常1〜2日）後に公開される

---

## 事前チェックリスト

Step 6（登録）の前に以下が揃っていること：

- [ ] `https://podcast.uzumaki-inc.jp/feed.xml` にアクセスできる
- [ ] feed.xml の `<itunes:image>` に有効なURL（アートワーク）が含まれる
- [ ] アートワーク画像が 1400×1400px 以上
- [ ] 第1回エピソードのMP3が再生できる（R2のURLを直接ブラウザで開く）
