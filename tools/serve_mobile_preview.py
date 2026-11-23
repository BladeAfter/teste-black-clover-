"""Local mobile/WebView preview of the exported Mini App. No public hosting."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
class Preview(SimpleHTTPRequestHandler):
    extensions_map = dict(SimpleHTTPRequestHandler.extensions_map, **{'.wasm':'application/wasm','.pck':'application/octet-stream'})
    def end_headers(self):
        self.send_header('Cache-Control','no-store')
        super().end_headers()
root = Path(__file__).resolve().parents[1] / 'build/telegram'
print('Mini App preview: http://127.0.0.1:8765', flush=True)
ThreadingHTTPServer(('127.0.0.1',8765),partial(Preview,directory=str(root))).serve_forever()
