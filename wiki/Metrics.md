# Metrics Reference

This document provides a complete reference of all metrics collected by the INTMAX Node Monitoring system.

---

## Metrics Overview

| Source | Endpoint | Update Interval | Purpose |
|--------|----------|-----------------|---------|
| Node Agent | `:9100/metrics` | 1-5 min (cron) | Node and container status |
| Wallet Exporter | `:9101/metrics` | 1 hour | Wallet balances |
| Reward Exporter | `:9102/metrics` | 1 hour | Pending rewards |

---

## Node Agent Metrics

These metrics are collected by the `intmax_builder_metrics.sh` script running on each Block Builder node.

### intmax_builder_up

**Type:** Gauge

**Description:** Indicates whether the node is being monitored (always 1 when agent is running).

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_up{node="builder-01"} 1
```

**Usage:** Use this to verify the agent is running on each node.

---

### intmax_builder_container_running

**Type:** Gauge

**Description:** Docker container status for the Block Builder.

**Values:**
- `1`: Container is running
- `0`: Container is not running

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_container_running{node="builder-01"} 1
```

**Alert Example:**
```yaml
- alert: INTMAXBuilderNotReady
  expr: intmax_builder_container_running == 0
  for: 10m
  labels:
    severity: critical
```

---

### intmax_builder_process_running

**Type:** Gauge

**Description:** Block Builder process status (checked via `pgrep`).

**Values:**
- `1`: Process is running
- `0`: Process is not running

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_process_running{node="builder-01"} 1
```

---

### intmax_builder_health_ok

**Type:** Gauge

**Description:** Health endpoint check result (if configured).

**Values:**
- `1`: Health check passed (HTTP 2xx response)
- `0`: Health check failed

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_health_ok{node="builder-01"} 1
```

**Configuration:**
Set `BUILDER_HEALTH_URL` in `/etc/default/intmax-builder-metrics`:
```bash
BUILDER_HEALTH_URL="http://localhost:8080/health"
```

---

### intmax_builder_uptime_seconds

**Type:** Gauge

**Description:** Container uptime in seconds since last start.

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_uptime_seconds{node="builder-01"} 86400
```

**Usage:** Track container stability and detect unexpected restarts:
```promql
# Detect containers restarted in last hour
intmax_builder_uptime_seconds < 3600
```

---

### intmax_builder_data_size_bytes

**Type:** Gauge

**Description:** Size of the Block Builder data directory in bytes.

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_data_size_bytes{node="builder-01"} 5368709120
```

**Usage:** Monitor disk usage growth:
```promql
# Data size in GB
intmax_builder_data_size_bytes / 1024 / 1024 / 1024

# Growth rate per day
rate(intmax_builder_data_size_bytes[1d])
```

---

### intmax_builder_last_scrape

**Type:** Gauge

**Description:** Unix timestamp of the last metrics collection.

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_last_scrape{node="builder-01"} 1704067200
```

**Usage:** Detect stale metrics:
```promql
# Metrics older than 5 minutes
time() - intmax_builder_last_scrape > 300
```

---

## Wallet Exporter Metrics

These metrics are collected by the `wallet-exporter` service from the Scroll blockchain.

### intmax_wallet_eth

**Type:** Gauge

**Description:** ETH balance of a wallet on Scroll network (for gas fees).

**Labels:**
- `wallet`: Wallet address (0x...)

**Example:**
```
intmax_wallet_eth{wallet="0x1234...abcd"} 0.0542
```

**Alert Example:**
```yaml
- alert: INTMAXWalletLowBalance
  expr: intmax_wallet_eth < 0.001
  for: 5m
  labels:
    severity: warning
