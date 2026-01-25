# About INTMAX Block Builder

## What is Block Builder?

INTMAX Block Builder is infrastructure that supports the INTMAX network by aggregating and processing transactions. Operators earn rewards for contributing to the network.

## Reward Structure

| Type | Currency | Description |
|------|----------|-------------|
| Transaction Fees | ETH | Fees from processed transactions |
| Protocol Incentives | sITX | Tokens distributed by the protocol |

## System Requirements

| Item | Minimum | Recommended |
|------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Storage | 50GB SSD | 100GB+ SSD |
| Network | Stable connection | Low latency |

## Official Resources

- [INTMAX Official](https://intmax.io)
- [Block Builder GitHub](https://github.com/InternetMaximalism/intmax2)
- [Documentation](https://docs.network.intmax.io/)

---

## Block Builder Setup

### 0. Install Required Packages

```bash
sudo apt update
sudo apt install -y curl git jq uuid-runtime build-essential pkg-config libssl-dev
```

### 1. Initialize Docker Swarm

```bash
docker swarm init
```

### 2. Prepare MetaMask Wallet

1. Create a new wallet in MetaMask
2. Export the private key (for Block Builder)
3. Note the wallet address (for receiving rewards)

### 3. Bridge ETH to Scroll

1. Get ETH on Ethereum Mainnet
2. Bridge to Scroll network via [Scroll Bridge](https://scroll.io/bridge)
3. Recommended: 0.01-0.05 ETH for initial gas

### 4. Get Scroll RPC URL

1. Sign up at [Infura](https://infura.io) or [Alchemy](https://alchemy.com)
2. Create a new project for Scroll network
3. Copy the RPC URL (e.g., `https://scroll-mainnet.infura.io/v3/YOUR_PROJECT_ID`)

### 5. Download and Run Block Builder

**For Mainnet:**
```bash
curl -o builder.sh https://raw.githubusercontent.com/InternetMaximalism/intmax2/refs/heads/main/scripts/block-builder-mainnet.sh
chmod +x builder.sh
```

**For Testnet:**
```bash
curl -o builder.sh https://raw.githubusercontent.com/InternetMaximalism/intmax2/refs/heads/main/scripts/block-builder-testnet.sh
chmod +x builder.sh
```

### 6. Setup

```bash
./builder.sh setup
./builder.sh setup-env
# Enter your private key and RPC URL when prompted
```

### 7. Start

```bash
./builder.sh run
```

### 8. Verify

```bash
./builder.sh health
./builder.sh monitor
```

---

## Network Configuration

| Network | Chain ID | RPC Example |
|---------|----------|-------------|
| Scroll Mainnet | 534352 | `https://scroll-mainnet.infura.io/v3/YOUR_ID` |
| Scroll Sepolia | 534351 | `https://scroll-sepolia.infura.io/v3/YOUR_ID` |

**Warning:** Do not mix Mainnet and Testnet configurations. If you see a NETWORK MISMATCH error, ensure your RPC URL matches your chosen network.

---

## INTMAX CLI Setup (for Rewards)

### 1. Clone Repository

```bash
cd ~
git clone https://github.com/InternetMaximalism/intmax2.git
cd intmax2/cli
```

### 2. Configure Environment

```bash
cp .env.example .env
nano .env
```

Set your RPC URLs:
```bash
L1_RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
L2_RPC_URL=https://scroll-mainnet.infura.io/v3/YOUR_PROJECT_ID
```

### 3. Build CLI

```bash
cargo build -r
```

### 4. Check Balance

```bash
./target/release/intmax2-cli balance --private-key 0xYOUR_SPEND_KEY
```

### 5. Claim Rewards

```bash
./target/release/intmax2-cli claim --private-key 0xYOUR_SPEND_KEY
```

---

## Cost Estimation

| Item | Cost | Frequency |
|------|------|-----------|
| Server (VPS) | $10-50/month | Monthly |
| Gas (Scroll) | ~0.001 ETH | Per transaction |
| Initial Setup | 0.01-0.05 ETH | One-time |

## Expected Revenue

Revenue varies based on:
- Network activity
- Number of transactions processed
- sITX token price

Check the official INTMAX documentation for current reward rates.
