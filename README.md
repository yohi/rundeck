# Rundeck with Nginx and AWS Cognito Authentication

このプロジェクトは、Docker ComposeでNginx、oauth2-proxy、RundeckでAWS Cognito認証を使用したセットアップです。

## 構成

- **Nginx**: バージョン 1.28.0 (リバースプロキシとして動作)
- **oauth2-proxy**: バージョン 7.4.0 (AWS Cognito OAuth2認証、Cookieベースセッションストレージ)
- **Rundeck**: バージョン 5.12.0-20250512 (ジョブスケジューラー)

## ファイル構成

```
.
├── compose-build.yaml          # Docker Composeファイル
├── nginx/
│   ├── nginx.conf             # Nginxメイン設定
│   └── conf.d/
│       └── rundeck.conf       # Rundeckプロキシ設定（OAuth2対応）
├── rundeck/
│   └── realm.properties       # Rundeck認証設定
├── scripts/
│   └── setup-cognito.sh       # Cognito自動セットアップスクリプト
├── env.example                # 環境変数サンプル
└── README.md                  # このファイル
```

## セッションストレージについて

このプロジェクトでは、oauth2-proxyのセッションストレージとしてCookieベースの方式を使用しています。これにより：

- **ステートレス**: oauth2-proxyは完全にステートレスで動作します
- **シンプル**: 外部のRedisサーバーが不要です
- **セキュア**: セッション情報はサーバーサイドで署名され、暗号化されてCookieに保存されます
- **スケーラブル**: 複数のoauth2-proxyインスタンスを簡単にスケールできます

## AWS Cognito認証の設定

### 1. AWS Cognitoでの設定

#### ユーザープールの作成

