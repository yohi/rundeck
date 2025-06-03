#!/bin/bash

# AWS Cognito Setup Script for Rundeck
# このスクリプトはAWS CLIを使用してCognitoユーザープールとアプリクライアントを作成します

set -e

# 色付きログ出力用の関数
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

log_warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# 設定値
USER_POOL_NAME="rundeck-users"
APP_CLIENT_NAME="rundeck-oauth2"
DOMAIN_PREFIX="rundeck-auth-$(date +%s)"
AWS_REGION="${AWS_REGION:-ap-northeast-1}"

log_info "🚀 Rundeck用のCognitoセットアップを開始します..."
log_info "Region: $AWS_REGION"

# AWS CLIの確認
if ! command -v aws &> /dev/null; then
    log_error "AWS CLIがインストールされていません"
    exit 1
fi

# AWS認証の確認
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS認証が設定されていません。aws configure を実行してください"
    exit 1
fi

# ユーザープールの作成
log_info "📝 ユーザープールを作成中..."
USER_POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name "$USER_POOL_NAME" \
  --region "$AWS_REGION" \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  }' \
  --auto-verified-attributes email \
  --username-attributes email \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    },
    {
      "Name": "given_name",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    },
    {
      "Name": "family_name",
      "AttributeDataType": "String",
      "Required": false,
      "Mutable": true
    }
  ]' \
  --query 'UserPool.Id' \
  --output text)

log_success "✅ ユーザープールが作成されました: $USER_POOL_ID"

# アプリクライアントの作成
log_info "📱 アプリクライアントを作成中..."
APP_CLIENT_RESPONSE=$(aws cognito-idp create-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-name "$APP_CLIENT_NAME" \
  --region "$AWS_REGION" \
  --generate-secret \
  --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --supported-identity-providers COGNITO \
  --callback-urls "http://localhost/oauth2/callback" \
  --logout-urls "http://localhost/oauth2/sign_out" \
  --allowed-o-auth-flows code \
  --allowed-o-auth-scopes openid email profile \
  --allowed-o-auth-flows-user-pool-client \
  --prevent-user-existence-errors ENABLED)

APP_CLIENT_ID=$(echo "$APP_CLIENT_RESPONSE" | jq -r '.UserPoolClient.ClientId')

# クライアントシークレットの取得
APP_CLIENT_SECRET=$(aws cognito-idp describe-user-pool-client \
  --user-pool-id "$USER_POOL_ID" \
  --client-id "$APP_CLIENT_ID" \
  --region "$AWS_REGION" \
  --query 'UserPoolClient.ClientSecret' \
  --output text)

log_success "✅ アプリクライアントが作成されました: $APP_CLIENT_ID"

# ドメインの作成
log_info "🌐 Cognitoドメインを作成中..."
if aws cognito-idp create-user-pool-domain \
  --domain "$DOMAIN_PREFIX" \
  --user-pool-id "$USER_POOL_ID" \
  --region "$AWS_REGION" &> /dev/null; then
    log_success "✅ ドメインが作成されました: $DOMAIN_PREFIX"
else
    log_warning "⚠️  ドメインの作成に失敗しました。既存のドメインを使用するか、手動で設定してください"
fi

# グループの作成
log_info "👥 Cognitoグループを作成中..."

# 管理者グループ
if aws cognito-idp create-group \
  --group-name "rundeck-admins" \
  --user-pool-id "$USER_POOL_ID" \
  --description "Rundeck管理者グループ - 全権限" \
  --region "$AWS_REGION" &> /dev/null; then
    log_success "✅ rundeck-adminsグループが作成されました"
else
    log_warning "⚠️  rundeck-adminsグループが既に存在します"
fi

# 一般ユーザーグループ
if aws cognito-idp create-group \
  --group-name "rundeck-users" \
  --user-pool-id "$USER_POOL_ID" \
  --description "Rundeck一般ユーザーグループ - 読み取り・実行権限" \
  --region "$AWS_REGION" &> /dev/null; then
    log_success "✅ rundeck-usersグループが作成されました"
else
    log_warning "⚠️  rundeck-usersグループが既に存在します"
fi

# 運用者グループ
if aws cognito-idp create-group \
  --group-name "rundeck-operators" \
  --user-pool-id "$USER_POOL_ID" \
  --description "Rundeck運用者グループ - デプロイ・ビルド権限" \
  --region "$AWS_REGION" &> /dev/null; then
    log_success "✅ rundeck-operatorsグループが作成されました"
else
    log_warning "⚠️  rundeck-operatorsグループが既に存在します"
fi

# アーキテクトグループ
if aws cognito-idp create-group \
  --group-name "rundeck-architects" \
  --user-pool-id "$USER_POOL_ID" \
  --description "Rundeckアーキテクトグループ - 設計・管理権限" \
  --region "$AWS_REGION" &> /dev/null; then
    log_success "✅ rundeck-architectsグループが作成されました"
else
    log_warning "⚠️  rundeck-architectsグループが既に存在します"
fi

# Cookie Secretの生成
log_info "🔐 OAuth2 Proxy Cookie Secretを生成中..."
COOKIE_SECRET=$(openssl rand -base64 32 | head -c 32)

# .envファイルの作成
log_info "📄 .envファイルを作成中..."
cat > .env << EOF
# AWS Cognito OAuth2 Settings
# Generated by setup-cognito.sh on $(date)

# AWS Region
AWS_REGION=$AWS_REGION

# Cognito User Pool ID
COGNITO_USER_POOL_ID=$USER_POOL_ID

# Cognito App Client ID
COGNITO_CLIENT_ID=$APP_CLIENT_ID

# Cognito App Client Secret
COGNITO_CLIENT_SECRET=$APP_CLIENT_SECRET

# OAuth2 Proxy Cookie Secret
OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET
EOF

log_success "✅ .envファイルが作成されました"

# 結果の表示
echo ""
log_success "🎉 Cognitoセットアップが完了しました！"
echo ""
echo "================================================"
echo "設定情報:"
echo "================================================"
echo "AWS_REGION=$AWS_REGION"
echo "COGNITO_USER_POOL_ID=$USER_POOL_ID"
echo "COGNITO_CLIENT_ID=$APP_CLIENT_ID"
echo "COGNITO_CLIENT_SECRET=$APP_CLIENT_SECRET"
echo "OAUTH2_PROXY_COOKIE_SECRET=$COOKIE_SECRET"
echo "================================================"
echo ""
log_info "📋 次のステップ："
echo "1. .envファイルが自動作成されました"
echo "2. AWS Cognito Consoleでユーザーを作成してください"
echo "3. 必要に応じてユーザーをグループに追加してください"
echo "4. docker-compose up -d でサービスを起動してください"
echo ""
log_info "🔗 Cognito Console URL:"
echo "https://console.aws.amazon.com/cognito/v2/idp/user-pools/$USER_POOL_ID/users?region=$AWS_REGION"
echo ""
log_info "👥 作成されたグループ:"
echo "- rundeck-admins: 管理者権限（全機能アクセス）"
echo "- rundeck-users: 一般ユーザー権限（読み取り・実行）"
echo "- rundeck-operators: 運用者権限（デプロイ・ビルド）"
echo "- rundeck-architects: アーキテクト権限（設計・管理）"
echo ""
log_warning "⚠️  重要な注意事項:"
echo "- .envファイルには機密情報が含まれています"
echo "- .envファイルをバージョン管理に含めないでください"
echo "- 本番環境では適切なHTTPS設定を追加してください" 