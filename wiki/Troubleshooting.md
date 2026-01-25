# Troubleshooting & FAQ

## Frequently Asked Questions (FAQ)

### General Questions

**Q: What is the minimum system requirement for the monitoring server?**

A: For the monitoring server:
- CPU: 2 cores
- RAM: 2GB (4GB recommended)
- Storage: 10GB+ (depends on retention period)
- Docker and Docker Compose installed

**Q: Can I run the monitoring server on the same machine as Block Builder?**

A: Yes, but it's not recommended for production. The monitoring server adds additional resource usage, which may affect Block Builder performance. For testing purposes, it's fine.

**Q: How long is the data retained?**

A: By default, Prometheus retains data for 90 days. You can adjust this by setting `PROMETHEUS_RETENTION` in the `.env` file:
```bash
PROMETHEUS_RETENTION=30d   # 30 days
PROMETHEUS_RETENTION=90d   # 90 days (default)
PROMETHEUS_RETENTION=180d  # 180 days
```

**Q: Can I monitor nodes on different networks (different subnets)?**

A: Yes, as long as the monitoring server can reach the nodes on port 9100. You may need to configure firewall rules or use a VPN for nodes in different networks.

**Q: Do I need to restart services after configuration changes?**

A: Yes. After modifying `.env` or `builders.yml`, restart the services:
```bash
docker compose down && docker compose up -d
```

### Reward Monitoring

**Q: Why do I need SSH access for reward monitoring?**

A: The reward exporter needs to run the INTMAX CLI `balance` command on each node to retrieve pending rewards. This requires SSH access to execute the command remotely.

**Q: Is it safe to store the spend-key on the node?**

A: The spend-key is only used for checking balances and claiming rewards. It cannot be used to transfer funds elsewhere. However, follow these security practices:
- Set appropriate file permissions (`chmod 644`)
- Restrict SSH access with key-based authentication
- See [Security Best Practices](Security) for more details

**Q: Can I claim rewards automatically?**

A: Yes, you can set up automatic reward claiming using the `claim_rewards.sh` script with cron. See [Rewards](Rewards) for configuration details.

### Dashboard & Visualization

**Q: Why does the dashboard show "No data"?**

A: This usually means:
1. Prometheus cannot reach the nodes (check `builders.yml` configuration)
2. node_exporter is not running on the target nodes
3. Firewall is blocking port 9100

Check Prometheus targets at http://localhost:9090/targets

**Q: Can I create custom dashboards?**

A: Yes, you can create custom dashboards in Grafana. The existing dashboard is a starting point. Export your custom dashboards as JSON and place them in `grafana/dashboards/` for persistence.

**Q: How do I change the dashboard refresh interval?**

A: In Grafana, click the refresh icon in the top-right corner and select your preferred interval (e.g., 5s, 10s, 30s, 1m).

---

## 404 Error During Installation

### Symptom
```
curl: (22) The requested URL returned error: 404
```

### Cause
GitHub CDN cache not updated

### Solution

**Method 1: Use git clone**
```bash
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git /tmp/intmax-monitoring
cd /tmp/intmax-monitoring/agent
sudo ./install.sh
```

**Method 2: Wait and retry**
```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash
```

---

## Metrics Not Being Collected

### Check if node_exporter is running
```bash
sudo systemctl status node_exporter
curl localhost:9100/metrics | head
```

### Check firewall
```bash
sudo ufw status
sudo ufw allow 9100/tcp
```

---

## "No data" in Grafana

### Check if Prometheus can connect to nodes
Prometheus UI (http://localhost:9090) → Status → Targets

### Check if builders.yml IPs are correct
```bash
cat server/prometheus/targets/builders.yml
```

---

## Docker Container Not Detected

### Check container name
```bash
docker ps --format '{{.Names}}'
```

### Update BUILDER_CONTAINER_NAME in config
```bash
sudo nano /etc/default/intmax-builder-metrics
# BUILDER_CONTAINER_NAME="actual container name prefix"
```

---

## SSH Connection Error (Reward Monitoring)

### Check if public key is registered
```bash
# SSH manually from monitoring server
ssh user@192.168.1.10

# Check on node side
cat ~/.ssh/authorized_keys
```

### Add to known_hosts
```bash
ssh-keyscan 192.168.1.10 >> ~/.ssh/known_hosts
```

---

## spend-key Related Errors

### Check if file exists
```bash
ls -la /etc/intmax-builder/spend-key
```

### Check permissions
```bash
sudo chmod 644 /etc/intmax-builder/spend-key
sudo chown $USER:$USER /etc/intmax-builder/spend-key
```

---

## Services Not Starting After Reboot

### Check Docker services
```bash
cd server
docker compose ps
docker compose up -d
```

### Check node_exporter
```bash
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

---

## Block Builder Setup Issues

### uuidgen not found

```
❌ Missing required tools: uuidgen
```

**Solution:**
```bash
sudo apt install -y uuid-runtime
```

### Mainnet/Testnet Mismatch

```
🚨 NETWORK MISMATCH DETECTED!
Expected: Chain ID 534351 (Scroll Sepolia Testnet)
Actual: Chain ID 534352
```

**Solution:**

For Mainnet operation, download the Mainnet script:
```bash
curl -o builder.sh https://raw.githubusercontent.com/InternetMaximalism/intmax2/refs/heads/main/scripts/block-builder-mainnet.sh
chmod +x builder.sh
./builder.sh clean && ./builder.sh setup
```

---

## CLI Build Errors

### OpenSSL not found

```
Could not find directory of OpenSSL installation
```

**Solution:**
```bash
sudo apt install -y libssl-dev pkg-config
cargo build -r
```

### Build tools missing

```
error: linker `cc` not found
```

**Solution:**
```bash
sudo apt install -y build-essential
cargo build -r
```

---

## Diagnostic Commands

Use these commands to quickly diagnose common issues:

### Check Overall System Status

```bash
# On monitoring server
docker compose ps                    # Check service status
docker compose logs -f               # View all logs
curl localhost:9090/-/healthy        # Prometheus health
curl localhost:3000/api/health       # Grafana health

# On each node
sudo systemctl status node_exporter  # node_exporter status
curl localhost:9100/metrics | grep intmax  # Check custom metrics
```

### Network Connectivity Test

```bash
# From monitoring server to node
nc -zv <node-ip> 9100               # Test port connectivity
curl http://<node-ip>:9100/metrics  # Fetch metrics directly
```

### SSH Connection Test (for Reward Monitoring)

```bash
# Test SSH access
ssh -v user@<node-ip> "echo 'SSH works'"

# Test CLI command
ssh user@<node-ip> "cd /path/to/intmax2/cli && ./target/release/intmax2-cli balance --private-key \$(cat /etc/intmax-builder/spend-key)"
```

---

## Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/Taiyou/intmax-node-monitoring-en/issues) for known problems
2. Search existing issues before creating a new one
3. When reporting an issue, include:
   - Operating system and version
   - Docker and Docker Compose versions
   - Relevant log output
   - Steps to reproduce the issue
