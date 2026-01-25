#!/usr/bin/env python3
"""
INTMAX Wallet Balance Exporter

監視サーバーから直接ウォレットの sITX 残高を取得し、
Prometheus メトリクスとして公開する
"""

import os
import time
import json
import logging
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
import urllib.request

# ログ設定
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)
logger = logging.getLogger(__name__)

# 設定
WALLET_ADDRESSES = os.environ.get('WALLET_ADDRESSES', '').split(',')
SITX_CONTRACT = os.environ.get('SITX_CONTRACT', '0xc0579287f3CDE6BF796BE6E2bB61DbB06DA85024')
SCROLL_RPC_URL = os.environ.get('SCROLL_RPC_URL', 'https://rpc.scroll.io')
PORT = int(os.environ.get('PORT', '9101'))
UPDATE_INTERVAL = int(os.environ.get('UPDATE_INTERVAL', '3600'))  # 1時間

# メトリクスキャッシュ
metrics_cache = ""
last_update = 0


def hex_to_int(hex_str: str) -> int:
    """Hex文字列を整数に変換"""
    if not hex_str or hex_str == '0x':
        return 0
    return int(hex_str, 16)


def wei_to_eth(wei: int) -> float:
    """Weiを18decimalトークンに変換"""
    return wei / 1e18


def rpc_call(method: str, params: list) -> dict:
    """JSON-RPC呼び出し"""
    data = json.dumps({
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1
    }).encode('utf-8')
    
    req = urllib.request.Request(
        SCROLL_RPC_URL,
        data=data,
        headers={'Content-Type': 'application/json'}
    )
    
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            result = json.loads(response.read().decode('utf-8'))
            return result
    except Exception as e:
        logger.error(f"RPC call failed: {e}")
        return {}


def get_eth_balance(address: str) -> int:
    """ETH残高を取得（Wei）"""
    result = rpc_call("eth_getBalance", [address, "latest"])
    if 'result' in result:
        return hex_to_int(result['result'])
    return 0


def get_erc20_balance(wallet: str, contract: str) -> int:
    """ERC-20トークン残高を取得（Wei）"""
    # balanceOf(address) selector: 0x70a08231
    address_padded = wallet[2:].lower().zfill(64)
    data = f"0x70a08231{address_padded}"
    
    result = rpc_call("eth_call", [{"to": contract, "data": data}, "latest"])
    if 'result' in result:
        return hex_to_int(result['result'])
    return 0


def generate_metrics() -> str:
    """Prometheusメトリクスを生成"""
    global metrics_cache, last_update
    
    lines = [
        "# HELP intmax_wallet_sitx Wallet sITX token balance on Scroll",
        "# TYPE intmax_wallet_sitx gauge",
        "# HELP intmax_wallet_sitx_total Total sITX balance across all wallets",
        "# TYPE intmax_wallet_sitx_total gauge",
        "# HELP intmax_wallet_eth Wallet ETH balance on Scroll (for gas)",
        "# TYPE intmax_wallet_eth gauge",
        "# HELP intmax_wallet_last_check Timestamp of last wallet balance check",
        "# TYPE intmax_wallet_last_check gauge",
    ]
    
    total_sitx_wei = 0
    
    for address in WALLET_ADDRESSES:
        address = address.strip()
        if not address:
            continue
            
        logger.info(f"Checking wallet: {address}")
        
        # ETH残高
        eth_wei = get_eth_balance(address)
        eth_balance = wei_to_eth(eth_wei)
        logger.info(f"  ETH: {eth_balance:.6f}")
        
        # sITX残高
        sitx_wei = get_erc20_balance(address, SITX_CONTRACT)
        sitx_balance = wei_to_eth(sitx_wei)
        logger.info(f"  sITX: {sitx_balance:.6f}")
        
        total_sitx_wei += sitx_wei
        
        lines.append(f'intmax_wallet_sitx{{address="{address}"}} {sitx_balance}')
        lines.append(f'intmax_wallet_eth{{address="{address}"}} {eth_balance}')
    
    total_sitx = wei_to_eth(total_sitx_wei)
    lines.append(f"intmax_wallet_sitx_total {total_sitx}")
    lines.append(f"intmax_wallet_last_check {int(time.time())}")
    
    logger.info(f"Total sITX: {total_sitx:.6f}")
    
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
        # アクセスログを抑制
        pass


def main():
    logger.info("=== INTMAX Wallet Balance Exporter ===")
    logger.info(f"Wallets: {WALLET_ADDRESSES}")
    logger.info(f"sITX Contract: {SITX_CONTRACT}")
    logger.info(f"RPC URL: {SCROLL_RPC_URL}")
    logger.info(f"Port: {PORT}")
    logger.info(f"Update interval: {UPDATE_INTERVAL}s")
    
    if not any(WALLET_ADDRESSES):
        logger.error("No wallet addresses configured!")
        logger.error("Set WALLET_ADDRESSES environment variable")
        return
    
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
