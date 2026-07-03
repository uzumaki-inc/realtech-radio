# リアルテックラジオ 運用ガイド

新しいエピソードを公開するための手順書です。

---

## 全体フロー

```
収録（Zoom：音声 m4a ＋ 動画 mp4）＋ 話者分離済み VTT を用意
    ↓
./scripts/publish.sh を実行（自動）
    ↓ m4aをR2アップロード → mp4から10秒ごとに静止画を切り出し → ファイル生成
VTT（＋静止画）をClaudeに渡してまとめを生成
    ↓
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
| publish.sh 実行 | スクリプト | 数分（アップロード＋静止画切り出し） |
| Claudeと対話（番組概要・ポイント・リンク生成） | 人間+Claude | 10〜15分 |
| meta.yaml 記入（title・duration・description） | 人間 | 5分 |
| shownotes.md 記入（登壇者クレジット） | 人間 | 2分 |
| git push | 人間 | 1分 |

---

## 手順

### 1. 収録データと VTT を用意する

- Zoom のローカル録画から、**音声 `.m4a`** と **動画 `.mp4`** をダウンロードフォルダに置く
- 話者分離済みの **`.vtt`**（文字起こし）を用意する

ファイル命名例：`realtech_radio_7_20260701.m4a` / `.mp4` / `.vtt`

> mp4 は「10 秒ごとの静止画」の切り出し元です。動画がない（音声のみの）回は mp4 を省略できます（VTT だけでまとめを作れます）。

---

### 2. publish.sh を実行する

```bash
cd ~/src/realtech-radio
./scripts/publish.sh 0007 ~/Downloads/realtech_radio_7.m4a ~/Downloads/realtech_radio_7.mp4
```

（mp4 がない回は 3 つ目の引数を省略：`./scripts/publish.sh 0007 ~/Downloads/realtech_radio_7.m4a`）

**スクリプトが自動でやること：**

1. m4a を R2 にアップロード（`episodes/0007.m4a`）
2. mp4 から 10 秒ごとに静止画（JPEG）を切り出し（`~/Downloads/realtech-frames-0007/`）
3. `episodes/0007/meta.yaml` を作成（audio_url / file_size は自動入力）
4. `episodes/0007/shownotes.md` のテンプレートを作成

> 文字起こしはスクリプトでは行いません（共有される VTT を使います）。

---

### 3. Claudeと対話してshownotes.mdを生成する

話者分離済みの **VTT** を Claude に渡す。さらに手順 2 で切り出した **静止画**（`~/Downloads/realtech-frames-0007/`）も渡すと、スライドや画面共有の内容も踏まえた精度の高いまとめになる。以下を生成してもらう：

- **番組概要** → `shownotes.md` の `## 番組概要` に貼り付け
- **今回のポイント** → `shownotes.md` の `## 今回のポイント` に貼り付け
- **リンク** → `shownotes.md` の `## リンク` に貼り付け

生成後、`## クレジット` の登壇者（工藤以外）を手入力で追加する。

**まとめが終わったら、切り出した静止画をローカルから削除する**（PC にノイズを溜めないため）。削除コマンドは publish.sh の最後にも表示されます：

```bash
rm -rf ~/Downloads/realtech-frames-0007
```

---

### 4. meta.yaml を編集する

`episodes/0007/meta.yaml` を開いて以下を記入する：

```yaml
title: "エピソードタイトル"      # ← 記入
date: 2026-07-01                  # ← 収録日または公開日
duration: "00:30:00"              # ← 実際の尺（例: 30分）
audio_url: "https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/0007.m4a"  # 自動入力済み
file_size: 31234567               # 自動入力済み
description: "説明文"             # ← 記入
explicit: false
```

> **durationの確認方法：**
> ```bash
> ffprobe ~/Downloads/realtech_radio_7.m4a 2>&1 | grep Duration
> ```

---

### 5. git push する

```bash
git add episodes/0007/
git commit -m "ep0007: publish"
git push
```

→ GitHub Actionsが自動起動して `feed.xml` が更新される（約1分）

→ SpotifyとApple Podcastsが次回のクロールで自動取得（数時間以内）

---

## 確認URL

| 確認内容 | URL |
|---|---|
| RSSフィード | https://podcast.uzumaki-inc.jp/feed.xml |
| 音声ファイル（例）| https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/0007.m4a |
| Spotify | https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p |
| Apple Podcasts | https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088 |

---

## トラブルシューティング

### aws / ffmpeg コマンドが見つからない

セットアップスクリプトを実行する（未導入のものだけ入れてくれる）：

```bash
./scripts/setup.sh
```

> **必要なツールは 2 つだけ**: `aws`（R2 へのアップロード）と `ffmpeg`（mp4 からの静止画切り出し）。文字起こしは共有される VTT を使うため、WhisperKit などの文字起こしツールは不要です。

### 静止画を切り出さずに公開したい（音声のみの回）

mp4 を渡さずに publish.sh を実行すると、静止画の切り出しをスキップして VTT だけで進められます：

```bash
./scripts/publish.sh 0007 ~/Downloads/realtech_radio_7.m4a
```

### 設定ファイルが見つからないと言われる

`~/.config/realtech-radio/config` が必要。作り方は [ONBOARDING.md](./ONBOARDING.md) を参照（値は 1Password の「realtech-radio 配信用」にある）。

### R2アップロードが失敗する

使用中のAPIトークン（管理者用 `realtech-radio-upload` ／ バックオフィス共有用 `realtech-radio-backoffice`）の有効期限・権限を確認する。

Cloudflare → R2 Object Storage → Overview → Account Details → Manage

---

## 次回エピソードのファイル命名規則

| 項目 | 規則 | 例 |
|---|---|---|
| エピソード番号 | 4桁ゼロ埋め | `0007`, `0008` |
| R2上のファイル名 | `episodes/{番号}.m4a` | `episodes/0007.m4a` |
| ローカルの m4a / mp4 / vtt | 自由（任意） | `realtech_radio_7.m4a` / `.mp4` / `.vtt` |
