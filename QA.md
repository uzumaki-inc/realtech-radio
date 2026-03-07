# リアルテックラジオ 配信基盤 Q&A

セットアップ中に出てきた疑問と回答をまとめたドキュメントです。

---

## 配信方針について

### Q: Podcastのデプロイ先はGitHubとSpotifyどちらがいい？

**A:** どちらか一方ではなく「スタック型配信」がベスト。自分のドメイン（podcast.uzumaki-inc.jp）でRSSフィードを公開し、音声ファイルはCloudflare R2に置く。その上でSpotifyやApple PodcastsにRSSフィードURLを登録する。こうすることで、独立性（自分の城を持つ）と利便性（プラットフォームのリーチ）を両立できる。

### Q: GitHubに音声ファイルを置く場合の制約は？

**A:** 3つの方法があり、それぞれ制約がある。

- **リポジトリ本体**: 推奨上限1GB、個別ファイル100MBまで。10〜15エピソードで上限に到達する
- **Git LFS**: ストレージ1GB、帯域月1GB（無料枠）。50MBのエピソードだと月20回分のダウンロードで枯渇する
- **GitHub Releases**: ファイルは2GBまでOKだが、CDN的な利用は規約上想定外。リスナー増加でレート制限のリスクあり

結論として、GitHubは「始めやすいがスケールしにくい」ため、Cloudflare R2を選択した。

### Q: Cloudflare R2とAWS S3の違いは？

**A:** Podcast用途ではR2が明確に有利。

- **R2**: エグレス（データ転送）が完全無料。ストレージ10GB/月無料。Podcastは「書き込み少、読み取り多」なのでR2との相性が良い
- **S3**: 実績豊富だがデータ転送に$0.09/GB。50MBのエピソードが月1000回ダウンロードされると約$4.50/月

R2はS3互換APIなので、AWS CLIやSDKがそのまま使える。

---

## Cloudflareについて

### Q: Cloudflareは無料プランでまかなえる？

**A:** はい。R2の無料枠で十分。

- ストレージ: 月10GBまで無料
- API操作: Class A（書き込み）100万回/月、Class B（読み取り）1000万回/月
- エグレス: 完全無料

月2回配信、リスナー1000人/月でもコストはほぼゼロ。

### Q: Cloudflareのアカウント種別（Personal / Professional）はどれを選ぶ？

**A:** Personalで十分。理由は以下の通り。

- 営利目的ではない個人的なPodcast配信
- R2の無料枠はどのプランでも同じ
- チーム管理やSSO認証は不要

会社のドメインやGitHubを使用していても、Podcast配信自体が個人的な活動であればPersonalで問題ない。

### Q: PersonalとProfessionalの違いは？

**A:** R2に関しては差がない。違いが出るのはCloudflareの主要サービス（CDN、DDoS保護、SSL管理など）で、Professionalは月$20。Podcast配信だけが目的ならPersonalのままでOK。会社公式化して、uzumaki-inc.jpのドメイン全体をCloudflareで管理したくなったらProfessionalに変更すればよい。

### Q: 独自DNS、WAF、DDoS保護とは？

**A:**

- **独自DNS**: ドメイン（uzumaki-inc.jp）のDNS管理をCloudflareに移管する機能。今はSquarespaceで管理しているので不要
- **WAF（Web Application Firewall）**: SQLインジェクションやXSS攻撃などをブロックするセキュリティ機能。Podcastは静的なRSSフィードなので不要
- **DDoS保護**: 大量アクセスによるサービスダウンを防ぐ機能。個人Podcastは攻撃対象になりにくいので不要

いずれも、Podcast配信だけの用途では必要ない。

---

## R2の設定について

### Q: R2バケット名は何がいい？

**A:** `realtech-radio-audio` を採用。理由は以下の通り。

- Podcast名「リアルテックラジオ」を英語化した識別子
- 音声ファイル用という意図が明確
- 将来的に `realtech-radio-video` など別リソースを追加しやすい

### Q: パブリックアクセスを有効化するとはどういう意味？なぜ必要？

**A:** R2バケットはデフォルトで非公開（アカウント所有者のみアクセス可能）。この状態だと、リスナーのPodcastアプリが音声ファイルをリクエストしても「403 Forbidden（アクセス拒否）」が返され、聴くことができない。

