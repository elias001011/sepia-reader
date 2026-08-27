import unittest

from main import merge_records


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


if __name__ == "__main__":
    unittest.main()
