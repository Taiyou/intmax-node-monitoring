#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# INTMAX Builder Monitoring Agent - Install Script
#
# - node_exporter のインストール (systemd)
# - textfile collector ディレクトリ作成
# - メトリクス収集スクリプトの cron 設定
#=============================================================================

NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.7.0}"
TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"
INSTALL_DIR="/opt/intmax-monitoring"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_SCRIPT="${SCRIPT_DIR}/intmax_builder_metrics.sh"
CRON_INTERVAL="${CRON_INTERVAL:-1}"  # 分単位

# 色付き出力
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# root チェック
[[ $EUID -eq 0 ]] || error "root 権限で実行してください: sudo $0"

# アーキテクチャ検出
detect_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armv7" ;;
        armv6l)  echo "armv6" ;;
        *)       error "未対応のアーキテクチャ: $arch" ;;
    esac
}

# node_exporter 用ユーザー作成
create_user() {
    if ! id -u node_exporter &>/dev/null; then
        info "node_exporter ユーザーを作成中..."
        useradd --no-create-home --shell /bin/false node_exporter
        ok "node_exporter ユーザーを作成しました"
    fi
}

# node_exporter インストール
install_node_exporter() {
    if command -v node_exporter &>/dev/null; then
        warn "node_exporter は既にインストールされています"
        node_exporter --version
        return 0
    fi

    local arch
    arch=$(detect_arch)
    local filename="node_exporter-${NODE_EXPORTER_VERSION}.linux-${arch}"
    local url="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${filename}.tar.gz"

    info "node_exporter v${NODE_EXPORTER_VERSION} (${arch}) をダウンロード中..."
    cd /tmp
    curl -fsSL "$url" -o node_exporter.tar.gz
    tar xzf node_exporter.tar.gz
    mv "${filename}/node_exporter" /usr/local/bin/
    rm -rf node_exporter.tar.gz "${filename}"
    chmod +x /usr/local/bin/node_exporter

    ok "node_exporter を /usr/local/bin にインストールしました"
}

# systemd サービス作成
create_systemd_service() {
    info "systemd サービスを作成中..."

    cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Prometheus Node Exporter
After=network-online.target
Wants=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \\
    --collector.textfile.directory=${TEXTFILE_DIR}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter

    ok "node_exporter サービスを起動しました"
}

# textfile collector ディレクトリ作成
setup_textfile_dir() {
    info "textfile collector ディレクトリを作成中..."
    mkdir -p "$TEXTFILE_DIR"
    chown node_exporter:node_exporter "$TEXTFILE_DIR"
    ok "ディレクトリ作成完了: $TEXTFILE_DIR"
}

# スクリプトをインストールディレクトリにコピー
install_scripts() {
    info "スクリプトをインストール中..."
    mkdir -p "$INSTALL_DIR"
    
    # メイン監視スクリプト
    cp "$METRICS_SCRIPT" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/intmax_builder_metrics.sh"
    
    # アンインストールスクリプト
    if [[ -f "${SCRIPT_DIR}/uninstall.sh" ]]; then
        cp "${SCRIPT_DIR}/uninstall.sh" "$INSTALL_DIR/"
        chmod +x "$INSTALL_DIR/uninstall.sh"
    fi
    
    ok "スクリプトを $INSTALL_DIR にインストールしました"
}

# cron ジョブ設定
setup_cron() {
    info "cron ジョブを設定中..."
    
    # メトリクス収集スクリプト（1分間隔）
    local metrics_cron_line="*/${CRON_INTERVAL} * * * * ${INSTALL_DIR}/intmax_builder_metrics.sh"
    local metrics_cron_marker="# intmax-builder-metrics"
    (crontab -l 2>/dev/null | grep -v "$metrics_cron_marker" || true; echo "${metrics_cron_line} ${metrics_cron_marker}") | crontab -
    ok "メトリクス収集 cron ジョブを設定しました (${CRON_INTERVAL}分間隔)"
}

# メイン処理
main() {
    echo "========================================"
    echo " INTMAX Builder Monitoring Agent"
    echo "========================================"
    echo

    create_user
    install_node_exporter
    setup_textfile_dir
    create_systemd_service
    install_scripts
    setup_cron

    echo
    ok "インストール完了!"
    echo
    info "確認コマンド:"
    echo "  systemctl status node_exporter"
    echo "  curl -s localhost:9100/metrics | grep intmax"
    echo
    info "インストール先: ${INSTALL_DIR}"
    echo
    info "次のステップ:"
    echo "  1. /etc/default/intmax-builder-metrics を編集して設定"
    echo "  2. Prometheus サーバーからこのノードの 9100 ポートにアクセスできることを確認"
}

main "$@"
