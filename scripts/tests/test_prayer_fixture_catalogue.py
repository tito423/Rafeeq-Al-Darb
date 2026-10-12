"""Read-only checks for the moved, original prayer-method catalogue."""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'prayer_fixture_builder', ROOT / 'scripts' / 'build_prayer_method_fixtures.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PrayerFixtureCatalogueTests(unittest.TestCase):
    catalogue = ROOT / 'rafeeq_app/lib/core/models/prayer_calculation_methods.dart'
    # The twenty offered methods, read from the actual current catalogue.
    expected = [1, 2, 3, 4, 5, 8, 9, 10, 11, 12,
                13, 14, 16, 17, 18, 19, 20, 21, 22, 23]

    def test_builder_points_to_actual_moved_catalogue(self):
        self.assertEqual(self.catalogue, Path(builder.CATALOGUE))
        self.assertTrue(Path(builder.CATALOGUE).is_file())

    def test_reads_all_twenty_actual_offered_methods(self):
        self.assertEqual(self.expected, builder.offered_ids())

    def test_reading_ids_does_not_fetch_or_change_source_fixtures(self):
        files = [self.catalogue, ROOT / 'rafeeq_app/test/fixtures/prayer_methods.json',
                 ROOT / 'rafeeq_app/test/fixtures/prayer_timings.json']
        before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
        with patch.object(builder, 'get', side_effect=AssertionError('Unexpected fetch')):
            self.assertEqual(self.expected, builder.offered_ids())
        self.assertEqual(before, {
            p: hashlib.sha256(p.read_bytes()).hexdigest() for p in files})

    def test_original_published_method_table_covers_each_offered_id(self):
        methods = json.loads((ROOT / 'rafeeq_app/test/fixtures/prayer_methods.json')
                             .read_text(encoding='utf-8'))
        for method in self.expected:
            self.assertIn(str(method), methods)


if __name__ == '__main__':
    unittest.main()
