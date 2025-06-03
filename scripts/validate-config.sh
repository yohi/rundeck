#!/bin/bash

# Configuration Validation Script for Rundeck with Cognito
# このスクリプトは設定ファイルと環境変数を検証します

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

# エラーカウンター
ERROR_COUNT=0

log_info "🔍 Rundeck with Cognito設定検証を開始します..."

# .envファイルの存在確認
if [ ! -f ".env" ]; then
    log_error ".envファイルが見つかりません"
    log_info "以下のコマンドで作成してください: cp .env.example .env"
    ((ERROR_COUNT++))
else
    log_success ".envファイルが存在します"
    
    # 環境変数の読み込み
    source .env
    
    # 必須環境変数の確認
    log_info "📋 環境変数を確認中..."
    
    if [ -z "$AWS_REGION" ]; then
        log_error "AWS_REGIONが設定されていません"
        ((ERROR_COUNT++))
    else
        log_success "AWS_REGION: $AWS_REGION"
    fi
    
    if [ -z "$COGNITO_USER_POOL_ID" ]; then
        log_error "COGNITO_USER_POOL_IDが設定されていません"
        ((ERROR_COUNT++))
    else
        log_success "COGNITO_USER_POOL_ID: $COGNITO_USER_POOL_ID"
    fi
    
    if [ -z "$COGNITO_CLIENT_ID" ]; then
        log_error "COGNITO_CLIENT_IDが設定されていません"
        ((ERROR_COUNT++))
    else
        log_success "COGNITO_CLIENT_ID: $COGNITO_CLIENT_ID"
    fi
    
    if [ -z "$COGNITO_CLIENT_SECRET" ]; then
        log_error "COGNITO_CLIENT_SECRETが設定されていません"
        ((ERROR_COUNT++))
    else
        log_success "COGNITO_CLIENT_SECRET: [設定済み]"
    fi
    
    if [ -z "$OAUTH2_PROXY_COOKIE_SECRET" ]; then
        log_error "OAUTH2_PROXY_COOKIE_SECRETが設定されていません"
        ((ERROR_COUNT++))
    else
        if [ ${#OAUTH2_PROXY_COOKIE_SECRET} -lt 32 ]; then
            log_warning "OAUTH2_PROXY_COOKIE_SECRETは32文字以上を推奨します"
        else
            log_success "OAUTH2_PROXY_COOKIE_SECRET: [設定済み]"
        fi
    fi
fi

# 設定ファイルの存在確認
log_info "📁 設定ファイルを確認中..."

CONFIG_FILES=(
    "config/nginx/nginx.conf"
    "config/nginx/conf.d/rundeck.conf"
    "config/rundeck/realm.properties"
    "config/rundeck/acl/admin.aclpolicy"
    "config/rundeck/acl/user.aclpolicy"
    "docker-compose.yml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        log_error "設定ファイルが見つかりません: $file"
        ((ERROR_COUNT++))
    else
        log_success "設定ファイル確認: $file"
    fi
done

# Docker Composeファイルの構文確認
log_info "🐳 Docker Compose設定を確認中..."
if command -v docker-compose &> /dev/null; then
    if docker-compose config > /dev/null 2>&1; then
        log_success "Docker Compose設定は正常です"
    else
        log_error "Docker Compose設定にエラーがあります"
        ((ERROR_COUNT++))
    fi
else
    log_warning "docker-composeコマンドが見つかりません"
fi

# AWS CLIの確認（オプション）
log_info "☁️  AWS CLI設定を確認中..."
if command -v aws &> /dev/null; then
    if aws sts get-caller-identity &> /dev/null; then
        log_success "AWS CLIが正しく設定されています"
        
        # Cognitoリソースの確認（環境変数が設定されている場合）
        if [ ! -z "$COGNITO_USER_POOL_ID" ] && [ "$COGNITO_USER_POOL_ID" != "ap-northeast-1_XXXXXXXXX" ]; then
            log_info "🔍 Cognitoリソースを確認中..."
            if aws cognito-idp describe-user-pool --user-pool-id "$COGNITO_USER_POOL_ID" --region "$AWS_REGION" &> /dev/null; then
                log_success "Cognitoユーザープールが存在します"
            else
                log_error "Cognitoユーザープールが見つかりません: $COGNITO_USER_POOL_ID"
                ((ERROR_COUNT++))
            fi
            
            if [ ! -z "$COGNITO_CLIENT_ID" ] && [ "$COGNITO_CLIENT_ID" != "your-cognito-app-client-id" ]; then
                if aws cognito-idp describe-user-pool-client --user-pool-id "$COGNITO_USER_POOL_ID" --client-id "$COGNITO_CLIENT_ID" --region "$AWS_REGION" &> /dev/null; then
                    log_success "Cognitoアプリクライアントが存在します"
                else
                    log_error "Cognitoアプリクライアントが見つかりません: $COGNITO_CLIENT_ID"
                    ((ERROR_COUNT++))
                fi
            fi
        fi
    else
        log_warning "AWS CLIの認証が設定されていません"
    fi
else
    log_warning "AWS CLIがインストールされていません"
fi

# ポートの使用状況確認
log_info "🔌 ポート使用状況を確認中..."
PORTS=(80 4180 4440)

for port in "${PORTS[@]}"; do
    if command -v netstat &> /dev/null; then
        if netstat -tuln | grep ":$port " &> /dev/null; then
            log_warning "ポート $port は既に使用されています"
        else
            log_success "ポート $port は利用可能です"
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln | grep ":$port " &> /dev/null; then
            log_warning "ポート $port は既に使用されています"
        else
            log_success "ポート $port は利用可能です"
        fi
    else
        log_warning "ポート確認ツールが見つかりません（netstat または ss）"
        break
    fi
done

# 結果の表示
echo ""
if [ $ERROR_COUNT -eq 0 ]; then
    log_success "🎉 すべての検証が完了しました！エラーはありません。"
    echo ""
    log_info "📋 次のステップ:"
    echo "1. docker-compose up -d でサービスを起動"
    echo "2. http://localhost でアクセス"
    echo "3. Cognitoログインでアクセス確認"
else
    log_error "❌ $ERROR_COUNT 個のエラーが見つかりました。"
    echo ""
    log_info "📋 修正が必要な項目:"
    echo "- 上記のエラーメッセージを確認してください"
    echo "- 設定ファイルや環境変数を修正してください"
    echo "- 修正後、再度このスクリプトを実行してください"
    exit 1
fi 