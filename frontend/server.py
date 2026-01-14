#!/usr/bin/env python3
"""
ShaneBrain Cyberpunk UI Server
Serves the frontend and handles CORS for local API connections.

Usage:
    python frontend/server.py

Then open: http://localhost:5000
"""

import http.server
import socketserver
import os
from pathlib import Path

PORT = 5000
DIRECTORY = Path(__file__).parent

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    """HTTP handler with CORS headers for local development."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DIRECTORY), **kwargs)

    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def log_message(self, format, *args):
        # Custom log format
        print(f"[ShaneBrain UI] {args[0]}")


def main():
    os.chdir(DIRECTORY)

    print(f"""
================================================================================
     SHANEBRAIN // CYBERPUNK NEURAL INTERFACE
================================================================================

  Server starting on port {PORT}...

  Open in browser:  http://localhost:{PORT}

  Frontend files:   {DIRECTORY}

  Press Ctrl+C to stop

================================================================================
""")

    with socketserver.TCPServer(("", PORT), CORSRequestHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[ShaneBrain UI] Server stopped.")


if __name__ == "__main__":
    main()
