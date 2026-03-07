# Step 5: ドメイン設定ガイド

`podcast.uzumaki-inc.jp` でRSSフィードを公開するための設定手順です。

## 全体像

```
リスナー → podcast.uzumaki-inc.jp/feed.xml → GitHub Pages（RSS配信）
                                                ↓
                                        音声URLはR2を参照
```

やることは2つだけ：

1. **GitHub側**: リポジトリでGitHub Pagesを有効化 + カスタムドメインを設定
2. **Squarespace側**: DNSにCNAMEレコードを追加

---

## ① GitHubリポジトリの準備

### 1. リポジトリを作成する

- https://github.com/uzumaki-inc にアクセス
- 「New repository」をクリック
- リポジトリ名: `realtech-radio`（推奨）
- 公開設定: **Public**（GitHub Pages無料利用にはPublicが必要）
- 「Create repository」をクリック

> ⚠️ Private リポジトリでGitHub Pagesを使うには GitHub Pro / Team / Enterprise が必要です。
> uzumaki-inc の Organization プランを確認してください。

### 2. GitHub Pagesを有効化する

- リポジトリの「Settings」タブを開く
- 左メニューの「Pages」をクリック
- 「Source」セクション:
  - **Source**: 「GitHub Actions」を選択
  - （deploy.yml で既にPages用のデプロイ設定済み）

### 3. カスタムドメインを設定する

- 同じ「Pages」設定画面で
- 「Custom domain」欄に `podcast.uzumaki-inc.jp` と入力
- 「Save」をクリック
- ⚠️ この時点ではDNS未設定なので検証エラーが出ますが、次のステップで解消します

---

## ② SquarespaceでDNSレコードを追加する

### 1. Squarespaceにログイン

- https://account.squarespace.com/ にアクセス
- uzumaki-inc.jp を管理しているアカウントでログイン

### 2. DNS設定を開く

- ダッシュボードから uzumaki-inc.jp のドメインを選択
- 「DNS」または「DNS Settings」をクリック
- 「Custom Records」セクションへ

### 3. CNAMEレコードを追加

以下の設定で新しいレコードを追加：

| 項目 | 値 |
|---|---|
| **Type** | CNAME |
| **Host** | `podcast` |
| **Value** | `uzumaki-inc.github.io` |
| **TTL** | 自動（またはデフォルト） |

- 「Add」または「Save」をクリック

> **Host欄の注意**: `podcast.uzumaki-inc.jp` ではなく、サブドメイン部分の `podcast` だけを入力してください。

### 4. DNS反映を待つ

- DNS変更は通常 **数分〜最大48時間** で反映される
- 実際は10〜30分で反映されることが多い

---

## ③ 確認作業

### DNSの反映確認

ターミナルで以下を実行：

```bash
dig podcast.uzumaki-inc.jp CNAME +short
```

`uzumaki-inc.github.io.` と返ってくれば成功。

### HTTPS の確認

- GitHub Pagesの設定画面に戻る
- 「Custom domain」欄の横に ✅ マークが表示されていればOK
- 「Enforce HTTPS」にチェックを入れる（SSL証明書はGitHubが自動発行）
- SSL証明書の発行に最大数十分かかる場合がある

### RSSフィードの確認

最終的に以下のURLでフィードにアクセスできるようになる：

```
https://podcast.uzumaki-inc.jp/feed.xml
```

---

## トラブルシューティング

### 「DNS check failed」と表示される

- DNS反映に時間がかかっている可能性がある。30分待って再確認
- Squarespaceで入力した値が正しいか確認（Host: `podcast`、Value: `uzumaki-inc.github.io`）

### 「Certificate not yet generated」と表示される

- 「Enforce HTTPS」のチェックを一度外して再度入れる
- 最大24時間待つ（通常は数十分）

### Private リポジトリの場合

- GitHub Pages は Public リポジトリなら無料
- Private の場合、Organization の GitHub Team プラン以上が必要
- まずは Public で始めて、必要に応じて後から変更可能

---

## まとめ

Step 5 で完了する設定：

- [ ] GitHubリポジトリ作成（`uzumaki-inc/realtech-radio`）
- [ ] GitHub Pages を有効化（Source: GitHub Actions）
- [ ] カスタムドメインに `podcast.uzumaki-inc.jp` を設定
- [ ] Squarespace で CNAME レコード追加（`podcast` → `uzumaki-inc.github.io`）
- [ ] DNS反映を確認（`dig` コマンド）
- [ ] HTTPS を有効化
