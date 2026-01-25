# INTMAX Node Monitoring

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-2.x-orange.svg)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-10.x-green.svg)](https://grafana.com/)

A Prometheus + Grafana monitoring environment for managing multiple INTMAX Block Builder nodes.

<img width="1160" height="463" alt="Dashboard Screenshot" src="https://github.com/user-attachments/assets/97fbc0f9-70e5-4ec4-8e82-458f945146b9" />

## Prerequisites

Before you begin, ensure you have the following:

| Requirement | Version | Notes |
|-------------|---------|-------|
| Docker | 20.10+ | [Installation Guide](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | Included with Docker Desktop |
| Git | 2.0+ | For cloning the repository |
| INTMAX Block Builder | Running | Must be operational before monitoring |

**Network Requirements:**
- Port 3000: Grafana dashboard
- Port 9090: Prometheus (optional, for debugging)
- Port 9100: node_exporter (on each monitored node)

## Project Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INTMAX Block Builder Operations                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Block Builder Setup                                             │
│     └─ Launch nodes using official script (builder.sh)              │
│     └─ Details: wiki/About-INTMAX.md                                │
│                                                                     │
│  2. Operations Monitoring  ← This Project                           │
│     └─ Centralized management of multiple nodes                     │
│     └─ Visualization of rewards (ETH/sITX)                          │
│     └─ Anomaly detection and alerting                               │
│                                                                     │
│  3. Reward Collection                                               │
│     └─ Automatic collection script (optional)                       │
│     └─ Manual collection via INTMAX CLI                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

After launching Block Builder, **set up the monitoring environment with this project** to:

- View status of multiple nodes on a single dashboard
- Detect node downtime immediately
- Visualize accumulated rewards in graphs
- Monitor wallet balance (gas fees)

## Features

| Feature | Description |
|---------|-------------|
| Multi-node Dashboard | View all nodes in a single Grafana dashboard |
| Real-time Monitoring | Container status, uptime, and health checks |
| Reward Tracking | Monitor pending ETH and sITX rewards |
| Wallet Balance | Track gas fees and token balances |
| Alerting | Configurable alerts for node downtime and low balances |
| Raspberry Pi Support | Compatible with 64-bit ARM devices |
| Easy Setup | One-liner installation for agents |
| Data Retention | 90 days of historical data (configurable) |

## Quick Start

### Step 1: Set Up Monitoring Server

```bash
# Clone the repository
git clone https://github.com/Taiyou/intmax-node-monitoring-en.git
cd intmax-node-monitoring-en/server

# Copy configuration templates
cp .env.example .env
cp prometheus/targets/builders.yml.example prometheus/targets/builders.yml

# Edit builders.yml to add your node IPs
nano prometheus/targets/builders.yml
```

Example `builders.yml`:
```yaml
- targets:
  - 192.168.1.10:9100   # Node 1
  - 192.168.1.11:9100   # Node 2
```

Start the monitoring stack:
```bash
docker compose up -d
```

**Access Points:**
| Service | URL | Default Credentials |
|---------|-----|---------------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | None |

### Step 2: Install Agent on Each Node

Run on each Block Builder node:

```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash
```

Create the configuration file:
```bash
sudo nano /etc/default/intmax-builder-metrics
```

```bash
NODE_NAME="builder-01"
BUILDER_CONTAINER_NAME="block-builder"
BUILDER_DATA_DIR="/home/pi/intmax2"
```

Verify the agent is working:
```bash
curl -s localhost:9100/metrics | grep intmax_builder
```

### Step 3: Verify in Grafana

1. Open Grafana at http://localhost:3000
2. Navigate to **Dashboards** > **INTMAX Builders Overview**
3. Your nodes should appear within 1-2 minutes

## Documentation

### Getting Started
| Page | Description |
|------|-------------|
| [About INTMAX](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/About-INTMAX) | Block Builder overview, setup, and reward structure |
| [Server Setup](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Setup-Server) | Prometheus + Grafana setup |
| [Node Setup](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Setup-Node) | Agent setup for each node |

### Operations
| Page | Description |
|------|-------------|
| [Rewards](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Rewards) | Reward monitoring and automatic collection |
| [Metrics Reference](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Metrics) | Complete list of collected metrics and PromQL examples |
| [Upgrading](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Upgrading) | How to upgrade the monitoring system |

### Reference
| Page | Description |
|------|-------------|
| [Security Best Practices](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Security) | Security recommendations and hardening |
| [Raspberry Pi](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Raspberry-Pi) | Compatible models and notes |
| [Troubleshooting & FAQ](https://github.com/Taiyou/intmax-node-monitoring-en/wiki/Troubleshooting) | Common issues, solutions, and frequently asked questions |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Monitoring Server                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │   Prometheus    │  │     Grafana     │  │    Exporters    │         │
│  │   (port 9090)   │←─│   (port 3000)   │  │  wallet: 9101   │         │
│  │                 │  │                 │  │  reward: 9102   │         │
│  └────────┬────────┘  └─────────────────┘  └────────┬────────┘         │
│           │              Scrape (15s)               │                   │
│           └──────────────────┬──────────────────────┘                   │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   Node 1        │   │   Node 2        │   │   Node N        │
│ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │
│ │Block Builder│ │   │ │Block Builder│ │   │ │Block Builder│ │
│ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │
│ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │
│ │node_exporter│ │   │ │node_exporter│ │   │ │node_exporter│ │
│ │ (port 9100) │ │   │ │ (port 9100) │ │   │ │ (port 9100) │ │
│ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

## Project Structure

```
intmax-node-monitoring/
├── agent/                    # Node-side monitoring agent
│   ├── setup.sh             # Remote installation script
│   ├── install.sh           # Local installation script
│   ├── uninstall.sh         # Removal script
│   └── intmax_builder_metrics.sh  # Metrics collection (cron)
│
├── server/                   # Docker-based monitoring server
│   ├── docker-compose.yml   # Service orchestration
│   ├── .env.example         # Configuration template
│   ├── prometheus/          # Prometheus configuration
│   │   ├── prometheus.yml   # Scrape configuration
│   │   ├── rules/           # Alert rules
│   │   └── targets/         # Node discovery
│   ├── wallet-exporter/     # Wallet balance monitoring
│   ├── reward-exporter/     # Reward balance monitoring
│   └── scripts/             # Automation scripts
│
├── grafana/                  # Grafana configuration
│   ├── provisioning/        # Auto-provisioning
│   └── dashboards/          # Dashboard JSON files
│
└── wiki/                     # Documentation
```

## Collected Metrics

| Metric | Description | Source |
|--------|-------------|--------|
| `intmax_builder_up` | Node availability (1=up, 0=down) | Agent |
| `intmax_builder_container_running` | Docker container status | Agent |
| `intmax_builder_uptime_seconds` | Container uptime | Agent |
| `intmax_builder_data_size_bytes` | Data directory size | Agent |
| `intmax_wallet_eth` | Wallet ETH balance | Wallet Exporter |
| `intmax_wallet_sitx` | Wallet sITX balance | Wallet Exporter |
| `intmax_builder_reward_eth` | Pending ETH rewards | Reward Exporter |
| `intmax_builder_reward_sitx` | Pending sITX rewards | Reward Exporter |

## Updating

To update to the latest version:

```bash
# On monitoring server
cd intmax-node-monitoring-en
git pull origin main
docker compose down
docker compose pull
docker compose up -d

# On each node (re-run installation)
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [INTMAX](https://intmax.io) - The INTMAX Network
- [Prometheus](https://prometheus.io) - Monitoring system
- [Grafana](https://grafana.com) - Visualization platform
