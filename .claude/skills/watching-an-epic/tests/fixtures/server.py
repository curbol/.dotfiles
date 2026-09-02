import glob, http.server, os, socketserver, sys, urllib.parse

root, portfile = sys.argv[1], sys.argv[2]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.serve()

    def do_POST(self):
        self.serve()

    def do_PUT(self):
        self.serve()

    def serve(self):
        raw = self.path.split("?")
        path = raw[0].strip("/").replace("/", "_")
        query = urllib.parse.parse_qs(raw[1]) if len(raw) > 1 else {}
        # A more specific fixture keyed on the timestamp argument wins when one exists, so a
        # rule about the watcher's own message can be told apart from one about the report.
        hits = []
        ts = (query.get("timestamp") or query.get("ts") or [None])[0]
        if ts:
            hits = sorted(glob.glob(os.path.join(root, "%s_%s@%s.*" % (self.command, path, ts))))
        if not hits:
            hits = sorted(glob.glob(os.path.join(root, "%s_%s.*" % (self.command, path))))
        if hits:
            status = int(hits[0].rsplit(".", 1)[1])
            body = open(hits[0], "rb").read()
        else:
            status, body = 599, b'{"error":"no fixture for this route"}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


with socketserver.TCPServer(("127.0.0.1", 0), Handler) as srv:
    with open(portfile, "w") as fh:
        fh.write(str(srv.server_address[1]))
    srv.serve_forever()
