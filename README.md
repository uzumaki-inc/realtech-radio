# リアルテックラジオ

エンジニアが普段何を考え、どんなことにワクワクしているのかを、非エンジニアの視点で紐解いていくラジオ。UZUMAKI Inc. が運営しています。

## 構成

- `podcast.yaml` - Podcast 全体の設定
- `episodes/` - エピソードごとのメタデータとショーノート
- `scripts/` - RSS フィード生成スクリプト
- `site/` - GitHub Pages に公開されるファイル（自動生成）

## エピソードの追加方法

1. `episodes/` に新しいディレクトリを作成（例: `002/`）
2. `meta.yaml` と `shownotes.md` を作成
3. 音声ファイルを Cloudflare R2（`realtech-radio-audio` バケット）にアップロード
4. `meta.yaml` の `audio_url` と `file_size` を更新
5. push すると GitHub Actions が RSS フィードを自動生成・デプロイ

## 配信先

- RSS: https://podcast.uzumaki-inc.jp/feed.xml
- Spotify: （登録後に追記）
- Apple Podcasts: （登録後に追記）
