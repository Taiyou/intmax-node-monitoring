#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# INTMAX Builder Monitoring Agent - Uninstall Script
#
# - cron ジョブの削除
# - node_exporter の停止・削除
# - textfile collector ディレクトリのクリーンアップ
#=============================================================================

TEXTFILE_DIR="/var/lib/node_exporter/textfile_collector"

# 色付き出力
info()  { echo -e "\033[1;34m[INFO]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# root チェック
[[ $EUID -eq 0 ]] || error "root 権限で実行してください: sudo $0"

# cron ジョブ削除
remove_cron() {
    info "cron ジョブを削除中..."
    local cron_marker="# intmax-builder-metrics"

    if crontab -l 2>/dev/null | grep -q "$cron_marker"; then
        crontab -l 2>/dev/null | grep -v "$cron_marker" | crontab -
        ok "cron ジョブを削除しました"
    else
        warn "cron ジョブは設定されていません"
    fi
}

# node_exporter 停止・削除
remove_node_exporter() {
    info "node_exporter を停止・削除中..."

    # systemd サービス停止
    if systemctl is-active --quiet node_exporter 2>/dev/null; then
        systemctl stop node_exporter
        ok "node_exporter サービスを停止しました"
    fi

    if systemctl is-enabled --quiet node_exporter 2>/dev/null; then
        systemctl disable node_exporter
    fi

    # サービスファイル削除
    if [[ -f /etc/systemd/system/node_exporter.service ]]; then
        rm -f /etc/systemd/system/node_exporter.service
        systemctl daemon-reload
        ok "systemd サービスファイルを削除しました"
    fi

    # バイナリ削除
    if [[ -f /usr/local/bin/node_exporter ]]; then
        rm -f /usr/local/bin/node_exporter
        ok "node_exporter バイナリを削除しました"
    else
        warn "node_exporter バイナリは見つかりませんでした"
    fi

    # ユーザー削除（オプション）
    if id -u node_exporter &>/dev/null; then
        userdel node_exporter 2>/dev/null || true
        ok "node_exporter ユーザーを削除しました"
    fi
}

# textfile collector ディレクトリ削除
cleanup_textfile_dir() {
    info "textfile collector ディレクトリをクリーンアップ中..."

    if [[ -d "$TEXTFILE_DIR" ]]; then
        # INTMAX 関連ファイルのみ削除
        rm -f "${TEXTFILE_DIR}/intmax_builder.prom"
        rm -f "${TEXTFILE_DIR}/intmax_builder.prom.tmp"

        # ディレクトリが空なら削除
        if [[ -z "$(ls -A "$TEXTFILE_DIR" 2>/dev/null)" ]]; then
            rmdir "$TEXTFILE_DIR" 2>/dev/null || true
            rmdir "$(dirname "$TEXTFILE_DIR")" 2>/dev/null || true
        fi

        ok "textfile collector ファイルを削除しました"
    else
        warn "textfile collector ディレクトリは存在しません"
    fi
}

# 確認プロンプト
confirm() {
    echo "========================================"
    echo " INTMAX Builder Monitoring Agent"
    echo " アンインストール"
    echo "========================================"
    echo
    warn "以下を削除します:"
    echo "  - cron ジョブ (intmax-builder-metrics)"
    echo "  - node_exporter サービス・バイナリ"
    echo "  - textfile collector ファイル"
    echo

    read -rp "続行しますか? [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            echo "キャンセルしました"
            exit 0
            ;;
    esac
}

# メイン処理
main() {
    # --yes オプションで確認スキップ
    if [[ "${1:-}" != "--yes" ]] && [[ "${1:-}" != "-y" ]]; then
        confirm
    fi

    echo
    remove_cron
    remove_node_exporter
    cleanup_textfile_dir

    echo
    ok "アンインストール完了!"
}

main "$@"
