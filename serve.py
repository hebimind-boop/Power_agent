#!/usr/bin/env python3
"""Internal dev server for Space Shooter - serves index.html on localhost."""
import argparse
import http.server
import socketserver
import os
import sys

class DevHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # No-cache for dev + allow direct open (no iframe block)
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, format, *args):
        sys.stdout.write("[%s] %s\n" % (self.address_string(), format % args))

def run(port):
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    socketserver.TCPServer.allow_reuse_address = True
    for p in [port, 8000, 3000, 5000, 9000]:
        try:
            with socketserver.TCPServer(("0.0.0.0", p), DevHandler) as httpd:
                print(f"Serving {os.getcwd()} at:")
                print(f"  -> http://localhost:{p}")
                print(f"  -> http://127.0.0.1:{p}")
                print("Press Ctrl+C to stop.")
                httpd.serve_forever()
                break
        except OSError as e:
            if "Address already in use" in str(e):
                print(f"Port {p} busy, trying next...")
                continue
            raise
    else:
        print("No free port found.")
        sys.exit(1)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", "-p", type=int, default=8080)
    args = ap.parse_args()
    run(args.port)
