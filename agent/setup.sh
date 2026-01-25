#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# INTMAX Builder Monitoring Agent - Remote Setup Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Taiyou/intmax-node-monitoring-en/main/agent/setup.sh | sudo bash
#
# または git clone:
#   git clone https://github.com/Taiyou/intmax-node-monitoring-en.git /tmp/intmax-monitoring
#   cd /tmp/intmax-monitoring/agent && sudo ./install.sh
#=============================================================================

# GitHub リポジトリ設定（フォーク時は変更してください）
GITHUB_USER="${GITHUB_USER:-Taiyou}"
GITHUB_REPO="${GITHUB_REPO:-intmax-node-monitoring-en}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# インストール先
INSTALL_DIR="${INSTALL_DIR:-/opt/intmax-monitoring}"

# 色付き出力
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# root チェック
[[ $EUID -eq 0 ]] || error "root 権限で実行してください: curl ... | sudo bash"

# 必要なコマンドチェック
check_requirements() {
    local missing=()
    for cmd in curl tar; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "必要なコマンドがありません: ${missing[*]}"
    fi
}

# GitHub から agent ファイルをダウンロード
download_files() {
    local base_url="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/agent"

    info "ファイルをダウンロード中..."
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    # 必要なファイルをダウンロード
    for file in install.sh intmax_builder_metrics.sh uninstall.sh; do
        info "  -> ${file}"
        curl -fsSL "${base_url}/${file}" -o "${file}"
        chmod +x "${file}"
    done

    ok "ダウンロード完了: $INSTALL_DIR"
}

# メイン処理
main() {
    echo "========================================"
    echo " INTMAX Builder Monitoring Agent"
    echo " Remote Setup"
    echo "========================================"
    echo
    info "GitHub: ${GITHUB_USER}/${GITHUB_REPO} (${GITHUB_BRANCH})"
    echo

    check_requirements
    download_files

    echo
    info "インストールを実行します..."
    echo

    # install.sh を実行
    cd "$INSTALL_DIR"
    ./install.sh

    echo
    ok "セットアップ完了!"
    echo
    info "スクリプトの場所: $INSTALL_DIR"
    info "アンインストール: sudo ${INSTALL_DIR}/uninstall.sh"
}

main "$@"
