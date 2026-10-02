# Local-only receiver: the AI Studio page POSTs the generated WAV here (127.0.0.1 only).
import http.server, os, time, urllib.parse
D = 'E:/DevEnv/kids_voice/inbox'
class H(http.server.BaseHTTPRequestHandler):
    def cors(self):
        self.send_header('Access-Control-Allow-Origin', 'https://aistudio.google.com')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.send_header('Access-Control-Allow-Private-Network', 'true')
    def do_OPTIONS(self):
        self.send_response(204); self.cors(); self.end_headers()
    def do_POST(self):
        n = int(self.headers['Content-Length']); data = self.rfile.read(n)
        name = os.path.basename(urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get('name', [str(time.time())])[0])
        open(os.path.join(D, name), 'wb').write(data)
        self.send_response(200); self.cors(); self.end_headers(); self.wfile.write(f'{name} {n}'.encode())
http.server.HTTPServer(('127.0.0.1', 8765), H).serve_forever()