1. [AWS Cognito Console](https://console.aws.amazon.com/cognito/) にアクセス
2. 「ユーザープールを作成」をクリック
3. 以下の設定を行う：
   - **サインインオプション**: Email
   - **パスワードポリシー**: デフォルトまたは要件に応じて設定
   - **MFA**: 必要に応じて設定
   - **ユーザーアカウントの復旧**: Email

#### アプリクライアントの作成

1. 作成したユーザープールを選択
2. 「アプリの統合」タブに移動
3. 「アプリクライアント」セクションで「アプリクライアントを作成」
4. 以下の設定を行う：
   - **アプリタイプ**: 機密クライアント
   - **アプリクライアント名**: rundeck-oauth2
   - **クライアントシークレットを生成**: チェック
   - **認証フロー**: ALLOW_USER_SRP_AUTH, ALLOW_REFRESH_TOKEN_AUTH
5. 「OAuth 2.0 設定」で以下を設定：
   - **許可されているコールバック URL**: `http://localhost/oauth2/callback`
   - **許可されているサインアウト URL**: `http://localhost/oauth2/sign_out`
   - **OAuth 2.0 許可タイプ**: Authorization code grant
   - **OpenID Connect スコープ**: email, openid, profile

#### ドメイン名の設定

1. 「アプリの統合」タブの「ドメイン名」セクション
2. 「Cognitoドメインを作成」または「カスタムドメインを使用」
3. ドメイン名を設定（例: `your-app-name`）

### 2. 環境変数の設定

1. `env.example`を`.env`にコピー：
   ```bash
   cp env.example .env
   ```

2. `.env`ファイルを編集して実際の値を設定：
   ```bash
   # AWS Region
   AWS_REGION=ap-northeast-1
   
   # Cognito User Pool ID (ユーザープールの詳細画面で確認)
   COGNITO_USER_POOL_ID=ap-northeast-1_XXXXXXXXX
   
   # Cognito App Client ID
   COGNITO_CLIENT_ID=your-actual-client-id
   
   # Cognito App Client Secret
   COGNITO_CLIENT_SECRET=your-actual-client-secret
   
   # OAuth2 Proxy Cookie Secret
   OAUTH2_PROXY_COOKIE_SECRET=your-32-character-random-string
   ```

3. Cookie Secretの生成：
   ```bash
   openssl rand -base64 32 | head -c 32
   ```

## 使用方法

### 1. サービスの起動

```bash
docker-compose -f compose-build.yaml up -d
```

### 2. サービスの確認

```bash
docker-compose -f compose-build.yaml ps
```

### 3. ログの確認

```bash
# 全サービスのログ
docker-compose -f compose-build.yaml logs -f

# 特定のサービスのログ
docker-compose -f compose-build.yaml logs -f nginx
docker-compose -f compose-build.yaml logs -f oauth2-proxy
docker-compose -f compose-build.yaml logs -f rundeck
```

### 4. アクセス

- **Rundeck Web UI**: http://localhost (AWS Cognito認証経由)
- **OAuth2 Proxy**: http://localhost:4180 (直接アクセス)
- **Rundeck直接アクセス**: http://localhost:4440 (認証なし)
- **Nginx Health Check**: http://localhost/health

### 5. サービスの停止

```bash
docker-compose -f compose-build.yaml down
```

### 6. データの削除（注意：全データが削除されます）

```bash
docker-compose -f compose-build.yaml down -v
```

## 認証の仕組み

1. ユーザーがRundeckにアクセス
2. Nginxがoauth2-proxyに認証をリクエスト
3. 未認証の場合、Cognitoログイン画面にリダイレクト
4. Cognito認証成功後、oauth2-proxyがユーザー情報をヘッダーに設定
5. RundeckがPreauthenticated Modeでユーザー情報を受け取り

## ユーザー権限の設定

`rundeck/realm.properties`でユーザーの権限を設定できます：

```properties
# 管理者権限
admin: admin,user,architect,deploy,build

# 一般ユーザー権限
user: user
```

認証されたすべてのCognitoユーザーには`admin`権限が付与されます。

## Cognitoユーザーの管理

### ユーザーの作成

1. AWS Cognito Consoleでユーザープールを選択
2. 「ユーザー」タブに移動
3. 「ユーザーを作成」をクリック
4. ユーザー情報を入力

### グループの作成と権限管理

1. 「グループ」タブに移動
2. 「グループを作成」をクリック
3. グループ名を設定（例: `rundeck-admins`, `rundeck-users`）
4. ユーザーをグループに追加

### グループベースの権限制御

oauth2-proxyの設定でグループベースの制御も可能です：

```yaml
command:
  - --provider=oidc
  - --oidc-groups-claim=cognito:groups
  - --allowed-group=rundeck-admins  # 特定のグループのみ許可
  # その他の設定...
```

## 高度な設定

### MFA（多要素認証）の有効化

1. ユーザープールの設定で「MFA」を有効化
2. SMS、TOTP、またはその両方を設定
3. ユーザーは初回ログイン時にMFAデバイスを設定

### カスタム属性の追加

1. ユーザープールの「属性」設定で カスタム属性を追加
2. oauth2-proxyの設定でカスタム属性をヘッダーに渡すよう設定

### パスワードポリシーの設定

1. ユーザープールの「パスワードポリシー」で要件を設定
2. 最小長、文字種類、有効期限などを設定

## データの永続化

以下のボリュームでデータが永続化されます：
- `rundeck-data`: Rundeckのデータベース
- `rundeck-projects`: プロジェクトファイル
- `rundeck-logs`: ログファイル
- `rundeck-plugins`: プラグインファイル

注意: oauth2-proxyはCookieベースのセッションストレージを使用するため、セッションデータの永続化は不要です。

## トラブルシューティング

### Cognito認証が失敗する場合

1. AWS Cognitoの設定確認
   - ユーザープールIDが正しいか
   - アプリクライアントIDとシークレットが正しいか
   - コールバックURLが正しく設定されているか
   - OAuth 2.0スコープが適切に設定されているか

2. 環境変数の確認
   ```bash
   docker-compose -f compose-build.yaml config
   ```

3. oauth2-proxyのログ確認
   ```bash
   docker-compose -f compose-build.yaml logs oauth2-proxy
   ```

4. Cognitoのログ確認
   - CloudWatchでCognitoのログを確認

5. デバッグスクリプトの実行
   ```bash
   ./scripts/debug-oauth.sh
   ```

### callbackエラーの対処法

#### Cookie関連のエラー
- ブラウザのCookieとキャッシュをクリア
- プライベートブラウジングモードで試行
- 別のブラウザで試行

#### 設定確認
```bash
# 設定の確認
docker-compose -f compose-build.yaml config

# oauth2-proxyの詳細ログ
docker-compose -f compose-build.yaml logs -f oauth2-proxy

# nginxのログ確認
docker-compose -f compose-build.yaml logs -f nginx
```

#### Cognitoアプリクライアント設定の確認
1. AWS Cognito Console → ユーザープール → アプリの統合 → アプリクライアント
2. 以下の設定を確認：
   - **クライアントシークレットを生成**: ✅ チェック済み
   - **認証フロー**: `ALLOW_USER_SRP_AUTH`, `ALLOW_REFRESH_TOKEN_AUTH`
   - **OAuth 2.0 許可タイプ**: `Authorization code grant`
   - **OpenID Connect スコープ**: `email`, `openid`, `profile`
   - **許可されているコールバック URL**: `http://localhost/oauth2/callback`
   - **許可されているサインアウト URL**: `http://localhost/oauth2/sign_out`

#### サービスの再起動
```bash
# 完全な再起動
docker-compose -f compose-build.yaml down
docker-compose -f compose-build.yaml up -d

# ログの監視
docker-compose -f compose-build.yaml logs -f
```

### よくあるエラー

#### "invalid_client" エラー
- アプリクライアントIDまたはシークレットが間違っている
- アプリクライアントの設定で「クライアントシークレットを生成」がチェックされていない

#### "redirect_uri_mismatch" エラー
- Cognitoのコールバック URL設定が間違っている
- `http://localhost/oauth2/callback` が正しく設定されているか確認

#### "unauthorized_client" エラー
- OAuth 2.0 許可タイプが正しく設定されていない
- 「Authorization code grant」が有効になっているか確認

### サービスが起動しない場合

1. ポートの競合を確認
   ```bash
   sudo netstat -tlnp | grep :80
   sudo netstat -tlnp | grep :4180
   sudo netstat -tlnp | grep :4440
   ```

2. Dockerイメージの確認
   ```bash
   docker images | grep nginx
   docker images | grep oauth2-proxy
   docker images | grep rundeck
   ```

3. ログの確認
   ```bash
   docker-compose -f compose-build.yaml logs
   ```

### Rundeckにアクセスできない場合

1. コンテナの状態確認
   ```bash
   docker-compose -f compose-build.yaml ps
   ```

2. ネットワーク接続の確認
   ```bash
   docker network ls
   docker network inspect saas-rundeck-v2_rundeck-network
   ```

## セキュリティ注意事項

- 本設定はHTTPのみです（HTTPSは設定されていません）
- 本番環境では適切なHTTPS設定を追加してください
- `.env`ファイルは機密情報を含むため、バージョン管理に含めないでください
- Cookie Secretは十分に複雑なランダム文字列を使用してください
- Cognitoのパスワードポリシーを適切に設定してください
- 必要に応じてMFAを有効化してください 