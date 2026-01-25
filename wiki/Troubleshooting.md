# トラブルシューティング & FAQ

## よくある質問（FAQ）

### 一般的な質問

**Q: 監視サーバーの最小システム要件は？**

A: 監視サーバーの場合：
- CPU: 2コア
- RAM: 2GB（4GB推奨）
- ストレージ: 10GB以上（保持期間による）
- DockerとDocker Composeがインストール済み

**Q: 監視サーバーをBlock Builderと同じマシンで実行できますか？**

A: はい、ただし本番環境では推奨しません。監視サーバーは追加のリソースを使用するため、Block Builderのパフォーマンスに影響する可能性があります。テスト目的であれば問題ありません。

**Q: データはどのくらい保持されますか？**

A: デフォルトでは、Prometheusは90日間データを保持します。`.env`ファイルで`PROMETHEUS_RETENTION`を設定して調整できます：
```bash
PROMETHEUS_RETENTION=30d   # 30日
PROMETHEUS_RETENTION=90d   # 90日（デフォルト）
PROMETHEUS_RETENTION=180d  # 180日
```

**Q: 異なるネットワーク（異なるサブネット）のノードを監視できますか？**

A: はい、監視サーバーがポート9100でノードに到達できる限り可能です。異なるネットワークのノードにはファイアウォールルールの設定やVPNの使用が必要な場合があります。

**Q: 設定変更後にサービスを再起動する必要がありますか？**

A: はい。`.env`や`builders.yml`を変更した後、サービスを再起動してください：
```bash
docker compose down && docker compose up -d
```

### 報酬監視

**Q: 報酬監視にSSHアクセスが必要なのはなぜですか？**

A: reward exporterは、保留中の報酬を取得するために各ノードでINTMAX CLIの`balance`コマンドを実行する必要があります。これにはコマンドをリモートで実行するためのSSHアクセスが必要です。

**Q: spend-keyをノードに保存しても安全ですか？**

A: spend-keyは残高確認と報酬請求にのみ使用されます。他の場所への資金移動には使用できません。ただし、以下のセキュリティプラクティスに従ってください：
- 適切なファイル権限を設定（`chmod 644`）
- 鍵ベースの認証でSSHアクセスを制限
- 詳細は[セキュリティベストプラクティス](Security)を参照

**Q: 報酬を自動で請求できますか？**

A: はい、`claim_rewards.sh`スクリプトとcronを使用して自動報酬請求を設定できます。設定の詳細は[報酬](Rewards)を参照してください。

### ダッシュボードと可視化

**Q: ダッシュボードに「No data」と表示されるのはなぜですか？**

A: これは通常以下を意味します：
1. Prometheusがノードに到達できない（`builders.yml`の設定を確認）
2. node_exporterが対象ノードで実行されていない
3. ファイアウォールがポート9100をブロックしている

http://localhost:9090/targets でPrometheusターゲットを確認してください。

**Q: カスタムダッシュボードを作成できますか？**

A: はい、Grafanaでカスタムダッシュボードを作成できます。既存のダッシュボードは出発点です。カスタムダッシュボードをJSONとしてエクスポートし、`grafana/dashboards/`に配置して永続化できます。

**Q: ダッシュボードの更新間隔を変更するには？**

A: Grafanaで、右上の更新アイコンをクリックして希望の間隔（5秒、10秒、30秒、1分など）を選択します。

---

## インストール時の404エラー

### 症状
```
curl: (22) The requested URL returned error: 404
```

### 原因
GitHub CDNキャッシュが更新されていない

### 解決策

**方法1: git cloneを使用**
```bash
git clone https://github.com/Taiyou/intmax-node-monitoring.git /tmp/intmax-monitoring
cd /tmp/intmax-monitoring/agent
sudo ./install.sh
```

**方法2: 待ってから再試行**
```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring/main/agent/setup.sh | sudo bash
```

---

## メトリクスが収集されない

### node_exporterが実行中か確認
```bash
sudo systemctl status node_exporter
curl localhost:9100/metrics | head
```

### ファイアウォールを確認
```bash
sudo ufw status
sudo ufw allow 9100/tcp
```

