#!/bin/bash

# OAuth2 Debug Script for Rundeck
# このスクリプトはOAuth2認証の問題をデバッグするためのツールです

echo "🔍 OAuth2認証デバッグ情報"
echo "=========================="

# 環境変数の確認
echo "📋 環境変数の確認:"
if [ -f .env ]; then
    echo "✅ .envファイルが存在します"
    echo "設定されている変数:"
    grep -E "^(AWS_REGION|COGNITO_USER_POOL_ID|COGNITO_CLIENT_ID|OAUTH2_PROXY_COOKIE_SECRET)=" .env | sed 's/=.*/=***/'
else
    echo "❌ .envファイルが見つかりません"
fi

echo ""

# Docker Composeの設定確認
echo "🐳 Docker Compose設定の確認:"
docker-compose -f compose-build.yaml config --quiet && echo "✅ Docker Compose設定は有効です" || echo "❌ Docker Compose設定にエラーがあります"

echo ""

# サービスの状態確認
echo "🚀 サービスの状態:"
docker-compose -f compose-build.yaml ps

echo ""

# oauth2-proxyの設定確認
echo "🔐 oauth2-proxy設定の確認:"
echo "oauth2-proxyコンテナの環境変数:"
docker exec oauth2-proxy env | grep -E "(OAUTH2_PROXY|AWS_REGION|COGNITO)" | sed 's/=.*/=***/' || echo "❌ oauth2-proxyコンテナが起動していません"

echo ""

# Cognitoエンドポイントの確認
echo "🌐 Cognitoエンドポイントの確認:"
if [ ! -z "$AWS_REGION" ] && [ ! -z "$COGNITO_USER_POOL_ID" ]; then
    OIDC_ENDPOINT="https://cognito-idp.${AWS_REGION}.amazonaws.com/${COGNITO_USER_POOL_ID}/.well-known/openid_configuration"
    echo "OIDC Discovery URL: $OIDC_ENDPOINT"
    
    # OIDC Discovery エンドポイントの確認
    if command -v curl >/dev/null 2>&1; then
        echo "OIDC Discovery エンドポイントのテスト:"
        curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$OIDC_ENDPOINT" || echo "❌ OIDC Discovery エンドポイントにアクセスできません"
    else
        echo "⚠️  curlが利用できないため、エンドポイントのテストをスキップします"
    fi
else
    echo "❌ AWS_REGIONまたはCOGNITO_USER_POOL_IDが設定されていません"
fi

echo ""

# ログの確認
echo "📝 最新のログ (oauth2-proxy):"
echo "最新の10行:"
docker-compose -f compose-build.yaml logs --tail=10 oauth2-proxy

echo ""
echo "📝 最新のログ (nginx):"
echo "最新の5行:"
docker-compose -f compose-build.yaml logs --tail=5 nginx

echo ""

# 接続テスト
echo "🔗 接続テスト:"
echo "localhost:80への接続テスト:"
if command -v curl >/dev/null 2>&1; then
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://localhost/" || echo "❌ localhostに接続できません"
    
    echo "oauth2-proxy直接接続テスト:"
    curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "http://localhost:4180/oauth2/sign_in" || echo "❌ oauth2-proxyに直接接続できません"
else
    echo "⚠️  curlが利用できないため、接続テストをスキップします"
fi

echo ""
echo "🎯 トラブルシューティングのヒント:"
echo "1. .envファイルに正しい値が設定されているか確認してください"
echo "2. Cognitoのコールバック URLが 'http://localhost/oauth2/callback' に設定されているか確認してください"
echo "3. Cognitoアプリクライアントで 'Authorization code grant' が有効になっているか確認してください"
echo "4. ブラウザのCookieをクリアしてから再度試してください"
echo "5. ログでエラーメッセージを確認してください: docker-compose -f compose-build.yaml logs oauth2-proxy" 