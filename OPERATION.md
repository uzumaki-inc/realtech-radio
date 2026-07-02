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
| Claudeと対話（番組概要・ポイント・リンク生成） | 人間+Claude | 10〜15分 |
| meta.yaml 記入（title・duration・description） | 人間 | 5分 |
| shownotes.md 記入（登壇者クレジット） | 人間 | 2分 |
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
./scripts/publish.sh 0002 ~/Downloads/realtech_radio_2_20260301.m4a
```

**スクリプトが自動でやること：**

1. `m4a → mp3` に変換（ffmpeg）
2. WhisperKit（large-v3）で日本語文字起こし → JSON レポート生成後、 `jq` で `.text` を抽出して `~/Downloads/ファイル名.txt` に保存
3. mp3を R2 にアップロード（`episodes/0002.mp3`）
4. `episodes/0002/meta.yaml` を作成（audio_url / file_size は自動入力）
5. `episodes/0002/shownotes.md` のテンプレートを作成

---

### 3. Claudeと対話してshownotes.mdを生成する

文字起こし（`~/Downloads/ファイル名.txt`）をClaudeに貼り付けて、以下を生成してもらう：

- **番組概要** → `shownotes.md` の `## 番組概要` に貼り付け
- **今回のポイント** → `shownotes.md` の `## 今回のポイント` に貼り付け
- **リンク** → `shownotes.md` の `## リンク` に貼り付け

生成後、`## クレジット` の登壇者（工藤以外）を手入力で追加する。

---

### 4. meta.yaml を編集する

`episodes/0002/meta.yaml` を開いて以下を記入する：

```yaml
title: "エピソードタイトル"      # ← 記入
date: 2026-03-01                  # ← 収録日または公開日
duration: "00:30:00"              # ← 実際の尺（例: 30分）
audio_url: "https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/0002.mp3"  # 自動入力済み
file_size: 31234567               # 自動入力済み
description: "説明文"             # ← 記入
explicit: false
```

> **durationの確認方法：**
> ```bash
> ffprobe ~/Downloads/realtech_radio_2.mp3 2>&1 | grep Duration
> ```

---

### 5. git push する

```bash
git add episodes/0002/
git commit -m "ep0002: publish"
git push
```

→ GitHub Actionsが自動起動して `feed.xml` が更新される（約1分）

→ SpotifyとApple Podcastsが次回のクロールで自動取得（数時間以内）

---

## 確認URL

| 確認内容 | URL |
|---|---|
| RSSフィード | https://podcast.uzumaki-inc.jp/feed.xml |
| 音声ファイル（例）| https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/0002.mp3 |
| Spotify | https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p |
| Apple Podcasts | https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088 |

---

## トラブルシューティング

### whisperkit-cli コマンドが見つからない

```bash
brew install whisperkit-cli
```

Argmax 製の Swift native 実装（Apple Silicon の Neural Engine / Metal GPU を活用）。 旧 `openai-whisper`（pip 版、CPU 推論のみ）から移行済み。

初回 transcribe 時に HuggingFace から CoreML モデルを自動 DL する（`large-v3` で数 GB）。 モデルは `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` 配下に cache される。

### jq コマンドが見つからない

macOS 15.x 以降は `/usr/bin/jq` が標準同梱。 古い macOS の場合は：

```bash
brew install jq
```

publish.sh は WhisperKit が生成する JSON レポートから `.text` フィールドを `jq` で抽出して txt を作る。

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
| エピソード番号 | 4桁ゼロ埋め | `0002`, `0003` |
| R2上のファイル名 | `episodes/{番号}.mp3` | `episodes/0002.mp3` |
| ローカルのm4a | 自由（任意） | `realtech_radio_2_20260301.m4a` |
