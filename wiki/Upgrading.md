# アップグレードガイド

このドキュメントでは、INTMAX Node Monitoringシステムのアップグレード方法を説明します。

---

## アップグレード前に

### データをバックアップ

アップグレード前に必ずバックアップを作成：

```bash
# 設定ファイルをバックアップ
cp server/.env server/.env.backup
cp server/prometheus/targets/builders.yml server/prometheus/targets/builders.yml.backup

# Grafanaダッシュボードをバックアップ（カスタマイズしている場合）
cp -r grafana/dashboards grafana/dashboards.backup

# オプション：Prometheusデータをバックアップ
docker compose exec prometheus tar -czf /tmp/prom-backup.tar.gz /prometheus
docker compose cp prometheus:/tmp/prom-backup.tar.gz ./prom-backup.tar.gz
```

### 現在のバージョンを確認

```bash
# 現在のコミットを確認
git log -1 --oneline

# 実行中のDockerイメージを確認
docker compose images
```

---

## アップグレード方法

### 方法1: Git Pull（推奨）

ほとんどのアップグレードの場合：

```bash
cd intmax-node-monitoring

# 最新の変更を取得
git fetch origin

# 変更内容を確認
git log HEAD..origin/main --oneline

# 変更をプル
git pull origin main

# サービスを再ビルドして再起動
docker compose down
docker compose build --no-cache
docker compose up -d
```

### 方法2: 新規インストール

メジャーバージョンアップグレードや問題が発生した場合：

```bash
# 現在の設定を保存
cp server/.env /tmp/.env.backup
cp server/prometheus/targets/builders.yml /tmp/builders.yml.backup

# 古いインストールを削除
cd ..
rm -rf intmax-node-monitoring

# 新しいコピーをクローン
git clone https://github.com/Taiyou/intmax-node-monitoring.git
cd intmax-node-monitoring/server

# 設定を復元
cp /tmp/.env.backup .env
cp /tmp/builders.yml.backup prometheus/targets/builders.yml

# サービスを起動
docker compose up -d
```

---

## コンポーネントのアップグレード

### 監視サーバーのアップグレード

```bash
cd intmax-node-monitoring

# サービスを停止
docker compose down

# 最新コードをプル
git pull origin main

# 最新Dockerイメージをプル
docker compose pull

# カスタムイメージ（exporter）を再ビルド
docker compose build --no-cache

# サービスを起動
docker compose up -d

# サービスが実行中か確認
docker compose ps
docker compose logs -f --tail=100
```

### ノードエージェントのアップグレード

各監視対象ノードで実行：

```bash
# 方法A：インストールスクリプトを再実行
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring/main/agent/setup.sh | sudo bash

# 方法B：手動更新
cd /tmp
git clone https://github.com/Taiyou/intmax-node-monitoring.git
sudo cp intmax-node-monitoring/agent/intmax_builder_metrics.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/intmax_builder_metrics.sh
rm -rf intmax-node-monitoring
```

エージェントの動作を確認：
```bash
curl localhost:9100/metrics | grep intmax_builder
```

### Prometheusのアップグレード

Prometheusを新しいバージョンに更新する場合、互換性を確認：

```bash
# 現在のバージョンを確認
docker compose exec prometheus prometheus --version

# docker-compose.ymlを新しいバージョンに更新
# prom/prometheus:v2.45.0 -> prom/prometheus:v2.50.0

# 新しいバージョンで再起動
docker compose down
docker compose pull prometheus
docker compose up -d
```

### Grafanaのアップグレード

```bash
# 現在のバージョンを確認
docker compose exec grafana grafana-server -v

# docker-compose.ymlを新しいバージョンに更新
# grafana/grafana:10.0.0 -> grafana/grafana:10.3.0

# 新しいバージョンで再起動
docker compose down
docker compose pull grafana
docker compose up -d
```

**注意:** Grafanaのアップグレードにはデータベースマイグレーションが必要な場合があります。アップグレード後にログを確認：
```bash
docker compose logs grafana | grep -i migration
```

---

## アップグレード後の確認

### サービスの確認

```bash
# すべてのコンテナが実行中か確認
docker compose ps

# Prometheusターゲットを確認
curl localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Grafanaがアクセス可能か確認
curl -s localhost:3000/api/health | jq
```

### メトリクスの確認

```bash
# ノードメトリクスを確認
curl localhost:9090/api/v1/query?query=intmax_builder_up | jq

# ウォレットメトリクスを確認
curl localhost:9090/api/v1/query?query=intmax_wallet_eth | jq

# 報酬メトリクスを確認
curl localhost:9090/api/v1/query?query=intmax_builder_reward_eth | jq
```

### ダッシュボードの確認

1. Grafanaを開く: http://localhost:3000
2. **Dashboards** > **INTMAX Builders Overview** に移動
3. すべてのパネルがデータを表示しているか確認
4. 履歴データが保持されているか確認

---

## ロールバック

アップグレードで問題が発生した場合：

### コード変更のロールバック

```bash
# 以前のコミットを探す
git log --oneline -10

# 以前のコミットに戻る
git checkout <previous-commit-hash>

# サービスを再起動
docker compose down
docker compose up -d
```

### Dockerイメージのロールバック

```bash
# docker-compose.ymlで正確なバージョンを指定
# image: prom/prometheus:v2.45.0
# image: grafana/grafana:10.0.0

docker compose down
docker compose up -d
```

### バックアップからの復元

```bash
# 設定を復元
cp server/.env.backup server/.env
cp server/prometheus/targets/builders.yml.backup server/prometheus/targets/builders.yml

# 再起動
docker compose down && docker compose up -d
```

---

## バージョン固有の注意事項

### v1.0.0からv1.1.0

*（例 - 新バージョンリリース時に更新）*

**破壊的変更:**
- なし

**新機能:**
- コンテナメモリ使用量の新メトリクス追加
- 追加パネルでダッシュボードを改善

**移行手順:**
1. 最新コードをプル
2. サービスを再起動
3. 新しいダッシュボードをインポート（オプション）

---

## カスタムフォークからのアップグレード

ローカルで変更を加えている場合：

```bash
# 変更をブランチに保存
git checkout -b my-customizations
git add .
git commit -m "My customizations"

# メインブランチを更新
git checkout main
git pull origin main

# 変更をマージ
git checkout my-customizations
git rebase main

# コンフリクトを解決して続行
# その後、自分のブランチからデプロイ
```

---

## アップグレードのトラブルシューティング

### Prometheusが起動しない

設定エラーを確認：
```bash
docker compose logs prometheus | grep -i error
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Grafanaダッシュボードが見つからない

ダッシュボードを再プロビジョニング：
```bash
docker compose restart grafana
```

または手動でインポート：
1. Grafanaを開く
2. **Dashboards** > **Import** に移動
3. `grafana/dashboards/intmax-builders-overview.json`をアップロード

### メトリクスが更新されない

exporterログを確認：
```bash
docker compose logs wallet-exporter
docker compose logs reward-exporter
```

Prometheusターゲットを確認：
```bash
curl localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### エージェントがメトリクスを送信しない

ノード上で：
```bash
# cronジョブを確認
crontab -l | grep intmax

# メトリクススクリプトを手動実行
sudo /usr/local/bin/intmax_builder_metrics.sh

# 出力ファイルを確認
cat /var/lib/node_exporter/textfile_collector/intmax_builder.prom

# node_exporterの状態を確認
sudo systemctl status node_exporter
```
