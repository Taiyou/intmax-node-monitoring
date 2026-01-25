#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# INTMAX Builder Metrics Collector
#
# textfile collector 形式でメトリクスを出力
# node_exporter が読み取り、Prometheus に公開する
#=============================================================================

# 設定ファイルを読み込み（存在する場合）
CONFIG_FILE="/etc/default/intmax-builder-metrics"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# 設定
TEXTFILE_DIR="${TEXTFILE_DIR:-/var/lib/node_exporter/textfile_collector}"
OUTPUT_FILE="${TEXTFILE_DIR}/intmax_builder.prom"
TEMP_FILE="${OUTPUT_FILE}.tmp"

# INTMAX Builder の設定
# /etc/default/intmax-builder-metrics で上書き可能
# Docker Swarm の場合、コンテナ名にはサービス名のプレフィックスが含まれる
BUILDER_CONTAINER_NAME="${BUILDER_CONTAINER_NAME:-block-builder}"
BUILDER_PROCESS_NAME="${BUILDER_PROCESS_NAME:-intmax-builder}"
BUILDER_DATA_DIR="${BUILDER_DATA_DIR:-}"
BUILDER_HEALTH_URL="${BUILDER_HEALTH_URL:-}"  # 例: http://localhost:8080/health

# ラベル（Grafana でフィルタ用）
NODE_NAME="${NODE_NAME:-$(hostname)}"

#-----------------------------------------------------------------------------
# メトリクス出力用ヘルパー
#-----------------------------------------------------------------------------
metrics=()

add_metric() {
    local name="$1"
    local value="$2"
    local help="${3:-}"
    local type="${4:-gauge}"

    if [[ -n "$help" ]]; then
        metrics+=("# HELP ${name} ${help}")
        metrics+=("# TYPE ${name} ${type}")
    fi
    metrics+=("${name}{node=\"${NODE_NAME}\"} ${value}")
}

#-----------------------------------------------------------------------------
# Docker コンテナ状態チェック（部分一致対応）
#-----------------------------------------------------------------------------

# コンテナ名を部分一致で検索してフルネームを取得
get_container_full_name() {
    if ! command -v docker &>/dev/null; then
        echo ""
        return
    fi
    # Docker Swarm のサービス名で部分一致検索
    docker ps --filter "name=${BUILDER_CONTAINER_NAME}" --format "{{.Names}}" 2>/dev/null | head -1
}

check_docker_container() {
    if ! command -v docker &>/dev/null; then
        return 1
    fi

    local container_name
    container_name=$(get_container_full_name)

    if [[ -z "$container_name" ]]; then
        return 1
    fi

    local status
    status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null || echo "not_found")

    case "$status" in
        running)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

get_docker_uptime_seconds() {
    if ! command -v docker &>/dev/null; then
        echo 0
        return
    fi

    local container_name
    container_name=$(get_container_full_name)

    if [[ -z "$container_name" ]]; then
        echo 0
        return
    fi

    local started_at
    started_at=$(docker inspect -f '{{.State.StartedAt}}' "$container_name" 2>/dev/null || echo "")

    if [[ -z "$started_at" ]]; then
        echo 0
        return
    fi

    local start_epoch now_epoch
    start_epoch=$(date -d "$started_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${started_at%%.*}" +%s 2>/dev/null || echo 0)
    now_epoch=$(date +%s)

    echo $((now_epoch - start_epoch))
}

#-----------------------------------------------------------------------------
# プロセス状態チェック
#-----------------------------------------------------------------------------
check_process() {
    pgrep -f "$BUILDER_PROCESS_NAME" &>/dev/null
}

#-----------------------------------------------------------------------------
# ヘルスエンドポイントチェック
#-----------------------------------------------------------------------------
check_health_endpoint() {
    if [[ -z "$BUILDER_HEALTH_URL" ]]; then
        return 1
    fi

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$BUILDER_HEALTH_URL" 2>/dev/null || echo "000")

    [[ "$http_code" == "200" ]]
}

#-----------------------------------------------------------------------------
# データディレクトリチェック
#-----------------------------------------------------------------------------
check_data_directory() {
    [[ -d "$BUILDER_DATA_DIR" ]]
}

get_data_dir_size_bytes() {
    if [[ -d "$BUILDER_DATA_DIR" ]]; then
        du -sb "$BUILDER_DATA_DIR" 2>/dev/null | cut -f1 || echo 0
    else
        echo 0
    fi
}

#-----------------------------------------------------------------------------
# メイン: メトリクス収集
#-----------------------------------------------------------------------------
collect_metrics() {
    local ready=0
    local container_running=0
    local process_running=0
    local health_ok=0
    local data_dir_exists=0

    # Docker コンテナチェック
    if check_docker_container; then
        container_running=1
        ready=1
    fi

    # プロセスチェック（Docker 以外で動作している場合）
    if check_process; then
        process_running=1
        ready=1
    fi

    # ヘルスエンドポイントチェック
    if check_health_endpoint; then
        health_ok=1
    fi

    # データディレクトリチェック
    if check_data_directory; then
        data_dir_exists=1
    fi

    # メトリクス生成
    add_metric "intmax_builder_ready" "$ready" \
        "INTMAX Builder is ready (1=running, 0=stopped)"

    add_metric "intmax_builder_container_running" "$container_running" \
        "INTMAX Builder Docker container is running"

    add_metric "intmax_builder_process_running" "$process_running" \
        "INTMAX Builder process is running"

    add_metric "intmax_builder_health_ok" "$health_ok" \
        "INTMAX Builder health endpoint returns 200"

    add_metric "intmax_builder_data_dir_exists" "$data_dir_exists" \
        "INTMAX Builder data directory exists"

    # コンテナ稼働時間
    local uptime_seconds
    uptime_seconds=$(get_docker_uptime_seconds)
    add_metric "intmax_builder_uptime_seconds" "$uptime_seconds" \
        "INTMAX Builder container uptime in seconds"

    # データディレクトリサイズ
    local data_size
    data_size=$(get_data_dir_size_bytes)
    add_metric "intmax_builder_data_dir_bytes" "$data_size" \
        "INTMAX Builder data directory size in bytes"

    # タイムスタンプ
    add_metric "intmax_builder_last_scrape_timestamp" "$(date +%s)" \
        "Timestamp of last metrics collection"
}

#-----------------------------------------------------------------------------
# 出力
#-----------------------------------------------------------------------------
write_metrics() {
    # ディレクトリ確認
    mkdir -p "$TEXTFILE_DIR"

    # アトミックに書き込み（一時ファイル経由）
    printf '%s\n' "${metrics[@]}" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$OUTPUT_FILE"
}

#-----------------------------------------------------------------------------
# メイン
#-----------------------------------------------------------------------------
main() {
    collect_metrics
    write_metrics
}

main "$@"