---

## Grafanaで「No data」

### PrometheusがノードにConnect可能か確認
Prometheus UI (http://localhost:9090) → Status → Targets

### builders.ymlのIPが正しいか確認
```bash
cat server/prometheus/targets/builders.yml
```

---

## Dockerコンテナが検出されない

### コンテナ名を確認
```bash
docker ps --format '{{.Names}}'
```

### 設定のBUILDER_CONTAINER_NAMEを更新
```bash
sudo nano /etc/default/intmax-builder-metrics
# BUILDER_CONTAINER_NAME="実際のコンテナ名プレフィックス"
```

---

## SSH接続エラー（報酬監視）

### 公開鍵が登録されているか確認
```bash
# 監視サーバーから手動でSSH
ssh user@192.168.1.10

# ノード側で確認
cat ~/.ssh/authorized_keys
```

### known_hostsに追加
```bash
ssh-keyscan 192.168.1.10 >> ~/.ssh/known_hosts
```

---

## spend-key関連のエラー

### ファイルが存在するか確認
```bash
ls -la /etc/intmax-builder/spend-key
```

### 権限を確認
```bash
sudo chmod 644 /etc/intmax-builder/spend-key
sudo chown $USER:$USER /etc/intmax-builder/spend-key
```

---

## 再起動後にサービスが起動しない

### Dockerサービスを確認
```bash
cd server
docker compose ps
docker compose up -d
```

### node_exporterを確認
```bash
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

---

## Block Builderセットアップの問題

### uuidgenが見つからない

```
❌ Missing required tools: uuidgen
```

**解決策:**
```bash
sudo apt install -y uuid-runtime
```

### Mainnet/Testnetの不一致

```
🚨 NETWORK MISMATCH DETECTED!
Expected: Chain ID 534351 (Scroll Sepolia Testnet)
Actual: Chain ID 534352
```

**解決策:**

Mainnet運用の場合、Mainnetスクリプトをダウンロード：
```bash
curl -o builder.sh https://raw.githubusercontent.com/InternetMaximalism/intmax2/refs/heads/main/scripts/block-builder-mainnet.sh
chmod +x builder.sh
./builder.sh clean && ./builder.sh setup
```

---

## CLIビルドエラー

### OpenSSLが見つからない

```
Could not find directory of OpenSSL installation
```

**解決策:**
```bash
sudo apt install -y libssl-dev pkg-config
cargo build -r
```

### ビルドツールが不足

```
error: linker `cc` not found
```

**解決策:**
```bash
sudo apt install -y build-essential
cargo build -r
```

---

## 診断コマンド

一般的な問題を素早く診断するためのコマンド：

### システム全体の状態を確認

```bash
# 監視サーバー上で
docker compose ps                    # サービス状態を確認
docker compose logs -f               # すべてのログを表示
curl localhost:9090/-/healthy        # Prometheusヘルス
curl localhost:3000/api/health       # Grafanaヘルス

# 各ノード上で
sudo systemctl status node_exporter  # node_exporter状態
curl localhost:9100/metrics | grep intmax  # カスタムメトリクスを確認
```

### ネットワーク接続テスト

```bash
# 監視サーバーからノードへ
nc -zv <node-ip> 9100               # ポート接続テスト
curl http://<node-ip>:9100/metrics  # メトリクスを直接取得
```

### SSH接続テスト（報酬監視用）

```bash
# SSHアクセスをテスト
ssh -v user@<node-ip> "echo 'SSH works'"

# CLIコマンドをテスト
ssh user@<node-ip> "cd /path/to/intmax2/cli && ./target/release/intmax2-cli balance --private-key \$(cat /etc/intmax-builder/spend-key)"
```

---

## ヘルプを得る

まだ問題が解決しない場合：

1. [GitHub Issues](https://github.com/Taiyou/intmax-node-monitoring/issues)で既知の問題を確認
2. 新しいイシューを作成する前に既存のイシューを検索
3. イシューを報告する際は以下を含めてください：
   - オペレーティングシステムとバージョン
   - DockerとDocker Composeのバージョン
   - 関連するログ出力
   - 問題を再現する手順
