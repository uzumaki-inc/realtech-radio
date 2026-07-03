# Cloudflare R2 セットアップガイド（管理者向け）

リアルテックラジオの音声ホスティング（Cloudflare R2）の構築と、アップロード用トークンの運用手順です。

**対象**: 配信基盤を管理するエンジニア（管理者）。編集者はこの資料を読む必要はありません（編集者のセットアップは [ONBOARDING.md](./ONBOARDING.md) へ）。

**この資料が必要になるとき**:

- 編集者を追加するとき → [編集者共有用トークンの発行と受け渡し](#編集者共有用トークンの発行と受け渡し)
- 編集者が離れるとき・トークンが漏洩/失効したとき → [メンバーが離れるとき](#メンバーが離れるとき)
- 配信基盤をゼロから作り直すとき（引き継ぎ・災害復旧） → [初期構築](#初期構築ゼロから作り直すとき)
- 独自ドメインでの配信に移行したいとき → [カスタムドメインの設定](#カスタムドメインの設定オプション)

構築済みの現在の設定値（Account ID・公開 URL・トークン名）は [CLAUDE.md](./CLAUDE.md) の「配信基盤」を参照。

---

## 初期構築（ゼロから作り直すとき）

現在の基盤は構築済みです。この節は、引き継ぎや災害復旧でバケットを作り直すときだけ使います。

### 1. Cloudflare アカウントとダッシュボード

- https://dash.cloudflare.com/ にログイン（アカウントがなければ作成。無料プランで十分）
- 左メニュー「Storage & databases」→「R2 object storage」

### 2. バケットを作成

- 「Overview」→「Create bucket」
- バケット名: `realtech-radio-audio` ／ リージョン: 自動（APAC）でOK
- フォルダ構成は publish.sh が自動で作ります：

  ```
  realtech-radio-audio/
  └── episodes/
      ├── 0001.mp3   ← 旧フロー時代のエピソード（0001〜0006）は mp3
      ├── 0007.m4a   ← 現行フローは m4a を直接ホスト
      └── ...
  ```

### 3. パブリックアクセスを有効化

デフォルトでは R2 は非公開なので、リスナーが音声を再生できるように公開します。

- バケット →「Settings」→「Public Development URL」の「Enable」
- 確認ダイアログのテキストフィールドに `allow` と入力して「Allow」
- 表示された `https://pub-xxxx.r2.dev` 形式の公開 URL を控え、`scripts/publish.sh` の `PUBLIC_BASE_URL` と `podcast.yaml` に反映する
- ※ この URL はレート制限あり。リスナーが増えたら「Custom Domains」への移行を推奨

### 4. CORS 設定（必須）

- 「Settings」→「CORS Policy」→「+ Add」で JSON エディタを開き、以下に書き換えて保存：

  ```json
  [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"]
    }
  ]
  ```

### 5. 管理者用アップロードトークンを発行

publish.sh（AWS CLI）でアップロードするための S3 互換トークンです。

- R2 →「API Tokens」→「Create API token」
- Token name: `realtech-radio-upload`
- トークン種別: 「S3 Compatible」／ 権限: **Object Read & Write**
- 表示された **Access Key ID / Secret Access Key** を保管する（この画面を離れると再表示不可）
- あわせて **Account ID**（ダッシュボード右上のプロフィール → Account details）も控える

手元の Mac の設定は `./scripts/setup.sh` の案内に沿えば完了します（設定ファイル作成＋認証設定＋R2 接続確認）。

---

## 編集者共有用トークンの発行と受け渡し

エピソード公開作業を編集者に共有する場合の手順です。

### 専用トークンを発行する

**既存のキー（`realtech-radio-upload` など自分用のトークン）は使い回さず、共有用に専用のトークンを発行します。**
共有用トークンの更新・失効を、自分用のキーに影響を与えずに行えるようにするためです。

作成手順は上の「[管理者用アップロードトークンを発行](#5-管理者用アップロードトークンを発行)」と同じ（トークン種別: S3 Compatible、権限: **Object Read & Write**）。以下の 2 点だけ変えます：

- Token name: `realtech-radio-backoffice`（用途が分かる名前にする）
- Specify bucket: **`realtech-radio-audio` のみ**に限定（「Apply to all buckets」にしない）

表示された **Access Key ID / Secret Access Key** をメモします（この画面を離れると再表示不可）。

### 1Password に登録する

発行したキーは、共有 Vault に以下の内容で登録します：

- **アイテム名**: `realtech-radio 配信用`
- **登録する 3 点**: R2 Account ID ／ Access Key ID ／ Secret Access Key
  - バケット名（`realtech-radio-audio`）は 1Password には入れない（publish.sh に標準値があるため不要）
- **メモ欄**: 用途（`publish.sh` での音声アップロード用）と、セットアップ手順は [ONBOARDING.md](./ONBOARDING.md) を参照、と記載

メンバーには Vault 共有で渡し、Slack やメールでは送らない運用とします。

### メンバーが離れるとき

トークンは共有制のため、**失効だけでなく更新（ローテーション）までがセット**です。失効したまま放置すると、残りのメンバー全員の publish.sh が動かなくなります。

1. 1Password の Vault 共有を解除する
2. 共有トークンをローテーションする：
   - Cloudflare → R2 → API Tokens → `realtech-radio-backoffice` を「Roll」（または Delete して再発行）
   - 新しい Access Key ID / Secret Access Key を 1Password のアイテムに上書き登録する
   - 残りのメンバーに、1Password の新しい値での認証再設定（[ONBOARDING.md](./ONBOARDING.md) の 4-2）を依頼する（設定ファイルの変更は不要）

---

## 音声のアップロードと公開 URL

通常運用では `./scripts/publish.sh` がアップロードから `meta.yaml` の自動記入まで行います（手順は [OPERATION.md](./OPERATION.md)）。管理者が単発で操作したいときは：

- **ダッシュボード**: バケット →「Upload」からファイルを選択
- **AWS CLI**:

  ```bash
  aws s3 cp 0007.m4a \
    s3://realtech-radio-audio/episodes/0007.m4a \
    --profile r2 \
    --endpoint-url https://<ACCOUNT_ID>.r2.cloudflarestorage.com
  ```

**リスナーに配信される URL は公開 URL（Public Development URL）のほうです**：

```
https://pub-2723121c04be418c8520405cedf4afee.r2.dev/episodes/0007.m4a
```

S3 エンドポイント（`<ACCOUNT_ID>.r2.cloudflarestorage.com`）は認証付きのアップロード用で、リスナーは再生できません。`meta.yaml` の `audio_url` には必ず公開 URL を書きます（publish.sh が自動記入するので、通常は意識不要）。

---

## カスタムドメインの設定（オプション）

`media.uzumaki-inc.jp` のような独自ドメインで配信したい場合：

1. R2 バケット → Settings → Custom Domains → Add domain
2. ドメイン名を入力し、案内される DNS 設定を行う
3. 移行時は `scripts/publish.sh` の `PUBLIC_BASE_URL` と、配信済みエピソードの `meta.yaml`（`audio_url`）を更新してフィードを再生成する

> ⚠️ R2 のカスタムドメインは、対象ドメインの DNS ゾーンが同じ Cloudflare アカウントで管理されている必要があります（現在 `uzumaki-inc.jp` の DNS は Squarespace 管理のため、移行時は DNS 移管の検討が必要）。着手前に Cloudflare 公式ドキュメントで最新仕様を確認してください。

必須ではありません。現在は Public Development URL（`pub-*.r2.dev`）で配信しています。
