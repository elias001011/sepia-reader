import contextlib
import importlib.util
import io
import json
import os
import tempfile
import threading
import unittest
from unittest.mock import patch
import urllib.error
import urllib.request
from pathlib import Path

import main
from sepia import Client


class CliTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old_data, self.old_web, self.old_token = main.DATA_DIR, main.WEB_DIR, main.TOKEN
        main.DATA_DIR = self.tmp.name
        main.WEB_DIR = os.path.join(self.tmp.name, 'no-web')
        main.TOKEN = ''
        main.configure_cli(True)
        self.server = main.Server(('127.0.0.1', 0), main.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.client = Client('http://127.0.0.1:' + str(self.server.server_port))

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        main.DATA_DIR, main.WEB_DIR, main.TOKEN = self.old_data, self.old_web, self.old_token
        self.tmp.cleanup()

    def test_full_library_workflow_and_sync_tombstones(self):
        c = self.client
        c.request('mkdir', '/Livros')
        c.request('mkdir', '/Livros/Subpasta')
        c.request('put', '/Livros/Subpasta/ação.md', content='Olá!\n' * 5000)
        record = c.request('get', '/Livros/Subpasta/ação.md')
        self.assertEqual(record['content'], 'Olá!\n' * 5000)
        c.request('put', '/Livros/Subpasta/ação.md', content='Editado', expectedUpdatedAt=record['updatedAt'])
        c.request('mv', '/Livros/Subpasta/ação.md', destination='/raiz.md')
        self.assertEqual(c.request('get', '/raiz.md')['content'], 'Editado')
        c.request('mv', '/Livros/Subpasta', destination='/Subpasta')
        self.assertEqual(c.request('ls')['entries'][2]['name'], 'raiz.md')
        c.request('rm', '/raiz.md')
        record = main._read_json('documents.json', [])[0]
        self.assertEqual(record['content'], '')
        self.assertTrue(record['deletedAt'])
        self.assertEqual(c.request('tree')['documents'], [])

    def test_conflicts_and_folder_cycles_do_not_change_existing_data(self):
        c = self.client
        c.request('mkdir', '/A')
        c.request('mkdir', '/A/B')
        with self.assertRaisesRegex(ValueError, 'itself'):
            c.request('mv', '/A', destination='/A/B/C')
        c.request('put', '/A/book.md', content='old')
        old = c.request('get', '/A/book.md')
        c.request('put', '/A/book.md', content='new', expectedUpdatedAt=old['updatedAt'])
        with self.assertRaisesRegex(ValueError, 'changed'):
            c.request('put', '/A/book.md', content='stale', expectedUpdatedAt=old['updatedAt'])
        with self.assertRaisesRegex(ValueError, 'changed'):
            c.request('put', '/A/book.md', content='overwrite without revision')
        self.assertEqual(c.request('get', '/A/book.md')['content'], 'new')
        with self.assertRaisesRegex(ValueError, 'not empty'):
            c.request('rm', '/A')
        c.request('rm', '/A', recursive=True)
        self.assertEqual(c.request('tree'), {'documents': [], 'folders': []})

    def test_disabled_and_token_protect_all_library_endpoints(self):
        main.configure_cli(False)
        with self.assertRaisesRegex(ValueError, 'disabled'):
            self.client.request('ls')
        main.configure_cli(True)
        main.TOKEN = 'test-secret'
        with self.assertRaisesRegex(ValueError, 'authentication'):
            self.client.request('ls')
        for method in ['GET', 'HEAD', 'PUT']:
            request = urllib.request.Request(self.client.base + '/api/documents', method=method)
            with self.assertRaises(urllib.error.HTTPError) as result:
                urllib.request.urlopen(request)
            self.assertEqual(result.exception.code, 401)
        self.client.token = 'test-secret'
        self.assertEqual(self.client.request('ls'), {'entries': []})
        with urllib.request.urlopen(self.client.base + '/healthz') as response:
            self.assertTrue(json.load(response)['authentication'])

    def test_config_is_persistent_and_not_part_of_synced_preferences(self):
        url = self.client.base + '/api/server-config'
        request = urllib.request.Request(url, data=b'{"cliEnabled":false}', method='PUT')
        with urllib.request.urlopen(request) as response:
            self.assertEqual(json.load(response), {'cliEnabled': False})
        self.assertFalse(main.health_payload()['cli_enabled'])
        self.assertFalse(Path(self.tmp.name, 'settings.json').exists())

    def test_upload_export_and_noninteractive_delete_confirmation(self):
        c = self.client
        source = Path(self.tmp.name, 'source.md')
        source.write_bytes('á\r\nlong text'.encode('utf-8'))
        exported = Path(self.tmp.name, 'out.md')
        with contextlib.redirect_stdout(io.StringIO()):
            c.execute(['upload', str(source), '/imported.md'])
            c.execute(['download', '/imported.md', str(exported)])
        self.assertEqual(exported.read_bytes(), source.read_bytes())
        with self.assertRaises(FileExistsError):
            c.execute(['download', '/imported.md', str(exported)])
        with self.assertRaisesRegex(ValueError, '--yes'):
            c.execute(['rm', '/imported.md'])
        with contextlib.redirect_stdout(io.StringIO()):
            c.execute(['rm', '/imported.md', '--yes'])
        self.assertEqual(c.request('ls')['entries'], [])

    def test_conflicted_editor_recovers_local_changes(self):
        c = self.client
        c.request('put', '/edit.md', content='initial')
        def editor(arguments, check):
            Path(arguments[-1]).write_bytes(b'local edit\r\n')
            record = c.request('get', '/edit.md')
            c.request('put', '/edit.md', content='concurrent edit', expectedUpdatedAt=record['updatedAt'])
        output = io.StringIO()
        with patch('sepia.subprocess.run', side_effect=editor), contextlib.redirect_stderr(output):
            with self.assertRaisesRegex(ValueError, 'changed'):
                c.execute(['edit', '/edit.md'])
        recovery = Path(output.getvalue().strip().split(' em ', 1)[1])
        try:
            self.assertEqual(recovery.read_bytes(), b'local edit\r\n')
        finally:
            recovery.unlink()
        self.assertEqual(c.request('get', '/edit.md')['content'], 'concurrent edit')

    def test_corrupt_data_is_not_overwritten_by_a_cli_write(self):
        path = Path(self.tmp.name, 'documents.json')
        path.write_text('{invalid data', encoding='utf-8')
        with self.assertRaisesRegex(ValueError, 'cannot read library data'):
            self.client.request('put', '/new.md', content='must not overwrite')
        self.assertEqual(path.read_text(), '{invalid data')

    def test_invalid_text_and_names_are_rejected(self):
        c = self.client
        for name, content in [('/bad.pdf', 'pdf'), ('/bad.txt', '\x00'), ('/huge.txt', 'a' * (5 * 1024 * 1024 + 1))]:
            with self.assertRaises(ValueError):
                c.request('put', name, content=content)
        with self.assertRaises(ValueError):
            c.request('mkdir', '/')
        c.request('mkdir', '/book.md')
        with self.assertRaisesRegex(ValueError, 'exists'):
            c.request('put', '/book.md', content='cannot replace folder')
        self.assertEqual(c.request('tree')['documents'], [])


if __name__ == '__main__':
    unittest.main()
