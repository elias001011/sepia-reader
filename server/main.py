#!/usr/bin/env python3
"""Sépia Reader: static web build and small, atomic JSON sync API."""

import json
import mimetypes
import os
import posixpath
import re
import threading
import urllib.parse
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WEB_DIR = os.environ.get("SEPIA_WEB_DIR", os.path.join(BASE_DIR, "web"))
DATA_DIR = os.environ.get("SEPIA_DATA_DIR", os.path.join(BASE_DIR, "data"))
PORT = int(os.environ.get("SEPIA_PORT", "8888"))
MAX_BODY_BYTES = 64 * 1024 * 1024
MERGE_HEADER = "X-Sepia-Write-Mode"

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("text/javascript", ".js")
mimetypes.add_type("text/javascript", ".mjs")
mimetypes.add_type("application/json", ".json")

NO_CACHE_FILES = {
    "index.html",
    "flutter.js",
    "flutter_bootstrap.js",
    "flutter_service_worker.js",
    "version.json",
    "manifest.json",
    "main.dart.js",
    "main.dart.mjs",
    "main.dart.wasm",
}

HASHED_NAME = re.compile(r"[.\-_][0-9a-f]{8,}\.[A-Za-z0-9]+$")

API_FILES = {
    "/api/documents": ("documents.json", []),
    "/api/folders": ("folders.json", []),
    "/api/settings": ("settings.json", {}),
    "/api/bookmarks": ("bookmarks.json", []),
}

DATA_LOCK = threading.Lock()


def _not_modified(if_modified_since, mtime):
    if not if_modified_since:
        return False
    try:
        cached = parsedate_to_datetime(if_modified_since)
    except (TypeError, ValueError):
        return False
    if cached is None:
        return False
    if cached.tzinfo is None:
        cached = cached.replace(tzinfo=timezone.utc)
    return int(mtime) <= int(cached.timestamp())


def _data_path(filename):
    return os.path.join(DATA_DIR, filename)


def _read_json(filename, default):
    path = _data_path(filename)
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError):
        return default


def _write_json_atomic(filename, value):
    os.makedirs(DATA_DIR, exist_ok=True)
    path = _data_path(filename)
    tmp_path = f"{path}.{os.getpid()}.{threading.get_ident()}.tmp"
    try:
        with open(tmp_path, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_path, path)
    finally:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass


def _record_time(record):
    raw = record.get("updatedAt")
    if not isinstance(raw, str):
        return datetime.min.replace(tzinfo=timezone.utc)
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _incoming_wins(incoming, current):
    incoming_time = _record_time(incoming)
    current_time = _record_time(current)
    if incoming_time != current_time:
        return incoming_time > current_time
    return incoming.get("deletedAt") is not None and current.get("deletedAt") is None


def merge_records(existing, incoming):
    """Merge sync collections by id, keeping the newest record atomically."""
    if not isinstance(existing, list) or not isinstance(incoming, list):
        raise ValueError("merge payload must be a list")

    by_id = {}
    order = []
    for record in [*existing, *incoming]:
        if not isinstance(record, dict) or not isinstance(record.get("id"), str):
            raise ValueError("every record must be an object with a string id")
        record_id = record["id"]
        current = by_id.get(record_id)
        if current is None:
            order.append(record_id)
            by_id[record_id] = record
        elif _incoming_wins(record, current):
            by_id[record_id] = record
    return [by_id[record_id] for record_id in order]


class Server(ThreadingHTTPServer):
    # Must be set before bind() runs in the constructor, or a restart races
    # the previous socket's TIME_WAIT and dies with "address already in use".
    allow_reuse_address = True
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    server_version = "SepiaServer/1.1"

    def log_message(self, format, *args):  # noqa: A002
        pass

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _static_path(self, url_path):
        path = urllib.parse.urlsplit(url_path).path
        path = posixpath.normpath(urllib.parse.unquote(path))
        if path in ("", "/", "."):
            path = "/index.html"
        path = path.lstrip("/")
        full = os.path.normpath(os.path.join(WEB_DIR, path))
        web_root = os.path.normpath(WEB_DIR)
        if not full.startswith(web_root + os.sep) and full != web_root:
            return None
        return full

    def _cache_control_for(self, full):
        rel = os.path.relpath(full, os.path.normpath(WEB_DIR)).replace(os.sep, "/")
        if rel in NO_CACHE_FILES:
            return "no-cache, must-revalidate"
        if HASHED_NAME.search(rel):
            return "public, max-age=31536000, immutable"
        return "no-cache, must-revalidate"

    def _resolve_static(self):
        full = self._static_path(self.path)
        if full is None or not os.path.isfile(full):
            return None, None, None, None
        content_type, _ = mimetypes.guess_type(full)
        content_type = content_type or "application/octet-stream"
        try:
            mtime = os.path.getmtime(full)
        except OSError:
            return None, None, None, None
        return full, content_type, mtime, self._cache_control_for(full)

    def _serve_static(self, head_only=False):
        full, content_type, mtime, cache_control = self._resolve_static()
        if full is None:
            self.send_error(404, "Not Found")
            return

        if _not_modified(self.headers.get("If-Modified-Since"), mtime):
            self.send_response(304)
            self.send_header("Cache-Control", cache_control)
            self.send_header("Last-Modified", self.date_time_string(int(mtime)))
            self.end_headers()
            return

        try:
            size = os.path.getsize(full)
            if head_only:
                data = b""
            else:
                with open(full, "rb") as handle:
                    data = handle.read()
        except OSError:
            self.send_error(404, "Not Found")
            return
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", cache_control)
        self.send_header("Last-Modified", self.date_time_string(int(mtime)))
        self.send_header("Content-Length", str(size))
        self.end_headers()
        if not head_only:
            self.wfile.write(data)

    def do_GET(self):
        route = urllib.parse.urlsplit(self.path).path
        if route in API_FILES:
            filename, default = API_FILES[route]
            with DATA_LOCK:
                payload = _read_json(filename, default)
            self._send_json(200, payload)
            return
        self._serve_static()

    def do_HEAD(self):
        route = urllib.parse.urlsplit(self.path).path
        if route in API_FILES:
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        self._serve_static(head_only=True)

    def do_PUT(self):
        route = urllib.parse.urlsplit(self.path).path
        if route not in API_FILES:
            self.send_error(404, "Not Found")
            return
        filename, default = API_FILES[route]
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._send_json(400, {"error": "invalid content length"})
            return
        if length < 0 or length > MAX_BODY_BYTES:
            self._send_json(413, {"error": "payload too large"})
            return
        raw = self.rfile.read(length) if length else b""
        try:
            value = json.loads(raw.decode("utf-8")) if raw else default
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._send_json(400, {"error": "invalid json"})
            return
        if not isinstance(value, type(default)):
            self._send_json(400, {"error": "unexpected payload type"})
            return

        try:
            with DATA_LOCK:
                merge_requested = (
                    self.headers.get(MERGE_HEADER, "").lower() == "merge"
                    and isinstance(default, list)
                )
                if merge_requested:
                    value = merge_records(_read_json(filename, default), value)
                _write_json_atomic(filename, value)
        except ValueError as error:
            self._send_json(400, {"error": str(error)})
            return
        self._send_json(200, value)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(WEB_DIR, exist_ok=True)
    server = Server(("0.0.0.0", PORT), Handler)
    print(f"Sepia server listening on :{PORT} (web={WEB_DIR}, data={DATA_DIR})")
    server.serve_forever()


if __name__ == "__main__":
    main()
