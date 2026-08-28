import unittest

from main import Server, merge_records, merge_settings


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


if __name__ == "__main__":
    unittest.main()
