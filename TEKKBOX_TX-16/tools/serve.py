#!/usr/bin/env python3
"""Lokaler Testserver für den Projektordner (für Browser-Tests mit tools/test.html).

  python3 tools/serve.py   -> http://127.0.0.1:8765/tools/test.html  bzw.  /TX-16_Live.html
"""
import http.server, functools, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT))
print('Server läuft: http://127.0.0.1:8765/  (Strg+C beendet)')
http.server.ThreadingHTTPServer(('127.0.0.1', 8765), handler).serve_forever()
