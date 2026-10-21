#!/usr/bin/env python3
"""Sépia Reader: static web build and small, atomic JSON sync API."""

import argparse
import hmac
import importlib.util
import ipaddress
import uuid
import gzip
import json
import mimetypes
import os
import posixpath
import re
import signal
import threading
import urllib.parse
from datetime import datetime, timezone, timedelta
from email.utils import parsedate_to_datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WEB_DIR = os.environ.get("SEPIA_WEB_DIR", os.path.join(BASE_DIR, "web"))
DATA_DIR = os.environ.get("SEPIA_DATA_DIR", os.path.join(BASE_DIR, "data"))
PORT = int(os.environ.get("SEPIA_PORT", "8888"))
HOST = os.environ.get("SEPIA_HOST", "0.0.0.0")
TOKEN = os.environ.get("SEPIA_TOKEN", "")
VERSION = "2.5.7"
# Old clients omitted the timezone. Operators can explicitly select the
# legacy client timezone; the host's local zone is the compatibility default.
LEGACY_TIMEZONE = os.environ.get("SEPIA_LEGACY_TIMEZONE", "")


def legacy_timezone():
    if not LEGACY_TIMEZONE:
        return datetime.now().astimezone().tzinfo
    offset = re.fullmatch(r"([+-])(\d{2}):(\d{2})", LEGACY_TIMEZONE)
    if offset:
        hours, minutes = int(offset[2]), int(offset[3])
        if hours > 23 or minutes > 59:
            raise ValueError("Invalid legacy timezone offset")
        delta = timedelta(hours=hours, minutes=minutes)
        return timezone(delta if offset[1] == "+" else -delta)
    from zoneinfo import ZoneInfo  # Only explicit IANA zones need Python 3.9+.
    return ZoneInfo(LEGACY_TIMEZONE)


def canonical_record(record):
    result = dict(record)
    for key in ("createdAt", "updatedAt", "deletedAt", "settingsUpdatedAt"):
        value = result.get(key)
        if not isinstance(value, str):
            continue
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            continue
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=legacy_timezone())
        result[key] = parsed.astimezone(timezone.utc).isoformat()
    return result


def canonical_payload(value):
    if isinstance(value, list):
        return [canonical_record(r) if isinstance(r, dict) else r for r in value]
    return canonical_record(value) if isinstance(value, dict) else value


def mutation_time(records):
    now = datetime.now(timezone.utc)
    for record in records:
        previous = _record_time(record)
        if previous >= now:
            now = previous + timedelta(microseconds=1)
    return now.isoformat()

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


def health_payload():
    """A tiny liveness response that does not depend on ``web/``.

    The server can run headless — sync API only, no web bundle — for a
    self-hosted instance that is only ever reached by the native apps. In that
    mode there is no ``web/version.json`` to probe, so ``/healthz`` is what a
    supervisor (and ``restart-sepia.sh``) checks instead.
    """
    return {
        "ok": True,
        "version": VERSION,
        "legacy_timezone": LEGACY_TIMEZONE or str(legacy_timezone()),
        "cli_enabled": server_config()["cliEnabled"],
        "authentication": bool(TOKEN),
        "service": "sepia-sync",
        "api": sorted(API_FILES),
        # Clients may send a single changed record only when this capability
        # is advertised. Older servers replaced the whole collection on PUT,
        # so assuming merge support could erase every omitted document.
        "write_modes": ["replace", "merge"],
        "tts_enabled": server_config()["ttsEnabled"],
        "serves_web": os.path.isfile(os.path.join(WEB_DIR, "index.html")),
    }


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


def _read_json(filename, default, strict=False):
    path = _data_path(filename)
    if not os.path.exists(path):
        return default
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except (json.JSONDecodeError, OSError) as error:
        if strict:
            raise CliError("cannot read library data; restore or repair " + filename, 500) from error
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


def _record_time(record, key="updatedAt"):
    raw = record.get(key)
    if not isinstance(raw, str):
        return datetime.min.replace(tzinfo=timezone.utc)
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError:
        return datetime.min.replace(tzinfo=timezone.utc)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=legacy_timezone())
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