```

---

### intmax_wallet_sitx

**Type:** Gauge

**Description:** sITX token balance of a wallet on Scroll network.

**Labels:**
- `wallet`: Wallet address (0x...)

**Example:**
```
intmax_wallet_sitx{wallet="0x1234...abcd"} 1523.456
```

---

### intmax_wallet_sitx_total

**Type:** Gauge

**Description:** Total sITX balance across all monitored wallets.

**Example:**
```
intmax_wallet_sitx_total 4521.789
```

---

### intmax_wallet_last_check

**Type:** Gauge

**Description:** Unix timestamp of the last wallet balance check.

**Example:**
```
intmax_wallet_last_check 1704067200
```

**Usage:** Detect stale wallet data:
```promql
# No update in last 2 hours
time() - intmax_wallet_last_check > 7200
```

---

## Reward Exporter Metrics

These metrics are collected by the `reward-exporter` service via SSH to each node.

### intmax_builder_reward_eth

**Type:** Gauge

**Description:** Pending ETH rewards on a node (unclaimed).

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_reward_eth{node="builder-01"} 0.0123
```

---

### intmax_builder_reward_sitx

**Type:** Gauge

**Description:** Pending sITX rewards on a node (unclaimed).

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_reward_sitx{node="builder-01"} 456.789
```

---

### intmax_builder_reward_total_eth

**Type:** Gauge

**Description:** Total pending ETH rewards across all nodes.

**Example:**
```
intmax_builder_reward_total_eth 0.0567
```

---

### intmax_builder_reward_total_sitx

**Type:** Gauge

**Description:** Total pending sITX rewards across all nodes.

**Example:**
```
intmax_builder_reward_total_sitx 1234.567
```

---

### intmax_builder_reward_check_success

**Type:** Gauge

**Description:** Indicates if the last reward check was successful.

**Values:**
- `1`: Check succeeded
- `0`: Check failed

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_reward_check_success{node="builder-01"} 1
```

**Alert Example:**
```yaml
- alert: INTMAXRewardCheckStale
  expr: intmax_builder_reward_check_success == 0
  for: 2h
  labels:
    severity: warning
```

---

### intmax_builder_reward_last_check

**Type:** Gauge

**Description:** Unix timestamp of the last reward balance check.

**Labels:**
- `node`: Node name from configuration

**Example:**
```
intmax_builder_reward_last_check{node="builder-01"} 1704067200
```

---

## PromQL Query Examples

### Dashboard Queries

**Total Nodes Up:**
```promql
count(intmax_builder_up == 1)
```

**Percentage of Healthy Nodes:**
```promql
(count(intmax_builder_container_running == 1) / count(intmax_builder_up)) * 100
```

**Total Pending Rewards (ETH + sITX in ETH equivalent):**
```promql
intmax_builder_reward_total_eth + (intmax_builder_reward_total_sitx * <sitx_price_in_eth>)
```

**Average Container Uptime:**
```promql
avg(intmax_builder_uptime_seconds) / 3600  # in hours
```

**Data Growth Rate (GB/day):**
```promql
rate(intmax_builder_data_size_bytes[1d]) / 1024 / 1024 / 1024
```

### Alerting Queries

**Nodes Down for More Than 10 Minutes:**
```promql
intmax_builder_container_running == 0
```

**Low Gas Balance:**
```promql
intmax_wallet_eth < 0.001
```

**High Unclaimed Rewards:**
```promql
intmax_builder_reward_eth > 0.1
```

**Stale Metrics (No Update in 5 min):**
```promql
time() - intmax_builder_last_scrape > 300
```

---

## Custom Metrics

You can add custom metrics by modifying the `intmax_builder_metrics.sh` script:

```bash
# Example: Add memory usage metric
MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemUsage}}" $CONTAINER_NAME | cut -d'/' -f1)
echo "intmax_builder_memory_bytes{node=\"$NODE_NAME\"} $MEMORY_BYTES" >> "$TEXTFILE_PATH"
```

After modifying, the new metrics will be available on the next cron execution.

---

## Grafana Dashboard Variables

The default dashboard uses these Prometheus queries for template variables:

**Node Selection:**
```promql
label_values(intmax_builder_up, node)
```

**Wallet Selection:**
```promql
label_values(intmax_wallet_eth, wallet)
```
