# メトリクスリファレンス

このドキュメントでは、INTMAX Node Monitoringシステムが収集するすべてのメトリクスの完全なリファレンスを提供します。

---

## メトリクス概要

| ソース | エンドポイント | 更新間隔 | 目的 |
|--------|---------------|----------|------|
| ノードエージェント | `:9100/metrics` | 1〜5分（cron） | ノードとコンテナの状態 |
| Wallet Exporter | `:9101/metrics` | 1時間 | ウォレット残高 |
| Reward Exporter | `:9102/metrics` | 1時間 | 保留中の報酬 |

---

## ノードエージェントメトリクス

これらのメトリクスは、各Block Builderノードで実行される`intmax_builder_metrics.sh`スクリプトによって収集されます。

### intmax_builder_up

**タイプ:** Gauge

**説明:** ノードが監視されているかどうかを示します（エージェント実行中は常に1）。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_up{node="builder-01"} 1
```

**使用方法:** 各ノードでエージェントが実行されていることを確認するために使用。

---

### intmax_builder_container_running

**タイプ:** Gauge

**説明:** Block BuilderのDockerコンテナ状態。

**値:**
- `1`: コンテナが実行中
- `0`: コンテナが実行されていない

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_container_running{node="builder-01"} 1
```

**アラート例:**
```yaml
- alert: INTMAXBuilderNotReady
  expr: intmax_builder_container_running == 0
  for: 10m
  labels:
    severity: critical
```

---

### intmax_builder_process_running

**タイプ:** Gauge

**説明:** Block Builderプロセス状態（`pgrep`で確認）。

**値:**
- `1`: プロセスが実行中
- `0`: プロセスが実行されていない

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_process_running{node="builder-01"} 1
```

---

### intmax_builder_health_ok

**タイプ:** Gauge

**説明:** ヘルスエンドポイントチェック結果（設定されている場合）。

**値:**
- `1`: ヘルスチェック成功（HTTP 2xxレスポンス）
- `0`: ヘルスチェック失敗

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_health_ok{node="builder-01"} 1
```

**設定:**
`/etc/default/intmax-builder-metrics`で`BUILDER_HEALTH_URL`を設定：
```bash
BUILDER_HEALTH_URL="http://localhost:8080/health"
```

---

### intmax_builder_uptime_seconds

**タイプ:** Gauge

**説明:** 最後の起動からのコンテナ稼働時間（秒）。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_uptime_seconds{node="builder-01"} 86400
```

**使用方法:** コンテナの安定性を追跡し、予期しない再起動を検出：
```promql
# 過去1時間以内に再起動したコンテナを検出
intmax_builder_uptime_seconds < 3600
```

---

### intmax_builder_data_size_bytes

**タイプ:** Gauge

**説明:** Block Builderデータディレクトリのサイズ（バイト）。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_data_size_bytes{node="builder-01"} 5368709120
```

**使用方法:** ディスク使用量の増加を監視：
```promql
# GBでのデータサイズ
intmax_builder_data_size_bytes / 1024 / 1024 / 1024

# 1日あたりの増加率
rate(intmax_builder_data_size_bytes[1d])
```

---

### intmax_builder_last_scrape

**タイプ:** Gauge

**説明:** 最後のメトリクス収集のUnixタイムスタンプ。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_last_scrape{node="builder-01"} 1704067200
```

**使用方法:** 古いメトリクスを検出：
```promql
# 5分以上古いメトリクス
time() - intmax_builder_last_scrape > 300
```

---

## Wallet Exporterメトリクス

これらのメトリクスは、`wallet-exporter`サービスによってScrollブロックチェーンから収集されます。

### intmax_wallet_eth

**タイプ:** Gauge

**説明:** Scrollネットワーク上のウォレットETH残高（ガス代用）。

**ラベル:**
- `wallet`: ウォレットアドレス（0x...）

**例:**
```
intmax_wallet_eth{wallet="0x1234...abcd"} 0.0542
```

**アラート例:**
```yaml
- alert: INTMAXWalletLowBalance
  expr: intmax_wallet_eth < 0.001
  for: 5m
  labels:
    severity: warning
