# セキュリティベストプラクティス

このドキュメントでは、INTMAX Node Monitoringシステムを運用する際のセキュリティ推奨事項を説明します。

## 概要

監視システムは以下の機密情報を扱います：
- ノードアクセス用のSSH鍵
- ウォレットアドレス
- 報酬請求用のspend-keyファイル
- ネットワークトポロジー情報

これらのガイドラインに従ってセキュリティリスクを最小限に抑えてください。

---

## ファイル権限

### 設定ファイル

```bash
# .envファイル（機密設定を含む）
chmod 600 server/.env
chown $USER:$USER server/.env

# SSH秘密鍵
chmod 600 ~/.ssh/id_ed25519
chown $USER:$USER ~/.ssh/id_ed25519

# ノード上のspend-keyファイル
sudo chmod 644 /etc/intmax-builder/spend-key
sudo chown root:root /etc/intmax-builder/spend-key
```

### Dockerソケット

Dockerソケットへのアクセスを必要なユーザーのみに制限：

```bash
# 現在の権限を確認
ls -la /var/run/docker.sock

# 信頼できるユーザーのみをdockerグループに追加
sudo usermod -aG docker <username>
```

---

## ネットワークセキュリティ

### ファイアウォール設定

ファイアウォールルールを設定してアクセスを制限：

```bash
# 監視サーバーからのみメトリクス取得を許可
sudo ufw allow from <monitoring-server-ip> to any port 9100

# Grafanaアクセスを制限（オプション - 内部ネットワークのみ）
sudo ufw allow from 192.168.0.0/16 to any port 3000

# Prometheusへの公開アクセスを拒否
sudo ufw deny 9090
```

### 推奨ファイアウォールルール

| ポート | サービス | 推奨設定 |
|--------|----------|----------|
| 9100 | node_exporter | 監視サーバーIPからのみ許可 |
| 9090 | Prometheus | 内部アクセスのみ（公開しない） |
| 3000 | Grafana | 内部ネットワークまたはVPNのみ |
| 22 | SSH | 鍵認証のみ、ポート変更を検討 |

### SSHハードニング

`/etc/ssh/sshd_config`を編集：

```bash
# パスワード認証を無効化
PasswordAuthentication no

# 特定のユーザーのみ許可
AllowUsers your-username

# rootログインを無効化
PermitRootLogin no

# SSHプロトコル2のみ使用
Protocol 2
```

SSHサービスを再起動：
```bash
sudo systemctl restart sshd
```

---

## 認証情報管理

### 環境変数

機密データをバージョン管理にコミットしない：

```bash
# .gitignoreに含めるべき項目：
.env
server/.env
prometheus/targets/builders.yml
scripts/claim_config.env
```

### SSH鍵管理

1. **ED25519鍵を使用**（RSAより安全）：
   ```bash
   ssh-keygen -t ed25519 -C "monitoring-server"
   ```

2. **目的別に鍵を分離**：
   - 監視用の鍵（読み取り専用操作）
   - 報酬請求用の鍵（自動化する場合）

3. **SSH鍵の使用を制限**：
   ノード上で、`~/.ssh/authorized_keys`を編集してSSH鍵が実行できるコマンドを制限：
   ```bash
   command="cd /home/user/intmax2/cli && ./target/release/intmax2-cli balance --private-key $(cat /etc/intmax-builder/spend-key)",no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAA... monitoring-key
   ```

### spend-keyのセキュリティ

spend-keyは以下に使用されます：
- 報酬残高の確認
- 報酬の請求

以下には使用**できません**：
- ウォレットからの資金移動
- 他のアカウントへのアクセス

ただし、以下の理由で保護が必要です：
- 鍵を持つ人は誰でも報酬を請求できる
- ウォレットとの関連が明らかになる

**推奨事項：**
1. `/etc/intmax-builder/`に制限された権限で保存
2. サーバー外に出るバックアップに含めない
3. 漏洩の疑いがある場合はローテーション

---

## Dockerセキュリティ

### コンテナを非rootで実行

