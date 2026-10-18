import 'dart:async';

/// A bounded, single-worker synthesis queue. Only the current utterance and
/// one look-ahead may wait. Cancelling resolves callers immediately; an FFI
/// call already running may finish, but its result is discarded.
class SpeechAudioBuffer<T extends Object> {
  SpeechAudioBuffer({required this.render, required this.discard});

  final Future<T> Function(String text) render;
  final void Function(T audio) discard;
  final _cache = <String, T>{};
  final _jobs = <String, _RenderJob<T>>{};
  _RenderJob<T>? _active;
  int _generation = 0;

  Future<T?> obtain(String text, {bool ahead = false}) {
    final cached = _cache[text];
    if (cached != null) {
      _cache.remove(text);
      _cache[text] = cached;
      return Future.value(cached);
    }
    final existing = _jobs[text];
    if (existing != null) {
      if (!ahead) existing.ahead = false;
      return existing.result.future;
    }
    // Replace obsolete queued look-ahead rather than accumulating a chapter
    // after quick skips. An active native call cannot be preempted safely.
    for (final job in _jobs.values.toList()) {
      if (job != _active && (job.ahead || !ahead)) {
        _jobs.remove(job.text);
        job.result.complete(null);
      }
    }
    final job = _RenderJob<T>(text, _generation, ahead);
    _jobs[text] = job;
    _pump();
    return job.result.future;
  }

  void _pump() {
    if (_active != null || _jobs.isEmpty) return;
    final job = _jobs.values.firstWhere(
      (job) => !job.ahead,
      orElse: () => _jobs.values.first,
    );
    _active = job;
    unawaited(_run(job));
  }

  Future<void> _run(_RenderJob<T> job) async {
    try {
      final audio = await render(job.text);
      if (job.generation != _generation) {
        discard(audio);
      } else {
        _cache[job.text] = audio;
        // Current, next, and the most recent utterance (resume/back).
        while (_cache.length > 3) {
          discard(_cache.remove(_cache.keys.first)!);
        }
        if (!job.result.isCompleted) job.result.complete(audio);
      }
    } catch (error, stack) {
      if (!job.result.isCompleted) job.result.completeError(error, stack);
    } finally {
      if (identical(_jobs[job.text], job)) _jobs.remove(job.text);
      _active = null;
      _pump();
    }
  }

  void clear() {
    _generation++;
    for (final job in _jobs.values) {
      if (!job.result.isCompleted) job.result.complete(null);
    }
    _jobs.clear();
    for (final audio in _cache.values) {
      discard(audio);
    }
    _cache.clear();
  }
}

class _RenderJob<T extends Object> {
  _RenderJob(this.text, this.generation, this.ahead);
  final String text;
  final int generation;
  bool ahead;
  final result = Completer<T?>();
}
