#!/usr/bin/env python3
"""
OLLAMA CLUSTER LOAD BALANCER v2.0
Routes queries between Computer A (192.168.100.1:11434) and Computer B (192.168.100.2:11434)
Tracks performance, load, response times
Provides API endpoint for Discord bot

Supports: /api/generate, /api/chat, /api/tags, /api/embeddings
"""

import requests
import time
import json
from datetime import datetime
from collections import defaultdict
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse

# Configuration
NODE_A = "http://192.168.100.1:11434"
NODE_B = "http://192.168.100.2:11434"
BALANCER_PORT = 8000

# Metrics tracking
metrics = {
    "node_a": {"requests": 0, "total_time": 0, "errors": 0, "models": []},
    "node_b": {"requests": 0, "total_time": 0, "errors": 0, "models": []},
    "start_time": datetime.now().isoformat()
}

def get_node_health():
    """Check health of both nodes"""
    health = {}
    
    # Check Node A
    try:
        resp = requests.get(f"{NODE_A}/api/tags", timeout=2)
        health["node_a"] = "🟢 ONLINE" if resp.status_code == 200 else "🔴 ERROR"
        metrics["node_a"]["models"] = [m["name"] for m in resp.json().get("models", [])]
    except:
        health["node_a"] = "🔴 OFFLINE"
        metrics["node_a"]["models"] = []
    
    # Check Node B
    try:
        resp = requests.get(f"{NODE_B}/api/tags", timeout=2)
        health["node_b"] = "🟢 ONLINE" if resp.status_code == 200 else "🔴 ERROR"
        metrics["node_b"]["models"] = [m["name"] for m in resp.json().get("models", [])]
    except:
        health["node_b"] = "🔴 OFFLINE"
        metrics["node_b"]["models"] = []
    
    return health

def choose_node(model_name=None):
    """Choose best node for request"""
    health = get_node_health()
    
    # Prefer online nodes
    node_a_online = health["node_a"] == "🟢 ONLINE"
    node_b_online = health["node_b"] == "🟢 ONLINE"
    
    if not node_a_online and not node_b_online:
        return None
    if not node_a_online:
        return NODE_B
    if not node_b_online:
        return NODE_A
    
    # If model specified, prefer node that has it
    if model_name:
        if model_name in metrics["node_a"]["models"]:
            return NODE_A
        if model_name in metrics["node_b"]["models"]:
            return NODE_B
    
    # Default: route to less loaded node (round-robin based on request count)
    if metrics["node_a"]["requests"] <= metrics["node_b"]["requests"]:
        return NODE_A
    else:
        return NODE_B

def proxy_request(endpoint, method="GET", body=None):
    """Route request to appropriate node"""
    node = choose_node(body.get("model") if body else None)
    
    if not node:
        return {"error": "No nodes available"}, 503, None, 0
    
    try:
        start = time.time()
        
        if method == "POST":
            resp = requests.post(f"{node}{endpoint}", json=body, timeout=300)
        else:
            resp = requests.get(f"{node}{endpoint}", timeout=5)
        
        elapsed = time.time() - start
        
        # Update metrics
        node_key = "node_a" if "192.168.100.1" in node else "node_b"
        metrics[node_key]["requests"] += 1
        metrics[node_key]["total_time"] += elapsed
        
        return resp.json(), resp.status_code, node, elapsed
    
    except Exception as e:
        node_key = "node_a" if "192.168.100.1" in node else "node_b"
        metrics[node_key]["errors"] += 1
        return {"error": str(e)}, 500, node, 0

