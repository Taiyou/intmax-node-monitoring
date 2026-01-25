#!/usr/bin/env python3
"""
INTMAX Reward Balance Exporter

SSH経由で各ノードのETH報酬残高を取得し、
Prometheus メトリクスとして公開する
"""

import os
import re
import time
import subprocess
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

# 設定
# ノード設定: "name:user@host:cli_dir:spend_key_file" をカンマ区切り
NODES_CONFIG = os.environ.get('NODES_CONFIG', '')
PORT = int(os.environ.get('PORT', '9102'))
UPDATE_INTERVAL = int(os.environ.get('UPDATE_INTERVAL', '3600'))  # 1時間
SSH_KEY_PATH = os.environ.get('SSH_KEY_PATH', '/root/.ssh/id_ed25519')

# メトリクスキャッシュ
metrics_cache = ""
last_update = 0


def parse_nodes_config():
    """ノード設定をパース"""
    nodes = []
    if not NODES_CONFIG:
        return nodes
    
    for entry in NODES_CONFIG.split(','):
        entry = entry.strip()
        if not entry:
            continue
        
        parts = entry.split(':')
        if len(parts) >= 4:
            nodes.append({
                'name': parts[0],
                'ssh_target': parts[1],
                'cli_dir': parts[2],
                'spend_key_file': ':'.join(parts[3:])  # パスに : が含まれる可能性
            })
    
    return nodes


def get_balance_via_ssh(node: dict) -> dict:
    """SSH経由でノードの報酬残高を取得"""
    result = {'eth': 0, 'sitx': 0, 'success': False}
    
    ssh_target = node['ssh_target']
    cli_dir = node['cli_dir']
    spend_key_file = node['spend_key_file']
    
    # SSH コマンド（ビルド済みバイナリを直接使用）
    # cli_dir から target/release/intmax2-cli のパスを推測
    binary_path = cli_dir.replace('/cli', '/target/release/intmax2-cli')
    
    # CLI ディレクトリで実行（.env ファイルを読み込むため）
    ssh_cmd = f"""
        cd {cli_dir} && \
        SPEND_KEY=$(cat {spend_key_file}) && \
        {binary_path} balance --private-key "$SPEND_KEY" 2>&1
    """
    
    try:
        cmd = [
            'ssh',
            '-o', 'ConnectTimeout=30',
            '-o', 'StrictHostKeyChecking=accept-new',
            '-o', 'BatchMode=yes',
        ]
        
        # SSH鍵が指定されている場合
        if SSH_KEY_PATH and os.path.exists(SSH_KEY_PATH):
            cmd.extend(['-i', SSH_KEY_PATH])
        
        cmd.extend([ssh_target, ssh_cmd])
        
        logger.info(f"Connecting to {ssh_target}...")
        output = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120
        )
        
        full_output = output.stdout + output.stderr
        logger.info(f"Output: {full_output[:500]}")
        
        # ETH をパース
        # パターン1: "ETH: 1.23456789" or "ETH: 1.23456789 ETH"
        eth_match = re.search(r'ETH:\s*([0-9]+\.?[0-9]*)', full_output)
        if eth_match:
            result['eth'] = float(eth_match.group(1))
        
        # パターン2: "Amount: 5000000000000" (Wei) with "Type: NATIVE"
        if 'Type: NATIVE' in full_output or 'NATIVE' in full_output:
            amount_match = re.search(r'Amount:\s*([0-9]+)', full_output)
            if amount_match:
                wei_amount = int(amount_match.group(1))
                result['eth'] = wei_amount / 1e18  # Wei to ETH
        
        # sITX をパース
        sitx_match = re.search(r'[sS]ITX:\s*([0-9]+\.?[0-9]*)', full_output)
        if sitx_match:
            result['sitx'] = float(sitx_match.group(1))
        
        result['success'] = True
        logger.info(f"  ETH: {result['eth']}, sITX: {result['sitx']}")
        
    except subprocess.TimeoutExpired:
        logger.error(f"SSH timeout for {ssh_target}")
    except Exception as e:
        logger.error(f"SSH error for {ssh_target}: {e}")
    
    return result


def generate_metrics() -> str:
    """Prometheusメトリクスを生成"""
    global metrics_cache, last_update
    
    nodes = parse_nodes_config()
    
    if not nodes:
        logger.warning("No nodes configured")
        return "# No nodes configured\n"
    
    lines = [
        "# HELP intmax_builder_reward_eth Pending ETH reward balance on builder node",
        "# TYPE intmax_builder_reward_eth gauge",
        "# HELP intmax_builder_reward_sitx Pending sITX reward balance on builder node",
        "# TYPE intmax_builder_reward_sitx gauge",
        "# HELP intmax_builder_reward_total_eth Total pending ETH rewards across all nodes",
        "# TYPE intmax_builder_reward_total_eth gauge",
        "# HELP intmax_builder_reward_check_success Whether the last balance check succeeded",
        "# TYPE intmax_builder_reward_check_success gauge",
        "# HELP intmax_builder_reward_last_check Timestamp of last reward check",
        "# TYPE intmax_builder_reward_last_check gauge",
    ]
    
    total_eth = 0
    total_sitx = 0
    
    for node in nodes:
        name = node['name']
        logger.info(f"Checking node: {name}")
        
        balance = get_balance_via_ssh(node)
        
        total_eth += balance['eth']
        total_sitx += balance['sitx']
        success = 1 if balance['success'] else 0
        
        lines.append(f'intmax_builder_reward_eth{{node="{name}"}} {balance["eth"]}')
        lines.append(f'intmax_builder_reward_sitx{{node="{name}"}} {balance["sitx"]}')
        lines.append(f'intmax_builder_reward_check_success{{node="{name}"}} {success}')
    
    lines.append(f"intmax_builder_reward_total_eth {total_eth}")
    lines.append(f"intmax_builder_reward_last_check {int(time.time())}")
    
    logger.info(f"Total ETH rewards: {total_eth}")
    
    metrics_cache = "\n".join(lines) + "\n"
    last_update = time.time()
    
    return metrics_cache


def update_loop():
    """定期的にメトリクスを更新"""
    while True:
        try:
            generate_metrics()
        except Exception as e:
            logger.error(f"Failed to update metrics: {e}")
        logger.info(f"Sleeping for {UPDATE_INTERVAL}s...")
        time.sleep(UPDATE_INTERVAL)


class MetricsHandler(BaseHTTPRequestHandler):
    """HTTPリクエストハンドラ"""
    
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; charset=utf-8')
            self.end_headers()
            self.wfile.write(metrics_cache.encode('utf-8'))
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'OK')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass


def main():
    logger.info("=== INTMAX Reward Balance Exporter ===")
    logger.info(f"Port: {PORT}")
    logger.info(f"Update interval: {UPDATE_INTERVAL}s")
    logger.info(f"SSH key: {SSH_KEY_PATH}")
    
    nodes = parse_nodes_config()
    if not nodes:
        logger.error("No nodes configured!")
        logger.error("Set NODES_CONFIG environment variable")
        logger.error("Format: name1:user@host:cli_dir:spend_key_file,name2:...")
    else:
        logger.info(f"Configured nodes: {[n['name'] for n in nodes]}")
    
    # 初回メトリクス生成
    generate_metrics()
    
    # バックグラウンドで定期更新
    update_thread = Thread(target=update_loop, daemon=True)
    update_thread.start()
    
    # HTTPサーバー起動
    server = HTTPServer(('0.0.0.0', PORT), MetricsHandler)
    logger.info(f"Listening on port {PORT}")
    server.serve_forever()


if __name__ == '__main__':
    main()
