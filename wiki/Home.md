# INTMAX Node Monitoring Wiki

## About This Project

When operating INTMAX Block Builder, you may face these challenges:

| Challenge | Solution |
|-----------|----------|
| Checking multiple nodes is tedious | Dashboard displays all nodes at once |
| Hard to notice when a node stops | Status monitoring and alerts |
| Don't know how much reward has accumulated | Graph display of ETH/sITX balance |
| Worried if wallet has enough gas | Balance monitoring and history display |
| Forget to collect rewards | Automatic collection script (optional) |

## Block Builder Operations Flow

```
┌──────────────────┐
│ 1. Node Setup    │  ← Launch with official builder.sh
└────────┬─────────┘
         ↓
┌──────────────────┐
│ 2. Monitoring    │  ← This Project
│   - Server setup │
│   - Agent setup  │
└────────┬─────────┘
         ↓
┌──────────────────┐
│ 3. Operations    │
│   - Dashboard    │
│   - Check rewards│
│   - Auto-collect │
└──────────────────┘
```

## Setup Guide

### Step 1: Launch Block Builder

If you haven't launched Block Builder yet, refer to [About INTMAX Block Builder](About-INTMAX) for setup.

### Step 2: Set Up Monitoring Server

Follow [Server Setup](Setup-Server) to build the Prometheus + Grafana environment.

### Step 3: Install Agent on Each Node

Follow [Node Setup](Setup-Node) to install the agent on each target node.

### Step 4: Configure Reward Monitoring (Optional)

To monitor ETH rewards and wallet balance, refer to [Rewards](Rewards).

## Table of Contents

### Getting Started
| Page | Description |
|------|-------------|
| [About INTMAX Block Builder](About-INTMAX) | Block Builder overview, setup, and reward structure |
| [Server Setup](Setup-Server) | Prometheus + Grafana setup |
| [Node Setup](Setup-Node) | Agent setup for each node |

### Operations
| Page | Description |
|------|-------------|
| [Rewards](Rewards) | Reward monitoring and automatic collection |
| [Metrics Reference](Metrics) | Complete list of collected metrics and PromQL examples |
| [Upgrading](Upgrading) | How to upgrade the monitoring system |

### Reference
| Page | Description |
|------|-------------|
| [Security Best Practices](Security) | Security recommendations and hardening |
| [Raspberry Pi](Raspberry-Pi) | Compatible models and notes |
| [Troubleshooting & FAQ](Troubleshooting) | Common issues, solutions, and frequently asked questions |

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            Monitoring Server                                 │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Docker Compose                               │   │
│  │                                                                      │   │
│  │  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐  │   │
│  │  │   Prometheus    │    │     Grafana     │    │ Wallet Exporter │  │   │
│  │  │   (port 9090)   │◄───│   (port 3000)   │    │   (port 9101)   │  │   │
│  │  │                 │    │                 │    │                 │  │   │
│  │  │  • Time-series  │    │  • Dashboard    │    │  • ETH balance  │  │   │
│  │  │  • Alert rules  │    │  • Alerts       │    │  • sITX balance │  │   │
│  │  │  • 90d retention│    │  • Graphs       │    │  • Scroll RPC   │  │   │
│  │  └────────┬────────┘    └─────────────────┘    └────────┬────────┘  │   │
│  │           │                                              │           │   │
│  │           │  Scrape every 15s                           │ HTTP/RPC  │   │
│  │           │                                              │           │   │
│  │  ┌────────┴────────┐                           ┌────────▼────────┐  │   │
│  │  │ Reward Exporter │                           │  Scroll Network │  │   │
│  │  │   (port 9102)   │                           │                 │  │   │
│  │  │                 │                           │  (Blockchain)   │  │   │
│  │  │  • SSH to nodes │                           └─────────────────┘  │   │
│  │  │  • CLI balance  │                                                │   │
│  │  └────────┬────────┘                                                │   │
│  │           │ SSH                                                     │   │
│  └───────────┼─────────────────────────────────────────────────────────┘   │
│              │                                                              │
└──────────────┼──────────────────────────────────────────────────────────────┘
               │
               │ Scrape metrics (HTTP :9100)
               │
    ┌──────────┴──────────┬───────────────────┬───────────────────┐
    │                     │                   │                   │
    ▼                     ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ ┌───────────┐
