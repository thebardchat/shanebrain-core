#!/usr/bin/env python3
"""
OLLAMA CLUSTER LOAD BALANCER v3.1
Routes queries between Computer A, Computer B, and Raspberry Pi
Tracks performance, load, response times
Provides API endpoint for Discord bot
NOW WITH: Remote Pi shutdown button (credentials in .env)

Supports: /api/generate, /api/chat, /api/tags, /api/embeddings

NODES:
  Computer A (Primary):   192.168.100.1:11434
  Computer B (Secondary): 192.168.100.2:11434
  Raspberry Pi (Network): 10.0.0.42:11434
"""

import requests
import time
import json
from datetime import datetime
from collections import defaultdict
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse
import os
from pathlib import Path

# Load environment variables
from dotenv import load_dotenv
load_dotenv(Path(__file__).parent / "bot" / ".env")

# Configuration
NODE_A = "http://192.168.100.1:11434"
NODE_B = "http://192.168.100.2:11434"
NODE_PI = "http://10.0.0.42:11434"
BALANCER_PORT = 8000

# Pi SSH credentials from .env
PI_HOST = os.getenv("PI_HOST", "10.0.0.42")
PI_USER = os.getenv("PI_USER", "shane")
PI_PASSWORD = os.getenv("PI_PASSWORD", "")

ALL_NODES = {
    "node_a": {"url": NODE_A, "name": "Computer A (Primary)"},
    "node_b": {"url": NODE_B, "name": "Computer B (Secondary)"},
    "node_pi": {"url": NODE_PI, "name": "Raspberry Pi (Network)"},
}

# Metrics tracking
metrics = {
    "node_a": {"requests": 0, "total_time": 0, "errors": 0, "models": []},
    "node_b": {"requests": 0, "total_time": 0, "errors": 0, "models": []},
    "node_pi": {"requests": 0, "total_time": 0, "errors": 0, "models": []},
    "start_time": datetime.now().isoformat()
}

def get_node_health():
    """Check health of all nodes"""
    health = {}
    for node_key, node_info in ALL_NODES.items():
        try:
            resp = requests.get(f"{node_info['url']}/api/tags", timeout=3)
            health[node_key] = "ONLINE" if resp.status_code == 200 else "ERROR"
            metrics[node_key]["models"] = [m["name"] for m in resp.json().get("models", [])]
        except:
            health[node_key] = "OFFLINE"
            metrics[node_key]["models"] = []
    return health

def choose_node(model_name=None):
    """Choose best node for request - round robin with health check"""
    health = get_node_health()

    # Build list of online nodes
    online_nodes = []
    for node_key, node_info in ALL_NODES.items():
        if health.get(node_key) == "ONLINE":
            online_nodes.append((node_key, node_info["url"]))

    if not online_nodes:
        return None, None

    # If model specified, prefer node that already has it loaded
    if model_name:
        for node_key, node_url in online_nodes:
            if model_name in metrics[node_key].get("models", []):
                return node_key, node_url

    # Pick node with fewest requests (simple load balancing)
    best_node = min(online_nodes, key=lambda n: metrics[n[0]]["requests"])
    return best_node[0], best_node[1]

def forward_request(node_key, node_url, path, body=None, timeout=120):
    """Forward request to chosen node and track metrics"""
    start = time.time()
    try:
        if body:
            resp = requests.post(f"{node_url}{path}", json=body, timeout=timeout)
        else:
            resp = requests.get(f"{node_url}{path}", timeout=timeout)

        elapsed = time.time() - start
        metrics[node_key]["requests"] += 1
        metrics[node_key]["total_time"] += elapsed
        return resp.status_code, resp.text, elapsed
    except Exception as e:
        metrics[node_key]["errors"] += 1
        return 500, json.dumps({"error": str(e)}), time.time() - start

def shutdown_pi():
    """Send shutdown command to Raspberry Pi via SSH"""
    if not PI_PASSWORD:
        return False, "PI_PASSWORD not set in .env file"
    
    try:
        import paramiko
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddHostPolicy())
        ssh.connect(PI_HOST, username=PI_USER, password=PI_PASSWORD, timeout=10)
        ssh.exec_command('sudo shutdown -h now')
        ssh.close()
        return True, "Pi shutdown command sent successfully"
    except ImportError:
        return False, "paramiko not installed. Run: pip install paramiko"
    except Exception as e:
        return False, f"Shutdown failed: {str(e)}"