def merge_settings(existing, incoming):
    """Keep the newer of two settings blobs by ``settingsUpdatedAt``.

    Settings are a single object, not a collection, so :func:`merge_records`
    does not apply. Without this, an out-of-order or stale PUT from one device
    silently overwrites a newer copy another device already pushed. When
    neither side carries a comparable timestamp the incoming write wins, which
    is the plain last-writer behaviour this had before.
    """
    if not isinstance(existing, dict) or not isinstance(incoming, dict):
        return incoming
    if "settingsUpdatedAt" not in existing or "settingsUpdatedAt" not in incoming:
        return incoming
    incoming_time = _record_time(incoming, "settingsUpdatedAt")
    existing_time = _record_time(existing, "settingsUpdatedAt")
    return incoming if incoming_time > existing_time else existing


# Optional terminal gateway; configuration lives outside synced reader settings.
def server_config():
    config = _read_json("server-config.json", {})
    return {"cliEnabled": config.get("cliEnabled") is True,
            "ttsEnabled": config.get("ttsEnabled", os.environ.get("SEPIA_TTS_ENABLED") == "1") is True}


def configure_cli(enabled):
    config = server_config()
    config["cliEnabled"] = bool(enabled)
    _write_json_atomic("server-config.json", config)


def tts_backend():
    try:
        import server_tts
        return server_tts
    except ImportError:
        return None


def tts_capabilities():
    backend = tts_backend()
    if backend is None:
        return {"enabled": False, "available": False, "reason": "missing-runtime", "voices": []}
    return backend.capabilities(os.environ.get("SEPIA_TTS_MODEL_DIR", ""), server_config()["ttsEnabled"])


class CliError(ValueError):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.status = status


