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
| 音声公開URL | R2 Public URL | https://pub-2723121c04be418c8520405cedf4afee.r2.dev |
| Spotify | Spotify for Creators | https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p |
| Apple Podcasts | Apple Podcast Connect | https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088 |
| ドメイン | Squarespace DNS → GitHub Pages | podcast.uzumaki-inc.jp |

### Cloudflare R2
- **Account ID**: `<ACCOUNT_ID>`
- **S3 Endpoint**: `https://<ACCOUNT_ID>.r2.cloudflarestorage.com`
- **公開URL Base**: `https://pub-2723121c04be418c8520405cedf4afee.r2.dev`
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

## エピソード公開フロー（運用）

詳細は `OPERATION.md` を参照。概要は以下の通り：

1. `./scripts/publish.sh 0007 ~/Downloads/file.m4a ~/Downloads/file.mp4` を実行
   - m4aをR2アップロード → mp4から10秒ごとに静止画切り出し → テンプレート生成（自動）
   - 文字起こしは行わない（共有される話者分離済み VTT を使う）
2. VTT（＋切り出した静止画）をClaudeに渡して番組概要・ポイント・リンクを生成（Claude+人間）
3. `meta.yaml` の title / description を記入（手動。duration は publish.sh が自動入力）
4. `shownotes.md` のクレジット登壇者（工藤以外）を記入（手動）
5. まとめ後、切り出した静止画をローカルから削除（`rm -rf ~/Downloads/realtech-frames-0007`）
6. `git push` → GitHub Actionsが feed.xml を自動更新

### エピソード番号規則
- **4桁ゼロ埋め**（例: `0001`, `0002`, `0003`）
- R2ファイル名: `episodes/0007.m4a`（配信音声は m4a を直接ホスト。mp3 変換はしない）

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
- [ ] ep0007 以降のエピソード公開（次回作業）

---

## ローカル環境（作業Mac）

- **AWS CLI**: `brew install awscli`（R2 アップロード用）
- **ffmpeg**: Homebrew でインストール（mp4 からの静止画切り出し・再生時間の自動計算用）
- **GitHub CLI（gh）**: Homebrew でインストール（公開時の git push 認証用）
- **リポジトリの場所**: `~/src/realtech-radio`（GitHub: uzumaki-inc/realtech-radio）

### 新しいMacで環境を作る場合

`./scripts/setup.sh` が必要なツール（ffmpeg / awscli / gh）の導入と認証設定・R2 接続の確認をまとめて行う。
認証情報の受け渡し・設定手順は [ONBOARDING.md](./ONBOARDING.md) を参照（値は 1Password の「realtech-radio 配信用」）。

> 文字起こしは共有される話者分離済み VTT を使うため、Whisper などの文字起こしツールは不要。

### gitにpushする方法
認証は以下の2系統がありますが、編集メンバーの利便性を考慮の上でAを採用

A. HTTPS + gh（GitHub CLI）認証 ← このプロジェクトでは推奨
- gh auth login を実行 → ブラウザが開いてログイン＆承認するだけ。
- SSH 鍵の生成・登録は一切不要。裏で OAuth トークンが安全に保存され、git push の認証もこれが肩代わりします。
- この番組は元々 gh を使う前提（CLAUDE.md のローカル環境に記載）なので、編集メンバーにも gh auth login を案内するのが一番シンプルです。非エンジニア＋Claude Code 前提なら特にこれ。

B. SSH 鍵を登録する方式
- ローカルで鍵を生成（ssh-keygen）→ 公開鍵を GitHub アカウントの Settings → SSH keys に登録。
- リポジトリを SSH URL（git@github.com:...）で clone している場合はこちら。
- こちらを選ぶなら「GitHub に鍵登録が必要」というのはその通りです。

整理すると
-「鍵登録が必ず要るか？」→ いいえ。 gh auth login（HTTPS）を使えば鍵登録なしで push できます。
- どちらの方式でも、共通で必要なのは「そのメンバーが Collaborator として招待を承諾済みであること」だけです。認証が通っても招待されていなければ push は弾かれます。
