# Upgrading Guide

This document describes how to upgrade the INTMAX Node Monitoring system.

---

## Before You Upgrade

### Backup Your Data

Always create backups before upgrading:

```bash
# Backup configuration files
cp server/.env server/.env.backup
cp server/prometheus/targets/builders.yml server/prometheus/targets/builders.yml.backup

# Backup Grafana dashboards (if customized)
cp -r grafana/dashboards grafana/dashboards.backup

# Optional: Backup Prometheus data
docker compose exec prometheus tar -czf /tmp/prom-backup.tar.gz /prometheus
docker compose cp prometheus:/tmp/prom-backup.tar.gz ./prom-backup.tar.gz
```

### Check Current Version

```bash
# Check the current commit
git log -1 --oneline

# Check running Docker images
docker compose images
```

---

## Upgrade Methods

### Method 1: Git Pull (Recommended)

For most upgrades:

```bash
cd intmax-node-monitoring-en

# Fetch latest changes
git fetch origin

# Check what changed
git log HEAD..origin/main --oneline

# Pull changes
git pull origin main

# Rebuild and restart services
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Method 2: Fresh Installation

For major version upgrades or if you encounter issues:

```bash
# Save current configuration
cp server/.env /tmp/.env.backup
cp server/prometheus/targets/builders.yml /tmp/builders.yml.backup

# Remove old installation
cd ..
rm -rf intmax-node-monitoring-en

# Clone fresh copy
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git
cd intmax-node-monitoring-en/server

# Restore configuration
cp /tmp/.env.backup .env
cp /tmp/builders.yml.backup prometheus/targets/builders.yml

# Start services
docker compose up -d
```

---

## Upgrading Components

### Upgrading the Monitoring Server

```bash
cd intmax-node-monitoring-en

# Stop services
docker compose down

# Pull latest code
git pull origin main

# Pull latest Docker images
docker compose pull

# Rebuild custom images (exporters)
docker compose build --no-cache

# Start services
docker compose up -d

# Verify services are running
docker compose ps
docker compose logs -f --tail=100
```

### Upgrading Node Agents

Run on each monitored node:

```bash
# Method A: Re-run installation script
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash

# Method B: Manual update
cd /tmp
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git
sudo cp intmax-node-monitoring-en/agent/intmax_builder_metrics.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/intmax_builder_metrics.sh
rm -rf intmax-node-monitoring-en
```

Verify the agent is working:
```bash
curl localhost:9100/metrics | grep intmax_builder
```

### Upgrading Prometheus

If updating Prometheus to a new version, check compatibility:

```bash
# Check current version
docker compose exec prometheus prometheus --version

# Update docker-compose.yml to new version
# prom/prometheus:v2.45.0 -> prom/prometheus:v2.50.0

# Restart with new version
docker compose down
docker compose pull prometheus
docker compose up -d
```

### Upgrading Grafana

```bash
# Check current version
docker compose exec grafana grafana-server -v

# Update docker-compose.yml to new version
# grafana/grafana:10.0.0 -> grafana/grafana:10.3.0

# Restart with new version
docker compose down
docker compose pull grafana
docker compose up -d
```

**Note:** Grafana upgrades may require database migrations. Check logs after upgrade:
```bash
docker compose logs grafana | grep -i migration
```

---

## Post-Upgrade Verification

### Verify Services

```bash
# Check all containers are running
docker compose ps

# Check Prometheus targets
curl localhost:9090/api/v1/targets | jq '.data.activeTargets[].health'

# Check Grafana is accessible
curl -s localhost:3000/api/health | jq
```

### Verify Metrics

```bash
# Check node metrics
curl localhost:9090/api/v1/query?query=intmax_builder_up | jq

# Check wallet metrics
curl localhost:9090/api/v1/query?query=intmax_wallet_eth | jq

# Check reward metrics
curl localhost:9090/api/v1/query?query=intmax_builder_reward_eth | jq
```

### Verify Dashboard

1. Open Grafana at http://localhost:3000
2. Navigate to **Dashboards** > **INTMAX Builders Overview**
3. Verify all panels are displaying data
4. Check that historical data is preserved

---

## Rollback

If the upgrade causes issues:

### Rollback Code Changes

```bash
# Find the previous commit
git log --oneline -10

# Revert to previous commit
git checkout <previous-commit-hash>

# Restart services
docker compose down
docker compose up -d
```

### Rollback Docker Images

```bash
# Specify exact versions in docker-compose.yml
# image: prom/prometheus:v2.45.0
# image: grafana/grafana:10.0.0

docker compose down
docker compose up -d
```

### Restore from Backup

```bash
# Restore configuration
cp server/.env.backup server/.env
cp server/prometheus/targets/builders.yml.backup server/prometheus/targets/builders.yml

# Restart
docker compose down && docker compose up -d
```

---

## Version-Specific Notes

### v1.0.0 to v1.1.0

*(Example - update when releasing new versions)*

**Breaking Changes:**
- None

**New Features:**
- Added new metrics for container memory usage
- Improved dashboard with additional panels

**Migration Steps:**
1. Pull latest code
2. Restart services
3. Import new dashboard (optional)

---

## Upgrading from Custom Forks

If you've made local modifications:

```bash
# Save your changes to a branch
git checkout -b my-customizations
git add .
git commit -m "My customizations"

# Update main branch
git checkout main
git pull origin main

# Merge your changes
git checkout my-customizations
git rebase main

# Resolve any conflicts and continue
# Then deploy from your branch
```

---

## Troubleshooting Upgrades

### Prometheus Won't Start

Check for configuration errors:
```bash
docker compose logs prometheus | grep -i error
docker compose exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

### Grafana Dashboard Missing

Re-provision dashboards:
```bash
docker compose restart grafana
```

Or manually import:
1. Open Grafana
2. Go to **Dashboards** > **Import**
3. Upload `grafana/dashboards/intmax-builders-overview.json`

### Metrics Not Updating

Check exporter logs:
```bash
docker compose logs wallet-exporter
docker compose logs reward-exporter
```

Check Prometheus targets:
```bash
curl localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'
```

### Agent Not Sending Metrics

On the node:
```bash
# Check cron job
crontab -l | grep intmax

# Run metrics script manually
sudo /usr/local/bin/intmax_builder_metrics.sh

# Check output file
cat /var/lib/node_exporter/textfile_collector/intmax_builder.prom

# Check node_exporter status
sudo systemctl status node_exporter
```
