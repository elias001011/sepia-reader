import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

  test('inicialização local não espera nem inicia a rede', () async {
    SharedPreferences.setMockInitialValues({
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': true,
        'syncServerUrl': 'http://sync.test',
      }),
      'sepia.settings.v1': jsonEncode(
        const AppSettings(syncEnabled: true).toJson(),
      ),
    });
    var requests = 0;
    var gets = 0;
    final storage = StorageService(
      client: MockClient((request) async {
        requests++;
        if (request.method == 'GET') gets++;
        return http.Response(
          request.url.path == '/api/settings' ? '{}' : '[]',
          200,
        );
      }),
    );
    final controller = AppController(
      storage: storage,
      updateChecker: offlineUpdateChecker(),
    );

    await controller.initialize();

    expect(requests, 0, reason: 'a primeira tela deve depender só do disco');
    expect(controller.documents, isNotEmpty);

    await controller.syncAfterLaunch();
    expect(gets, 4, reason: 'o sync começa somente depois da abertura');
    expect(requests, greaterThanOrEqualTo(gets));
  });

  test('edição feita durante o sync de abertura não é sobrescrita', () async {
    final old = document('antigo', DateTime.utc(2026, 8, 29, 1));
    SharedPreferences.setMockInitialValues({
      'sepia.syncconfig.v1': jsonEncode({
        'syncEnabled': true,
        'syncServerUrl': 'http://sync.test',
      }),
      'sepia.documents.v1': jsonEncode([old.toJson()]),
    });
    final documentsStarted = Completer<void>();
    final releaseDocuments = Completer<void>();
    final storage = StorageService(
      client: MockClient((request) async {
        if (request.method == 'PUT') return http.Response(request.body, 200);
        if (request.url.path == '/api/documents') {
          documentsStarted.complete();
          await releaseDocuments.future;
          return http.Response(jsonEncode([old.toJson()]), 200);
        }
        return http.Response(
          request.url.path == '/api/settings' ? '{}' : '[]',
          200,
        );
      }),
    );
    final controller = AppController(
      storage: storage,
      updateChecker: offlineUpdateChecker(),
    );
    await controller.initialize();

    final syncing = controller.syncAfterLaunch();
    await documentsStarted.future;
    await controller.updateDocument(
      controller.documentById('d')!.copyWith(content: 'editado durante sync'),
    );
    releaseDocuments.complete();
    await syncing;

    expect(controller.documentById('d')!.content, 'editado durante sync');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('sepia.documents.v1'),
      contains('editado durante sync'),
    );
  });

  test('teste de conexão usa o healthz pequeno', () async {
    final paths = <String>[];
    final storage = StorageService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        return http.Response('{"ok":true}', 200);
      }),
    );

    final result = await storage.testConnection('http://sync.test');

    expect(result.ok, isTrue);
    expect(result.documentCount, isNull);
    expect(paths, ['/healthz']);
  });

  test('teste de conexão ainda aceita servidor anterior ao healthz', () async {
    final paths = <String>[];
    final storage = StorageService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/healthz') return http.Response('', 404);
        return http.Response(
          '[{"id":"a"},{"id":"b","deletedAt":"2026-08-29"}]',
          200,
        );
      }),
    );

    final result = await storage.testConnection('http://sync.test');

    expect(result.ok, isTrue);
    expect(result.documentCount, 1);
    expect(paths, ['/healthz', '/api/documents']);
  });

  group('relógio de merge das configurações', () {
    Future<AppSettings> loadWith({
      required DateTime localAt,
      required DateTime serverAt,
      required Color localColor,
      required Color serverColor,
      void Function(http.Request)? onPut,
    }) async {
      SharedPreferences.setMockInitialValues({
        'sepia.syncconfig.v1': jsonEncode({
          'syncEnabled': true,
          'syncServerUrl': 'http://sync.test',
        }),
        'sepia.settings.v1': jsonEncode(
          AppSettings(seedColor: localColor)
              .copyWith(settingsUpdatedAt: localAt)
              .toJson(),
        ),
      });
      final storage = StorageService(
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            onPut?.call(request);
            return http.Response('{}', 200);
          }
          if (request.url.path == '/api/settings') {
            return http.Response(
              jsonEncode(
                AppSettings(seedColor: serverColor)
                    .copyWith(settingsUpdatedAt: serverAt)
                    .toJson(),
              ),
              200,
            );
          }
          return http.Response('[]', 200);
        }),
      );
      final loaded = await storage.loadSettings();
      await storage.waitForPendingSync();
      return loaded;
    }

    test('uma cópia mais antiga do servidor não sobrescreve a local', () async {
      http.Request? pushed;
      final loaded = await loadWith(
        localAt: DateTime.utc(2026, 8, 27, 10),
        serverAt: DateTime.utc(2026, 8, 27, 9),
        localColor: const Color(0xFF112233),
        serverColor: const Color(0xFF999999),
        onPut: (request) => pushed = request,
      );

      expect(loaded.seedColor, const Color(0xFF112233));
      expect(pushed, isNotNull, reason: 'a local mais nova é reenviada');
    });

    test('uma cópia mais nova do servidor substitui a local', () async {
      final loaded = await loadWith(
        localAt: DateTime.utc(2026, 8, 27, 9),
        serverAt: DateTime.utc(2026, 8, 27, 10),
        localColor: const Color(0xFF112233),
        serverColor: const Color(0xFF999999),
      );

      expect(loaded.seedColor, const Color(0xFF999999));
    });

    test(
      'instalação nova adota a configuração do servidor sem relógio',
      () async {
        SharedPreferences.setMockInitialValues({
          'sepia.syncconfig.v1': jsonEncode({
            'syncEnabled': true,
            'syncServerUrl': 'http://sync.test',
          }),
        });
        final storage = StorageService(
          client: MockClient((request) async {
            if (request.url.path == '/api/settings') {
              return http.Response(
                jsonEncode(const {
                  'seedColor': 0xFF445566,
                  'themeMode': 'dark',
                }),
                200,
              );
            }
            return http.Response('[]', 200);
          }),
        );

        final loaded = await storage.loadSettings();

        expect(loaded.seedColor, const Color(0xFF445566));
        expect(loaded.themeMode, ThemeMode.dark);
      },
    );

    test('configuração remota malformada não derruba o sync', () async {
      SharedPreferences.setMockInitialValues({
        'sepia.syncconfig.v1': jsonEncode({
          'syncEnabled': true,
          'syncServerUrl': 'http://sync.test',
        }),
        'sepia.settings.v1': jsonEncode(
          const AppSettings(seedColor: Color(0xFF112233)).toJson(),
        ),
      });
      final storage = StorageService(
        client: MockClient((request) async {
          if (request.url.path == '/api/settings') {
            // Valid JSON object, wrong type where fromJson expects a String.
            return http.Response(jsonEncode(const {'themeMode': 123}), 200);
          }
          return http.Response('[]', 200);
        }),
      );

      final result = await storage.forcePull();

      expect(result.reachedServer, isTrue);
      expect(result.settings.seedColor, const Color(0xFF112233));
    });
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
