# INTMAX Node Monitoring

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![Prometheus](https://img.shields.io/badge/Prometheus-2.x-orange.svg)](https://prometheus.io/)
[![Grafana](https://img.shields.io/badge/Grafana-10.x-green.svg)](https://grafana.com/)

複数のINTMAX Block Builderノードを管理するためのPrometheus + Grafana監視環境です。

<img width="1160" height="463" alt="Dashboard Screenshot" src="https://github.com/user-attachments/assets/97fbc0f9-70e5-4ec4-8e82-458f945146b9" />

## 前提条件

開始する前に、以下が必要です：

| 要件 | バージョン | 備考 |
|------|-----------|------|
| Docker | 20.10+ | [インストールガイド](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.0+ | Docker Desktopに含まれています |
| Git | 2.0+ | リポジトリのクローン用 |
| INTMAX Block Builder | 稼働中 | 監視前に起動している必要があります |

**ネットワーク要件：**
- ポート 3000: Grafanaダッシュボード
- ポート 9090: Prometheus（オプション、デバッグ用）
- ポート 9100: node_exporter（各監視対象ノード）

## プロジェクト概要

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INTMAX Block Builder 運用                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. Block Builder セットアップ                                       │
│     └─ 公式スクリプト (builder.sh) でノードを起動                     │
│     └─ 詳細: wiki/About-INTMAX.md                                   │
│                                                                     │
│  2. 運用監視  ← このプロジェクト                                      │
│     └─ 複数ノードの一元管理                                          │
│     └─ 報酬（ETH/sITX）の可視化                                      │
│     └─ 異常検知とアラート                                            │
│                                                                     │
│  3. 報酬回収                                                         │
│     └─ 自動回収スクリプト（オプション）                               │
│     └─ INTMAX CLI による手動回収                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

Block Builder起動後、**このプロジェクトで監視環境を構築**することで：

- 複数ノードの状態を1つのダッシュボードで確認
- ノードの停止を即座に検知
- 蓄積された報酬をグラフで可視化
- ウォレット残高（ガス代）を監視

## 機能

| 機能 | 説明 |
|------|------|
| マルチノードダッシュボード | 全ノードを1つのGrafanaダッシュボードで表示 |
| リアルタイム監視 | コンテナ状態、稼働時間、ヘルスチェック |
| 報酬追跡 | 保留中のETHおよびsITX報酬を監視 |
| ウォレット残高 | ガス代とトークン残高を追跡 |
| アラート | ノード停止や残高低下の設定可能なアラート |
| Raspberry Pi対応 | 64ビットARMデバイスに対応 |
| 簡単セットアップ | エージェントのワンライナーインストール |
| データ保持 | 90日間の履歴データ（設定可能） |

## クイックスタート

### ステップ1: 監視サーバーのセットアップ

```bash
# リポジトリをクローン
git clone https://github.com/Taiyou/intmax-node-monitoring.git
cd intmax-node-monitoring/server

# 設定テンプレートをコピー
cp .env.example .env
cp prometheus/targets/builders.yml.example prometheus/targets/builders.yml

# builders.ymlを編集してノードIPを追加
nano prometheus/targets/builders.yml
```

`builders.yml`の例：
```yaml
- targets:
  - 192.168.1.10:9100   # ノード1
  - 192.168.1.11:9100   # ノード2
```

監視スタックを起動：
```bash
docker compose up -d
```

**アクセスポイント：**
| サービス | URL | デフォルト認証情報 |
|----------|-----|-------------------|
| Grafana | http://localhost:3000 | admin / admin |
| Prometheus | http://localhost:9090 | なし |

### ステップ2: 各ノードにエージェントをインストール

各Block Builderノードで実行：

```bash
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring/main/agent/setup.sh | sudo bash
```

設定ファイルを作成：
```bash
sudo nano /etc/default/intmax-builder-metrics
```

```bash
NODE_NAME="builder-01"
BUILDER_CONTAINER_NAME="block-builder"
BUILDER_DATA_DIR="/home/pi/intmax2"
```

エージェントの動作を確認：
```bash
curl -s localhost:9100/metrics | grep intmax_builder
```

### ステップ3: Grafanaで確認

1. Grafanaを開く: http://localhost:3000
2. **Dashboards** > **INTMAX Builders Overview** に移動
3. 1〜2分以内にノードが表示されます

## ドキュメント

### はじめに
| ページ | 説明 |
|--------|------|
| [INTMAX について](wiki/About-INTMAX.md) | Block Builderの概要、セットアップ、報酬構造 |
| [サーバーセットアップ](wiki/Setup-Server.md) | Prometheus + Grafanaのセットアップ |
| [ノードセットアップ](wiki/Setup-Node.md) | 各ノードへのエージェントセットアップ |

### 運用
| ページ | 説明 |
|--------|------|
| [報酬](wiki/Rewards.md) | 報酬監視と自動回収 |
| [メトリクスリファレンス](wiki/Metrics.md) | 収集されるメトリクスの完全なリストとPromQL例 |
| [アップグレード](wiki/Upgrading.md) | 監視システムのアップグレード方法 |

### リファレンス
| ページ | 説明 |
|--------|------|
| [セキュリティベストプラクティス](wiki/Security.md) | セキュリティ推奨事項とハードニング |
| [Raspberry Pi](wiki/Raspberry-Pi.md) | 対応モデルと注意事項 |
| [トラブルシューティング & FAQ](wiki/Troubleshooting.md) | よくある問題、解決策、よくある質問 |

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         監視サーバー                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │   Prometheus    │  │     Grafana     │  │   Exporters     │         │
│  │   (port 9090)   │←─│   (port 3000)   │  │  wallet: 9101   │         │
│  │                 │  │                 │  │  reward: 9102   │         │
│  └────────┬────────┘  └─────────────────┘  └────────┬────────┘         │
│           │              スクレイプ (15秒)           │                   │
│           └──────────────────┬──────────────────────┘                   │
└──────────────────────────────┼──────────────────────────────────────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   ノード 1       │   │   ノード 2       │   │   ノード N       │
│ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │
│ │Block Builder│ │   │ │Block Builder│ │   │ │Block Builder│ │
│ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │
│ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌─────────────┐ │
│ │node_exporter│ │   │ │node_exporter│ │   │ │node_exporter│ │
│ │ (port 9100) │ │   │ │ (port 9100) │ │   │ │ (port 9100) │ │
│ └─────────────┘ │   │ └─────────────┘ │   │ └─────────────┘ │
└─────────────────┘   └─────────────────┘   └─────────────────┘
```

## プロジェクト構成

```
intmax-node-monitoring/
├── agent/                    # ノード側監視エージェント
│   ├── setup.sh             # リモートインストールスクリプト
│   ├── install.sh           # ローカルインストールスクリプト
│   ├── uninstall.sh         # 削除スクリプト
│   └── intmax_builder_metrics.sh  # メトリクス収集（cron）
│
├── server/                   # Dockerベース監視サーバー
│   ├── docker-compose.yml   # サービスオーケストレーション
│   ├── .env.example         # 設定テンプレート
│   ├── prometheus/          # Prometheus設定
│   │   ├── prometheus.yml   # スクレイプ設定
│   │   ├── rules/           # アラートルール
│   │   └── targets/         # ノード検出
│   ├── wallet-exporter/     # ウォレット残高監視
│   ├── reward-exporter/     # 報酬残高監視
│   └── scripts/             # 自動化スクリプト
│
├── grafana/                  # Grafana設定
│   ├── provisioning/        # 自動プロビジョニング
│   └── dashboards/          # ダッシュボードJSONファイル
│
└── wiki/                     # ドキュメント
```

## 収集されるメトリクス

| メトリクス | 説明 | ソース |
|-----------|------|--------|
| `intmax_builder_up` | ノード可用性（1=稼働中, 0=停止） | Agent |
| `intmax_builder_container_running` | Dockerコンテナ状態 | Agent |
| `intmax_builder_uptime_seconds` | コンテナ稼働時間 | Agent |
| `intmax_builder_data_size_bytes` | データディレクトリサイズ | Agent |
| `intmax_wallet_eth` | ウォレットETH残高 | Wallet Exporter |
| `intmax_wallet_sitx` | ウォレットsITX残高 | Wallet Exporter |
| `intmax_builder_reward_eth` | 保留中ETH報酬 | Reward Exporter |
| `intmax_builder_reward_sitx` | 保留中sITX報酬 | Reward Exporter |

## アップデート

最新バージョンへの更新：

```bash
# 監視サーバー上で
cd intmax-node-monitoring
git pull origin main
docker compose down
docker compose pull
docker compose up -d

# 各ノード上で（インストールを再実行）
curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring/main/agent/setup.sh | sudo bash
```

## コントリビューション

コントリビューションを歓迎します！お気軽にPull Requestを送ってください。

1. リポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'Add some amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. Pull Requestを作成

## ライセンス

このプロジェクトはMITライセンスの下でライセンスされています - 詳細は[LICENSE](LICENSE)ファイルを参照してください。

## 謝辞

- [INTMAX](https://intmax.io) - INTMAXネットワーク
- [Prometheus](https://prometheus.io) - 監視システム
- [Grafana](https://grafana.com) - 可視化プラットフォーム
