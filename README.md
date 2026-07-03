# リアルテックラジオ

エンジニアが普段何を考え、どんなことにワクワクしているのかを、非エンジニアの視点で紐解いていくラジオ。UZUMAKI, Inc. が運営しています。

## 🎧 番組を聴きたい方

- **Spotify**: https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p
- **Apple Podcasts**: https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088
- **RSS フィード**: https://podcast.uzumaki-inc.jp/feed.xml

各エピソードの詳細（ショーノート）は [`episodes/`](./episodes/) 配下にあります。これより下は番組運営用の資料です。

## ✍️ 編集者の方（エピソード公開を担当する方）

読むのは次の 2 つだけで大丈夫です：

1. **[ONBOARDING.md](./ONBOARDING.md)** — 初回のセットアップ（作業に加わるとき最初に 1 回だけ）
2. **[OPERATION.md](./OPERATION.md)** — 普段のエピソード公開手順

どちらも非エンジニア向けに書かれており、作業の多くは Claude Code に頼めます。

## 🔧 管理者の方（配信基盤を管理するエンジニア）

- **[R2_SETUP.md](./R2_SETUP.md)** — Cloudflare R2 の構築と、編集者用トークンの発行・ローテーション
- **[RSS_FLOW.md](./RSS_FLOW.md)** — RSS フィードが自動生成・配信される仕組みの技術解説
- **[QA.md](./QA.md)** — 配信基盤の設計判断 Q&A（なぜこの構成にしたか）
- **[CLAUDE.md](./CLAUDE.md)** — Claude Code 用のプロジェクトコンテキスト（基盤の設定値の早見表としても使えます）

## リポジトリ構成

- `podcast.yaml` — Podcast 全体の設定（番組名・著者・説明文など）
- `episodes/` — エピソードごとのメタデータとショーノート（4桁ゼロ埋め: `0001/`, `0002/`...）
- `scripts/` — セットアップ（`setup.sh`）・公開自動化（`publish.sh`）・RSS フィード生成（`generate_feed.py`）
- `site/` — GitHub Pages に公開されるファイル（GitHub Actions が自動生成。手で触らない）

## 技術構成

- **RSSフィード**: GitHub Pages（podcast.uzumaki-inc.jp）
- **音声ホスティング**: Cloudflare R2（`realtech-radio-audio` バケット）
- **CI/CD**: GitHub Actions（push → feed.xml 自動生成・デプロイ）
