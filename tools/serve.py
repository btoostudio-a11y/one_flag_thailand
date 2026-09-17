"""Local game preview. No npm or website repo required."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--port", type=int, default=8060)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1] / "build" / "web"
if not (root / "index.pck").exists():
    raise SystemExit("Export the game first: see README.md")
class Handler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root), **kwargs)
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
print(f"Game preview: http://localhost:{args.port}", flush=True)
ThreadingHTTPServer(("127.0.0.1", args.port), Handler).serve_forever()
