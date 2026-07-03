# リアルテックラジオ

エンジニアが普段何を考え、どんなことにワクワクしているのかを、非エンジニアの視点で紐解いていくラジオ。UZUMAKI, Inc. が運営しています。

## 構成

- `podcast.yaml` - Podcast 全体の設定（番組名・著者・説明文など）
- `episodes/` - エピソードごとのメタデータとショーノート（4桁ゼロ埋め: `0001/`, `0002/`...）
- `scripts/` - RSS フィード生成スクリプト・公開自動化スクリプト
- `site/` - GitHub Pages に公開されるファイル（自動生成）

## 新しいエピソードの公開方法

`scripts/publish.sh` を使って半自動化されています。詳細は [OPERATION.md](./OPERATION.md) を参照してください。

新メンバーのセットアップは [ONBOARDING.md](./ONBOARDING.md) を参照してください。

```bash
./scripts/publish.sh 0007 ~/Downloads/realtech_radio_7.m4a ~/Downloads/realtech_radio_7.mp4
```

（音声の m4a を R2 にアップロードし、mp4 から 10 秒ごとに静止画を切り出します。文字起こしは共有される話者分離済み VTT を使います。）

## 配信先

- RSS: https://podcast.uzumaki-inc.jp/feed.xml
- Spotify: https://open.spotify.com/show/0MBHbtyvPf47oPxBiR0k9p
- Apple Podcasts: https://podcasts.apple.com/us/podcast/リアルテックラジオ/id1883493088

## 技術構成

- **RSSフィード**: GitHub Pages（podcast.uzumaki-inc.jp）
- **音声ホスティング**: Cloudflare R2（`realtech-radio-audio` バケット）
- **CI/CD**: GitHub Actions（push → feed.xml 自動生成・デプロイ）