パブリックアクセスを有効化すると「読み取りは公開、書き込みは非公開のまま」になる。つまり、リスナーは音声をダウンロード・再生できるが、第三者がファイルをアップロード・削除することはできない（書き込みにはAPIトークンが必要）。

具体的には「Public Development URL」を有効化することで、`*.r2.dev` 形式の公開URLが発行される。設定画面で `allow` と入力して確認する。

なお、このURLはレート制限がある。リスナーが増えてきたら「Custom Domains」でカスタムドメインを設定すれば回避できる。

---

## RSS生成スクリプトについて

### Q: RSS生成スクリプトが必要な理由は？

**A:** Podcastの配信は「RSSフィード」というXML形式のファイルが起点。Spotify、Apple Podcasts等はこのRSSフィードを定期的にチェックして、最新エピソードを取得する。

エピソードが増えるたびにXMLを手動編集するのは面倒でミスも起きやすい。`generate_feed.py` は `episodes/*/meta.yaml` を読み取ってXMLを自動生成するので、作業者は「YAMLを書いてpushするだけ」で済む。

GitHub Actionsと組み合わせることで、push → RSS生成 → デプロイまで完全自動化される。

---

## ドメインについて

### Q: 既存ドメイン（uzumaki-inc.jp）にサブドメインを設定できる？

**A:** できる。SquarespaceのDNS管理画面でCNAMEレコードを追加するだけ。

- `podcast.uzumaki-inc.jp` → GitHub Pages（RSSフィードとPodcastサイト）
- 音声ファイルの実体 → Cloudflare R2

リスナーが登録するRSSのURLは `https://podcast.uzumaki-inc.jp/feed.xml` になる。これが「自分の城」であり、R2やGitHub Pagesを別のサービスに変えても、DNSの向き先を変えるだけでリスナーには影響しない。

---

## アートワークについて

### Q: SpotifyやApple Podcastsに表示されるヘッダー画像（アートワーク）は必要？

**A:** はい、必要。RSSフィードの `<itunes:image>` タグで指定する。この画像がSpotify、Apple Podcasts等で番組のサムネイルとして表示される。アートワークがないとプラットフォーム登録時に審査が通らない可能性がある。

要件は以下の通り：

- 最小サイズ: 1400×1400px
- 推奨サイズ: 3000×3000px
- 正方形（1:1比率）
- フォーマット: JPEG または PNG
- ファイルサイズ: 500KB〜2MB程度

Step 6（プラットフォーム登録）の前までに用意する必要がある。

---

## 文字起こしについて

### Q: エピソードの文字起こしはどうやる？

**A:** Zoom収録がローカル録画の場合、Zoom側の自動文字起こしは利用できない。OpenAI Whisperをローカルで実行するのが無料かつ高精度。

### Q: Whisperのセットアップと実行手順は？

**A:** MacのターミナルでHomebrewがない場合から含めた手順は以下の通り。

```bash
# ① Homebrewがなければインストール（既にあればスキップ）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# ② Python 3 と ffmpeg をインストール
brew install python@3.11 ffmpeg

# ③ Whisperをインストール
pip3 install openai-whisper

# ④ 文字起こしを実行（音声ファイルのあるフォルダで）
whisper realtech_radio_1_20260218.m4a --language ja --model medium --output_format txt
```

- `--model medium` は日本語の精度と実行速度のバランスが良い。より高精度を求めるなら `--model large` にする（ただし時間がかかる）
- 出力は同じフォルダに `realtech_radio_1_20260218.txt` として保存される
- M1/M2 Macなら `medium` モデルで34分の音声が10〜20分程度で完了する見込み

### Q: Whisper以外の選択肢は？

**A:** 有料だがクラウドサービスも使える。

- **OpenAI Whisper API**: $0.006/分。34分で約$0.20（約30円）。API経由なのでPCスペック不問
- **Google Speech-to-Text**: 無料枠あり（月60分）。それ以降は$0.006/15秒
- **macOS「聞き取り」**: 無料だがリアルタイム速度。34分の音声に34分かかる