class LoadBalancerHandler(BaseHTTPRequestHandler):
    """Handle incoming requests and route to best node"""

    def log_message(self, format, *args):
        """Suppress default logging - we do our own"""
        pass

    def do_GET(self):
        if self.path == "/health":
            self.handle_health()
        elif self.path == "/dashboard":
            self.handle_dashboard()
        elif self.path == "/api/tags":
            self.handle_tags()
        else:
            # Forward to best node
            node_key, node_url = choose_node()
            if not node_url:
                self.send_error(503, "All nodes offline")
                return
            status, body, elapsed = forward_request(node_key, node_url, self.path)
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())

    def do_POST(self):
        # Handle Pi shutdown request
        if self.path == "/shutdown/pi":
            success, message = shutdown_pi()
            self.send_response(200 if success else 500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"success": success, "message": message}).encode())
            if success:
                print(f"\n  🔴 SHUTDOWN: Pi shutdown initiated from dashboard")
            else:
                print(f"\n  ⚠️  SHUTDOWN FAILED: {message}")
            return

        content_length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(content_length)) if content_length else {}

        model_name = body.get("model", "")
        node_key, node_url = choose_node(model_name)

        if not node_url:
            self.send_response(503)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": "All nodes offline"}).encode())
            return

        node_name = ALL_NODES[node_key]["name"]
        print(f"  -> {self.path} [{model_name}] -> {node_name}")

        status, response, elapsed = forward_request(node_key, node_url, self.path, body)

        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(response.encode())
        print(f"  <- {node_name} responded in {elapsed:.1f}s")

    def handle_health(self):
        health = get_node_health()
        result = {
            "status": "healthy" if any(v == "ONLINE" for v in health.values()) else "degraded",
            "nodes": {},
            "uptime": str(datetime.now() - datetime.fromisoformat(metrics["start_time"])),
        }
        for node_key, node_info in ALL_NODES.items():
            avg_time = (
                metrics[node_key]["total_time"] / metrics[node_key]["requests"]
                if metrics[node_key]["requests"] > 0
                else 0
            )
            status_icon = "ONLINE" if health[node_key] == "ONLINE" else "OFFLINE"
            result["nodes"][node_key] = {
                "name": node_info["name"],
                "url": node_info["url"],
                "status": status_icon,
                "requests": metrics[node_key]["requests"],
                "errors": metrics[node_key]["errors"],
                "avg_response_time": f"{avg_time:.2f}s",
                "models": metrics[node_key]["models"],
            }
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps(result, indent=2).encode())

    def handle_tags(self):
        """Combine model lists from all online nodes"""
        all_models = []
        seen = set()
        health = get_node_health()
        for node_key, node_info in ALL_NODES.items():
            if health.get(node_key) == "ONLINE":
                try:
                    resp = requests.get(f"{node_info['url']}/api/tags", timeout=3)
                    for m in resp.json().get("models", []):
                        if m["name"] not in seen:
                            all_models.append(m)
                            seen.add(m["name"])
                except:
                    pass
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"models": all_models}, indent=2).encode())

    def handle_dashboard(self):
        health = get_node_health()
        html = """<!DOCTYPE html>
<html>
<head>
    <title>ShaneBrain Cluster Dashboard</title>
    <meta http-equiv="refresh" content="10">
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', sans-serif; background: #0a0a0a; color: #e0e0e0; padding: 20px; }
        h1 { text-align: center; color: #00ff88; margin-bottom: 5px; font-size: 2em; }
        .subtitle { text-align: center; color: #888; margin-bottom: 30px; font-size: 0.9em; }
        .grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; max-width: 1200px; margin: 0 auto; }
        .card { background: #1a1a1a; border: 2px solid #333; border-radius: 12px; padding: 25px; text-align: center; position: relative; }
        .card.online { border-color: #00ff88; }
        .card.offline { border-color: #ff4444; opacity: 0.6; }
        .node-name { font-size: 1.2em; font-weight: 600; margin-bottom: 10px; }
        .node-url { font-size: 0.8em; color: #666; margin-bottom: 15px; }
        .status { font-size: 1.5em; margin-bottom: 15px; }
        .status.online { color: #00ff88; }
        .status.offline { color: #ff4444; }
        .stat { margin: 8px 0; }
        .stat-label { color: #888; font-size: 0.85em; }
        .stat-value { color: #fff; font-size: 1.3em; font-weight: 600; }
        .models { margin-top: 15px; padding-top: 15px; border-top: 1px solid #333; }
        .model-tag { display: inline-block; background: #2a2a2a; padding: 4px 10px; border-radius: 6px; font-size: 0.8em; margin: 3px; color: #00ff88; }
        .footer { text-align: center; margin-top: 30px; color: #444; font-size: 0.8em; }
        .total { text-align: center; margin: 20px auto; max-width: 1200px; }
        .total-card { background: #1a1a1a; border: 2px solid #00ff88; border-radius: 12px; padding: 20px; display: inline-block; min-width: 200px; margin: 10px; }
        .total-label { color: #888; font-size: 0.9em; }
        .total-value { color: #00ff88; font-size: 2em; font-weight: 700; }
        .shutdown-btn { 
            position: absolute; 
            top: 10px; 
            right: 10px; 
            background: #ff4444; 
            color: white; 
            border: none; 
            padding: 8px 15px; 
            border-radius: 6px; 
            cursor: pointer; 
            font-size: 0.85em;
            font-weight: 600;
            transition: background 0.2s;
        }
        .shutdown-btn:hover { background: #cc0000; }
        .shutdown-btn:active { background: #990000; }
        @media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
    </style>
    <script>
        function shutdownPi() {
            if (!confirm('Shutdown Raspberry Pi?\\n\\nThis will safely power down the Pi node.')) return;
            
            fetch('/shutdown/pi', { method: 'POST' })
                .then(r => r.json())
                .then(data => {
                    if (data.success) {
                        alert('✅ Pi shutdown initiated');
                        setTimeout(() => location.reload(), 2000);
                    } else {
                        alert('❌ Shutdown failed:\\n' + data.message);
                    }
                })
                .catch(e => alert('❌ Request failed: ' + e));
        }
    </script>
</head>
<body>
    <h1>SHANEBRAIN CLUSTER</h1>
    <p class="subtitle">Three-Node AI Load Balancer v3.1</p>
    <div class="total">"""

        total_requests = sum(metrics[n]["requests"] for n in ALL_NODES)
        total_errors = sum(metrics[n]["errors"] for n in ALL_NODES)
        online_count = sum(1 for v in health.values() if v == "ONLINE")

        html += f"""
        <div class="total-card">
            <div class="total-label">Total Requests</div>
            <div class="total-value">{total_requests}</div>
        </div>
        <div class="total-card">
            <div class="total-label">Nodes Online</div>
            <div class="total-value">{online_count}/3</div>
        </div>
        <div class="total-card">
            <div class="total-label">Errors</div>
            <div class="total-value">{total_errors}</div>
        </div>
    </div>
    <div class="grid">"""

        for node_key, node_info in ALL_NODES.items():
            is_online = health.get(node_key) == "ONLINE"
            card_class = "online" if is_online else "offline"
            status_text = "ONLINE" if is_online else "OFFLINE"
            status_icon = "🟢" if is_online else "🔴"
            avg_time = (
                metrics[node_key]["total_time"] / metrics[node_key]["requests"]
                if metrics[node_key]["requests"] > 0
                else 0
            )
            models_html = ""
            for m in metrics[node_key].get("models", []):
                models_html += f'<span class="model-tag">{m}</span>'

            # Add shutdown button only to Pi card
            shutdown_button = ""
            if node_key == "node_pi" and is_online:
                shutdown_button = '<button class="shutdown-btn" onclick="shutdownPi()">⚡ SHUTDOWN</button>'

            html += f"""
        <div class="card {card_class}">
            {shutdown_button}
            <div class="node-name">{node_info['name']}</div>
            <div class="node-url">{node_info['url']}</div>
            <div class="status {card_class}">{status_icon} {status_text}</div>
            <div class="stat">
                <div class="stat-label">Requests</div>
                <div class="stat-value">{metrics[node_key]['requests']}</div>
            </div>
            <div class="stat">
                <div class="stat-label">Avg Response</div>
                <div class="stat-value">{avg_time:.2f}s</div>
            </div>
            <div class="stat">
                <div class="stat-label">Errors</div>
                <div class="stat-value">{metrics[node_key]['errors']}</div>
            </div>
            <div class="models">
                <div class="stat-label">Models</div>
                {models_html if models_html else '<span style="color:#666">None loaded</span>'}
            </div>
        </div>"""

        html += f"""
    </div>
    <div class="footer">
        ShaneBrain Cluster | Started: {metrics['start_time'][:19]} | Auto-refresh: 10s<br>
        Shane Brazelton - SRM Dispatch, Alabama | Family First. Local First.
    </div>
</body>
</html>"""

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode())