class LoadBalancerHandler(BaseHTTPRequestHandler):
    """HTTP handler for load balancer API"""
    
    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            health = get_node_health()
            response = {
                "status": "healthy",
                "timestamp": datetime.now().isoformat(),
                "nodes": health,
                "metrics": metrics
            }
            self.wfile.write(json.dumps(response, indent=2).encode())
        
        elif self.path == "/api/tags":
            result, status, node, elapsed = proxy_request("/api/tags")
            self.send_response(status)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            if node:
                result["_served_by"] = node
                result["_response_time_ms"] = round(elapsed * 1000, 2)
            self.wfile.write(json.dumps(result).encode())
        
        elif self.path == "/dashboard":
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            html = self.get_dashboard_html()
            self.wfile.write(html.encode())
        
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = json.loads(self.rfile.read(content_length))
        
        # Handle all Ollama API endpoints
        if self.path in ["/api/generate", "/api/chat", "/api/embeddings", "/api/embed"]:
            result, status, node, elapsed = proxy_request(self.path, "POST", body)
            self.send_response(status)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            if node and isinstance(result, dict):
                result["_served_by"] = node
                result["_response_time_ms"] = round(elapsed * 1000, 2)
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Custom logging"""
        node_info = ""
        if len(args) >= 1 and "POST" in str(args[0]):
            node_info = " -> cluster"
        print(f"[LB] {args[0] if args else 'request'}{node_info}")
    
    def get_dashboard_html(self):
        health = get_node_health()
        node_a_avg = metrics["node_a"]["total_time"] / max(metrics["node_a"]["requests"], 1) * 1000
        node_b_avg = metrics["node_b"]["total_time"] / max(metrics["node_b"]["requests"], 1) * 1000
        
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <title>ShaneBrain Cluster Dashboard</title>
            <meta http-equiv="refresh" content="5">
            <style>
                body {{ font-family: 'Courier New', monospace; background: #0a0a0a; color: #00ff00; padding: 20px; }}
                .container {{ max-width: 900px; margin: 0 auto; }}
                .header {{ text-align: center; border-bottom: 2px solid #00ff00; padding-bottom: 20px; margin-bottom: 20px; }}
                .node {{ background: #1a1a1a; margin: 20px 0; padding: 20px; border: 1px solid #00ff00; border-radius: 5px; }}
                .status {{ font-size: 24px; font-weight: bold; margin-bottom: 15px; }}
                .metric {{ margin: 8px 0; }}
                .label {{ color: #ffff00; }}
                .online {{ color: #00ff00; }}
                .offline {{ color: #ff0000; }}
                .stats {{ display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🧠 SHANEBRAIN CLUSTER</h1>
                    <p>Load Balancer v2.0 | Auto-refresh: 5s</p>
                </div>
                
                <div class="node">
                    <div class="status">NODE A: 192.168.100.1 (Primary)</div>
                    <div class="stats">
                        <div class="metric"><span class="label">Status:</span> {health['node_a']}</div>
                        <div class="metric"><span class="label">Requests:</span> {metrics['node_a']['requests']}</div>
                        <div class="metric"><span class="label">Avg Response:</span> {node_a_avg:.0f}ms</div>
                        <div class="metric"><span class="label">Errors:</span> {metrics['node_a']['errors']}</div>
                        <div class="metric"><span class="label">Models:</span> {len(metrics['node_a']['models'])}</div>
                    </div>
                </div>
                
                <div class="node">
                    <div class="status">NODE B: 192.168.100.2 (Secondary)</div>
                    <div class="stats">
                        <div class="metric"><span class="label">Status:</span> {health['node_b']}</div>
                        <div class="metric"><span class="label">Requests:</span> {metrics['node_b']['requests']}</div>
                        <div class="metric"><span class="label">Avg Response:</span> {node_b_avg:.0f}ms</div>
                        <div class="metric"><span class="label">Errors:</span> {metrics['node_b']['errors']}</div>
                        <div class="metric"><span class="label">Models:</span> {len(metrics['node_b']['models'])}</div>
                    </div>
                </div>
                
                <div class="node">
                    <div class="status">📊 CLUSTER TOTALS</div>
                    <div class="stats">
                        <div class="metric"><span class="label">Total Requests:</span> {metrics['node_a']['requests'] + metrics['node_b']['requests']}</div>
                        <div class="metric"><span class="label">Total Errors:</span> {metrics['node_a']['errors'] + metrics['node_b']['errors']}</div>
                        <div class="metric"><span class="label">Online Since:</span> {metrics['start_time'][:19]}</div>
                        <div class="metric"><span class="label">API:</span> http://localhost:{BALANCER_PORT}</div>
                    </div>
                </div>
                
                <div class="node" style="border-color: #ffff00;">
                    <div class="status" style="color: #ffff00;">📡 API ENDPOINTS</div>
                    <div class="metric">POST /api/chat - Chat completions (used by bot)</div>
                    <div class="metric">POST /api/generate - Text generation</div>
                    <div class="metric">POST /api/embeddings - Vector embeddings</div>
                    <div class="metric">GET /api/tags - List models</div>
                    <div class="metric">GET /health - Cluster health</div>
                </div>
            </div>
        </body>
        </html>
        """

def start_balancer():
    """Start load balancer server"""
    print()
    print("=" * 60)
    print("  SHANEBRAIN CLUSTER LOAD BALANCER v2.0")
    print("=" * 60)
    print(f"\n  📊 Dashboard:     http://localhost:{BALANCER_PORT}/dashboard")
    print(f"  💊 Health Check:  http://localhost:{BALANCER_PORT}/health")
    print(f"  📡 API Endpoint:  http://localhost:{BALANCER_PORT}")
    print(f"\n  🖥️  Node A: {NODE_A}")
    print(f"  🖥️  Node B: {NODE_B}")
    print("\n  Checking nodes...")
    
    health = get_node_health()
    print(f"    Node A: {health['node_a']}")
    print(f"    Node B: {health['node_b']}")
    
    print(f"\n  ✅ Balancer ready on port {BALANCER_PORT}")
    print("=" * 60)
    print()
    
    server = HTTPServer(("0.0.0.0", BALANCER_PORT), LoadBalancerHandler)
    server.serve_forever()

if __name__ == "__main__":
    start_balancer()