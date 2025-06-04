# Rundeck with AWS Cognito Authentication

このプロジェクトは、AWS CognitoでOAuth2認証を行い、**メールアドレスをユーザー名として使用する**Rundeckの設定です。

## 特徴

- ✅ AWS Cognito OAuth2認証
- ✅ メールアドレスをRundeckのユーザー名として使用
- ✅ Nginx + OAuth2 Proxy + Rundeck の構成
- ✅ Docker Composeによる簡単なデプロイ

## 必要な環境変数

`.env`ファイルを作成して以下の値を設定してください：

```bash
# AWS Cognito設定
AWS_REGION=your-aws-region
COGNITO_USER_POOL_ID=your-user-pool-id
COGNITO_CLIENT_ID=your-client-id
COGNITO_CLIENT_SECRET=your-client-secret

# OAuth2 Proxy設定
OAUTH2_PROXY_COOKIE_SECRET=your-32-char-secret
```

## AWS Cognito設定

### ユーザープールの作成

1. AWS Cognito コンソールで新しいユーザープールを作成
2. **「サインインオプション」で「メールアドレス」を選択**
3. 「ユーザー名の要件」で「メールアドレスをユーザー名として使用」を有効化

### アプリクライアントの設定

1. ユーザープール内でアプリクライアントを作成
2. 以下の設定を確認：
   - **クライアントシークレットを生成**: 有効
   - **許可されているOAuthフロー**: Authorization code grant
   - **許可されているOAuthスコープ**: openid, email, profile
   - **コールバックURL**: `http://localhost/oauth2/callback`

## 起動方法

```bash
# コンテナを起動
docker-compose up -d

# ログを確認
docker-compose logs -f
```

## アクセス

- Rundeck: <http://localhost>
- OAuth2 Proxy: <http://localhost:4180>
- Rundeck直接アクセス: <http://localhost:4440>

## 技術的な仕組み

### メールアドレスをユーザー名として使用する方法

1. **OAuth2 Proxy設定**:
   - `--prefer-email-to-user=true`: メールアドレスを優先
   - `--oidc-email-claim=email`: Cognitoのemailクレームを使用

2. **Nginx設定**:
   ```nginx
   # メールアドレスが利用可能な場合はそれを使用、そうでなければユーザーIDを使用
   map $upstream_http_x_auth_request_email $final_username {
       default $upstream_http_x_auth_request_email;
       "" $upstream_http_x_auth_request_user;
   }
   ```

3. **Rundeck設定**:
   - プリ認証モードを有効化
   - `X-Forwarded-User`ヘッダーからユーザー名を取得

### 認証フロー

1. ユーザーが `http://localhost` にアクセス
2. Nginxが認証をチェック（OAuth2 Proxy経由）
3. 未認証の場合、Cognitoログインページにリダイレクト
4. Cognitoでログイン成功後、OAuth2 Proxyがトークンを処理
5. Nginxがメールアドレスを`X-Forwarded-User`ヘッダーに設定
6. Rundeckがヘッダーからユーザー情報を取得してログイン

## トラブルシューティング

### データベースリセット

既存のユーザー情報をクリアしたい場合：

```bash
# Rundeckを停止
docker-compose stop rundeck

# データベースファイルを削除
docker run --rm -v saas-rundeck-v2_rundeck-data:/data alpine rm -f /data/grailsdb.*

# Rundeckを再起動
docker-compose start rundeck
```

### ログの確認

```bash
# OAuth2 Proxyのログ
docker logs rundeck-oauth2-proxy

# Nginxのログ
docker logs rundeck-nginx

# Rundeckのログ
docker logs rundeck-server
```

## セキュリティ考慮事項

- 本番環境では`OAUTH2_PROXY_COOKIE_SECRET`を安全に管理してください
- HTTPSを使用することを強く推奨します
- Cognitoのセキュリティ設定（MFA、パスワードポリシーなど）を適切に設定してください

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 🏗️ アーキテクチャ

```text
[ユーザー] → [Nginx] → [OAuth2 Proxy] → [AWS Cognito] → [Rundeck]
```

## 📦 構成

- **Nginx**: バージョン 1.28.0 (リバースプロキシ)
- **OAuth2 Proxy**: バージョン 7.4.0 (AWS Cognito OAuth2認証)
- **Rundeck**: バージョン 5.12.0-20250512 (ジョブスケジューラー)

## 📁 ファイル構成

```tree
.
├── docker-compose.yml          # Docker Composeファイル
├── config/
│   ├── nginx/
│   │   ├── nginx.conf         # Nginxメイン設定
│   │   └── conf.d/
│   │       └── rundeck.conf   # Rundeckプロキシ設定
│   └── rundeck/
│       ├── realm.properties   # Rundeck認証設定
│       └── acl/              # ACLポリシーファイル
│           ├── admin.aclpolicy
│           └── user.aclpolicy
├── scripts/
│   └── setup-cognito.sh      # Cognito自動セットアップスクリプト
├── .env.example              # 環境変数サンプル
└── README.md                 # このファイル
```

## 🚀 クイックスタート

### 1. AWS Cognitoの設定

自動セットアップスクリプトを使用：

```bash
# AWS CLIが設定済みであることを確認
aws sts get-caller-identity

# Cognitoリソースを自動作成
./scripts/setup-cognito.sh
```

または手動で設定：

