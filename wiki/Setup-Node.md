# Node Setup

## Required Information

Before starting, prepare the following information:

| Item | Example | Description |
|------|---------|-------------|
| Node IP | `192.168.1.12` | IP address of the target node |
| Node Name | `builder-03` | Name displayed in Grafana |
| Docker Container Name | `block-builder` | INTMAX Builder container name (partial match OK) |
| Data Directory | `/home/pi/intmax2` | intmax2 installation directory |
| SSH Username | `pi` | (For reward monitoring) SSH connection user |
| CLI Directory | `/home/pi/intmax2/cli` | (For reward monitoring) CLI location |
| spend-key | `0x...` | (For reward monitoring) INTMAX private key |

---

## Steps to Add a New Node

### 1. Install Agent on the Node

**Method A: One-liner (Recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash
```

**Method B: git clone**

If you get a 404 error (GitHub CDN cache issue):

```bash
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git /tmp/intmax-monitoring
cd /tmp/intmax-monitoring/agent
sudo ./install.sh
```

**Method C: Manual Download**

```bash
mkdir -p /tmp/intmax-agent && cd /tmp/intmax-agent
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/install.sh -o install.sh
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/intmax_builder_metrics.sh -o intmax_builder_metrics.sh
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/uninstall.sh -o uninstall.sh
chmod +x *.sh
sudo ./install.sh
```

### 2. Create Configuration File on the Node

```bash
sudo nano /etc/default/intmax-builder-metrics
```

```bash
NODE_NAME="builder-03"
BUILDER_CONTAINER_NAME="block-builder"
BUILDER_DATA_DIR="/home/pi/intmax2"
```

### 3. Verify on the Node

```bash
curl -s localhost:9100/metrics | grep intmax_builder
```

Expected output:
```
intmax_builder_up{node="builder-03"} 1
intmax_builder_container_running{node="builder-03"} 1
```

### 4. Add to Targets on Monitoring Server

```bash
nano server/prometheus/targets/builders.yml
```

```yaml
- targets:
  - 192.168.1.10:9100   # Existing
  - 192.168.1.11:9100   # Existing
  - 192.168.1.12:9100   # New
```

### 5. (Optional) Add to Reward Monitoring

#### 5-1. Create spend-key File on the Node

```bash
sudo mkdir -p /etc/intmax-builder
echo "0xYourSpendKey" | sudo tee /etc/intmax-builder/spend-key
sudo chmod 644 /etc/intmax-builder/spend-key
```

#### 5-2. Register Monitoring Server's SSH Public Key on the Node

Check public key on monitoring server:
```bash
cat ~/.ssh/id_ed25519.pub
```

Add to authorized_keys on the node:
```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

#### 5-3. Add to known_hosts on Monitoring Server

```bash
ssh-keyscan 192.168.1.12 >> ~/.ssh/known_hosts
```

#### 5-4. Edit .env on Monitoring Server

```bash
# Add to NODES_CONFIG
NODES_CONFIG=node1:...,node2:...,node3:user@192.168.1.12:/home/user/intmax2/cli:/etc/intmax-builder/spend-key

# Add to WALLET_ADDRESSES (for sITX monitoring)
WALLET_ADDRESSES=0x...,0x...,0xNewWalletAddress
```

### 6. Restart Monitoring Server

```bash
cd server
docker compose down && docker compose up -d
```

---

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/uninstall.sh | sudo bash
```

Or if you used git clone:

```bash
sudo /tmp/intmax-monitoring/agent/uninstall.sh
```
