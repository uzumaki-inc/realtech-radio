# リアルテックラジオ プロジェクトコンテキスト

このファイルはClaude Coworkで作業を引き継ぐためのコンテキストです。
新しいPCやセッションで作業を開始するときに、このファイルを読み込ませてください。

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
| Spotify | Spotify for Creators | https://open.spotify.com/show/0MBHbtyvPf47oPxBi |
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
20260308 podcast/
├── CONTEXT.md          ← このファイル
├── OPERATION.md        ← 運用手順書（エピソード公開フロー）
├── UPLOAD_AND_PUBLISH.md
├── DOMAIN_SETUP.md
├── QA.md               ← セットアップQ&A集
├── RSS_FLOW.md
├── README.md
├── podcast.yaml        ← 番組全体の設定
├── episodes/
│   └── 0001/           ← エピソードは4桁ゼロ埋め
│       ├── meta.yaml
│       └── shownotes.md
├── scripts/
│   ├── publish.sh      ← 新エピソード公開の自動化スクリプト
│   ├── generate_feed.py
│   └── requirements.txt
└── site/               ← GitHub Actionsが自動生成（触らない）
```

---

## エピソード公開フロー（運用）

詳細は `OPERATION.md` を参照。概要は以下の通り：

1. `./scripts/publish.sh 0002 ~/Downloads/ファイル名.m4a` を実行
   - mp3変換 → Whisper文字起こし → R2アップロード → テンプレート生成（自動）
2. 文字起こしをClaudeに貼り付けて番組概要・ポイント・リンクを生成（Claude+人間）
3. `meta.yaml` の title / duration / description を記入（手動）
4. `shownotes.md` のクレジット登壇者（工藤以外）を記入（手動）
5. `git push` → GitHub Actionsが feed.xml を自動更新

### エピソード番号規則
- **4桁ゼロ埋め**（例: `0001`, `0002`, `0003`）
- R2ファイル名: `episodes/0001.mp3`

---

## 固定クレジット情報

```markdown
- 工藤：株式会社UZUMAKI 代表取締役 ／ X([@ToraDady](https://x.com/ToraDady))
- （他の登壇者は毎回変わるので手入力）

制作：[株式会社UZUMAKI](https://uzumaki-inc.jp)
```

---

## 現在の状態（2026-03-09時点）

- [x] GitHub Actions + GitHub Pages セットアップ完了
- [x] Cloudflare R2 バケット作成・公開設定完了
- [x] podcast.uzumaki-inc.jp ドメイン設定完了
- [x] ep0001 音声アップロード・公開完了
- [x] Spotify 登録完了（審査通過済み）
- [x] Apple Podcasts 登録・申請完了（審査中）
- [x] 運用スクリプト（publish.sh）作成完了
- [ ] ep0002 以降のエピソード公開（次回作業）

---

## ローカル環境（作業Mac）

- **AWS CLI**: `brew install awscli` でインストール済み（v2.34.4）
- **Whisper**: `~/Library/Python/3.9/bin/whisper`（PATHに要追加）
- **ffmpeg**: Homebrewでインストール済み
- **リポジトリの場所**: このフォルダ（`20260308 podcast/`）がGitリポジトリ

### 新しいMacで環境を作る場合

```bash
# 1. AWS CLIをインストール
brew install awscli

# 2. R2プロファイルを設定
aws configure --profile r2
# → Access Key ID: Cloudflareの realtech-radio-upload トークン
# → Secret Access Key: 同上
# → Default region: auto
# → Output format: json

# 3. Whisperをインストール
pip3 install openai-whisper
brew install ffmpeg

# 4. PATHを通す（~/.zshrcに追加）
export PATH="$HOME/Library/Python/3.9/bin:$PATH"
```

---

## Claudeへの引き継ぎメモ

- 工藤さんはiOSエンジニア出身の経営者。技術的な話はエンジニアレベルで通じる
- プロジェクトマネージャーとして振る舞い、作業を一緒に進めるスタイルを好む
- ドキュメントはリアルタイムで更新する（作業中に発見したことをすぐ反映）
- Q&A（`QA.md`）は疑問が出たらその都度追記する
- 次回の作業は第2回エピソード（`0002`）の公開から
