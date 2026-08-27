import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sepia_reader/models/app_settings.dart';
import 'package:sepia_reader/models/library_document.dart';
import 'package:sepia_reader/services/storage_service.dart';
import 'package:sepia_reader/state/app_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/offline_updates.dart';

LibraryDocument document(String content, DateTime updatedAt) => LibraryDocument(
  id: 'd',
  title: 'Documento',
  content: content,
  extension: 'md',
  createdAt: DateTime(2026),
  updatedAt: updatedAt,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('migração da configuração de sync', () {
    test('preserva a configuração gravada no payload antigo', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.settings.v1': jsonEncode(
          const AppSettings(
            syncEnabled: true,
            syncServerUrl: 'http://192.168.2.5:8888',
          ).toJson(),
        ),
      });

      final config = await StorageService().loadSyncConfig();

      expect(config.enabled, isTrue);
      expect(config.serverUrl, 'http://192.168.2.5:8888');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('sepia.syncconfig.v1'), isNotNull);
    });

    test('payload anterior ao switch mantém o sync na origem', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.settings.v1': jsonEncode({'localeCode': 'pt_BR'}),
      });

      final config = await StorageService().loadSyncConfig();

      expect(config.enabled, isTrue);
      expect(config.serverUrl, isEmpty);
    });

    test('instalação realmente nova continua com sync desligado', () async {
      final config = await StorageService().loadSyncConfig();

      expect(config.enabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(
        jsonDecode(prefs.getString('sepia.syncconfig.v1')!),
        containsPair('syncEnabled', false),
      );
    });

    test('a chave local explícita continua autoritativa', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.settings.v1': jsonEncode(
          const AppSettings(syncEnabled: true).toJson(),
        ),
        'sepia.syncconfig.v1': jsonEncode({
          'syncEnabled': false,
          'syncServerUrl': '',
        }),
      });

      final config = await StorageService().loadSyncConfig();

      expect(config.enabled, isFalse);
    });
  });

  test('PUTs são serializados e pedem merge ao servidor', () async {
    SharedPreferences.setMockInitialValues({
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': true,
        'syncServerUrl': 'http://sync.test',
      }),
    });
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'PUT') {
        requests.add(request);
        if (requests.length == 1) {
          firstStarted.complete();
          await releaseFirst.future;
        }
      }
      return http.Response('[]', 200);
    });
    final storage = StorageService(client: client);

    await storage.saveDocuments([
      document('primeiro', DateTime(2026, 8, 27, 1)),
    ]);
    await firstStarted.future;
    await storage.saveDocuments([
      document('segundo', DateTime(2026, 8, 27, 2)),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(
      requests,
      hasLength(1),
      reason: 'o segundo PUT deve esperar o primeiro',
    );
    releaseFirst.complete();
    await storage.waitForPendingSync();
    expect(requests, hasLength(2));
    expect(
      requests.every((r) => r.headers['X-Sepia-Write-Mode'] == 'merge'),
      isTrue,
    );
    expect(requests.last.body, contains('segundo'));
  });

  test('configuração remota não recebe o endereço local de sync', () async {
    SharedPreferences.setMockInitialValues({
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': true,
        'syncServerUrl': 'http://sync.test',
      }),
    });
    http.Request? pushed;
    final storage = StorageService(
      client: MockClient((request) async {
        pushed = request;
        return http.Response('{}', 200);
      }),
    );

    await storage.saveSettings(
      const AppSettings(
        syncEnabled: true,
        syncServerUrl: 'http://192.168.2.5:8888',
      ),
    );
    await storage.waitForPendingSync();

    final body = jsonDecode(pushed!.body) as Map<String, dynamic>;
    expect(body, isNot(contains('syncEnabled')));
    expect(body, isNot(contains('syncServerUrl')));
  });

  test('favoritar avança o relógio usado pelo merge', () async {
    final controller = AppController(updateChecker: offlineUpdateChecker());
    await controller.initialize();
    final created = await controller.createDocument(title: 'Relógio');
    await Future<void>.delayed(const Duration(milliseconds: 2));

    await controller.toggleFavorite(created.id);

    final updated = controller.documentById(created.id)!;
    expect(updated.isFavorite, isTrue);
    expect(updated.updatedAt, isNot(created.updatedAt));
    expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
  });
}
