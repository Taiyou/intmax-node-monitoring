# Raspberry Pi

## Supported Models

| Model | CPU | RAM | Support |
|-------|-----|-----|---------|
| Raspberry Pi 5 | Cortex-A76 | 4GB+ | * Recommended |
| Raspberry Pi 4 | Cortex-A72 | 4GB+ | * Supported |
| Raspberry Pi 3 | Cortex-A53 | 1GB | Limited |

## Requirements

- **64-bit OS** (Raspberry Pi OS 64-bit recommended)
- Docker & Docker Compose
- At least 2GB RAM (4GB+ recommended)

## Installation Notes

### Check Architecture

```bash
uname -m
# Should show: aarch64
```

### node_exporter

The agent automatically downloads the ARM64 version of node_exporter.

### Docker

Install Docker on Raspberry Pi:

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

## Performance Considerations

### Monitoring Server on Raspberry Pi

Running Prometheus + Grafana on Raspberry Pi is possible but may be slow. Consider:

- Using an SSD instead of SD card
- Increasing swap space
- Reducing data retention period

### Node Agent on Raspberry Pi

The agent is lightweight and works well on Raspberry Pi 3 and above.

## Troubleshooting

### High Memory Usage

Reduce Prometheus retention:
```bash
# .env
PROMETHEUS_RETENTION=30d
```

### Slow Dashboard

- Reduce time range in Grafana
- Use instant queries instead of range queries for stat panels
