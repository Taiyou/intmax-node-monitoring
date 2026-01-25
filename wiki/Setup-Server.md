# Server Setup

## Requirements

- Docker & Docker Compose
- Available ports: 3000 (Grafana), 9090 (Prometheus)
- SSH key (if using reward monitoring)

## Setup

```bash
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git
cd intmax-node-monitoring-en/server

# Copy configuration files
cp .env.example .env
cp prometheus/targets/builders.yml.example prometheus/targets/builders.yml
```

## Basic Configuration

### Register Target Nodes

Edit `prometheus/targets/builders.yml`:

```yaml
- targets:
  - 192.168.1.10:9100   # Node 1
  - 192.168.1.11:9100   # Node 2
```

### Environment Variables

Edit `server/.env`:

```bash
# Grafana admin settings
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=your_password

# Prometheus data retention (3 months = 90 days)
PROMETHEUS_RETENTION=90d
```

## Reward Monitoring Setup (Optional)

### Wallet Balance Monitoring

Monitor ETH and sITX wallet balances.

```bash
# Add to .env
WALLET_ADDRESSES=0xYourWallet1,0xYourWallet2
SITX_CONTRACT=0xc0579287f3CDE6BF796BE6E2bB61DbB06DA85024
SCROLL_RPC_URL=https://rpc.scroll.io
UPDATE_INTERVAL=3600
```

### Pending Reward Monitoring (via SSH)

Monitor unclaimed rewards on each node.

**1. Generate SSH key (if not exists):**
```bash
ssh-keygen -t ed25519
```

**2. Add configuration to .env:**
```bash
# Format: "name:user@host:cli_dir:spend_key_file"
NODES_CONFIG=node1:user@192.168.1.10:/home/user/intmax2/cli:/etc/intmax-builder/spend-key,node2:user@192.168.1.11:/home/user/intmax2/cli:/etc/intmax-builder/spend-key
REWARD_UPDATE_INTERVAL=3600
```

**3. Register SSH public key on each node:**

See [Node Setup](Setup-Node) for details.

## Start

```bash
docker compose up -d
```

## Access

| Service | URL | Authentication |
|---------|-----|----------------|
| Grafana | http://localhost:3000 | admin / (your password) |
| Prometheus | http://localhost:9090 | None |

## Dashboard Features

| Panel | Description |
|-------|-------------|
| Pending Rewards (ETH) | Total unclaimed ETH rewards across nodes |
| Wallet ETH (Gas) | Wallet ETH balance |
| Total sITX (Wallet) | Wallet sITX balance |
| Next Reward Check | Next reward check time |
| Next Wallet Check | Next wallet check time |
| Rewards History | ETH/sITX history graph (3 months) |
| Builder Status | Status of each node |
| Builder Nodes | Node list table |

## Management Commands

```bash
# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f

# Remove including data
docker compose down -v
```

## After Configuration Changes

Restart required after changing `.env` or `builders.yml`:

```bash
docker compose down && docker compose up -d
```
