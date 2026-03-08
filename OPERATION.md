# リアルテックラジオ 運用ガイド

新しいエピソードを公開するための手順書です。

---

## 全体フロー

```
収録（Zoom）
    ↓
./scripts/publish.sh を実行（自動）
    ↓ mp3変換 → 文字起こし → R2アップロード → ファイル生成
meta.yaml / shownotes.md を編集（手動）
    ↓
git push（手動）
    ↓
GitHub Actions が feed.xml を自動更新（自動）
    ↓
Spotify / Apple Podcasts が自動取得（自動）
```

| 作業 | 担当 | 目安時間 |
|---|---|---|
| Zoom収録 | 人間 | 収録時間による |
| publish.sh 実行 | スクリプト | 15〜30分（文字起こし含む） |
| meta.yaml 記入 | 人間 | 5分 |
| shownotes.md 記入 | 人間 | 15〜30分 |
| git push | 人間 | 1分 |

---

## 手順

### 1. Zoom収録後、m4aファイルをDownloadsに置く

Zoomのローカル録画（`.m4a`）をダウンロードフォルダに移動する。

ファイル命名例：`realtech_radio_2_20260301.m4a`

---

### 2. publish.sh を実行する

```bash
cd ~/path/to/podcast-repo
./scripts/publish.sh 002 ~/Downloads/realtech_radio_2_20260301.m4a
```

**スクリプトが自動でやること：**

1. `m4a → mp3` に変換（ffmpeg）
2. Whisperで日本語文字起こし → `~/Downloads/ファイル名.txt` に保存
3. mp3を R2 にアップロード（`episodes/002.mp3`）
4. `episodes/002/meta.yaml` を作成（audio_url / file_size は自動入力）
5. `episodes/002/shownotes.md` のテンプレートを作成

---

### 3. meta.yaml を編集する

`episodes/002/meta.yaml` を開いて以下を記入する：

```yaml
title: "エピソードタイトル"      # ← 記入
date: 2026-03-01                  # ← 収録日または公開日
duration: "00:30:00"              # ← 実際の尺（例: 30分）
audio_url: "https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/002.mp3"  # 自動入力済み
file_size: 31234567               # 自動入力済み
description: "説明文"             # ← 記入
explicit: false
```

> **durationの確認方法：**
> ```bash
> ffprobe ~/Downloads/realtech_radio_2.mp3 2>&1 | grep Duration
> ```

---

### 4. shownotes.md を編集する

`episodes/002/shownotes.md` を開いて、文字起こし（.txt）を参考に内容を記入する。

---

### 5. git push する

```bash
git add episodes/002/
git commit -m "ep002: publish"
git push
```

→ GitHub Actionsが自動起動して `feed.xml` が更新される（約1分）

→ SpotifyとApple Podcastsが次回のクロールで自動取得（数時間以内）

---

## 確認URL

| 確認内容 | URL |
|---|---|
| RSSフィード | https://podcast.uzumaki-inc.jp/feed.xml |
| 音声ファイル（例）| https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/002.mp3 |
| Spotify | https://open.spotify.com/show/0MBHbtyvPf47oPxBi |
| Apple Podcasts | https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088 |

---

## トラブルシューティング

### whisper コマンドが見つからない

```bash
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
```

`~/.zshrc` に上記を追加しておくと次回以降不要になる。

### aws コマンドが見つからない

```bash
brew install awscli
aws configure --profile r2
```

configure で入力する内容：
- Access Key ID: Cloudflareで作成した `realtech-radio-upload` トークンのAccess Key ID
- Secret Access Key: 同上のSecret Access Key
- Default region: `auto`
- Output format: `json`

### R2アップロードが失敗する

APIトークン（`realtech-radio-upload`）の有効期限・権限を確認する。

Cloudflare → R2 Object Storage → Overview → Account Details → Manage

---

## 次回エピソードのファイル命名規則

| 項目 | 規則 | 例 |
|---|---|---|
| エピソード番号 | 3桁ゼロ埋め | `002`, `003` |
| R2上のファイル名 | `episodes/{番号}.mp3` | `episodes/002.mp3` |
| ローカルのm4a | 自由（任意） | `realtech_radio_2_20260301.m4a` |
