# リアルテックラジオ プロジェクトコンテキスト

Claude Code / Claude Cowork が自動で読み込むプロジェクトコンテキストです。

---

## プロジェクト概要

**番組名**: リアルテックラジオ
**運営**: 株式会社UZUMAKI（工藤 崇志 / @ToraDady）
**コンセプト**: エンジニア語を非エンジニア向けに翻訳するPodcast

---

## 配信基盤（技術構成）

| 役割 | サービス | URL/詳細 |
|---|---|---|
| RSSフィード | GitHub Pages | https://podcast.uzumaki-inc.jp/feed.xml |
| 音声ホスティング | Cloudflare R2 | `realtech-radio-audio` バケット |
| 音声公開URL | R2 Public URL | `scripts/publish.sh` の `PUBLIC_BASE_URL` を参照 |
| Spotify | Spotify for Creators | https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p |
| Apple Podcasts | Apple Podcast Connect | https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088 |
| ドメイン | Squarespace DNS → GitHub Pages | podcast.uzumaki-inc.jp |

### Cloudflare R2
- **Account ID**: `<ACCOUNT_ID>`
- **S3 Endpoint**: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
- **公開URL Base**: `scripts/publish.sh` の `PUBLIC_BASE_URL` を参照
- **APIトークン名**: `realtech-radio-upload`（Account API Token、Object Read & Write）
- **AWS CLIプロファイル名**: `r2`（ローカルの `~/.aws/credentials` に保存済み）

---

## リポジトリ構成

```
realtech-radio/              ← GitHub: uzumaki-inc/realtech-radio
├── CLAUDE.md                ← このファイル
├── OPERATION.md             ← 運用手順書（エピソード公開フロー）
├── ONBOARDING.md            ← 編集者向けオンボーディング
├── R2_SETUP.md              ← R2セットアップ・トークン発行（管理者向け）
├── QA.md                    ← セットアップQ&A集
├── RSS_FLOW.md
├── README.md
├── podcast.yaml             ← 番組全体の設定
├── episodes/
│   ├── 0001/                ← エピソードは4桁ゼロ埋め
│   │   ├── meta.yaml
│   │   └── shownotes.md
│   └── 0002/
│       ├── meta.yaml
│       └── shownotes.md
├── scripts/
│   ├── publish.sh           ← 新エピソード公開の自動化スクリプト
│   ├── setup.sh             ← 配信環境のセットアップスクリプト
│   ├── generate_feed.py
│   └── requirements.txt
└── site/                    ← GitHub Actionsが自動生成（触らない）
```

---

## Claude への必須ルール（公開作業の進め方）

このリポジトリで編集者（非エンジニアを含む）の公開作業を手伝うとき、Claude は必ず次を守ること：

- **1ステップずつ進める**: 各手順の完了ごとに「何をしたか・次に何をするか」を報告し、編集者の返事を待ってから次に進む。複数手順を一気に実行しない
- **⛔ git push（＝公開）は、編集者が内容を確認して明示的に「OK」と言うまで絶対に実行しない**。push は Podcast の世界公開を意味する。承認前に push しそうな流れになったら止まって確認する
- 「手動で記入」とある欄（title / description / 登壇者）は、編集者に質問して答えをもらってから記入する。Claude が推測で埋めない
- 編集者が「動画はなし」と言ったら、publish.sh の第3引数に `--no-video` を渡す
- push は hook（`.claude/hooks/block-push.sh`）で機械的にブロックされる。編集者の「OK」を得た後に `touch .claude/.push-approved` を実行してから push する（承認は 1 回の push で使い切り）

## ドキュメントマップ（各文書の役割）

- **CLAUDE.md（このファイル）** = Claude への命令書。毎セッション自動ロードされ、ここのルールが最優先
- **OPERATION.md** = 編集者（人間）向けの公開手順書。Claude は公開作業時にこれを読んで手順を把握するが、実行ペースは上記ルール（1ステップずつ・push 前承認）に従う
- **ONBOARDING.md** = 初回セットアップ手順（人間向け）。「設定ファイルが無い」などのトラブル時に Claude が参照して編集者を誘導する
- **R2_SETUP.md / RSS_FLOW.md / QA.md** = 管理者向け・背景説明。通常の公開作業では触らない

## エピソード公開フロー（運用）

詳細は `OPERATION.md` を参照。概要は以下の通り：