このプロジェクトのexporterはデフォルトで非rootとして実行されます。以下で確認：

```bash
docker compose exec wallet-exporter whoami
```

### コンテナ機能を制限

`docker-compose.yml`はすでに機能を制限しています。必要でない限り変更しないでください：

```yaml
security_opt:
  - no-new-privileges:true
```

### 可能な限り読み取り専用ボリュームを使用

```yaml
volumes:
  - ./config:/config:ro  # 読み取り専用マウント
```

---

## 監視セキュリティ

### Grafanaセキュリティ

1. **デフォルトパスワードを即座に変更**：
   ```bash
   # .envで設定
   GRAFANA_ADMIN_PASSWORD=your-strong-password
   ```

2. **HTTPSを有効化**（本番環境で推奨）：
   リバースプロキシ（nginx、Traefik）とSSL証明書を使用。

3. **匿名アクセスを無効化**：
   この設定ではデフォルトで無効になっています。

### Prometheusセキュリティ

1. **Prometheusを公開しない**：
   Prometheusには組み込みの認証がありません。内部に保持してください。

2. **外部アクセスが必要な場合はリバースプロキシを使用**：
   ```nginx
   # nginx設定例
   location /prometheus/ {
       auth_basic "Prometheus";
       auth_basic_user_file /etc/nginx/.htpasswd;
       proxy_pass http://localhost:9090/;
   }
   ```

---

## バックアップセキュリティ

### バックアップ対象

| 項目 | 場所 | 機密度 |
|------|------|--------|
| Grafanaダッシュボード | `grafana/dashboards/` | 低 |
| Prometheusデータ | Dockerボリューム `prom_data` | 中 |
| 設定 | `.env`, `builders.yml` | 高 |
| SSH鍵 | `~/.ssh/` | **重要** |

### バックアップ推奨事項

1. オフサイトに保存する前に**バックアップを暗号化**
2. 必要でない限りspend-keyファイルを**バックアップしない**
3. 定期的に**復元をテスト**

```bash
# 例：暗号化バックアップ
tar -czf - server/.env prometheus/targets/ | gpg -c > backup-$(date +%Y%m%d).tar.gz.gpg
```

---

## インシデント対応

### SSH鍵が漏洩した場合

1. **即座に**鍵を再生成：
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
   ```

2. すべてのノードから古い鍵を削除：
   ```bash
   # 各ノードでauthorized_keysを編集
   nano ~/.ssh/authorized_keys
   # 漏洩した鍵の行を削除
   ```

3. 新しい鍵をすべてのノードに追加

### spend-keyが漏洩した場合

1. **即座に保留中のすべての報酬を請求**：
   ```bash
   ./intmax2-cli claim --private-key 0xYOUR_SPEND_KEY
   ```

2. 報酬は登録されたウォレットに送られます（アクセスには別の鍵が必要）

3. INTMAX CLIで新しいspend-keyを生成

### 監視サーバーが侵害された場合

1. すべてのサービスを即座に停止：
   ```bash
   docker compose down
   ```

2. すべてのSSH鍵をローテーション

3. Grafanaパスワードを変更

4. アクセスログを確認：
   ```bash
   docker compose logs > incident-logs.txt
   ```

5. クリーンインストールから再構築

---

## セキュリティチェックリスト

本番環境にデプロイする前に：

- [ ] デフォルトのGrafanaパスワードを変更
- [ ] ファイアウォールルールを設定
- [ ] SSH鍵認証のみ
- [ ] `.env`ファイルの権限を制限（600）
- [ ] Prometheusを公開しない
- [ ] Dockerソケットアクセスを制限
- [ ] spend-keyファイルに適切な権限
- [ ] バックアップ戦略を策定
- [ ] 監視サーバーを別のネットワークセグメントに配置（可能であれば）

---

## セキュリティ問題の報告

このプロジェクトでセキュリティ脆弱性を発見した場合：

1. 公開GitHubイシューを**開かない**
2. メンテナーに直接連絡
3. 脆弱性の詳細を提供
4. 公開前に修正の時間を確保
