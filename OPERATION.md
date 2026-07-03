# リアルテックラジオ 運用ガイド

新しいエピソードを公開するための手順書です。

---

## 全体フロー

```
配信者：Zoom クラウド録画から 音声 m4a・動画 mp4・話者分離 VTT をダウンロード → 編集者に渡す
    ↓
編集者：音声 m4a を編集（BGM 付けなど）
    ↓
./scripts/publish.sh を実行（自動）
    ↓ m4aをR2アップロード → mp4から10秒ごとに静止画を切り出し → ファイル生成
VTT（＋静止画）を Claude Code に渡してまとめを生成
    ↓
Claude Code に頼んで meta.yaml / shownotes.md を仕上げ、公開（git push）
    ↓
GitHub Actions が feed.xml を自動更新（自動）
    ↓
Spotify / Apple Podcasts が自動取得（自動）
```

| 作業 | 担当 | 目安時間 |
|---|---|---|
| Zoom収録（クラウド録画）＋ファイル受け渡し | 配信者 | 収録時間による |
| 音声編集（BGM 付けなど） | 編集者 | 編集内容による |
| publish.sh 実行 | 編集者（スクリプトが自動処理） | 数分（アップロード＋静止画切り出し） |
| Claude Code と対話（番組概要・ポイント・リンク生成） | 編集者+Claude Code | 10〜15分 |
| meta.yaml / shownotes 仕上げ・公開 | 編集者+Claude Code | 5分 |

---

## 手順

### 1. 配信者が収録データを用意し、編集者に渡す

配信者が Zoom の**クラウド録画**から、次の 3 つをダウンロードして編集者に渡す：

- **音声 `.m4a`**
- **動画 `.mp4`**
- 話者分離済みの **`.vtt`**（文字起こし）

編集者は受け取ったファイルをダウンロードフォルダに置く。ファイル命名例：`realtech_radio_7.m4a` / `.mp4` / `.vtt`

> mp4 は「10 秒ごとの静止画」の切り出し元です。動画がない（音声のみの）回は mp4 を省略できます（VTT だけでまとめを作れます）。

---

### 2. 編集者が音声を編集する

音声 `.m4a` に**手動で編集を加える**（BGM を付ける、頭出しや不要部分のカットなど）。**編集後の m4a を配信に使う**。

---

### 3. publish.sh を実行する

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

---

### 4. Claude Code に VTT を渡してまとめを作る

話者分離済みの **VTT** を Claude Code に渡す。さらに手順 3 で切り出した **静止画**（`~/Downloads/realtech-frames-0007/`）も渡すと、スライドや画面共有の内容も踏まえた精度の高いまとめになる。番組概要・今回のポイント・リンクを作ってもらい、`shownotes.md` に反映してもらう。

登壇者クレジット（工藤以外）は、Claude Code に「今回の登壇者は〇〇」と伝えれば追記してくれる。

**まとめが終わったら、切り出した静止画をローカルから削除する**（PC にノイズを溜めないため）。削除コマンドは publish.sh の最後にも表示されます：

```bash
rm -rf ~/Downloads/realtech-frames-0007
```

---

### 5. Claude Code に頼んで仕上げ、公開する

ここは自分でファイルを直接編集する必要はありません。**Claude Code に自然言語で頼めば対応してくれます**（足りない情報は Claude Code のほうから聞いてくれます）。たとえばこう伝えます：

> ep0007 を公開したい。タイトルは「〇〇」、説明は「〇〇」。meta.yaml と shownotes を仕上げて、コミットして push して。

- `meta.yaml` の title / description / 収録日、`shownotes.md` の登壇者などは、Claude Code が聞いてきたら答えるだけでOK（尺（duration）は Claude Code が音声から調べてくれます）
- 仕上がったら「コミットして push して」と頼めば、`git push` まで実行してくれます

push されると GitHub Actions が起動し、約 1 分で `feed.xml` が更新されます。Spotify・Apple Podcasts は次回のクロールで自動取得します（数時間以内）。

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

使用中のAPIトークン（管理者用 `realtech-radio-upload` ／ 編集者共有用 `realtech-radio-backoffice`）の有効期限・権限を確認する。

Cloudflare → R2 Object Storage → Overview → Account Details → Manage

---

## 次回エピソードのファイル命名規則

| 項目 | 規則 | 例 |
|---|---|---|
| エピソード番号 | 4桁ゼロ埋め | `0007`, `0008` |
| R2上のファイル名 | `episodes/{番号}.m4a` | `episodes/0007.m4a` |
| ローカルの m4a / mp4 / vtt | 自由（任意） | `realtech_radio_7.m4a` / `.mp4` / `.vtt` |
