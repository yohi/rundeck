#!/bin/bash

echo "=== Rundeck OAuth2 認証テスト ==="
echo

echo "1. http://localhost へのアクセステスト"
echo "期待値: OAuth2 start へのリダイレクト"
curl -s -I http://localhost | grep -E "(HTTP|Location)"
echo

echo "2. OAuth2 start エンドポイントのテスト"
echo "期待値: Cognito認証ページへのリダイレクト"
curl -s -I "http://localhost/oauth2/start?rd=/" | grep -E "(HTTP|Location)" | head -2
echo

echo "3. サービス状態の確認"
docker-compose -f compose-build.yaml ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo

echo "4. Rundeckの起動状況確認"
if docker-compose -f compose-build.yaml logs rundeck | grep -q "Started Application"; then
    echo "✅ Rundeck起動完了"
else
    echo "⏳ Rundeck起動中..."
fi
echo

echo "5. OAuth2 Proxy の状態確認"
if docker-compose -f compose-build.yaml logs oauth2-proxy | grep -q "OAuthProxy configured"; then
    echo "✅ OAuth2 Proxy設定完了"
else
    echo "❌ OAuth2 Proxy設定エラー"
fi
echo

echo "=== テスト完了 ==="
echo "ブラウザで http://localhost にアクセスして、Cognitoログインページが表示されることを確認してください。" 