│   Node 1        │ │   Node 2        │ │   Node 3        │ │  Node N   │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │ │           │
│ │Block Builder│ │ │ │Block Builder│ │ │ │Block Builder│ │ │    ...    │
│ │  (Docker)   │ │ │ │  (Docker)   │ │ │ │  (Docker)   │ │ │           │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │ │           │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │ │           │
│ │node_exporter│ │ │ │node_exporter│ │ │ │node_exporter│ │ │           │
│ │ (port 9100) │ │ │ │ (port 9100) │ │ │ │ (port 9100) │ │ │           │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │ │           │
│ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │ │           │
│ │Metrics Cron │ │ │ │Metrics Cron │ │ │ │Metrics Cron │ │ │           │
│ │ (1-5 min)   │ │ │ │ (1-5 min)   │ │ │ │ (1-5 min)   │ │ │           │
│ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │ │           │
└─────────────────┘ └─────────────────┘ └─────────────────┘ └───────────┘
```

## Data Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│                              Data Flow                                      │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│  1. Node Metrics Collection (Every 1-5 minutes)                            │
│     ┌──────────────────┐     ┌──────────────────┐     ┌────────────────┐  │
│     │ intmax_builder_  │     │ node_exporter    │     │ Prometheus     │  │
│     │ metrics.sh       │────▶│ textfile_collector│────▶│ (scrape)      │  │
│     │ (cron job)       │     │ (:9100/metrics)  │     │                │  │
│     └──────────────────┘     └──────────────────┘     └────────────────┘  │
│                                                                            │
│  2. Wallet Balance (Every 1 hour)                                          │
│     ┌──────────────────┐     ┌──────────────────┐     ┌────────────────┐  │
│     │ Scroll Network   │     │ wallet-exporter  │     │ Prometheus     │  │
│     │ (JSON-RPC)       │◀────│ eth_getBalance   │────▶│ (scrape)      │  │
│     │                  │     │ balanceOf(sITX)  │     │                │  │
│     └──────────────────┘     └──────────────────┘     └────────────────┘  │
│                                                                            │
│  3. Reward Balance (Every 1 hour)                                          │
│     ┌──────────────────┐     ┌──────────────────┐     ┌────────────────┐  │
│     │ Builder Nodes    │     │ reward-exporter  │     │ Prometheus     │  │
│     │ (INTMAX CLI)     │◀────│ SSH + balance cmd│────▶│ (scrape)      │  │
│     │                  │     │                  │     │                │  │
│     └──────────────────┘     └──────────────────┘     └────────────────┘  │
│                                                                            │
│  4. Visualization                                                          │
│     ┌──────────────────┐     ┌──────────────────┐                         │
│     │ Prometheus       │     │ Grafana          │                         │
│     │ (time-series DB) │────▶│ (dashboard)      │────▶  User Browser     │
│     │                  │     │                  │                         │
│     └──────────────────┘     └──────────────────┘                         │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

| Component | Port | Purpose | Update Interval |
|-----------|------|---------|-----------------|
| Prometheus | 9090 | Time-series database, alert evaluation | 15s scrape |
| Grafana | 3000 | Dashboard visualization | Real-time |
| Wallet Exporter | 9101 | ETH/sITX wallet balance from Scroll | 1 hour |
| Reward Exporter | 9102 | Pending rewards via SSH | 1 hour |
| node_exporter | 9100 | System and custom metrics | 15s scrape |
| Metrics Cron | - | Docker/process status collection | 1-5 min |