def cli_operation(payload):
    """Execute one library operation under DATA_LOCK, sharing sync tombstones.

    Paths address library records, never paths on the server filesystem.
    Edits carry an optimistic revision to avoid clobbering a concurrent save.
    """
    if not isinstance(payload, dict):
        raise CliError("expected an object")
    command = payload.get("command", "ls")
    path = payload.get("path", "/")
    if not isinstance(path, str):
        raise CliError("path must be a string")
    docs = canonical_payload(_read_json("documents.json", [], strict=True))
    folders = canonical_payload(_read_json("folders.json", [], strict=True))
    if not isinstance(docs, list) or not isinstance(folders, list) or not all(
        isinstance(r, dict) and isinstance(r.get("id"), str) for r in docs + folders
    ):
        raise CliError("invalid library schema; repair the data before editing", 500)
    live_folders = [f for f in folders if not f.get("deletedAt")]
    live_docs = [d for d in docs if not d.get("deletedAt")]
    if not all(isinstance(f.get("name"), str) for f in live_folders) or not all(
        isinstance(d.get("title"), str) and isinstance(d.get("content"), str)
        and isinstance(d.get("extension", "md"), str) for d in live_docs
    ):
        raise CliError("invalid library schema; repair the data before editing", 500)

    def name(record):
        return record["name"] if "name" in record else record["title"] + "." + record.get("extension", "md")

    def resolve(value, folder_only=False):
        if not isinstance(value, str) or not value.startswith("/"):
            raise CliError("use an absolute library path")
        parts = [part for part in value.split("/") if part and part != "."]
        if any(part == ".." for part in parts):
            raise CliError("parent traversal must be normalized by the client")
        parent = None
        found = None
        for index, part in enumerate(parts):
            candidates = [f for f in live_folders if f.get("parentId") == parent and name(f) == part]
            if index == len(parts) - 1 and not folder_only:
                candidates += [d for d in live_docs if d.get("folderId") == parent and name(d) == part]
            if len(candidates) != 1:
                raise CliError("path not found or ambiguous: " + value, 404 if not candidates else 409)
            found = candidates[0]
            parent = found["id"]
        return found

    def destination(value):
        if not isinstance(value, str) or not value.startswith("/"):
            raise CliError("destination must be an absolute library path")
        parent_path, _, leaf = value.rstrip("/").rpartition("/")
        if not leaf or leaf in (".", "..") or any(ord(c) < 32 for c in leaf):
            raise CliError("invalid name")
        parent_record = resolve(parent_path or "/", folder_only=True)
        return parent_record["id"] if parent_record else None, leaf

    def ensure_free(parent, leaf, exclude=None):
        matches = [f for f in live_folders if f.get("parentId") == parent]
        matches += [d for d in live_docs if d.get("folderId") == parent]
        if any(name(r) == leaf and r["id"] != exclude for r in matches):
            raise CliError("destination already exists", 409)

    def document_name(leaf):
        title, ext = os.path.splitext(leaf)
        if not ext:
            return leaf, "md"
        if ext.lower() not in TEXT_EXTENSIONS:
            raise CliError("unsupported text file extension")
        return title, ext[1:].lower()

    if command in ("ls", "tree"):
        folder = resolve(path, folder_only=True)
        parent = folder["id"] if folder else None
        if command == "tree":
            return {"folders": live_folders, "documents": [
                {k: v for k, v in d.items() if k != "content"} for d in live_docs
            ]}
        return {"entries": sorted([
            {"name": name(f), "type": "folder", "id": f["id"]}
            for f in live_folders if f.get("parentId") == parent
        ] + [
            {"name": name(d), "type": "file", "id": d["id"],
             "bytes": len(d.get("content", "").encode("utf-8")), "updatedAt": d.get("updatedAt")}
            for d in live_docs if d.get("folderId") == parent
        ], key=lambda e: (e["type"] != "folder", e["name"].casefold()))}
    if command == "get":
        record = resolve(path)
        if record is None or "content" not in record:
            raise CliError("expected a file")
        return record
    now = mutation_time(docs + folders)
    if command == "mkdir":
        parent, leaf = destination(path)
        ensure_free(parent, leaf)
        record = {"id": str(uuid.uuid4()), "name": leaf, "parentId": parent,
                  "createdAt": now, "updatedAt": now}
        folders.append(record)
        _write_json_atomic("folders.json", folders)
        return record
    if command == "put":
        parent, leaf = destination(path)
        title, ext = document_name(leaf)
        # An extension-less upload is stored as .md, just like app-created documents.
        leaf = title + "." + ext
        content = payload.get("content")
        if not isinstance(content, str) or len(content.encode("utf-8")) > 5 * 1024 * 1024 or "\x00" in content:
            raise CliError("expected UTF-8 text up to 5 MB")
        candidates = [d for d in live_docs if d.get("folderId") == parent and name(d) == leaf]
        if len(candidates) > 1:
            raise CliError("ambiguous file name", 409)
        record = candidates[0] if candidates else None
        ensure_free(parent, leaf, record["id"] if record else None)
        if record:
            if payload.get("expectedUpdatedAt") != record.get("updatedAt"):
                raise CliError("file changed; fetch it again before overwriting", 409)
            record.update(content=content, updatedAt=now)
        else:
            if payload.get("expectedUpdatedAt") is not None:
                raise CliError("file was deleted; fetch the library again", 409)
            record = {"id": str(uuid.uuid4()), "title": title, "extension": ext,
                      "content": content, "folderId": parent, "createdAt": now,
                      "updatedAt": now, "isFavorite": False}
            docs.append(record)
        _write_json_atomic("documents.json", docs)
        return {k: v for k, v in record.items() if k != "content"}
    if command == "mv":
        record = resolve(path)
        if record is None:
            raise CliError("cannot move root")
        parent, leaf = destination(payload.get("destination"))
        if "name" in record:
            ancestor = parent
            seen = set()
            by_id = {f["id"]: f for f in live_folders}
            while ancestor is not None:
                if ancestor == record["id"] or ancestor in seen:
                    raise CliError("cannot move a folder inside itself")
                seen.add(ancestor)
                ancestor = by_id.get(ancestor, {}).get("parentId")
            ensure_free(parent, leaf, record["id"])
            record.update(name=leaf, parentId=parent, updatedAt=now)
            _write_json_atomic("folders.json", folders)
        else:
            title, ext = document_name(leaf)
            ensure_free(parent, title + "." + ext, record["id"])
            record.update(title=title, extension=ext, folderId=parent, updatedAt=now)
            _write_json_atomic("documents.json", docs)
        return {"ok": True}
    if command == "rm":
        record = resolve(path)
        if record is None:
            raise CliError("cannot delete root")
        deleted_folders = set()
        if "name" in record:
            deleted_folders.add(record["id"])
            while True:
                children = {f["id"] for f in live_folders if f.get("parentId") in deleted_folders}
                if children <= deleted_folders:
                    break
                deleted_folders |= children
            contained = [d for d in live_docs if d.get("folderId") in deleted_folders]
            if (contained or len(deleted_folders) > 1) and payload.get("recursive") is not True:
                raise CliError("folder is not empty; use rm -r")
            removed_docs = contained
        else:
            removed_docs = [record]
        removed_ids = {d["id"] for d in removed_docs}
        bookmarks = canonical_payload(_read_json("bookmarks.json", [], strict=True))
        if not isinstance(bookmarks, list) or not all(isinstance(b, dict) for b in bookmarks):
            raise CliError("invalid bookmark data", 500)
        now = mutation_time(docs + folders + bookmarks)
        for f in live_folders:
            if f["id"] in deleted_folders:
                f.update(updatedAt=now, deletedAt=now)
        for d in removed_docs:
            d.update(content="", updatedAt=now, deletedAt=now)
        for b in bookmarks:
            if b.get("documentId") in removed_ids:
                b.update(updatedAt=now, deletedAt=now)
        _write_json_atomic("bookmarks.json", bookmarks)
        _write_json_atomic("documents.json", docs)
        _write_json_atomic("folders.json", folders)
        return {"deletedFiles": len(removed_docs), "deletedFolders": len(deleted_folders)}
    raise CliError("unknown command")


