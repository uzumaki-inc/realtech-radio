# 編集者向けオンボーディングガイド

リアルテックラジオのエピソード公開作業に新しく加わる編集者向けの手順書です。
エンジニアでなくても進められるように書いています。分からないところがあれば配信者に聞いてください。

---

## はじめに：秘密情報の取り扱いについて

**このリポジトリはインターネット上に公開（Public）されています。**

そのため、アクセスキーなどの秘密情報は、リポジトリには一切置かず、**リポジトリの外で受け渡す**方針です。

- ✅ 秘密情報は **1Password の共有 Vault** で受け取る
- ❌ **Slack やメールでの共有は禁止**（コピーが残り、漏洩のもとになります）
- ❌ 受け取った値をリポジトリ内のファイルに書き込まない（コミットしない）

---

## 1. 認証情報と招待を受け取る

管理者から、1Password の共有 Vault にあるアイテム **「realtech-radio 配信用」** への招待を受けます。
アイテムには以下の 3 点が入っています。手順 4 で、それぞれを 1Password からコピーして設定します：

| 項目 | 何に使うか |
|---|---|
| R2 Account ID | アップロード先の接続情報（設定ファイルに書く） |
| Access Key ID | アップロードの認証（`aws configure set` で入力） |
| Secret Access Key | 同上 |

> バケット名は 1Password には入れていません。標準値（`realtech-radio-audio`）が自動で使われます。

あわせて、**GitHub リポジトリへの招待**も受けます。編集者は realtech-radio リポジトリの **Outside Collaborator（Write ロール）** として招待されます（組織メンバーになる必要はありません）。配信者に自分の GitHub ユーザー名を伝え、届いた招待（メールまたは GitHub の通知）の「Accept」を押してください。GitHub アカウントがない場合は https://github.com/ で先に作成します。

> まだ届いていないものがある場合は、管理者に依頼してください。

---

## 2. リポジトリを手元に持ってくる（git clone）

ターミナル（アプリケーション → ユーティリティ → ターミナル）を開いて、以下を 1 行ずつ実行します：

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/uzumaki-inc/realtech-radio.git
cd realtech-radio
```

> git が入っていない場合は、初回にインストールを促すダイアログが出るので「インストール」を選んでください。**インストールが終わったら、`git clone` の行からもう一度実行してください**（最初の実行は中断されています）。

---

## 3. セットアップスクリプトを実行する

必要な道具（静止画の切り出し・アップロードのツール）をまとめて整えます：

```bash
./scripts/setup.sh
```

- 何度実行しても安全です（導入済みのものはスキップされます）
- 「Homebrew が見つかりません」と表示されて止まった場合は、案内される公式ページ（https://brew.sh/ja/）の手順で Homebrew をインストールし、**ターミナルを開き直して `cd ~/src/realtech-radio` してから**もう一度実行してください
- 最後に残りの作業の一覧が表示されたら、次のステップに進んでください

---

## 4. 認証情報を設定する

1Password の「realtech-radio 配信用」を開いて見ながら、以下の 3 つを設定します。

### 4-1. 設定ファイルを作る（R2 Account ID）

1Password の「realtech-radio 配信用」に、**コピペ一発で設定できる手順**（`~/.config/realtech-radio/config` を作るコマンド）が書いてあります。そのメモを参照して、ターミナルに貼り付けて実行してください。

作れたか確認します。1Password の値と同じものが表示されればOKです：

```bash
cat ~/.config/realtech-radio/config
```

### 4-2. アップロードの認証を設定する

こちらも 1Password の「realtech-radio 配信用」に、**コピペ一発で設定できる手順**（`aws configure set` で Access Key ID / Secret Access Key を登録するコマンド）が書いてあります。そのメモを参照して、ターミナルに貼り付けて実行してください。

### 4-3. GitHub の認証を設定する（git push 用）

エピソード公開の最後の手順（`git push`）には GitHub の認証が必要です。

編集者は realtech-radio リポジトリの **Outside Collaborator（Write ロール）** として招待されているので、自分の GitHub アカウントでログインすれば、そのまま push できます（フォークや Pull Request は不要です）。手順 1 の招待（Accept 済み）を確認してから：

```bash
brew install gh
gh auth login
```

質問には「GitHub.com」→「HTTPS」→「Login with a web browser」の順に答え、ブラウザに表示される画面でコードを入力してログインします。自分の GitHub アカウントでログインしてください（Write ロールが付いているので、このリポジトリへ直接 push できます）。

---

## 5. 動作確認

もう一度セットアップスクリプトを実行して、すべて ✅ になる（完了メッセージが出る）ことを確認します：

```bash
./scripts/setup.sh
```

続いて、R2 に実際につながるかを確認します。次の 1 行を**そのまま**ターミナルに貼り付けて実行してください（書き換え不要）：

```bash
. ~/.config/realtech-radio/config && aws s3 ls "s3://${R2_BUCKET:-realtech-radio-audio}/episodes/" --profile r2 --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
```

エピソードの音声ファイルの一覧が表示されれば、準備完了です 🎉
エラーが出る場合は、手順 4 の設定値（Account ID / Access Key / Secret）を 1Password と見比べて見直してください。

エピソードの公開手順は [OPERATION.md](./OPERATION.md) を参照してください。
