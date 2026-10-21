import hashlib
import io
import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import wave
from types import SimpleNamespace
from pathlib import Path
from unittest.mock import patch

import main
import server_tts


def wav_bytes():
    data = io.BytesIO()
    with wave.open(data, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(24000)
        wav.writeframes(b'\0' * 480)
    return data.getvalue()


class SpeechApiTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.old_data, self.old_token = main.DATA_DIR, main.TOKEN
        main.DATA_DIR, main.TOKEN = self.tmp.name, 'test-device-token'
        self.env = patch.dict(os.environ, {'SEPIA_TTS_MODEL_DIR': '', 'SEPIA_TTS_ENABLED': '0'})
        self.env.start()
        self.server = main.Server(('127.0.0.1', 0), main.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = f'http://127.0.0.1:{self.server.server_port}'

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        main.DATA_DIR, main.TOKEN = self.old_data, self.old_token
        self.env.stop()
        self.tmp.cleanup()

    def request(self, path, data=None, method=None, token='test-device-token'):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(self.base + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
        return urllib.request.urlopen(request, timeout=10)

    def test_credentials_checked_before_voice_or_audio_operations(self):
        for path, data in [('/api/tts/voices', None), ('/api/tts/speech', {'text': 'Hello'})]:
            with self.assertRaises(urllib.error.HTTPError) as error:
                self.request(path, data, token='wrong')
            self.assertEqual(error.exception.code, 401)
            error.exception.close()

    def test_unconfigured_backend_is_optional_and_off(self):
        with self.request('/api/tts/voices') as response:
            result = json.load(response)
        self.assertFalse(result['enabled'])
        self.assertFalse(result['available'])
        self.assertEqual(result['reason'], 'not-configured')
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request('/api/tts/speech', {'text': 'Hello'})
        self.assertEqual(error.exception.code, 503)
        error.exception.close()
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request('/api/server-config', {'ttsEnabled': True}, 'PUT')
        self.assertEqual(error.exception.code, 503)
        error.exception.close()

    def fake_backend(self, render=None):
        def synthesize(directory, payload):
            server_tts.validate_request(payload)
            self.assertFalse(main.DATA_LOCK.locked())
            return wav_bytes()
        return SimpleNamespace(capabilities=lambda directory, enabled: {'enabled': enabled, 'available': True, 'voices': [{'id': 'M2', 'name': 'M2', 'locale': 'pt'}]},
            synthesize=render or synthesize, TtsError=server_tts.TtsError)

    def test_enabling_tts_preserves_cli_and_returns_authenticated_audio(self):
        main.configure_cli(True)
        with patch.object(main, 'tts_backend', return_value=self.fake_backend()):
            with self.request('/api/server-config', {'ttsEnabled': True}, 'PUT') as response:
                self.assertEqual(json.load(response), {'cliEnabled': True, 'ttsEnabled': True})
            main.configure_cli(False)
            self.assertTrue(main.server_config()['ttsEnabled'])
            with self.request('/api/tts/speech', {'text': 'Olá… tudo bem?', 'voice': 'M2', 'language': 'pt', 'speed': 1.2}) as response:
                self.assertEqual(response.headers['Content-Type'], 'audio/wav')
                self.assertEqual(response.headers['Cache-Control'], 'no-store')
                self.assertEqual(response.read(), wav_bytes())
            with self.assertRaises(urllib.error.HTTPError) as error:
                self.request('/api/tts/speech', {'text': 'x', 'voice': '../file'})
            self.assertEqual(error.exception.code, 400)
            error.exception.close()

    def test_library_remains_available_during_synthesis(self):
        started, finish = threading.Event(), threading.Event()
        def slow(directory, payload):
            started.set()
            finish.wait(5)
            return wav_bytes()
        main._write_json_atomic('server-config.json', {'ttsEnabled': True})
        results = []
        def call():
            with self.request('/api/tts/speech', {'text': 'Olá'}) as response:
                results.append(response.read())
        with patch.object(main, 'tts_backend', return_value=self.fake_backend(slow)):
            worker = threading.Thread(target=call)
            worker.start()
            self.assertTrue(started.wait(3))
            try:
                with self.request('/api/documents') as response:
                    self.assertEqual(json.load(response), [])
            finally:
                finish.set()
                worker.join()
        self.assertEqual(len(results), 1)

    def test_payload_is_bounded_before_model_allocation(self):
        with self.assertRaises(urllib.error.HTTPError) as error:
            self.request('/api/tts/speech', {'text': 'x' * 20000})
        self.assertEqual(error.exception.code, 413)
        error.exception.close()


class SpeechValidationTest(unittest.TestCase):
    def test_invalid_input_and_nonfinite_rates(self):
        for payload in [[], {}, {'text': ''}, {'text': 'x' * 1201}, {'text': 'x', 'speed': float('nan')}, {'text': 'x', 'speed': True},
                        {'text': 'x', 'voice': '../M1'}, {'text': 'x', 'language': 'invalid'}]:
            with self.assertRaises(server_tts.TtsError):
                server_tts.validate_request(payload)

    def test_busy_requests_do_not_queue_or_allocate_models(self):
        server_tts._LOCK.acquire()
        try:
            with self.assertRaises(server_tts.TtsError) as error:
                server_tts.synthesize('', {'text': 'Hello'})
            self.assertEqual(error.exception.status, 429)
        finally:
            server_tts._LOCK.release()


class ModelInstallTest(unittest.TestCase):
    def test_interrupted_download_retries_atomically_and_rejects_oversized_model(self):
        content = b'verified model bytes'
        entry = {'path': 'onnx/model.onnx', 'actual_size': len(content),
                 'sha256': hashlib.sha256(content).hexdigest(), 'repo': 'test/model', 'revision': 'fixed'}
        with tempfile.TemporaryDirectory() as directory, patch.object(server_tts, 'manifest', return_value=[entry]), \
                patch.object(server_tts.time, 'sleep'), patch.object(server_tts.urllib.request, 'urlopen',
                side_effect=[ConnectionResetError(), io.BytesIO(content), io.BytesIO(content + b'extra')]) as download:
            server_tts.install(directory)
            target = Path(directory) / entry['path']
            self.assertEqual(target.read_bytes(), content)
            self.assertFalse(target.with_suffix('.onnx.part').exists())
            server_tts.install(directory)
            self.assertEqual(download.call_count, 2)
            target.write_bytes(b'old incomplete installation')
            with self.assertRaises(ValueError):
                server_tts.install(directory)
            self.assertEqual(target.read_bytes(), b'old incomplete installation')
            self.assertFalse(target.with_suffix('.onnx.part').exists())
