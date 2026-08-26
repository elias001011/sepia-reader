import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sepia_reader/services/tts/voice_catalog.dart';
import 'package:sepia_reader/services/tts/voice_download_manager.dart';
import 'package:sepia_reader/services/tts/voice_store.dart';

/// A store that records what it was asked to do and only finishes an install
/// when the test says so, so overlapping requests are observable.
class FakeStore implements VoiceStorage {
  final installOrder = <String>[];
  final removed = <String>[];
  final Map<String, Completer<void>> _pending = {};
  final Set<String> installed = {};
  int concurrent = 0;
  int peakConcurrent = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> isInstalled(VoicePack pack) async => installed.contains(pack.id);

  @override
  Future<List<VoicePack>> installedPacks() async =>
      voicePacks.where((pack) => installed.contains(pack.id)).toList();

  Future<int> installedSize(VoicePack pack) async => 0;

  @override
  Future<void> remove(VoicePack pack) async {
    removed.add(pack.id);
    installed.remove(pack.id);
  }

  @override
  Future<void> install(
    VoicePack pack, {
    void Function(VoiceInstallProgress)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    installOrder.add(pack.id);
    concurrent++;
    peakConcurrent = concurrent > peakConcurrent ? concurrent : peakConcurrent;
    final completer = Completer<void>();
    _pending[pack.id] = completer;
    try {
      onProgress?.call(
        const VoiceInstallProgress(
          filesDone: 1,
          filesTotal: 2,
          bytesDone: 50,
          bytesTotal: 100,
        ),
      );
      await completer.future;
      if (shouldCancel?.call() ?? false) throw const VoiceInstallCancelled();
      installed.add(pack.id);
    } finally {
      concurrent--;
    }
  }

  void finish(String packId) {
    final completer = _pending.remove(packId);
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void fail(String packId, Object error) {
    final completer = _pending.remove(packId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
    }
  }

  bool isRunning(String packId) => _pending.containsKey(packId);
}

VoicePack packAt(int index) => voicePacks[index];

void main() {
  test('downloads pedidos ao mesmo tempo entram em fila, não em corrida', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    manager.enqueue(packAt(1));
    manager.enqueue(packAt(2));
    await Future<void>.delayed(Duration.zero);

    expect(store.installOrder, [packAt(0).id]);
    expect(manager.jobs, hasLength(3));

    store.finish(packAt(0).id);
    await Future<void>.delayed(Duration.zero);
    expect(store.installOrder, [packAt(0).id, packAt(1).id]);

    store.finish(packAt(1).id);
    await Future<void>.delayed(Duration.zero);
    store.finish(packAt(2).id);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      store.peakConcurrent,
      1,
      reason: 'dois downloads ao mesmo tempo podem escrever os mesmos '
          'arquivos quando compartilham um modelo',
    );
    expect(manager.jobs, isEmpty);
    expect(manager.isInstalled(packAt(0)), isTrue);
  });

  test('pedir a mesma voz duas vezes não baixa duas vezes', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    manager.enqueue(packAt(0));
    manager.enqueue(packAt(0));
    await Future<void>.delayed(Duration.zero);

    expect(manager.jobs, hasLength(1));
    store.finish(packAt(0).id);
    await Future<void>.delayed(Duration.zero);
    expect(store.installOrder, [packAt(0).id]);
  });

  test('uma voz já instalada não é enfileirada', () async {
    final store = FakeStore()..installed.add(packAt(0).id);
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    await Future<void>.delayed(Duration.zero);

    expect(manager.jobs, isEmpty);
    expect(store.installOrder, isEmpty);
  });

  test('cancelar na fila remove o pedido sem tocar no disco', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    manager.enqueue(packAt(1));
    await Future<void>.delayed(Duration.zero);

    manager.cancel(packAt(1));
    expect(manager.jobFor(packAt(1)), isNull);

    store.finish(packAt(0).id);
    await Future<void>.delayed(Duration.zero);
    expect(store.installOrder, [packAt(0).id]);
  });

  test('cancelar em andamento devolve os arquivos', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    await Future<void>.delayed(Duration.zero);
    manager.cancel(packAt(0));
    store.finish(packAt(0).id);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(store.removed, [packAt(0).id]);
    expect(manager.isInstalled(packAt(0)), isFalse);
    expect(manager.jobs, isEmpty);
  });

  test('uma falha não bloqueia a fila e pode ser tentada de novo', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();

    manager.enqueue(packAt(0));
    manager.enqueue(packAt(1));
    await Future<void>.delayed(Duration.zero);

    store.fail(packAt(0).id, StateError('sem rede'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final failed = manager.jobFor(packAt(0));
    expect(failed?.state, VoiceDownloadState.failed);
    expect(failed?.error, contains('sem rede'));
    // The next one still ran.
    expect(store.installOrder, contains(packAt(1).id));

    manager.dismiss(packAt(0));
    expect(manager.jobFor(packAt(0)), isNull);
    manager.enqueue(packAt(0));
    expect(manager.jobFor(packAt(0)), isNotNull);
  });

  test('o progresso do download em curso fica visível', () async {
    final store = FakeStore();
    final manager = VoiceDownloadManager(store: store);
    await manager.refreshInstalled();
    var notifications = 0;
    manager.addListener(() => notifications++);

    manager.enqueue(packAt(0));
    await Future<void>.delayed(Duration.zero);

    expect(manager.jobFor(packAt(0))?.fraction, 0.5);
    expect(notifications, greaterThan(0));
  });
}
