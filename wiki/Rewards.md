# Rewards

## Overview

| Feature | Description | Update Interval |
|---------|-------------|-----------------|
| Wallet Balance Monitoring | ETH + sITX | Hourly (configurable) |
| Pending Reward Monitoring | Unclaimed rewards on nodes | Hourly (configurable) |
| Automatic Collection | Collect rewards to wallet | Weekly (cron) |

## Dashboard Display

| Panel | Content |
|-------|---------|
| Pending Rewards (ETH) | Total unclaimed ETH rewards across all nodes |
| Wallet ETH (Gas) | Wallet ETH balance (for gas fees) |
| Total sITX (Wallet) | Wallet sITX balance |
| Next Reward Check | Next reward check time (local time) |
| Next Wallet Check | Next wallet check time (local time) |
| Rewards History | 3-month balance history graph |

## Wallet Balance Monitoring

Edit `server/.env`:

```bash
# Wallet addresses (comma-separated)
WALLET_ADDRESSES=0xYourWallet1,0xYourWallet2

# sITX token contract (Scroll)
SITX_CONTRACT=0xc0579287f3CDE6BF796BE6E2bB61DbB06DA85024

# Scroll RPC URL
SCROLL_RPC_URL=https://rpc.scroll.io

# Update interval (seconds) Default: 3600 = 1 hour
UPDATE_INTERVAL=3600
```

## Pending Reward Monitoring (via SSH)

### Monitoring Server Setup

Edit `server/.env`:

```bash
# Format: "name:user@host:cli_dir:spend_key_file"
NODES_CONFIG=node1:user@192.168.1.10:/home/user/intmax2/cli:/etc/intmax-builder/spend-key

# Update interval (seconds) Default: 3600 = 1 hour
REWARD_UPDATE_INTERVAL=3600
```

### Node-side Setup

**1. Register SSH public key:**

Display public key on monitoring server:
```bash
cat ~/.ssh/id_ed25519.pub
```

Add to authorized_keys on node:
```bash
mkdir -p ~/.ssh
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

**2. Create spend-key file:**
```bash
sudo mkdir -p /etc/intmax-builder
echo "0xYourSpendKey" | sudo tee /etc/intmax-builder/spend-key
sudo chmod 644 /etc/intmax-builder/spend-key
```

**3. Add to known_hosts on monitoring server:**
```bash
ssh-keyscan 192.168.1.10 >> ~/.ssh/known_hosts
```

### Verification

```bash
# SSH test from monitoring server
ssh user@192.168.1.10 "cat /etc/intmax-builder/spend-key"

# Check reward-exporter logs
docker compose logs -f reward-exporter
```

## Automatic Collection (Weekly)

### Configuration

```bash
cd server/scripts
cp claim_config.env.example claim_config.env
nano claim_config.env
```

Example configuration:
```bash
NODES=(
    "user@192.168.1.10:/home/user/intmax2/cli:/etc/intmax-builder/spend-key"
    "user@192.168.1.11:/home/user/intmax2/cli:/etc/intmax-builder/spend-key"
)
```

### Add to cron

Run automatically at 3:00 PM on Sundays:
```bash
crontab -e
```

```
0 15 * * 0 /path/to/server/scripts/claim_rewards.sh >> /tmp/intmax-claim.log 2>&1
```

### Manual Execution

```bash
./server/scripts/claim_rewards.sh
```

## Alerts

Alerts trigger under the following conditions (Prometheus rules):

| Alert | Condition |
|-------|-----------|
| INTMAXWalletLowBalance | Wallet ETH < 0.001 |
| INTMAXWalletCriticalBalance | Wallet ETH < 0.0001 |
| INTMAXHighSITXBalance | sITX > 1000 (24 hours) |
| INTMAXHighRewardBalance | Reward ETH > 0.1 (24 hours) |
| INTMAXRewardCheckStale | Reward check older than 2 hours |
