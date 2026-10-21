"""Optional, local Supertonic 3 inference. Never imported by basic sync/CLI use.

Install assets explicitly: python3 server_tts.py --install /path/to/models
The weights' own Open RAIL-M license is downloaded unchanged with the model.
"""
import argparse
import hashlib
from http.client import IncompleteRead
import importlib.util
import io
import json
import math
import os
from pathlib import Path
import threading
import time
import urllib.request
import wave

ROOT = Path(__file__).resolve().parent
LANGUAGES = ('en ko ja ar bg cs da de el es et fi fr hi hr hu id it lt lv nl pl pt ro ru sk sl sv tr uk vi').split()
_MODEL = None
_STYLES = None
_DIRECTORY = None
_LOCK = threading.Lock()

class TtsError(ValueError):
    def __init__(self, code, status=400):
        super().__init__(code)
        self.status = status


def manifest():
    return json.loads((ROOT / 'supertonic-model.json').read_text())


def capabilities(directory, enabled):
    result = {'enabled': False, 'available': False, 'model': 'Supertonic 3',
              'languages': LANGUAGES, 'voices': [
                  {'id': 'M2', 'name': 'Supertonic 3 M2', 'locale': 'pt'},
                  {'id': 'M1', 'name': 'Supertonic 3 M1', 'locale': 'pt'}]}
    if not directory:
        return dict(result, reason='not-configured')
    if any(importlib.util.find_spec(name) is None for name in ['numpy', 'onnxruntime']):
        return dict(result, reason='missing-runtime')
    try:
        folder = Path(directory)
        if any(not (folder / f['path']).is_file() or (folder / f['path']).stat().st_size != f['actual_size'] for f in manifest()):
            return dict(result, reason='missing-models')
    except (OSError, ValueError, KeyError):
        return dict(result, reason='missing-models')
    return dict(result, available=True, enabled=bool(enabled), reason=None if enabled else 'disabled')


def _load(directory):
    global _MODEL, _STYLES, _DIRECTORY
    if _MODEL is not None and _DIRECTORY == directory:
        return _MODEL, _STYLES
    import onnxruntime as ort
    from vendor import supertonic as helper
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = max(1, min(8, int(os.environ.get('SEPIA_TTS_THREADS', '2'))))
    opts.inter_op_num_threads = 1
    opts.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    folder = Path(directory)
    onnx = str(folder / 'onnx')
    class BoundedTts(helper.TextToSpeech):
        def sample_noisy_latent(self, duration):
            import numpy as np
            if not np.isfinite(duration).all() or (duration <= 0).any() or (duration > 90).any():
                raise TtsError('invalid-audio-duration', 422)
            return super().sample_noisy_latent(duration)
    model = BoundedTts(helper.load_cfgs(onnx), helper.load_text_processor(onnx),
        *helper.load_onnx_all(onnx, opts, ['CPUExecutionProvider']))
    styles = {name: helper.load_voice_style([str(folder / 'voice_styles' / (name + '.json'))]) for name in ['M1', 'M2']}
    _MODEL, _STYLES, _DIRECTORY = model, styles, directory
    return model, styles


def validate_request(payload):
    if not isinstance(payload, dict):
        raise TtsError('expected-object')
    text, voice, language, speed = (payload.get('text'), payload.get('voice', 'M2'),
        payload.get('language', 'pt'), payload.get('speed', 1))
    if not isinstance(text, str) or not text.strip() or len(text) > 1200:
        raise TtsError('text-must-contain-1-to-1200-characters')
    if voice not in ('M1', 'M2') or language not in LANGUAGES:
        raise TtsError('invalid-voice-or-language')
    if isinstance(speed, bool) or not isinstance(speed, (int, float)) or not math.isfinite(speed) or not .5 <= speed <= 2:
        raise TtsError('invalid-speed')
    return text, voice, language, float(speed)


def synthesize(directory, payload):
    text, voice, language, speed = validate_request(payload)
    # No waiting queue: one active synthesis, independent of the library lock.
    if not _LOCK.acquire(blocking=False):
        raise TtsError('tts-busy', 429)
    try:
        import numpy as np
        from vendor import supertonic as helper
        model, styles = _load(directory)
        parts = []
        total = 0
        for chunk in helper.chunk_text(text, max_len=120 if language in ('ja', 'ko') else 300):
            samples, duration = model._infer([chunk], [language], styles[voice], total_step=8, speed=speed)
            audio = samples[0, :int(model.sample_rate * float(duration[0]))]
            if not audio.size or not np.isfinite(audio).all():
                raise TtsError('invalid-audio', 422)
            total += audio.size
            if total > model.sample_rate * 120:
                raise TtsError('audio-too-long', 413)
            parts.extend([audio, np.zeros(int(model.sample_rate * .2), dtype=np.float32)])
        if not parts:
            raise TtsError('empty-audio', 422)
        audio = np.concatenate([np.zeros(int(model.sample_rate * .12), dtype=np.float32), *parts])
        peak = float(np.abs(audio).max())
        if peak > .98:
            audio *= .98 / peak
        output = io.BytesIO()
        with wave.open(output, 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(model.sample_rate)
            wav.writeframes((audio.clip(-1, 1) * 32767).astype('<i2').tobytes())
        return output.getvalue()
    finally:
        _LOCK.release()


def install(directory):
    directory = Path(directory)
    directory.mkdir(parents=True, exist_ok=True)
    def digest(path):
        with path.open('rb') as f:
            return hashlib.file_digest(f, 'sha256').hexdigest()
    for entry in manifest():
        target = directory / entry['path']
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.is_file() and target.stat().st_size == entry['actual_size'] and digest(target) == entry['sha256']:
            continue
        temp = target.with_name(target.name + '.part')
        url = f"https://huggingface.co/{entry['repo']}/resolve/{entry['revision']}/{entry['path']}"
        for attempt in range(3):
            try:
                with urllib.request.urlopen(url, timeout=60) as response, temp.open('wb') as f:
                    size = 0
                    while chunk := response.read(256 * 1024):
                        size += len(chunk)
                        if size > entry['actual_size']:
                            raise ValueError('model exceeds expected size')
                        f.write(chunk)
                if size != entry['actual_size'] or digest(temp) != entry['sha256']:
                    raise ValueError('model checksum mismatch')
                temp.replace(target)
                break
            except (OSError, EOFError, IncompleteRead):
                if attempt == 2:
                    raise
                time.sleep(2 ** attempt)
            finally:
                temp.unlink(missing_ok=True)
        print('Installed:', entry['path'], flush=True)
    print('Model ready. License:', directory / 'LICENSE')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--install', required=True, metavar='MODEL_DIRECTORY')
    install(parser.parse_args().install)