TEXT_EXTENSIONS = {".md", ".markdown", ".txt", ".text", ".json", ".yaml", ".yml", ".html", ".htm",
                   ".css", ".js", ".ts", ".py", ".dart", ".sh", ".sql", ".xml", ".csv",
                   ".toml", ".ini", ".log", ".rs", ".go", ".java", ".kt", ".swift", ".c", ".cpp", ".h"}


class Server(ThreadingHTTPServer):
    # ThreadingHTTPServer already inherits allow_reuse_address=True (SO_REUSEADDR,
    # from HTTPServer) and sets daemon_threads=True itself. What it does not set
    # is SO_REUSEPORT, and that is the one that lets a fresh process bind while
    # the previous one is still winding down its listening socket on a restart.
    allow_reuse_port = False


class Handler(BaseHTTPRequestHandler):
    server_version = "SepiaServer/" + VERSION

    def _authorized(self, admin=False):
        supplied = self.headers.get("Authorization", "")
        valid_token = bool(TOKEN) and hmac.compare_digest(supplied.encode("utf-8"), ("Bearer " + TOKEN).encode("utf-8"))
        loopback = ipaddress.ip_address(self.client_address[0]).is_loopback
        if TOKEN and not valid_token:
            self._send_json(401, {"error": "authentication required"})
            return False
        if admin and not loopback and not valid_token:
            self._send_json(403, {"error": "configure through SSH/localhost, or authenticate with SEPIA_TOKEN"})
            return False
        return True

    def _json_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            raise CliError("invalid content length")
        if length < 0 or length > MAX_BODY_BYTES:
            raise CliError("payload too large", 413)
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            raise CliError("invalid json")

    def do_POST(self):
        route = urllib.parse.urlsplit(self.path).path
        if route == "/api/tts/speech":
            self._tts_speech()
            return
        if route != "/api/cli":
            self.send_error(404)
            return
        if not self._authorized():
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip() != "application/json":
            self._send_json(415, {"error": "application/json required"})
            return
        try:
            payload = self._json_body()
            with DATA_LOCK:
                if not server_config()["cliEnabled"]:
                    raise CliError("CLI disabled; enable it in server settings or run: python3 main.py --cli on", 403)
                result = cli_operation(payload)
            self._send_json(200, result)
        except CliError as error:
            self._send_json(error.status, {"error": str(error)})


    def setup(self):
        super().setup()
        self.connection.settimeout(30)

    def log_message(self, format, *args):  # noqa: A002
        pass

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        accepts_gzip = "gzip" in self.headers.get("Accept-Encoding", "").lower()
        encoded = (
            gzip.compress(body, compresslevel=5)
            if accepts_gzip and len(body) > 1024
            else body
        )
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Vary", "Accept-Encoding")
        if encoded is not body:
            self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def _static_path(self, url_path):
        path = urllib.parse.urlsplit(url_path).path
        path = posixpath.normpath(urllib.parse.unquote(path))
        if path in ("", "/", "."):
            path = "/index.html"
        path = path.lstrip("/")
        full = os.path.realpath(os.path.join(WEB_DIR, path))
        web_root = os.path.realpath(WEB_DIR)
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

    def _tts_speech(self):
        if not self._authorized():
            return
        if not TOKEN and not ipaddress.ip_address(self.client_address[0]).is_loopback:
            self._send_json(403, {"error": "set SEPIA_TOKEN before exposing speech to the network"})
            return
        if self.headers.get("Content-Type", "").split(";", 1)[0].strip() != "application/json":
            self._send_json(415, {"error": "application/json required"})
            return
        try:
            if int(self.headers.get("Content-Length", "0")) > 16 * 1024:
                self._send_json(413, {"error": "payload too large"})
                return
            payload = self._json_body()
        except (CliError, ValueError):
            self._send_json(400, {"error": "invalid speech request"})
            return
        backend = tts_backend()
        if backend is None or not tts_capabilities()["enabled"]:
            self._send_json(503, {"error": "server TTS unavailable"})
            return
        try:
            data = backend.synthesize(os.environ.get("SEPIA_TTS_MODEL_DIR", ""), payload)
        except backend.TtsError as error:
            self._send_json(error.status, {"error": str(error)})
            return
        except Exception:
            self._send_json(503, {"error": "speech synthesis failed"})
            return
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        try:
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        route = urllib.parse.urlsplit(self.path).path
        if route == "/healthz":
            self._send_json(200, health_payload())
            return
        if route.startswith("/api/") and not self._authorized():
            return
        if route == "/api/tts/voices":
            self._send_json(200, tts_capabilities())
            return
        if route == "/api/server-config":
            with DATA_LOCK:
                config = server_config()
            self._send_json(200, config)
            return
        if route in API_FILES:
            filename, default = API_FILES[route]
            with DATA_LOCK:
                payload = canonical_payload(_read_json(filename, default))
            self._send_json(200, payload)
            return
        self._serve_static()

    def do_HEAD(self):
        route = urllib.parse.urlsplit(self.path).path
        if route.startswith("/api/") and not self._authorized():
            return
        if route == "/healthz" or route in API_FILES:
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        self._serve_static(head_only=True)

    def do_PUT(self):
        route = urllib.parse.urlsplit(self.path).path
        if not self._authorized(admin=route == "/api/server-config"):
            return
        if route == "/api/server-config":
            try:
                payload = self._json_body()
                if not isinstance(payload, dict) or not payload or any(k not in {"cliEnabled", "ttsEnabled"} or type(v) is not bool for k, v in payload.items()):
                    raise CliError("server flags must be booleans")
                with DATA_LOCK:
                    if payload.get("ttsEnabled") is True and not tts_capabilities().get("available"):
                        raise CliError("install the optional TTS runtime and model first", 503)
                    config = server_config()
                    config.update(payload)
                    _write_json_atomic("server-config.json", config)
                self._send_json(200, server_config())
            except CliError as error:
                self._send_json(error.status, {"error": str(error)})
            return
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
                value = canonical_payload(value)
                merge_requested = self.headers.get(MERGE_HEADER, "").lower() == "merge"
                if merge_requested and isinstance(default, list):
                    value = merge_records(canonical_payload(_read_json(filename, default)), value)
                elif merge_requested and isinstance(default, dict):
                    value = merge_settings(canonical_payload(_read_json(filename, default)), value)
                _write_json_atomic(filename, value)
        except ValueError as error:
            self._send_json(400, {"error": str(error)})
            return
        self._send_json(200, value)

    def do_OPTIONS(self):
        self.send_response(204)
        self.end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cli", choices=("on", "off"), help="enable/disable terminal access and exit")
    args = parser.parse_args()
    if args.cli:
        configure_cli(args.cli == "on")
        print(json.dumps(server_config()))
        return
    legacy_timezone()  # Fail before serving if an explicitly configured IANA zone is invalid.
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(WEB_DIR, exist_ok=True)
    server = Server((HOST, PORT), Handler)
    server.timeout = 30
    print(f"Sepia server listening on :{PORT} (web={WEB_DIR}, data={DATA_DIR})")

    # Shut the listening socket down cleanly on the signal `pkill` sends, so a
    # restart is not racing a process that is still holding the port.
    def _stop(signum, _frame):
        print(f"Sepia server stopping on signal {signum}")
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