1. [AWS Cognito Console](https://console.aws.amazon.com/cognito/) でユーザープールを作成
2. アプリクライアントを作成（クライアントシークレット有効）
3. OAuth 2.0設定：
   - コールバックURL: `http://localhost/oauth2/callback`
   - サインアウトURL: `http://localhost/oauth2/sign_out`
   - 許可タイプ: Authorization code grant
   - スコープ: openid, email, profile

### 2. 環境変数の設定

```bash
# .envファイルを作成
cp .env.example .env

# 必要に応じて値を編集
vim .env
```

### 3. サービスの起動

```bash
# Docker Composeを使用してサービスを起動
docker-compose up -d
```

### 4. アクセス

- **Rundeck**: [http://localhost](http://localhost) (Cognito認証経由)
- **Health Check**: [http://localhost/health](http://localhost/health)

## 🔧 設定詳細

### OAuth2 Proxy設定

OAuth2 Proxyは以下の設定で動作します：

- **プロバイダー**: OpenID Connect (AWS Cognito)
- **セッション**: Cookieベース（Redisなし）
- **認証ヘッダー**: X-Forwarded-User, X-Forwarded-Roles
- **グループクレーム**: cognito:groups

### Rundeck設定

Rundeckは事前認証モードで動作します：

- **認証**: OAuth2 Proxyからのヘッダー情報を使用
- **権限**: Cognitoグループに基づく権限マッピング
- **デフォルト権限**: 認証されたユーザーには`user`権限

### 権限マッピング

| Cognitoグループ | Rundeck権限 | 説明 |
|----------------|-------------|------|
| rundeck-admins | admin,user,architect,deploy,build | 管理者権限 |
| rundeck-users | user | 一般ユーザー権限 |
| rundeck-operators | user,deploy,build | 運用者権限 |
| rundeck-architects | user,architect | アーキテクト権限 |
| (なし) | user | デフォルト権限 |

## 🛠️ 管理コマンド

### Docker Composeを使用した管理

```bash
# サービス管理
docker-compose up -d        # サービス起動
docker-compose down         # サービス停止
docker-compose restart     # サービス再起動
docker-compose ps           # サービス状態確認

# ログ確認
docker-compose logs -f      # 全サービスのログ
docker-compose logs nginx   # Nginxのログ
docker-compose logs oauth2-proxy  # OAuth2 Proxyのログ
docker-compose logs rundeck # Rundeckのログ

# 設定確認
docker-compose config       # 設定確認

# データ管理
docker-compose exec rundeck tar -czf /tmp/backup.tar.gz /home/rundeck/server/data  # データバックアップ
docker cp $(docker-compose ps -q rundeck):/tmp/backup.tar.gz ./backup.tar.gz      # バックアップファイルをホストにコピー
```

## 🔍 トラブルシューティング

### 認証エラー

1. **Cognitoログイン後にRundeckログイン画面が表示される**
   ```bash
   # OAuth2 Proxyのログを確認
   docker-compose logs oauth2-proxy
   
   # Nginxのログを確認
   docker-compose logs nginx
   ```

2. **リダイレクトループが発生する**
   ```bash
   # ブラウザのCookieをクリア
   # プライベートブラウジングで試行
   
   # 設定確認
   docker-compose config
   ```

3. **権限エラーが発生する**
   ```bash
   # Rundeckのログを確認
   docker-compose logs rundeck
   
   # ACLポリシーを確認
   cat config/rundeck/acl/*.aclpolicy
   ```

### 設定確認

```bash
# サービス状態確認
docker-compose ps

# AWS CLI設定確認
aws sts get-caller-identity

# Cognito設定確認
aws cognito-idp describe-user-pool --user-pool-id $COGNITO_USER_POOL_ID
aws cognito-idp describe-user-pool-client --user-pool-id $COGNITO_USER_POOL_ID --client-id $COGNITO_CLIENT_ID

# ネットワーク確認
docker network inspect saas-rundeck-v2_rundeck-network
```

### よくあるエラー

| エラー | 原因 | 解決方法 |
|--------|------|----------|
| `invalid_client` | クライアントID/シークレットが間違い | .envファイルの値を確認 |
| `redirect_uri_mismatch` | コールバックURLが間違い | Cognitoの設定を確認 |
| `unauthorized_client` | OAuth設定が間違い | 許可タイプとスコープを確認 |
| `REJECTED_NO_SUBJECT_OR_ENV_FOUND` | ACLポリシーが間違い | ACLファイルを確認 |

## 🔒 セキュリティ注意事項

- **HTTPS**: 本番環境では必ずHTTPS設定を追加してください
- **Cookie Secret**: 十分に複雑なランダム文字列を使用してください
- **環境変数**: `.env`ファイルをバージョン管理に含めないでください
- **MFA**: 本番環境ではCognitoでMFAを有効化することを推奨します
- **ネットワーク**: 必要に応じてファイアウォール設定を追加してください

## 📚 参考資料

- [Rundeck Documentation](https://docs.rundeck.com/)
- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [AWS Cognito Documentation](https://docs.aws.amazon.com/cognito/)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🤝 サポート

問題が発生した場合は、以下の情報を含めてIssueを作成してください：

1. エラーメッセージ
2. 関連するログ出力
3. 環境情報（OS、Dockerバージョンなど）
4. 実行したコマンド

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています 
