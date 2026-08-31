import json
import gzip
import os
import shutil
import tempfile
import threading
import unittest
import urllib.error
import urllib.request

import main
from main import Server, health_payload, merge_records, merge_settings


class MergeRecordsTest(unittest.TestCase):
    def test_keeps_records_missing_from_a_stale_snapshot(self):
        existing = [
            {"id": "a", "updatedAt": "2026-08-27T01:00:00", "value": 1},
            {"id": "b", "updatedAt": "2026-08-27T01:00:00", "value": 2},
        ]
        incoming = [
            {"id": "b", "updatedAt": "2026-08-27T02:00:00", "value": 3},
        ]

        merged = merge_records(existing, incoming)

        self.assertEqual([record["id"] for record in merged], ["a", "b"])
        self.assertEqual(merged[1]["value"], 3)

    def test_newest_update_wins_regardless_of_arrival_order(self):
        newest = {"id": "a", "updatedAt": "2026-08-27T03:00:00", "value": 3}
        stale = {"id": "a", "updatedAt": "2026-08-27T02:00:00", "value": 2}

        self.assertEqual(merge_records([newest], [stale]), [newest])
        self.assertEqual(merge_records([stale], [newest]), [newest])

    def test_tombstone_wins_a_timestamp_tie(self):
        live = {"id": "a", "updatedAt": "2026-08-27T03:00:00"}
        deleted = {
            "id": "a",
            "updatedAt": "2026-08-27T03:00:00",
            "deletedAt": "2026-08-27T03:00:00",
        }

        self.assertEqual(merge_records([live], [deleted]), [deleted])
        self.assertEqual(merge_records([deleted], [live]), [deleted])

    def test_rejects_records_without_an_id(self):
        with self.assertRaisesRegex(ValueError, "string id"):
            merge_records([], [{"updatedAt": "2026-08-27T03:00:00"}])


class MergeSettingsTest(unittest.TestCase):
    def test_newer_settings_win_regardless_of_arrival_order(self):
        newer = {"seedColor": 1, "settingsUpdatedAt": "2026-08-27T03:00:00"}
        older = {"seedColor": 2, "settingsUpdatedAt": "2026-08-27T02:00:00"}

        self.assertEqual(merge_settings(older, newer), newer)
        self.assertEqual(merge_settings(newer, older), newer)

    def test_missing_timestamp_falls_back_to_last_writer(self):
        stored = {"seedColor": 1, "settingsUpdatedAt": "2026-08-27T03:00:00"}
        incoming = {"seedColor": 2}

        self.assertEqual(merge_settings(stored, incoming), incoming)

    def test_equal_timestamp_keeps_the_stored_copy(self):
        stored = {"seedColor": 1, "settingsUpdatedAt": "2026-08-27T03:00:00"}
        incoming = {"seedColor": 2, "settingsUpdatedAt": "2026-08-27T03:00:00"}

        self.assertEqual(merge_settings(stored, incoming), stored)


class ServerSocketOptionsTest(unittest.TestCase):
    def test_restart_friendly_socket_options(self):
        # allow_reuse_address is inherited; allow_reuse_port is what this
        # subclass adds so a restart can bind before the old socket is gone.
        self.assertTrue(Server.allow_reuse_address)
        self.assertTrue(Server.allow_reuse_port)
        self.assertTrue(Server.daemon_threads)


class HeadlessServerTest(unittest.TestCase):
    """The sync API and /healthz must work with no web/ bundle at all."""

    def setUp(self):
        self._tmp = tempfile.mkdtemp()
        self._web = main.WEB_DIR
        self._data = main.DATA_DIR
        # Point WEB_DIR at a directory that has no index.html — the headless
        # case — and DATA_DIR at a throwaway.
        main.WEB_DIR = os.path.join(self._tmp, "web-empty")
        main.DATA_DIR = os.path.join(self._tmp, "data")
        os.makedirs(main.WEB_DIR, exist_ok=True)
        self._server = Server(("127.0.0.1", 0), main.Handler)
        self._port = self._server.server_address[1]
        self._thread = threading.Thread(
            target=self._server.serve_forever, daemon=True
        )
        self._thread.start()

    def tearDown(self):
        self._server.shutdown()
        self._server.server_close()
        self._thread.join(timeout=5)
        main.WEB_DIR = self._web
        main.DATA_DIR = self._data
        shutil.rmtree(self._tmp, ignore_errors=True)

    def _get(self, path):
        with urllib.request.urlopen(
            f"http://127.0.0.1:{self._port}{path}", timeout=5
        ) as response:
            return response.status, response.read()

    def test_healthz_reports_liveness_without_a_web_bundle(self):
        status, body = self._get("/healthz")
        self.assertEqual(status, 200)
        payload = json.loads(body)
        self.assertTrue(payload["ok"])
        self.assertFalse(payload["serves_web"])
        self.assertIn("merge", payload["write_modes"])
        self.assertIn("/api/documents", payload["api"])

    def test_sync_api_still_answers_headless(self):
        status, body = self._get("/api/documents")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), [])

    def test_missing_web_file_is_a_plain_404(self):
        with self.assertRaises(urllib.error.HTTPError) as caught:
            self._get("/index.html")
        self.assertEqual(caught.exception.code, 404)
        caught.exception.close()

    def test_health_payload_shape(self):
        payload = health_payload()
        self.assertEqual(payload["service"], "sepia-sync")
        self.assertEqual(payload["api"], sorted(main.API_FILES))

    def test_large_json_responses_support_gzip(self):
        documents = [
            {
                "id": "large",
                "title": "Large",
                "content": "compressible text " * 500,
                "updatedAt": "2026-08-29T00:00:00",
            }
        ]
        os.makedirs(main.DATA_DIR, exist_ok=True)
        with open(
            os.path.join(main.DATA_DIR, "documents.json"),
            "w",
            encoding="utf-8",
        ) as handle:
            json.dump(documents, handle)

        request = urllib.request.Request(
            f"http://127.0.0.1:{self._port}/api/documents",
            headers={"Accept-Encoding": "gzip"},
        )
        with urllib.request.urlopen(request, timeout=5) as response:
            body = response.read()
            self.assertEqual(response.headers["Content-Encoding"], "gzip")
            self.assertIn("Accept-Encoding", response.headers["Vary"])

        self.assertEqual(json.loads(gzip.decompress(body)), documents)


if __name__ == "__main__":
    unittest.main()