1. `./scripts/publish.sh 0007 ~/Downloads/file.m4a ~/Downloads/file.mp4` を実行（動画がない回は mp4 の代わりに `--no-video` を明示。省略はエラーになる）
   - m4aをmp3に変換してR2アップロード → mp4から10秒ごとに静止画切り出し → テンプレート生成（自動）
   - 文字起こしは行わない（共有される話者分離済み VTT を使う）
2. VTT（＋切り出した静止画）をClaudeに渡して番組概要・ポイント・リンクを生成（Claude+人間）
3. `meta.yaml` の title / description を記入（手動。duration は publish.sh が自動入力）
4. `shownotes.md` のクレジット登壇者（工藤以外）を記入（手動）
5. まとめ後、切り出した静止画をローカルから削除（`rm -rf ~/Downloads/realtech-frames-0007`）
6. **編集者が内容を確認して「OK」と言ったら** `git push` → GitHub Actionsが feed.xml を自動更新（⛔ 承認前の push は禁止。上記「Claude への必須ルール」参照）

### shownotes.md のテンプレート構成

shownotes.md は **ep0007 以降の構成**（💡 エピソード概要 / 🔗 リンク / 🎙 クレジット / 📻 番組概要）で書く。雛形は publish.sh が生成するので、それを埋める。実例は `episodes/0007/shownotes.md` を正とする。

### エピソード番号規則
- **4桁ゼロ埋め**（例: `0001`, `0002`, `0003`）
- R2ファイル名: `episodes/0007.mp3`（配信音声は mp3 に統一。Podcast アプリの互換性が最も高いため）
- 入力（編集者が渡す音声）は `.m4a` のまま。mp3 への変換は publish.sh が自動で行う

---

## 固定クレジット情報

```markdown
- 工藤：株式会社UZUMAKI 代表取締役 ／ X([@ToraDady](https://x.com/ToraDady))
- （他の登壇者は毎回変わるので手入力）

制作：[株式会社UZUMAKI](https://uzumaki-inc.jp)
```

---

## 現在の状態（2026-05-22時点）

- [x] GitHub Actions + GitHub Pages セットアップ完了
- [x] Cloudflare R2 バケット作成・公開設定完了
- [x] podcast.uzumaki-inc.jp ドメイン設定完了
- [x] ep0001 音声アップロード・公開完了
- [x] Spotify 登録完了（審査通過済み）
- [x] Apple Podcasts 登録・申請完了
- [x] 運用スクリプト（publish.sh）作成完了
- [x] ep0002 公開完了（2026-03-28）
- [x] ep0003 公開完了（2026-04-13、収録日 2026-04-11）
- [x] ep0004 公開完了（2026-05-11、収録日 2026-04-23）
- [x] ep0005 公開完了（2026-05-22、収録日 2026-05-18）
- [x] ep0006 公開完了（2026-06-12、収録日 2026-06-05）
- [x] ep0007 公開完了（2026-07-16、収録日 2026-07-10）
- [ ] ep0008 以降のエピソード公開（次回作業）

---

## ローカル環境（作業Mac）

- **AWS CLI**: `brew install awscli`（R2 アップロード用）
- **ffmpeg**: Homebrew でインストール（mp3 への変換・mp4 からの静止画切り出し・再生時間の自動計算用）
- **GitHub CLI（gh）**: Homebrew でインストール（公開時の git push 認証用）
- **リポジトリの場所**: `~/src/realtech-radio`（GitHub: uzumaki-inc/realtech-radio）

### 新しいMacで環境を作る場合

`./scripts/setup.sh` が必要なツール（ffmpeg / awscli / gh）の導入と認証設定・R2 接続の確認をまとめて行う。
認証情報の受け渡し・設定手順は [ONBOARDING.md](./ONBOARDING.md) を参照（値は 1Password の「realtech-radio 配信用」）。

> 文字起こしは共有される話者分離済み VTT を使うため、Whisper などの文字起こしツールは不要。

### git push の認証

編集メンバーの push 認証は **`gh`（GitHub CLI）の HTTPS 認証**に統一する（`gh auth login` のみ。SSH 鍵の生成・登録は不要）。編集者向けの実手順は [ONBOARDING.md](./ONBOARDING.md) の「4-3. GitHub にログインする」を参照。

- SSH 鍵方式（`git@github.com:` で clone する場合）も使えるが、非エンジニア＋Claude Code 前提では `gh` 方式を推奨。
- push できる前提は、対象メンバーが realtech-radio の **Outside Collaborator（Write ロール）** として招待され、承諾済みであること。認証が通っても未招待なら push は弾かれる。
