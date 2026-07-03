# RSS生成スクリプトの役割

エピソードを `git push` すると RSS フィードが自動で配信される仕組みの技術解説です。読まなくても普段の運用はできます。「なぜ GitHub リポジトリが配信のマスターなのか」「push の裏で何が起きているのか」を知りたいときに読んでください。

## 全体フロー

```
┌─────────────────────────────────────────────────────────────────┐
│ リアルテックラジオ 配信システム                                      │
└─────────────────────────────────────────────────────────────────┘

【編集者の作業】
  収録音声 (.m4a) ──(publish.sh)──→ Cloudflare R2 にアップロード（配信されるのはこれだけ）
                                        └→ 公開URL（https://pub-....r2.dev/episodes/0007.m4a）を
                                           meta.yaml の audio_url に自動記入
  動画 (.mp4)     ──(publish.sh)──→ 切り出した静止画を .vtt とセットで Claude Code に食わせ、まとめ後に削除
  話者分離 (.vtt) ──(Claude Code)──→ shownotes.md の元ネタ（.mp4同様にアップロードしない）

  episodes/0007/
  ├── meta.yaml         ← 番組タイトル、公開日、audio_url（= R2 の音声URL）など（publish.sh が下書きを自動生成）
  └── shownotes.md      ← ショーノート（説明文。Claude Code と仕上げる）
      ↓
   git push
      ↓
【自動化される部分】GitHub Actions が以下を自動実行
  ↓
  generate_feed.py を実行
  ↓
  meta.yaml + shownotes.md をパースして
  ↓
  site/feed.xml を生成
  （<enclosure> は R2 上の音声URLを指すだけ。音声本体は GitHub Pages には載らない）
  ↓
  GitHub Pages にデプロイ（= podcast.uzumaki-inc.jp/feed.xml）
      ↓
【各プラットフォーム】
  Spotify     ─┐
  Apple       ─┴─→ podcast.uzumaki-inc.jp/feed.xml を定期的に確認
      ↓
  リスナーのアプリが feed.xml を読み、音声本体は Cloudflare R2 から直接ストリーミング
```

## RSS生成スクリプトの詳細

```
入力ファイル:

  podcast.yaml
  │
  ├─ title: "リアルテックラジオ"
  ├─ author: "UZUMAKI"
  ├─ description: "エンジニアが普段何を考え..."
  ├─ image: "https://podcast.uzumaki-inc.jp/artwork.jpg"
  └─ link: "https://podcast.uzumaki-inc.jp"

  episodes/0001/meta.yaml
  │
  ├─ title: "声でPC操作！でも落とし穴は？音声認識サービスの裏側"
  ├─ date: 2026-03-07
  ├─ duration: "00:30:00"
  ├─ audio_url: "https://r2.../0001.mp3"    ← Cloudflare R2上の場所
  └─ description: "音声認識でPCを操作する..."

  episodes/0001/shownotes.md
  │
  ├─ # 声でPC操作！でも落とし穴は？
  ├─ ## 今回のテーマ
  ├─ - 音声認識の仕組みと現在地
  └─ - 便利さと落とし穴

         ↓
    [ generate_feed.py ]
         ↓
    これらをパースして、
    RSS 2.0 + iTunes拡張のXMLに変換
         ↓

出力ファイル:

  site/feed.xml
  │
  └─ <rss>
       <channel>
         <title>リアルテックラジオ</title>
         <link>https://podcast.uzumaki-inc.jp</link>
         <item>
           <title>声でPC操作！でも落とし穴は？音声認識サービスの裏側</title>
           <pubDate>Sat, 07 Mar 2026 00:00:00 +0000</pubDate>
           <enclosure url="https://r2.../0001.mp3" ... />
           <itunes:duration>00:30:00</itunes:duration>
           <content:encoded>
             <h2>今回のテーマ</h2>
             <ul>
               <li>音声認識の仕組みと現在地</li>
               <li>便利さと落とし穴</li>
             </ul>
           </content:encoded>
         </item>
       </channel>
     </rss>
```

> 例は ep0001（mp3 時代）のもの。ep0007 以降の現行フローは m4a ですが、`generate_feed.py` がファイル形式に応じた MIME タイプを自動判定するため、どちらも同じ仕組みで配信されます。

## 手動 vs 自動化の比較

```
【手動でXMLを編集する場合】

  エピソード追加
    ↓
  site/feed.xml を手で編集（XML形式）
    ↓
  <item>, <enclosure>, <itunes:duration> などを
  手で書く（間違えやすい、面倒）
    ↓
  git push


【スクリプトで自動化する場合】

  エピソード追加
    ↓
  episodes/0007/meta.yaml と shownotes.md を書く
  （テンプレは publish.sh が自動生成）
    ↓
  git push
    ↓
  GitHub Actions が自動実行
    ↓
  generate_feed.py が site/feed.xml を生成
    ↓
  GitHub Pages にデプロイ
    ↓
  完了（ユーザーは何もしない）
```

## なぜこれが重要か

```
【独立性を保つために】

  podcast.uzumaki-inc.jp/feed.xml
  ↑
  これが「我々の城」

  RSSのマスター = 我々のGitHubリポジトリ
  ↓
  音声ファイル置き場を変更したい
    →  meta.yaml の audio_url を変えるだけ
    →  generate_feed.py が自動的に新しいXMLを生成
    →  リスナーには何の影響もない

  Spotify, Apple Podcasts は
  このfeed.xmlのURLをずっと監視し続ける
    →  feed.xml の内容が更新されたら、自動的に反映
    →  変わるのは feed.xml の内容だけ
    →  リスナーのURL登録はそのまま
```

## スクリプトが不要な場合

```
もしエピソードが1つか2つだけなら、
手動でXMLを書くのもあり。

でも、長く続けるなら：
  - 月2回、50年続けたら → 1200エピソード
  - 各エピソードでXMLを手で編集するのは現実的ではない
  - スクリプトがあれば、あなたはYAMLだけに集中できる
```
