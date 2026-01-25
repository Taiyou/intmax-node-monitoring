# Security Best Practices

This document outlines security recommendations for operating the INTMAX Node Monitoring system.

## Overview

The monitoring system handles sensitive information including:
- SSH keys for node access
- Wallet addresses
- spend-key files for reward claiming
- Network topology information

Follow these guidelines to minimize security risks.

---

## File Permissions

### Configuration Files

```bash
# .env file (contains sensitive configuration)
chmod 600 server/.env
chown $USER:$USER server/.env

# SSH private key
chmod 600 ~/.ssh/id_ed25519
chown $USER:$USER ~/.ssh/id_ed25519

# spend-key file on nodes
sudo chmod 644 /etc/intmax-builder/spend-key
sudo chown root:root /etc/intmax-builder/spend-key
```

### Docker Socket

Restrict Docker socket access to necessary users only:

```bash
# Check current permissions
ls -la /var/run/docker.sock

# Only add trusted users to docker group
sudo usermod -aG docker <username>
```

---

## Network Security

### Firewall Configuration

Configure firewall rules to restrict access:

```bash
# Allow only monitoring server to scrape metrics
sudo ufw allow from <monitoring-server-ip> to any port 9100

# Restrict Grafana access (optional - internal network only)
sudo ufw allow from 192.168.0.0/16 to any port 3000

# Deny public access to Prometheus
sudo ufw deny 9090
```

### Recommended Firewall Rules

| Port | Service | Recommendation |
|------|---------|----------------|
| 9100 | node_exporter | Allow only from monitoring server IP |
| 9090 | Prometheus | Internal access only (not public) |
| 3000 | Grafana | Internal network or VPN only |
| 22 | SSH | Key-based auth only, consider changing port |

### SSH Hardening

Edit `/etc/ssh/sshd_config`:

```bash
# Disable password authentication
PasswordAuthentication no

# Allow only specific users
AllowUsers your-username

# Disable root login
PermitRootLogin no

# Use SSH protocol 2 only
Protocol 2
```

Restart SSH service:
```bash
sudo systemctl restart sshd
```

---

## Credential Management

### Environment Variables

Never commit sensitive data to version control:

```bash
# .gitignore should include:
.env
server/.env
prometheus/targets/builders.yml
scripts/claim_config.env
```

### SSH Key Management

1. **Use ED25519 keys** (more secure than RSA):
   ```bash
   ssh-keygen -t ed25519 -C "monitoring-server"
   ```

2. **Separate keys for different purposes**:
   - One key for monitoring (read-only operations)
   - One key for reward claiming (if automated)

3. **Limit SSH key usage**:
   On nodes, you can restrict what commands an SSH key can run by editing `~/.ssh/authorized_keys`:
   ```bash
   command="cd /home/user/intmax2/cli && ./target/release/intmax2-cli balance --private-key $(cat /etc/intmax-builder/spend-key)",no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAA... monitoring-key
   ```

### spend-key Security

The spend-key is used for:
- Checking reward balances
- Claiming rewards

It **cannot** be used to:
- Transfer funds from your wallet
- Access other accounts

However, protect it because:
- Anyone with the key can claim rewards
- It reveals your wallet association

**Recommendations:**
1. Store in `/etc/intmax-builder/` with restricted permissions
2. Don't include in backups that leave the server
3. Rotate if you suspect compromise

---

## Docker Security

### Run Containers as Non-Root

The exporters in this project run as non-root by default. Verify with:

```bash
docker compose exec wallet-exporter whoami
```

### Limit Container Capabilities

The `docker-compose.yml` already limits capabilities. Do not modify these unless necessary:

```yaml
security_opt:
  - no-new-privileges:true
```

### Use Read-Only Volumes Where Possible

```yaml
volumes:
  - ./config:/config:ro  # Read-only mount
```

---

## Monitoring Security

### Grafana Security

1. **Change default password immediately**:
   ```bash
   # In .env
   GRAFANA_ADMIN_PASSWORD=your-strong-password
   ```

2. **Enable HTTPS** (recommended for production):
   Use a reverse proxy (nginx, Traefik) with SSL certificates.

3. **Disable anonymous access**:
   Already disabled by default in this configuration.

### Prometheus Security

1. **Don't expose Prometheus publicly**:
   Prometheus has no built-in authentication. Keep it internal.

2. **Use a reverse proxy** if external access is needed:
   ```nginx
   # Example nginx configuration
   location /prometheus/ {
       auth_basic "Prometheus";
       auth_basic_user_file /etc/nginx/.htpasswd;
       proxy_pass http://localhost:9090/;
   }
   ```

---

## Backup Security

### What to Backup

| Item | Location | Sensitivity |
|------|----------|-------------|
| Grafana dashboards | `grafana/dashboards/` | Low |
| Prometheus data | Docker volume `prom_data` | Medium |
| Configuration | `.env`, `builders.yml` | High |
| SSH keys | `~/.ssh/` | **Critical** |

### Backup Recommendations

1. **Encrypt backups** before storing off-site
2. **Don't backup** spend-key files unless necessary
3. **Test restoration** periodically

```bash
# Example: encrypted backup
tar -czf - server/.env prometheus/targets/ | gpg -c > backup-$(date +%Y%m%d).tar.gz.gpg
```

---

## Incident Response

### If SSH Key is Compromised

1. **Immediately** regenerate the key:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ```

2. Remove old key from all nodes:
   ```bash
   # On each node, edit authorized_keys
   nano ~/.ssh/authorized_keys
   # Remove the compromised key line
   ```

3. Add new key to all nodes

### If spend-key is Compromised

1. **Claim all pending rewards immediately**:
   ```bash
   ./intmax2-cli claim --private-key 0xYOUR_SPEND_KEY
   ```

2. Rewards are sent to your registered wallet (which requires a different key to access)

3. Generate a new spend-key through INTMAX CLI

### If Monitoring Server is Compromised

1. Stop all services immediately:
   ```bash
   docker compose down
   ```

2. Rotate all SSH keys

3. Change Grafana password

4. Review access logs:
   ```bash
   docker compose logs > incident-logs.txt
   ```

5. Rebuild from clean installation

---

## Security Checklist

Before deploying to production:

- [ ] Changed default Grafana password
- [ ] Configured firewall rules
- [ ] SSH key-based authentication only
- [ ] `.env` file has restricted permissions (600)
- [ ] Prometheus not exposed publicly
- [ ] Docker socket access restricted
- [ ] spend-key files have appropriate permissions
- [ ] Backup strategy in place
- [ ] Monitoring server on a separate network segment (if possible)

---

## Reporting Security Issues

If you discover a security vulnerability in this project:

1. **Do not** open a public GitHub issue
2. Contact the maintainer directly
3. Provide details about the vulnerability
4. Allow time for a fix before public disclosure
