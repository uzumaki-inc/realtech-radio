# リアルテックラジオ 運用ガイド

新しいエピソードを公開するための手順書です。

---

## 全体フロー

```
配信者：Zoom クラウド録画から 音声 m4a・動画 mp4・話者分離 VTT をダウンロード → 編集者に渡す
    ↓
編集者：音声 m4a を編集（BGM 付けなど）
    ↓
編集者：Claude Code に「ep0007 を公開したい」と頼む
    ↓ Claude Code が publish.sh を実行（m4a を R2 アップロード・静止画切り出し・テンプレ生成）
    ↓ VTT（＋静止画）からまとめを生成し、meta.yaml / shownotes.md を仕上げて公開（git push）
GitHub Actions が feed.xml を自動更新（自動）
    ↓
Spotify / Apple Podcasts が自動取得（自動）
```

| 作業 | 担当 | 目安時間 |
|---|---|---|
| Zoom収録（クラウド録画）＋ファイル受け渡し | 配信者 | 収録時間による |
| 音声編集（BGM 付けなど） | 編集者 | 編集内容による |
| エピソード公開（publish.sh 〜 まとめ生成 〜 push） | 編集者+Claude Code | 15〜20分 |

---

## 手順

### 1. 配信者が収録データを用意し、編集者に渡す

配信者が Zoom の**クラウド録画**から、次の 3 つをダウンロードして編集者に渡す：

- **音声 `.m4a`**
- **動画 `.mp4`**
- 話者分離済みの **`.vtt`**（文字起こし）

編集者は受け取ったファイルをダウンロードフォルダに置く。**ファイル名は自由**（Zoom からダウンロードした名前のままでOK）。

> mp4 は「10 秒ごとの静止画」の切り出し元です。動画がない（音声のみの）回は mp4 なしで進められます（VTT だけでまとめを作れます）。

---

### 2. 編集者が音声を編集する

音声 `.m4a` に**手動で編集を加える**（BGM を付ける、頭出しや不要部分のカットなど）。**編集後の m4a を配信に使う**。

---

### 3. Claude Code にエピソード公開を頼む

ターミナルでリポジトリに移動して、Claude Code を起動する：

```bash
cd ~/src/realtech-radio
claude
```

こう伝える（エピソード番号とファイルの場所は実際のものに置き換え）：

> ep0007 を公開したい。
> 編集後の音声は ~/Downloads/○○○.m4a、動画は ~/Downloads/○○○.mp4、
> 話者分離 VTT は ~/Downloads/○○○.vtt。

あとは Claude Code が順に進めてくれる：

1. `./scripts/publish.sh` を実行（m4a を R2 にアップロード、mp4 から 10 秒ごとに静止画を切り出し、`meta.yaml` / `shownotes.md` のテンプレートを生成。再生時間・ファイルサイズ・音声 URL は自動入力）
2. VTT（＋静止画）から番組概要・今回のポイント・リンクを生成して `shownotes.md` に反映
3. タイトル・説明・登壇者（工藤以外）など、足りない情報は Claude Code のほうから質問してくるので、答える
4. `meta.yaml` / `shownotes.md` を仕上げて、コミット → push
5. まとめが終わったら、切り出した静止画フォルダを削除（PC にノイズを溜めないため）

push されると GitHub Actions が起動し、約 1 分で `feed.xml` が更新される。Spotify・Apple Podcasts は次回のクロールで自動取得する（数時間以内）。

> 💡 同じエピソード番号でやり直しても大丈夫です。記入済みの内容（`meta.yaml` の title / description、`shownotes.md` 全体）は守られ、音声を差し替えた場合は再生時間などの機械計算欄だけ新しい音声に合わせて自動更新されます。

> Claude Code をまだ入れていない場合は、公式ドキュメント（https://code.claude.com/docs ）に沿ってインストール・ログインしてください。

#### 参考：ターミナルで手動実行する場合

publish.sh を自分で実行することもできる：

```bash
cd ~/src/realtech-radio
./scripts/publish.sh 0007 ~/Downloads/（編集後の音声）.m4a ~/Downloads/（動画）.mp4
```

（mp4 がない回は 3 つ目の引数を省略）。実行後にやることは、スクリプトの完了メッセージに表示される。

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

### aws / ffmpeg / gh コマンドが見つからない

セットアップスクリプトを実行する（未導入のものだけ入れてくれる）：

```bash
./scripts/setup.sh
```

> **必要なツールは 3 つだけ**: `aws`（R2 へのアップロード）・`ffmpeg`（静止画切り出し・再生時間の自動計算）・`gh`（GitHub 認証）。いずれも setup.sh が自動で導入します。文字起こしは共有される VTT を使うため、WhisperKit などの文字起こしツールは不要です。

### 静止画を切り出さずに公開したい（音声のみの回）

Claude Code に「動画はなし」と伝えるだけでOK。手動実行の場合は mp4 を渡さずに実行する：

```bash
./scripts/publish.sh 0007 ~/Downloads/（編集後の音声）.m4a
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
| ローカルの m4a / mp4 / vtt | 自由 | Zoom のダウンロード名のままでOK |
