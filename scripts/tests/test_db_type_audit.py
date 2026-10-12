"""Regression checks for live Dart casts, using the original bundled corpus."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'db_type_audit', ROOT / 'scripts' / 'db_type_audit.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class DatabaseTypeAuditTests(unittest.TestCase):
    def columns(self, source):
        with tempfile.TemporaryDirectory(prefix='rafeeq_A20_') as directory:
            Path(directory, 'repository.dart').write_text(source, encoding='utf-8')
            with patch.object(audit, 'CODE_DIRS', [directory]):
                return audit.columns_cast_as_int()

    def test_actual_repository_historical_chapter_cast_is_not_live(self):
        self.assertNotIn('chapter_no', audit.columns_cast_as_int())

    def test_actual_repository_still_checks_live_integer_columns(self):
        self.assertTrue({'id', 'book_id', 'number_in_book', 'hadith_count',
                         'chapter_count'} <= audit.columns_cast_as_int())

    def test_line_comment_does_not_add_a_column(self):
        self.assertEqual({'id'}, self.columns(
            "// Old: r['chapter_no'] as int\nreturn r['id'] as int;"))

    def test_block_comment_does_not_add_a_column(self):
        self.assertEqual({'book_id'}, self.columns(
            "/* Old: r['chapter_no'] as int */ return r['book_id'] as int;"))

    def test_nested_dart_block_comments_are_skipped(self):
        self.assertEqual({'id'}, self.columns(
            "/* outer /* inner */ r['chapter_no'] as int */ r['id'] as int;"))

    def test_comments_separate_cast_tokens(self):
        self.assertEqual({'id'}, self.columns("r['id'] as/* note */int;"))

    def test_nullable_cast_remains_nullable_across_a_comment(self):
        self.assertEqual(set(), self.columns("r['id'] as int/* note */?;"))

    def test_original_nullable_cast_remains_excluded(self):
        self.assertEqual(set(), self.columns("r['id'] as int?;"))

    def test_quoted_url_is_not_a_line_comment(self):
        self.assertEqual({'book_id'}, self.columns(
            "const url = 'https://pub-39dbef68a1a845d5ba669b43a59516b9.r2.dev'; "
            "return r['book_id'] as int;"))

    def test_raw_triple_and_escaped_strings_do_not_open_comments(self):
        self.assertEqual({'id'}, self.columns(
            "const raw = r'/*'; const triple = '''// /* */'''; "
            "const escaped = 'it\\'s //'; return r['id'] as int;"))

    def test_real_readonly_database_audit_is_clean(self):
        # All original DBs are opened by the production tool with mode=ro.
        # Redirect only its report; never overwrite committed audit evidence.
        with tempfile.TemporaryDirectory(prefix='rafeeq_A20_report_') as directory:
            report = str(Path(directory, 'report.txt'))
            with patch.object(audit, 'REPORT', report), \
                    contextlib.redirect_stdout(io.StringIO()):
                result = audit.main()
            text = Path(report).read_text(encoding='utf-8')
            self.assertEqual(0, result)
            self.assertIn('every column the code casts as int really is an integer', text)
            self.assertNotIn('can crash a cast', text)


if __name__ == '__main__':
    unittest.main()