def start_balancer():
    """Start load balancer server"""
    print()
    print("=" * 60)
    print("  SHANEBRAIN CLUSTER LOAD BALANCER v3.1")
    print("=" * 60)
    print(f"\n  📊 Dashboard:     http://localhost:{BALANCER_PORT}/dashboard")
    print(f"  💊 Health Check:  http://localhost:{BALANCER_PORT}/health")
    print(f"  📡 API Endpoint:  http://localhost:{BALANCER_PORT}")
    print(f"\n  🖥️  Node A:  {NODE_A}")
    print(f"  🖥️  Node B:  {NODE_B}")
    print(f"  🥧 Node Pi: {NODE_PI}")
    print("\n  🔴 NEW: Pi shutdown button in dashboard")
    print(f"  🔐 Pi credentials loaded from .env")
    print("\n  Checking nodes...")

    health = get_node_health()
    icons = {"ONLINE": "🟢", "OFFLINE": "🔴", "ERROR": "🔴"}
    for node_key, node_info in ALL_NODES.items():
        status = health.get(node_key, "OFFLINE")
        print(f"    {icons.get(status, '🔴')} {node_info['name']}: {status}")

    online_count = sum(1 for v in health.values() if v == "ONLINE")
    print(f"\n  ✅ Balancer ready on port {BALANCER_PORT} ({online_count}/3 nodes online)")
    print("=" * 60)
    print()

    server = HTTPServer(("0.0.0.0", BALANCER_PORT), LoadBalancerHandler)
    server.serve_forever()


if __name__ == "__main__":
    start_balancer()