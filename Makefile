# Rundeck with AWS Cognito - Makefile
# 便利なコマンドを提供します

.PHONY: help setup validate start stop restart logs status clean backup restore

# デフォルトターゲット
help: ## このヘルプメッセージを表示
	@echo "Rundeck with AWS Cognito - 利用可能なコマンド:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## AWS Cognitoリソースを自動作成
	@echo "🚀 AWS Cognitoセットアップを開始..."
	./scripts/setup-cognito.sh

validate: ## 設定ファイルと環境変数を検証
	@echo "🔍 設定検証を開始..."
	./scripts/validate-config.sh

start: ## サービスを起動
	@echo "🚀 サービスを起動中..."
	docker-compose up -d

stop: ## サービスを停止
	@echo "🛑 サービスを停止中..."
	docker-compose down

restart: ## サービスを再起動
	@echo "🔄 サービスを再起動中..."
	docker-compose down
	docker-compose up -d

logs: ## 全サービスのログを表示
	docker-compose logs -f

logs-nginx: ## Nginxのログを表示
	docker-compose logs -f nginx

logs-oauth2: ## OAuth2 Proxyのログを表示
	docker-compose logs -f oauth2-proxy

logs-rundeck: ## Rundeckのログを表示
	docker-compose logs -f rundeck

status: ## サービスの状態を確認
	@echo "📊 サービス状態:"
	docker-compose ps
	@echo ""
	@echo "🔌 ポート使用状況:"
	@ss -tuln | grep -E ':(80|4180|4440) ' || echo "対象ポートは使用されていません"

config: ## Docker Compose設定を確認
	docker-compose config

health: ## ヘルスチェックを実行
	@echo "🏥 ヘルスチェック実行中..."
	@echo "Nginx Health Check:"
	@curl -s http://localhost/health || echo "❌ Nginx接続失敗"
	@echo ""
	@echo "OAuth2 Proxy Ping:"
	@curl -s http://localhost:4180/ping || echo "❌ OAuth2 Proxy接続失敗"
	@echo ""
	@echo "Rundeck API:"
	@curl -s http://localhost:4440/api/14/system/info | jq -r '.system.rundeck.version' 2>/dev/null || echo "❌ Rundeck接続失敗"

clean: ## 停止してボリュームも削除（注意：データが削除されます）
	@echo "⚠️  警告: この操作はすべてのデータを削除します"
	@read -p "続行しますか？ (y/N): " confirm && [ "$$confirm" = "y" ]
	docker-compose down -v
	docker system prune -f

backup: ## Rundeckデータをバックアップ
	@echo "💾 Rundeckデータをバックアップ中..."
	@mkdir -p backups
	docker run --rm -v rundeck-data:/data -v $(PWD)/backups:/backup alpine tar czf /backup/rundeck-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz -C /data .
	@echo "✅ バックアップ完了: backups/rundeck-backup-$(shell date +%Y%m%d-%H%M%S).tar.gz"

restore: ## Rundeckデータをリストア（バックアップファイルを指定）
	@echo "📥 Rundeckデータをリストア中..."
	@if [ -z "$(FILE)" ]; then echo "❌ バックアップファイルを指定してください: make restore FILE=backups/rundeck-backup-YYYYMMDD-HHMMSS.tar.gz"; exit 1; fi
	@if [ ! -f "$(FILE)" ]; then echo "❌ ファイルが見つかりません: $(FILE)"; exit 1; fi
	docker-compose down
	docker run --rm -v rundeck-data:/data -v $(PWD):/backup alpine tar xzf /backup/$(FILE) -C /data
	docker-compose up -d
	@echo "✅ リストア完了"

dev: ## 開発モード（ログ付きで起動）
	docker-compose up

build: ## イメージを再ビルド
	docker-compose build --no-cache

update: ## イメージを更新
	docker-compose pull
	docker-compose up -d

env-example: ## .env.exampleから.envを作成
	@if [ ! -f .env ]; then cp .env.example .env && echo "✅ .envファイルを作成しました。値を編集してください。"; else echo "⚠️  .envファイルは既に存在します"; fi

# AWS関連のコマンド
aws-check: ## AWS CLI設定を確認
	@echo "☁️  AWS CLI設定確認:"
	@aws sts get-caller-identity || echo "❌ AWS CLIが設定されていません"

cognito-users: ## Cognitoユーザー一覧を表示
	@if [ -f .env ]; then source .env && aws cognito-idp list-users --user-pool-id $$COGNITO_USER_POOL_ID --region $$AWS_REGION; else echo "❌ .envファイルが見つかりません"; fi

cognito-groups: ## Cognitoグループ一覧を表示
	@if [ -f .env ]; then source .env && aws cognito-idp list-groups --user-pool-id $$COGNITO_USER_POOL_ID --region $$AWS_REGION; else echo "❌ .envファイルが見つかりません"; fi 