```

---

### intmax_wallet_sitx

**タイプ:** Gauge

**説明:** Scrollネットワーク上のウォレットsITXトークン残高。

**ラベル:**
- `wallet`: ウォレットアドレス（0x...）

**例:**
```
intmax_wallet_sitx{wallet="0x1234...abcd"} 1523.456
```

---

### intmax_wallet_sitx_total

**タイプ:** Gauge

**説明:** すべての監視対象ウォレットの合計sITX残高。

**例:**
```
intmax_wallet_sitx_total 4521.789
```

---

### intmax_wallet_last_check

**タイプ:** Gauge

**説明:** 最後のウォレット残高チェックのUnixタイムスタンプ。

**例:**
```
intmax_wallet_last_check 1704067200
```

**使用方法:** 古いウォレットデータを検出：
```promql
# 過去2時間更新なし
time() - intmax_wallet_last_check > 7200
```

---

## Reward Exporterメトリクス

これらのメトリクスは、`reward-exporter`サービスによって各ノードへのSSH経由で収集されます。

### intmax_builder_reward_eth

**タイプ:** Gauge

**説明:** ノード上の保留中ETH報酬（未請求）。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_reward_eth{node="builder-01"} 0.0123
```

---

### intmax_builder_reward_sitx

**タイプ:** Gauge

**説明:** ノード上の保留中sITX報酬（未請求）。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_reward_sitx{node="builder-01"} 456.789
```

---

### intmax_builder_reward_total_eth

**タイプ:** Gauge

**説明:** すべてのノードの合計保留中ETH報酬。

**例:**
```
intmax_builder_reward_total_eth 0.0567
```

---

### intmax_builder_reward_total_sitx

**タイプ:** Gauge

**説明:** すべてのノードの合計保留中sITX報酬。

**例:**
```
intmax_builder_reward_total_sitx 1234.567
```

---

### intmax_builder_reward_check_success

**タイプ:** Gauge

**説明:** 最後の報酬チェックが成功したかどうかを示す。

**値:**
- `1`: チェック成功
- `0`: チェック失敗

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_reward_check_success{node="builder-01"} 1
```

**アラート例:**
```yaml
- alert: INTMAXRewardCheckStale
  expr: intmax_builder_reward_check_success == 0
  for: 2h
  labels:
    severity: warning
```

---

### intmax_builder_reward_last_check

**タイプ:** Gauge

**説明:** 最後の報酬残高チェックのUnixタイムスタンプ。

**ラベル:**
- `node`: 設定からのノード名

**例:**
```
intmax_builder_reward_last_check{node="builder-01"} 1704067200
```

---

## PromQLクエリ例

### ダッシュボードクエリ

**稼働中のノード総数:**
```promql
count(intmax_builder_up == 1)
```

**正常なノードの割合:**
```promql
(count(intmax_builder_container_running == 1) / count(intmax_builder_up)) * 100
```

**合計保留中報酬（ETH + sITXをETH換算）:**
```promql
intmax_builder_reward_total_eth + (intmax_builder_reward_total_sitx * <sitx_price_in_eth>)
```

**平均コンテナ稼働時間:**
```promql
avg(intmax_builder_uptime_seconds) / 3600  # 時間単位
```

**データ増加率（GB/日）:**
```promql
rate(intmax_builder_data_size_bytes[1d]) / 1024 / 1024 / 1024
```

### アラートクエリ

**10分以上停止しているノード:**
```promql
intmax_builder_container_running == 0
```

**ガス残高不足:**
```promql
intmax_wallet_eth < 0.001
```

**未請求報酬が多い:**
```promql
intmax_builder_reward_eth > 0.1
```

**古いメトリクス（5分間更新なし）:**
```promql
time() - intmax_builder_last_scrape > 300
```

---

## カスタムメトリクス

`intmax_builder_metrics.sh`スクリプトを変更してカスタムメトリクスを追加できます：

```bash
# 例：メモリ使用量メトリクスを追加
MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" $CONTAINER_NAME | cut -d'/' -f1)
echo "intmax_builder_memory_bytes{node=\"$NODE_NAME\"} $MEMORY_BYTES" >> "$TEXTFILE_PATH"
```

変更後、新しいメトリクスは次のcron実行時に利用可能になります。

---

## Grafanaダッシュボード変数

デフォルトのダッシュボードはテンプレート変数に以下のPrometheusクエリを使用：

**ノード選択:**
```promql
label_values(intmax_builder_up, node)
```

**ウォレット選択:**
```promql
label_values(intmax_wallet_eth, wallet)
```
